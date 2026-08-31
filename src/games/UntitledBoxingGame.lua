local UntitledBoxingGame = {}
UntitledBoxingGame.__index = UntitledBoxingGame

local function valueOf(instance)
    if not instance then return nil end
    local ok, value = pcall(function() return instance.Value end)
    return ok and value or nil
end

local function humanoidRoot(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function isEffectHelper(value)
    return type(value) == "table"
        and type(rawget(value, "AttackTrail")) == "function"
        and type(rawget(value, "StartupHighlight")) == "function"
end

local function tracebackError(message)
    local text = tostring(message)
    if type(debug) == "table" and type(debug.traceback) == "function" then
        return debug.traceback(text, 2)
    end
    return text
end

local function fullName(instance)
    return instance and instance:GetFullName() or "<missing>"
end

function UntitledBoxingGame.new(ctx)
    local self = setmetatable({
        ctx = ctx,
        Enabled = false,
        Debug = false,
        LatencyCompensation = 0.045,
        DodgeStartupTime = 0,
        FallbackRange = 9.9,
        OnlyLockedOpponent = true,
        Hooks = {},
        SeenEffects = setmetatable({}, {__mode = "k"}),
        TransitionFrom = setmetatable({}, {__mode = "k"}),
    }, UntitledBoxingGame)

    local page = ctx.Window:AddPage("Untitled Boxing Game", "M1/M2 Auto Dodge через внутренний combat flow")
    local stack = ctx.Window:ModuleStack(page, 70)
    local module = stack:Add("Auto Dodge", 300)
    self.EnabledControl = ctx.Window:Toggle(module.Settings, UDim2.fromOffset(10, 4), 220, "Enabled", false, function(value)
        self:SetEnabled(value)
        ctx.Touch()
    end)
    self.DebugControl = ctx.Window:Toggle(module.Settings, UDim2.fromOffset(240, 4), 220, "Debug", false, function(value)
        self.Debug = value
        ctx.Touch()
    end)
    self.LatencyControl = ctx.Window:Slider(module.Settings, 48, "Lead (ms)", 45, 0, 60, 1, function(value)
        self.LatencyCompensation = value / 1000
        ctx.Touch()
    end)
    self.RangeControl = ctx.Window:Slider(module.Settings, 88, "Fallback range", 9.9, 4, 15, 0.1, function(value)
        self.FallbackRange = value
        ctx.Touch()
    end)
    self.LockedControl = ctx.Window:Toggle(module.Settings, UDim2.fromOffset(10, 128), 260, "Only locked opponent", true, function(value)
        self.OnlyLockedOpponent = value
        ctx.Touch()
    end)

    local hint = Instance.new("TextLabel")
    hint.Position = UDim2.fromOffset(10, 172)
    hint.Size = UDim2.new(1, -20, 0, 42)
    hint.BackgroundTransparency = 1
    hint.Font = Enum.Font.Code
    hint.Text = "AttackTrail = timing/hit window; StartupHighlight = M1/M2 commit или cancel.\nБез AnimationId и таблиц boxing styles."
    hint.TextWrapped = true
    hint.TextColor3 = Color3.fromRGB(165, 165, 165)
    hint.TextSize = 12
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextYAlignment = Enum.TextYAlignment.Top
    hint.Parent = module.Settings

    local status = Instance.new("TextLabel")
    status.Position = UDim2.fromOffset(10, 220)
    status.Size = UDim2.new(1, -20, 0, 28)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.Code
    status.Text = "Status: disabled"
    status.TextColor3 = Color3.fromRGB(185, 185, 185)
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = module.Settings
    self.Status = status

    local Controller = ctx.LoadModule("games/AutoDodgeController")
    self.Controller = Controller.new({
        Settings = self,
        Now = function() return ctx.Workspace:GetServerTimeNow() end,
        Delay = function(delay, callback) task.delay(delay, callback) end,
        CanHit = function(attack) return self:CanAttackHit(attack) end,
        CanDodge = function(attack) return self:CanDodge(attack) end,
        Dodge = function(attack) return self:ExecuteDodge(attack) end,
        Log = function(message) print(message) end,
    })
    return self
end

function UntitledBoxingGame:SetStatus(text, errorState)
    if not self.Status then return end
    self.Status.Text = "Status: " .. text
    self.Status.TextColor3 = errorState and Color3.fromRGB(255, 115, 115) or Color3.fromRGB(185, 220, 185)
end

function UntitledBoxingGame:SetEnabled(value)
    self.Enabled = value == true
    self.Controller:SetEnabled(self.Enabled)
    if self.Enabled then
        self:SetStatus("Initializing...", false)
        local ok = self:InstallHooks()
        if ok then
            self.Initialized = true
            self:SetStatus("Ready", false)
        else
            self.Initialized = false
            self.Enabled = false
            self.Controller:SetEnabled(false)
            self.EnabledControl.Set(false)
            self:SetStatus("ERROR - see Output", true)
        end
    else
        self.Initialized = false
        self:UninstallHooks()
        self:SetStatus("disabled", false)
    end
end

function UntitledBoxingGame:FindEffectHelperModule()
    local storage = self.ctx.ReplicatedStorage
    local modules = storage:FindFirstChild("Modules")
    local expected = modules and modules:FindFirstChild("EffectHelper")
    if expected and expected:IsA("ModuleScript") then return expected, true end
    for _, candidate in ipairs(storage:GetDescendants()) do
        if candidate:IsA("ModuleScript") and candidate.Name == "EffectHelper" then return candidate, false end
    end
    return nil, false
end

function UntitledBoxingGame:FindLoadedEffectHelper()
    local environment = _G
    if type(getgenv) == "function" then
        local ok, result = pcall(getgenv)
        if ok and type(result) == "table" then environment = result end
    end
    local getGarbage = environment.getgc or getgc
    if type(getGarbage) ~= "function" then return nil, "executor does not expose getgc" end
    local ok, objects = xpcall(function() return getGarbage(true) end, tracebackError)
    if not ok or type(objects) ~= "table" then
        local firstError = objects
        ok, objects = xpcall(function() return getGarbage() end, tracebackError)
        if not ok or type(objects) ~= "table" then
            return nil, "getgc(true): " .. tostring(firstError) .. "\ngetgc(): " .. tostring(objects)
        end
    end
    for _, candidate in pairs(objects) do
        if isEffectHelper(candidate) then return candidate end
    end
    return nil, "loaded EffectHelper API table was not found in getgc"
end

function UntitledBoxingGame:ResolveEffectHelper()
    if isEffectHelper(self.EffectHelper) then return self.EffectHelper, self.EffectHelperSource end

    local moduleScript, expectedPath = self:FindEffectHelperModule()
    if moduleScript then
        print("[BezNigativa/UBG] EffectHelper ModuleScript: " .. fullName(moduleScript))
        if not expectedPath then
            warn("[BezNigativa/UBG] Expected ReplicatedStorage.Modules.EffectHelper, found alternate path: " .. fullName(moduleScript))
        end
    else
        warn("[BezNigativa/UBG] EffectHelper ModuleScript does not exist under ReplicatedStorage. Expected path: ReplicatedStorage.Modules.EffectHelper")
    end

    local loaded, getGcError = self:FindLoadedEffectHelper()
    if loaded then
        self.EffectHelper, self.EffectHelperSource = loaded, "getgc"
        print("[BezNigativa/UBG] EffectHelper API resolved from the already loaded combat table (getgc)")
        return loaded, self.EffectHelperSource
    end

    if not moduleScript then
        warn("[BezNigativa/UBG] Auto Dodge initialization failed.\n" .. tostring(getGcError))
        return nil, "EffectHelper ModuleScript missing"
    end

    local ok, result = xpcall(function()
        return require(moduleScript)
    end, tracebackError)
    if ok and isEffectHelper(result) then
        self.EffectHelper, self.EffectHelperSource = result, "require"
        print("[BezNigativa/UBG] EffectHelper API returned by require: AttackTrail=function, StartupHighlight=function")
        return result, self.EffectHelperSource
    end
    if not ok then
        warn("[BezNigativa/UBG] EffectHelper require crashed.\nModule: " .. fullName(moduleScript) .. "\nFull error/ dependency traceback:\n" .. tostring(result))
    else
        warn("[BezNigativa/UBG] EffectHelper returned an invalid API.\nModule: " .. fullName(moduleScript)
            .. "\nReturn type: " .. type(result)
            .. "\nAttackTrail: " .. type(type(result) == "table" and rawget(result, "AttackTrail") or nil)
            .. "\nStartupHighlight: " .. type(type(result) == "table" and rawget(result, "StartupHighlight") or nil))
    end

    if type(getrenv) == "function" then
        local environmentOk, runtimeEnvironment = xpcall(function() return getrenv() end, tracebackError)
        local runtimeRequire = environmentOk and type(runtimeEnvironment) == "table" and runtimeEnvironment.require or nil
        if type(runtimeRequire) == "function" and runtimeRequire ~= require then
            local runtimeOk, runtimeResult = xpcall(function() return runtimeRequire(moduleScript) end, tracebackError)
            if runtimeOk and isEffectHelper(runtimeResult) then
                self.EffectHelper, self.EffectHelperSource = runtimeResult, "getrenv require"
                print("[BezNigativa/UBG] EffectHelper API resolved through getrenv().require")
                return runtimeResult, self.EffectHelperSource
            end
            if not runtimeOk then
                warn("[BezNigativa/UBG] getrenv().require also crashed.\nModule: " .. fullName(moduleScript) .. "\nFull error/ dependency traceback:\n" .. tostring(runtimeResult))
            end
        end
    end

    loaded, getGcError = self:FindLoadedEffectHelper()
    if loaded then
        self.EffectHelper, self.EffectHelperSource = loaded, "getgc after require"
        print("[BezNigativa/UBG] EffectHelper API appeared in getgc after require")
        return loaded, self.EffectHelperSource
    end
    warn("[BezNigativa/UBG] Auto Dodge initialization failed after every resolver.\nModule: " .. fullName(moduleScript)
        .. "\ngetgc diagnostic: " .. tostring(getGcError))
    return nil, "EffectHelper resolution failed"
end

function UntitledBoxingGame:InstallHooks()
    if next(self.Hooks) then return true, self.EffectHelperSource end
    local helper, sourceOrError = self:ResolveEffectHelper()
    if not helper then
        warn("[BezNigativa/UBG] Auto Dodge is not Ready: " .. tostring(sourceOrError))
        return false, sourceOrError
    end
    local dodgeRemote = self:ResolveDodgeRemote()
    if not dodgeRemote then
        warn("[BezNigativa/UBG] Dodge RemoteEvent does not exist. Expected ReplicatedStorage.dataRemoteEvent")
        return false, "Dodge RemoteEvent missing"
    end
    local count = 0
    for _, key in ipairs({"AttackTrail", "StartupHighlight"}) do
        local original = helper[key]
        if type(original) == "function" then
            local base = original
            local wrapper = function(data, ...)
                local ok, hookError = xpcall(function() self:OnCombatEffect(data) end, tracebackError)
                if not ok and not self.HookWarning then
                    self.HookWarning = true
                    warn("[BezNigativa/UBG] combat hook crashed.\nFull traceback:\n" .. tostring(hookError))
                end
                return base(data, ...)
            end
            local wasReadonly = false
            if type(isreadonly) == "function" then
                local checked, result = pcall(isreadonly, helper)
                wasReadonly = checked and result == true
            end
            if wasReadonly and type(setreadonly) == "function" then pcall(setreadonly, helper, false) end
            local patched, patchError = xpcall(function() helper[key] = wrapper end, tracebackError)
            if wasReadonly and type(setreadonly) == "function" then pcall(setreadonly, helper, true) end
            if patched and helper[key] == wrapper then
                self.Hooks[key] = {Mode = "Table", Original = base, Wrapper = wrapper}
                count += 1
            else
                local environment = type(getgenv) == "function" and getgenv() or _G
                local hookFunction = environment.hookfunction or hookfunction
                local hookOk, previous
                if type(hookFunction) == "function" then
                    hookOk, previous = xpcall(function() return hookFunction(original, wrapper) end, tracebackError)
                end
                if hookOk and type(previous) == "function" then
                    base = previous
                    self.Hooks[key] = {
                        Mode = "HookFunction",
                        Target = original,
                        Original = previous,
                        Wrapper = wrapper,
                        HookFunction = hookFunction,
                    }
                    count += 1
                else
                    warn("[BezNigativa/UBG] Failed to install " .. key .. " hook."
                        .. "\nTable assignment error:\n" .. tostring(patchError or "table rejected assignment")
                        .. "\nhookfunction error:\n" .. tostring(previous or "hookfunction unavailable"))
                end
            end
        else
            warn("[BezNigativa/UBG] Invalid EffectHelper API: " .. key .. " is " .. type(original) .. ", expected function")
        end
    end
    if count ~= 2 then
        self:UninstallHooks()
        warn("[BezNigativa/UBG] Auto Dodge hook verification failed: installed " .. tostring(count) .. "/2 handlers")
        return false, "combat hook verification failed"
    end
    print("[BezNigativa/UBG] Auto Dodge initialized and Ready | EffectHelper=" .. tostring(sourceOrError)
        .. " | DodgeRemote=" .. fullName(dodgeRemote) .. " | Hooks=2/2")
    return true, sourceOrError
end

function UntitledBoxingGame:UninstallHooks()
    local helper = self.EffectHelper
    for key, hook in pairs(self.Hooks) do
        if hook.Mode == "HookFunction" then
            local environment = type(getgenv) == "function" and getgenv() or _G
            local restoreFunction = environment.restorefunction or restorefunction
            if type(restoreFunction) == "function" then
                pcall(restoreFunction, hook.Target)
            elseif type(hook.HookFunction) == "function" then
                pcall(hook.HookFunction, hook.Target, hook.Original)
            end
        elseif helper and helper[key] == hook.Wrapper then
                local wasReadonly = false
                if type(isreadonly) == "function" then
                    local checked, result = pcall(isreadonly, helper)
                    wasReadonly = checked and result == true
                end
                if wasReadonly and type(setreadonly) == "function" then pcall(setreadonly, helper, false) end
                pcall(function() helper[key] = hook.Original end)
                if wasReadonly and type(setreadonly) == "function" then pcall(setreadonly, helper, true) end
        end
    end
    self.Hooks = {}
    self.SeenEffects = setmetatable({}, {__mode = "k"})
end

function UntitledBoxingGame:SourceAttackId(data)
    for _, key in ipairs({"AttackId", "AttackID", "SequenceId", "SequenceID", "ActionId", "ActionID"}) do
        if data[key] ~= nil then return data[key] end
    end
    local nested = data.Attack or data.Action or data.HitboxData
    if type(nested) == "table" then
        for _, key in ipairs({"AttackId", "AttackID", "SequenceId", "SequenceID", "Id", "ID"}) do
            if nested[key] ~= nil then return nested[key] end
        end
    end
    return data
end

function UntitledBoxingGame:ImpactTime(data)
    local now = self.ctx.Workspace:GetServerTimeNow()
    local absolute = tonumber(data.ImpactTime or data.HitTime or data.ActiveTime)
    if absolute then return absolute > now - 1 and absolute or now + math.max(0, absolute) end
    local offset = tonumber(data.TimeUntilImpact or data.ImpactDelay or data.Delay)
    if offset then return now + math.max(0, offset) end
    local trailWindow = tonumber(data[5])
    if trailWindow and trailWindow >= 0 and trailWindow <= 5 then return now + trailWindow end
    return nil
end

function UntitledBoxingGame:PayloadHitbox(data)
    local source = type(data.HitboxData) == "table" and data.HitboxData or data
    local hitbox = {}
    local cframe = source.CFrame or source.HitboxCFrame or source.BoxCFrame
    local size = source.Size or source.HitboxSize or source.BoxSize
    local range = tonumber(source.Range or source.HitboxRange or source.Reach)
    if typeof(cframe) == "CFrame" then hitbox.CFrame = cframe end
    if typeof(size) == "Vector3" then hitbox.Size = size end
    if range then hitbox.Range = range end
    return hitbox
end

function UntitledBoxingGame:RememberTransition(attacker)
    local current = self.Controller:GetCurrent(attacker)
    if current and current.AttackType then self.TransitionFrom[attacker] = current.AttackType end
end

function UntitledBoxingGame:CommitCurrent(attacker, attackType)
    local current = self.Controller:GetCurrent(attacker)
    if not current then return end
    if self.TransitionFrom[attacker] and self.TransitionFrom[attacker] ~= attackType then
        self.Controller:Log(self.TransitionFrom[attacker] .. " -> " .. attackType .. " detected")
    end
    self.TransitionFrom[attacker] = nil
    current.AttackType = attackType
    if current.ImpactTime then
        self.Controller:Commit(attacker, current.AttackId, attackType, current.ImpactTime, current.HitboxData)
    end
end

function UntitledBoxingGame:OnAttackTrail(data, attacker)
    local impactTime = self:ImpactTime(data)
    if not impactTime then return end
    local hitbox = self:PayloadHitbox(data)
    local current = self.Controller:GetCurrent(attacker)
    if current and current.State == "Started" and current.AttackType and not current.ImpactTime then
        if self.TransitionFrom[attacker] and self.TransitionFrom[attacker] ~= current.AttackType then
            self.Controller:Log(self.TransitionFrom[attacker] .. " -> " .. current.AttackType .. " detected")
        end
        self.TransitionFrom[attacker] = nil
        current.ImpactTime, current.HitboxData = impactTime, hitbox
        self.Controller:Commit(attacker, current.AttackId, current.AttackType, impactTime, hitbox)
        return
    end
    self:RememberTransition(attacker)
    local attack = self.Controller:Start(attacker, self:SourceAttackId(data), nil, self.ctx.Workspace:GetServerTimeNow(), impactTime, hitbox)
    if attack then attack.SourceStage = "AttackTrail" end
end

function UntitledBoxingGame:OnStartupHighlight(data, attacker)
    local isHeavy = data.IsHeavy == true or data[3] == true
    local isCharge = data.IsCharge == true or data[4] == true
    local isUltimate = data.IsUltimate == true or data[5] == true
    local isCancelled = data.Cancelled == true or data.State == "Cancelled" or data.IsFeint == true or data[7] == true
    local current = self.Controller:GetCurrent(attacker)
    if isUltimate then
        if current then self.Controller:Cancel(attacker, current.AttackId, "ability ignored") end
        return
    end
    if isCancelled then
        self:RememberTransition(attacker)
        if current then self.Controller:Cancel(attacker, current.AttackId, "combat flow cancelled") end
        return
    end
    local attackType = (isHeavy or isCharge) and "M2" or "M1"
    if current and current.State == "Started" and not current.AttackType then
        self:CommitCurrent(attacker, attackType)
        return
    end
    self:RememberTransition(attacker)
    local attack = self.Controller:Start(attacker, self:SourceAttackId(data), attackType, self.ctx.Workspace:GetServerTimeNow(), nil, self:PayloadHitbox(data))
    if attack then attack.SourceStage = "StartupHighlight" end
end

function UntitledBoxingGame:OnCombatEffect(data)
    if not self.Enabled or type(data) ~= "table" or self.SeenEffects[data] then return end
    local eventName = data.Event or data.Type or data.StateEvent or data[1]
    if eventName ~= "AttackTrail" and eventName ~= "StartupHighlight" then return end
    self.SeenEffects[data] = true
    local attacker = data.Attacker or data.Character or data[2]
    if typeof(attacker) ~= "Instance" or not attacker:IsA("Model") or attacker == self.ctx.LocalPlayer.Character then return end
    if eventName == "AttackTrail" then self:OnAttackTrail(data, attacker)
    else self:OnStartupHighlight(data, attacker) end
end

function UntitledBoxingGame:StateFolder(character)
    local states = self.ctx.Workspace:FindFirstChild("States")
    return states and character and states:FindFirstChild(character.Name)
end

function UntitledBoxingGame:FindState(character, names)
    local folder = self:StateFolder(character)
    if not folder then return nil, nil end
    for _, name in ipairs(names) do
        local item = folder:FindFirstChild(name, true)
        if item then return valueOf(item), item end
        local attribute = folder:GetAttribute(name)
        if attribute ~= nil then return attribute, folder end
        if character then
            attribute = character:GetAttribute(name)
            if attribute ~= nil then return attribute, character end
        end
    end
    return nil, nil
end

function UntitledBoxingGame:LockedCharacter(character)
    local value = self:FindState(character, {"LockedOn", "LockOn", "Target"})
    return typeof(value) == "Instance" and value or nil
end

function UntitledBoxingGame:IsTruthyState(character, names)
    local value = self:FindState(character, names)
    if type(value) == "boolean" then return value end
    if type(value) == "number" then return value > 0 end
    if type(value) == "string" then return value ~= "" and value ~= "Idle" and value ~= "None" end
    return value ~= nil
end

function UntitledBoxingGame:StateRange(character)
    local value = self:FindState(character, {"HitboxRange", "AttackRange", "PunchRange", "Reach"})
    value = tonumber(value)
    return value and value > 0 and value < 30 and value or nil
end

function UntitledBoxingGame:CanAttackHit(attack)
    local localCharacter = self.ctx.LocalPlayer.Character
    local localRoot = humanoidRoot(localCharacter)
    local attackerRoot = humanoidRoot(attack.Attacker)
    local localHumanoid = localCharacter and localCharacter:FindFirstChildOfClass("Humanoid")
    local attackerHumanoid = attack.Attacker and attack.Attacker:FindFirstChildOfClass("Humanoid")
    if not localRoot or not attackerRoot or not localHumanoid or localHumanoid.Health <= 0 or not attackerHumanoid or attackerHumanoid.Health <= 0 then
        return false, "character unavailable"
    end
    if self:IsTruthyState(attack.Attacker, {"Stunned", "Stun", "Knocked", "Knockdown", "Downed", "Ragdolled", "Recovery"}) then
        return false, "attacker cannot hit"
    end
    if self.OnlyLockedOpponent then
        local ourTarget = self:LockedCharacter(localCharacter)
        local theirTarget = self:LockedCharacter(attack.Attacker)
        if (ourTarget or theirTarget) and ourTarget ~= attack.Attacker and theirTarget ~= localCharacter then
            return false, "not current opponent"
        end
    end

    local hitbox = attack.HitboxData or {}
    local range = tonumber(hitbox.Range) or self:StateRange(attack.Attacker) or self.FallbackRange
    local boxCFrame = typeof(hitbox.CFrame) == "CFrame" and hitbox.CFrame or attackerRoot.CFrame * CFrame.new(0, 0, -range * 0.5)
    local boxSize = typeof(hitbox.Size) == "Vector3" and hitbox.Size or Vector3.new(7, 7, range)
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = {localCharacter}
    local ok, parts = pcall(function() return self.ctx.Workspace:GetPartBoundsInBox(boxCFrame, boxSize, params) end)
    if ok and #parts > 0 then return true end
    local relative = boxCFrame:PointToObjectSpace(localRoot.Position)
    local half = boxSize * 0.5 + Vector3.new(1.5, 2.5, 1.5)
    local inside = math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
    return inside, inside and nil or "out of hitbox"
end

function UntitledBoxingGame:IsDodgeCooldown(character)
    if self.ctx.Workspace:GetServerTimeNow() < (self.NextDodgeAt or 0) then return true end
    local canDash, canDashNode = self:FindState(character, {"CanDash", "CanDodge"})
    if canDashNode and (canDash == false or canDash == 0 or canDash == "false") then return true end
    if self:IsTruthyState(character, {"Dashing", "Dodging"}) then return true end
    local cooldown = self:FindState(character, {"DodgeCooldown", "DashCooldown", "DodgeCD", "DashCD"})
    if type(cooldown) == "boolean" then return cooldown end
    if type(cooldown) == "number" then
        local now = self.ctx.Workspace:GetServerTimeNow()
        if cooldown > 60 then return cooldown > now end
        return cooldown > 0
    end
    if type(cooldown) == "string" then return cooldown ~= "" and cooldown ~= "0" and cooldown ~= "false" end
    return false
end

function UntitledBoxingGame:CanDodge()
    local character = self.ctx.LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or not humanoid or humanoid.Health <= 0 then return false, "player dead" end
    if humanoid.PlatformStand or humanoid.Sit then return false, "player knocked down" end
    if self:IsTruthyState(character, {"Stunned", "Stun"}) then return false, "player stunned" end
    if self:IsTruthyState(character, {"Knocked", "Knockdown", "Downed", "Ragdolled"}) then return false, "player knockdown" end
    if self:IsTruthyState(character, {"Recovery", "Recovering"}) then return false, "player recovery" end
    if self:IsTruthyState(character, {"Punching", "Attacking", "AttackLocked", "Endlag", "EndLag"}) then return false, "player action locked" end
    if self:IsDodgeCooldown(character) then return false, "dodge cooldown" end
    return true
end

function UntitledBoxingGame:ResolveDodgeRemote()
    if self.DodgeRemote and self.DodgeRemote.Parent then return self.DodgeRemote end
    local direct = self.ctx.ReplicatedStorage:FindFirstChild("dataRemoteEvent")
    local recursive = direct or self.ctx.ReplicatedStorage:FindFirstChild("dataRemoteEvent", true)
    if recursive and recursive:IsA("RemoteEvent") then self.DodgeRemote = recursive end
    return self.DodgeRemote
end

function UntitledBoxingGame:ExecuteDodge(attack)
    local remote = self:ResolveDodgeRemote()
    local character = self.ctx.LocalPlayer.Character
    local root = humanoidRoot(character)
    local attackerRoot = humanoidRoot(attack.Attacker)
    if not remote or not root or not attackerRoot then return false end
    local direction = root.Position - attackerRoot.Position
    if direction.Magnitude < 0.01 then direction = root.CFrame.RightVector end
    self.DodgeSide = self.DodgeSide == "Right" and "Left" or "Right"
    remote:FireServer({{direction, self.DodgeSide}, "\21"})
    self.NextDodgeAt = self.ctx.Workspace:GetServerTimeNow() + 0.12
    return true
end

function UntitledBoxingGame:GetConfig()
    return {
        enabled = self.Enabled,
        debug = self.Debug,
        latencyCompensation = self.LatencyCompensation,
        fallbackRange = self.FallbackRange,
        onlyLockedOpponent = self.OnlyLockedOpponent,
    }
end

function UntitledBoxingGame:ApplyConfig(data)
    if type(data) ~= "table" then return end
    self.Debug = data.debug == true
    self.LatencyCompensation = math.clamp(tonumber(data.latencyCompensation) or self.LatencyCompensation, 0, 0.06)
    self.FallbackRange = math.clamp(tonumber(data.fallbackRange) or self.FallbackRange, 4, 15)
    self.OnlyLockedOpponent = data.onlyLockedOpponent ~= false
    self.DebugControl.Set(self.Debug)
    self.LatencyControl.Set(self.LatencyCompensation * 1000)
    self.RangeControl.Set(self.FallbackRange)
    self.LockedControl.Set(self.OnlyLockedOpponent)
    self:SetEnabled(data.enabled == true)
    self.EnabledControl.Set(self.Enabled)
end

function UntitledBoxingGame:Destroy()
    self.Enabled = false
    if self.Controller then self.Controller:SetEnabled(false) end
    self:UninstallHooks()
end

return UntitledBoxingGame
