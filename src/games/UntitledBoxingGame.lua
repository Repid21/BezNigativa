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
        and type(rawget(value, "StartupHighlight")) == "function"
end

local function executorEnvironment()
    local environment = _G
    if type(getgenv) == "function" then
        local ok, result = pcall(getgenv)
        if ok and type(result) == "table" then environment = result end
    end
    return environment
end

local function findEffectHelperInValue(value, depth, seen)
    if isEffectHelper(value) then return value end
    if type(value) ~= "table" or depth >= 3 or seen[value] then return nil end
    seen[value] = true
    local inspected = 0
    for _, nested in pairs(value) do
        inspected += 1
        if inspected > 64 then break end
        local found = findEffectHelperInValue(nested, depth + 1, seen)
        if found then return found end
    end
    return nil
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

local function isCombatEventName(value)
    return value == "AttackTrail" or value == "StartupHighlight"
end

local function findCombatPayload(value, depth, seen)
    if type(value) ~= "table" or depth > 2 or seen[value] then return nil end
    seen[value] = true
    local eventName = value.Event or value.Type or value.StateEvent or value[1]
    if isCombatEventName(eventName) then return value, eventName end
    local inspected = 0
    for _, nested in pairs(value) do
        inspected += 1
        if inspected > 24 then break end
        if isCombatEventName(nested) then return value, nested end
        local result, nestedEventName = findCombatPayload(nested, depth + 1, seen)
        if result then return result, nestedEventName end
    end
    return nil
end

local function bufferShape(value)
    if typeof(value) ~= "buffer" then return nil end
    local ok, result = pcall(function()
        local length = buffer.len(value)
        local bytes = {}
        for offset = 0, math.min(length, 16) - 1 do
            table.insert(bytes, string.format("%02X", buffer.readu8(value, offset)))
        end
        return "buffer(len=" .. tostring(length) .. ",hex=" .. table.concat(bytes, " ")
            .. (length > 16 and " ..." or "") .. ")"
    end)
    return ok and result or "buffer(unreadable)"
end

local function shortValue(value)
    local kind = typeof(value)
    if kind == "string" then
        local clean = string.gsub(value, "%c", "?")
        return "\"" .. string.sub(clean, 1, 28) .. (#clean > 28 and "..." or "") .. "\""
    end
    if kind == "number" or kind == "boolean" then return tostring(value) end
    if kind == "Instance" then return value.ClassName .. "(" .. value.Name .. ")" end
    if kind == "buffer" then return bufferShape(value) end
    return kind
end

local function valueShape(value)
    local kind = typeof(value)
    if kind == "string" then
        local clean = string.gsub(value, "%c", "?")
        return "string(" .. string.sub(clean, 1, 24) .. ")"
    end
    if kind == "number" or kind == "boolean" then return kind .. "(" .. tostring(value) .. ")" end
    if kind == "Instance" then return value.ClassName .. "(" .. fullName(value) .. ")" end
    if kind == "buffer" then return bufferShape(value) end
    if type(value) == "table" then
        local entries, count = {}, 0
        for key, nested in pairs(value) do
            count += 1
            if count <= 6 then table.insert(entries, tostring(key) .. "=" .. shortValue(nested)) end
        end
        return "table{" .. table.concat(entries, ",") .. (count > 6 and ",..." or "") .. "}"
    end
    return kind
end

local function characterFromInstance(value)
    if typeof(value) ~= "Instance" then return nil end
    if value:IsA("Player") then return value.Character end
    if value:IsA("Model") and value:FindFirstChildOfClass("Humanoid") then return value end
    local model = value:FindFirstAncestorOfClass("Model")
    return model and model:FindFirstChildOfClass("Humanoid") and model or nil
end

local function findCharacterInValue(value, localCharacter, depth, seen)
    local direct = characterFromInstance(value)
    if direct and direct ~= localCharacter then return direct end
    if type(value) ~= "table" or depth >= 3 or seen[value] then return nil end
    seen[value] = true
    local inspected = 0
    for _, nested in pairs(value) do
        inspected += 1
        if inspected > 40 then break end
        local character = findCharacterInValue(nested, localCharacter, depth + 1, seen)
        if character then return character end
    end
    return nil
end

local function normalizedCombatPayload(payload, eventName)
    if type(payload) ~= "table" then return nil end
    if isCombatEventName(payload.Event or payload.Type or payload.StateEvent or payload[1]) then return payload end
    local normalized = {}
    for key, value in pairs(payload) do normalized[key] = value end
    normalized.Event = eventName
    normalized.SourcePayload = payload
    return normalized
end

function UntitledBoxingGame.new(ctx)
    local self = setmetatable({
        ctx = ctx,
        Enabled = false,
        Debug = false,
        LatencyCompensation = 0.045,
        DodgeStartupTime = 0,
        FallbackRange = 9.9,
        RemoteFallbackImpactDelay = 0.24,
        OnlyLockedOpponent = true,
        Hooks = {},
        SeenEffects = setmetatable({}, {__mode = "k"}),
        TransitionFrom = setmetatable({}, {__mode = "k"}),
    }, UntitledBoxingGame)

    local page = ctx.Window:AddPage("Untitled Boxing Game", "M1/M2 Auto Dodge через внутренний combat flow")
    local stack = ctx.Window:ModuleStack(page, 70)
    local module = stack:Add("Auto Dodge", 450)
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

    local diagnostics = Instance.new("ScrollingFrame")
    diagnostics.Position = UDim2.fromOffset(10, 252)
    diagnostics.Size = UDim2.new(1, -20, 0, 116)
    diagnostics.BackgroundColor3 = Color3.fromRGB(29, 29, 29)
    diagnostics.BorderSizePixel = 0
    diagnostics.ScrollBarThickness = 5
    diagnostics.AutomaticCanvasSize = Enum.AutomaticSize.Y
    diagnostics.CanvasSize = UDim2.fromOffset(0, 0)
    diagnostics.ScrollingDirection = Enum.ScrollingDirection.Y
    diagnostics.Parent = module.Settings

    local diagnosticLabel = Instance.new("TextLabel")
    diagnosticLabel.Position = UDim2.fromOffset(6, 5)
    diagnosticLabel.Size = UDim2.new(1, -14, 0, 0)
    diagnosticLabel.AutomaticSize = Enum.AutomaticSize.Y
    diagnosticLabel.BackgroundTransparency = 1
    diagnosticLabel.Font = Enum.Font.Code
    diagnosticLabel.Text = "Включи Auto Dodge для запуска диагностики."
    diagnosticLabel.TextWrapped = true
    diagnosticLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
    diagnosticLabel.TextSize = 11
    diagnosticLabel.TextXAlignment = Enum.TextXAlignment.Left
    diagnosticLabel.TextYAlignment = Enum.TextYAlignment.Top
    diagnosticLabel.Parent = diagnostics
    self.DiagnosticLabel = diagnosticLabel

    self.CopyButton = ctx.Window:Button(module.Settings, UDim2.fromOffset(10, 376), UDim2.fromOffset(220, 30), "Copy diagnostics", function()
        self:CopyDiagnostics()
    end)
    self.RetryButton = ctx.Window:Button(module.Settings, UDim2.fromOffset(240, 376), UDim2.fromOffset(220, 30), "Retry", function()
        self:SetEnabled(true)
        self.EnabledControl.Set(self.Enabled)
        ctx.Touch()
    end)

    local Controller = ctx.LoadModule("games/AutoDodgeController")
    self.Controller = Controller.new({
        Settings = self,
        Now = function() return ctx.Workspace:GetServerTimeNow() end,
        Delay = function(delay, callback) task.delay(delay, callback) end,
        CanHit = function(attack) return self:CanAttackHit(attack) end,
        CanDodge = function(attack) return self:CanDodge(attack) end,
        Dodge = function(attack) return self:ExecuteDodge(attack) end,
        Log = function(message) self:AddDiagnostic(message, false) end,
    })
    return self
end

function UntitledBoxingGame:SetStatus(text, errorState)
    if not self.Status then return end
    self.Status.Text = "Status: " .. text
    self.Status.TextColor3 = errorState and Color3.fromRGB(255, 115, 115) or Color3.fromRGB(185, 220, 185)
end

function UntitledBoxingGame:ResetDiagnostics()
    self.DiagnosticLines = {}
    self.LastDiagnostic = ""
    if self.DiagnosticLabel then self.DiagnosticLabel.Text = "Диагностика запущена..." end
end

function UntitledBoxingGame:AddDiagnostic(message, errorState)
    local text = tostring(message)
    self.DiagnosticLines = self.DiagnosticLines or {}
    table.insert(self.DiagnosticLines, text)
    while #self.DiagnosticLines > 30 do table.remove(self.DiagnosticLines, 1) end
    self.LastDiagnostic = table.concat(self.DiagnosticLines, "\n\n")
    if #self.LastDiagnostic > 12000 then self.LastDiagnostic = string.sub(self.LastDiagnostic, -12000) end
    if self.DiagnosticLabel then
        self.DiagnosticLabel.Text = self.LastDiagnostic
        self.DiagnosticLabel.TextColor3 = errorState and Color3.fromRGB(255, 145, 145) or Color3.fromRGB(190, 210, 190)
    end
    if errorState then warn("[BezNigativa/UBG] " .. text) else print("[BezNigativa/UBG] " .. text) end
end

function UntitledBoxingGame:CopyDiagnostics()
    local environment = _G
    if type(getgenv) == "function" then
        local ok, result = pcall(getgenv)
        if ok and type(result) == "table" then environment = result end
    end
    local copy = environment.setclipboard or environment.toclipboard or setclipboard or toclipboard
    if type(copy) ~= "function" then
        self:AddDiagnostic("Clipboard API недоступен. Сделай скриншот блока диагностики.", true)
        return
    end
    local ok, message = xpcall(function() copy(self.LastDiagnostic or "") end, tracebackError)
    if not ok then
        self:AddDiagnostic("Не удалось скопировать диагностику:\n" .. tostring(message), true)
        return
    end
    if self.CopyButton then
        self.CopyButton.Text = "Copied"
        task.delay(1.2, function()
            if self.CopyButton and self.CopyButton.Parent then self.CopyButton.Text = "Copy diagnostics" end
        end)
    end
end

function UntitledBoxingGame:SetEnabled(value)
    self.Enabled = value == true
    self.Controller:SetEnabled(self.Enabled)
    if self.Enabled then
        self:ResetDiagnostics()
        self.CombatConfirmed = false
        self.TryAttackSequence = 0
        self.TryAttackFallbackReported = false
        self.TryAttackMissingAttackerWarning = false
        self.DodgeInputReported = false
        self:SetStatus("Initializing...", false)
        local ok, message = self:InstallHooks()
        if ok then
            self.Initialized = true
            self:SetStatus(self.CombatConfirmed and "Ready" or "Listening: waiting for first attack", false)
        else
            self.Initialized = false
            self.Enabled = false
            self.Controller:SetEnabled(false)
            self.EnabledControl.Set(false)
            self:SetStatus("ERROR: " .. tostring(message or "initialization failed"), true)
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
    local environment = executorEnvironment()
    local getGarbage = environment.getgc or getgc
    if type(getGarbage) ~= "function" then return nil, "executor does not expose getgc" end
    local snapshots, diagnostics = {}, {}
    local okTrue, objectsTrue = xpcall(function() return getGarbage(true) end, tracebackError)
    if okTrue and type(objectsTrue) == "table" then table.insert(snapshots, objectsTrue)
    else table.insert(diagnostics, "getgc(true): " .. tostring(objectsTrue)) end
    local okDefault, objectsDefault = xpcall(function() return getGarbage() end, tracebackError)
    if okDefault and type(objectsDefault) == "table" and objectsDefault ~= objectsTrue then
        table.insert(snapshots, objectsDefault)
    elseif not okDefault then
        table.insert(diagnostics, "getgc(): " .. tostring(objectsDefault))
    end

    local tableCount, functionCount, upvalueCount = 0, 0, 0
    for _, objects in ipairs(snapshots) do
        for _, candidate in pairs(objects) do
            if type(candidate) == "table" then
                tableCount += 1
                local helper = findEffectHelperInValue(candidate, 0, {})
                if helper then return helper end
            end
        end
    end
    for _, objects in ipairs(snapshots) do
        for _, candidate in pairs(objects) do
            if type(candidate) == "function" and functionCount < 1500 then
                functionCount += 1
                if functionCount % 250 == 0 then task.wait() end
                local values = self:GetFunctionUpvalues(candidate)
                if values then
                    upvalueCount += 1
                    local helper = findEffectHelperInValue(values, 0, {})
                    if helper then return helper end
                end
            end
        end
    end
    table.insert(diagnostics, "scanned getgc tables=" .. tostring(tableCount) .. ", functions=" .. tostring(functionCount)
        .. ", readable upvalues=" .. tostring(upvalueCount))
    return nil, table.concat(diagnostics, "\n")
end

function UntitledBoxingGame:GetFunctionUpvalues(callback)
    local environment = executorEnvironment()
    local getter = environment.getupvalues
    if type(getter) ~= "function" and type(debug) == "table" then getter = debug.getupvalues end
    if type(getter) == "function" then
        local ok, values = xpcall(function() return getter(callback) end, tracebackError)
        if ok and type(values) == "table" then return values end
    end
    local getOne = environment.getupvalue
    if type(getOne) ~= "function" and type(debug) == "table" then getOne = debug.getupvalue end
    if type(getOne) ~= "function" then return nil end
    local values = {}
    for index = 1, 40 do
        local ok, name, value = pcall(getOne, callback, index)
        if not ok or name == nil then break end
        if value == nil and type(name) ~= "string" then values[index] = name
        else values[name] = value end
    end
    return values
end

function UntitledBoxingGame:FindEffectHelperFromConnections()
    local environment = executorEnvironment()
    local getConnections = environment.getconnections or getconnections
    if type(getConnections) ~= "function" then return nil, "executor does not expose getconnections" end
    local remoteCount, connectionCount, functionCount = 0, 0, 0
    for _, remote in ipairs(self.ctx.ReplicatedStorage:GetDescendants()) do
        if self:IsClientRemote(remote) then
            remoteCount += 1
            local ok, connections = xpcall(function() return getConnections(remote.OnClientEvent) end, tracebackError)
            if ok and type(connections) == "table" then
                for _, connection in pairs(connections) do
                    connectionCount += 1
                    local readOk, callback = pcall(function() return connection.Function end)
                    if readOk and type(callback) == "function" then
                        functionCount += 1
                        local values = self:GetFunctionUpvalues(callback)
                        if values then
                            local helper = findEffectHelperInValue(values, 0, {})
                            if helper then return helper, fullName(remote) end
                        end
                    end
                end
            end
        end
    end
    return nil, "scanned remotes=" .. tostring(remoteCount) .. ", connections=" .. tostring(connectionCount)
        .. ", readable callbacks=" .. tostring(functionCount)
end

function UntitledBoxingGame:ResolveEffectHelper()
    if isEffectHelper(self.EffectHelper) then return self.EffectHelper, self.EffectHelperSource end

    local moduleScript, expectedPath = self:FindEffectHelperModule()
    if moduleScript then
        self:AddDiagnostic("EffectHelper ModuleScript: " .. fullName(moduleScript), false)
        if not expectedPath then
            self:AddDiagnostic("Ожидался ReplicatedStorage.Modules.EffectHelper, найден другой путь: " .. fullName(moduleScript), true)
        end
    else
        self:AddDiagnostic("EffectHelper ModuleScript отсутствует в ReplicatedStorage. Ожидался путь ReplicatedStorage.Modules.EffectHelper", true)
    end

    local loaded, getGcError = self:FindLoadedEffectHelper()
    if loaded then
        self.EffectHelper, self.EffectHelperSource = loaded, "getgc"
        self:AddDiagnostic("EffectHelper API найден в уже загруженной combat-таблице (getgc).", false)
        return loaded, self.EffectHelperSource
    end

    local connectionHelper, connectionSource = self:FindEffectHelperFromConnections()
    if connectionHelper then
        self.EffectHelper, self.EffectHelperSource = connectionHelper, "OnClientEvent upvalue"
        self:AddDiagnostic("EffectHelper API найден в upvalue игрового OnClientEvent.\nRemote: " .. tostring(connectionSource), false)
        return connectionHelper, self.EffectHelperSource
    end

    self:AddDiagnostic("Загруженный EffectHelper API недоступен: " .. tostring(getGcError)
        .. "\nUpvalue scan: " .. tostring(connectionSource)
        .. "\nПрямой require отключён, потому что игровой ModuleScript падает внутри собственных зависимостей."
        .. "\nПереключаюсь на входящий combat RemoteEvent.", false)
    return nil, "RemoteEvent fallback"
end

function UntitledBoxingGame:IsClientRemote(instance)
    return instance:IsA("RemoteEvent") or instance.ClassName == "UnreliableRemoteEvent"
end

function UntitledBoxingGame:ConfirmCombatFlow(source)
    if self.CombatConfirmed then return end
    self.CombatConfirmed = true
    self:SetStatus("Ready", false)
    self:AddDiagnostic("Combat flow подтверждён через " .. tostring(source) .. ".", false)
end

function UntitledBoxingGame:RecordRemoteSample(remote, arguments)
    self.RemoteSamples = self.RemoteSamples or setmetatable({}, {__mode = "k"})
    if self.RemoteSamples[remote] or (self.RemoteSampleCount or 0) >= 8 then return end
    self.RemoteSamples[remote] = true
    self.RemoteSampleCount = (self.RemoteSampleCount or 0) + 1
    local shapes = {}
    for index = 1, math.min(arguments.n, 6) do
        table.insert(shapes, tostring(index) .. "=" .. valueShape(arguments[index]))
    end
    self:AddDiagnostic("Remote sample " .. fullName(remote) .. " | args=" .. tostring(arguments.n)
        .. " | " .. table.concat(shapes, " ; "), false)
end

function UntitledBoxingGame:InspectRemotePayload(remote, ...)
    local arguments = table.pack(...)
    if isCombatEventName(arguments[1]) then
        local payload = {}
        for index = 1, arguments.n do payload[index] = arguments[index] end
        payload.Event = arguments[1]
        payload.Attacker = findCharacterInValue(arguments, self.ctx.LocalPlayer.Character, 0, {})
        if not self.ObservedCombatRemote then self.ObservedCombatRemote = remote end
        self:ConfirmCombatFlow(fullName(remote))
        self:OnCombatEffect(payload)
        return
    end
    for index = 1, arguments.n do
        local payload, eventName = findCombatPayload(arguments[index], 0, {})
        if payload then
            payload = normalizedCombatPayload(payload, eventName)
            payload.Attacker = payload.Attacker
                or findCharacterInValue(arguments[index], self.ctx.LocalPlayer.Character, 0, {})
                or findCharacterInValue(arguments, self.ctx.LocalPlayer.Character, 0, {})
            if not self.ObservedCombatRemote then self.ObservedCombatRemote = remote end
            self:ConfirmCombatFlow(fullName(remote))
            self:OnCombatEffect(payload)
            return
        end
    end
    if remote.Name == "ReplicateTryAttack" then
        self:OnReplicateTryAttack(remote, arguments)
    end
end

function UntitledBoxingGame:OnReplicateTryAttack(remote, arguments)
    local attacker = findCharacterInValue(arguments, self.ctx.LocalPlayer.Character, 0, {})
    if not attacker then
        if not self.TryAttackMissingAttackerWarning then
            self.TryAttackMissingAttackerWarning = true
            self:AddDiagnostic("ReplicateTryAttack найден, но Instance атакующего не удалось преобразовать в Character.", true)
        end
        return
    end

    self.ObservedCombatRemote = remote
    self:ConfirmCombatFlow(fullName(remote) .. " (buffer fallback)")
    self.TryAttackSequence = (self.TryAttackSequence or 0) + 1
    local sequence = self.TryAttackSequence
    if not self.TryAttackFallbackReported then
        self.TryAttackFallbackReported = true
        self:AddDiagnostic("ReplicateTryAttack распознан: attacker=" .. fullName(attacker)
            .. ". Буферный fallback активен; точный CreateEffect имеет приоритет.", false)
    end

    task.delay(0.035, function()
        if not self.Enabled or sequence ~= self.TryAttackSequence then return end
        if not attacker.Parent or attacker == self.ctx.LocalPlayer.Character then return end
        local now = self.ctx.Workspace:GetServerTimeNow()
        local current = self.Controller:GetCurrent(attacker)
        if current and (current.State == "Committed" or current.State == "Active") then return end

        local impactTime = now + self.RemoteFallbackImpactDelay
        if current and current.State == "Started" then
            current.AttackType = current.AttackType or "M1"
            current.ImpactTime = impactTime
            self.Controller:Commit(attacker, current.AttackId, current.AttackType, impactTime, current.HitboxData)
            return
        end

        local attackId = {Remote = remote, Sequence = sequence, Payload = arguments[1]}
        local attack = self.Controller:Start(attacker, attackId, "M1", now, impactTime, {})
        if attack then
            attack.SourceStage = "ReplicateTryAttack"
            self.Controller:Commit(attacker, attackId, "M1", impactTime, {})
        end
    end)
end

function UntitledBoxingGame:ConnectCombatRemote(remote)
    self.RemoteConnections = self.RemoteConnections or setmetatable({}, {__mode = "k"})
    if self.RemoteConnections[remote] or not self:IsClientRemote(remote) then return false end
    local connection = remote.OnClientEvent:Connect(function(...)
        self.RemoteEventsSeen = (self.RemoteEventsSeen or 0) + 1
        if not self.CombatConfirmed and (self.RemoteEventsSeen <= 3 or self.RemoteEventsSeen % 25 == 0) then
            self:SetStatus("Listening: " .. tostring(self.RemoteEventsSeen) .. " events / 0 combat", false)
        end
        local arguments = table.pack(...)
        if not self.CombatConfirmed then self:RecordRemoteSample(remote, arguments) end
        local ok, message = xpcall(function()
            self:InspectRemotePayload(remote, table.unpack(arguments, 1, arguments.n))
        end, tracebackError)
        if not ok and not self.RemoteWarning then
            self.RemoteWarning = true
            self:AddDiagnostic("Combat RemoteEvent observer crashed.\nRemote: " .. fullName(remote)
                .. "\nFull traceback:\n" .. tostring(message), true)
            self:SetStatus("ERROR: combat observer crashed", true)
        end
    end)
    self.RemoteConnections[remote] = connection
    return true
end

function UntitledBoxingGame:InstallRemoteObserver()
    if self.RemoteAddedConnection then return true, self.RemoteConnectionCount or 0 end
    self.RemoteConnections = setmetatable({}, {__mode = "k"})
    self.RemoteConnectionCount = 0
    self.RemoteEventsSeen = 0
    self.RemoteSamples = setmetatable({}, {__mode = "k"})
    self.RemoteSampleCount = 0
    for _, instance in ipairs(self.ctx.ReplicatedStorage:GetDescendants()) do
        if self:IsClientRemote(instance) and self:ConnectCombatRemote(instance) then
            self.RemoteConnectionCount += 1
        end
    end
    self.RemoteAddedConnection = self.ctx.ReplicatedStorage.DescendantAdded:Connect(function(instance)
        if self:IsClientRemote(instance) and self:ConnectCombatRemote(instance) then
            self.RemoteConnectionCount += 1
        end
    end)
    if self.RemoteConnectionCount == 0 then
        self:UninstallRemoteObserver()
        return false, 0
    end
    self.EffectHelperSource = "RemoteEvent observer"
    self:AddDiagnostic("RemoteEvent fallback готов: подключено " .. tostring(self.RemoteConnectionCount)
        .. " входящих событий. Ожидаю AttackTrail/StartupHighlight или ReplicateTryAttack.", false)
    return true, self.RemoteConnectionCount
end

function UntitledBoxingGame:UninstallRemoteObserver()
    if self.RemoteAddedConnection then self.RemoteAddedConnection:Disconnect(); self.RemoteAddedConnection = nil end
    for _, connection in pairs(self.RemoteConnections or {}) do connection:Disconnect() end
    self.RemoteConnections = setmetatable({}, {__mode = "k"})
    self.RemoteConnectionCount = 0
    self.RemoteEventsSeen = 0
    self.RemoteSamples = setmetatable({}, {__mode = "k"})
    self.RemoteSampleCount = 0
    self.ObservedCombatRemote = nil
end

function UntitledBoxingGame:InstallHooks()
    if next(self.Hooks) or self.RemoteAddedConnection then return true, self.EffectHelperSource end
    local helper, sourceOrError = self:ResolveEffectHelper()
    if not helper then
        local observerOk = self:InstallRemoteObserver()
        if not observerOk then
            self:AddDiagnostic("Не найден ни один входящий RemoteEvent для combat fallback.", true)
            return false, "combat RemoteEvent missing"
        end
        local dodgeRemote = self:ResolveDodgeRemote()
        if not dodgeRemote then
            self:UninstallRemoteObserver()
            self:AddDiagnostic("Dodge RemoteEvent отсутствует. Ожидался ReplicatedStorage.dataRemoteEvent.", true)
            return false, "Dodge RemoteEvent missing"
        end
        self:AddDiagnostic("Auto Dodge observer initialized; ожидаю первое combat-событие.\nDodgeRemote="
            .. fullName(dodgeRemote), false)
        return true, sourceOrError
    end
    local dodgeRemote = self:ResolveDodgeRemote()
    if not dodgeRemote then
        self:AddDiagnostic("Dodge RemoteEvent отсутствует. Ожидался ReplicatedStorage.dataRemoteEvent.", true)
        return false, "Dodge RemoteEvent missing"
    end
    local count, callableCount = 0, 0
    local startupHooked = false
    for key, original in pairs(helper) do
        if type(original) == "function" then
            callableCount += 1
            local base = original
            local wrapper = function(data, ...)
                local ok, hookError = xpcall(function() self:OnCombatEffect(data) end, tracebackError)
                if not ok and not self.HookWarning then
                    self.HookWarning = true
                    self:AddDiagnostic("combat hook crashed.\nFull traceback:\n" .. tostring(hookError), true)
                    self:SetStatus("ERROR: combat hook crashed", true)
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
                if key == "StartupHighlight" then startupHooked = true end
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
                    if key == "StartupHighlight" then startupHooked = true end
                else
                    self:AddDiagnostic("Failed to install " .. tostring(key) .. " hook."
                        .. "\nTable assignment error:\n" .. tostring(patchError or "table rejected assignment")
                        .. "\nhookfunction error:\n" .. tostring(previous or "hookfunction unavailable"), true)
                end
            end
        end
    end
    if callableCount == 0 or count ~= callableCount or not startupHooked then
        self:UninstallHooks()
        self:AddDiagnostic("Auto Dodge hook verification failed: installed " .. tostring(count) .. "/" .. tostring(callableCount)
            .. " handlers; StartupHighlight=" .. tostring(startupHooked), true)
        return false, "combat hook verification failed"
    end
    self:AddDiagnostic("Auto Dodge hooks установлены; ожидаю первое combat-событие.\nEffectHelper=" .. tostring(sourceOrError)
        .. "\nDodgeRemote=" .. fullName(dodgeRemote) .. "\nHooks=" .. tostring(count) .. "/" .. tostring(callableCount), false)
    return true, sourceOrError
end

function UntitledBoxingGame:UninstallHooks()
    self:UninstallRemoteObserver()
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
    self:ConfirmCombatFlow(self.ObservedCombatRemote and fullName(self.ObservedCombatRemote) or (self.EffectHelperSource or "EffectHelper hook"))
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

function UntitledBoxingGame:SendDodgeInput()
    local environment = executorEnvironment()
    local press = environment.keypress or keypress
    local release = environment.keyrelease or keyrelease
    if type(press) == "function" and type(release) == "function" then
        local ok = pcall(function()
            press(0x20)
            task.delay(0.025, function() pcall(release, 0x20) end)
        end)
        if ok then return true, "executor Space input" end
    end

    local ok = pcall(function()
        local input = game:GetService("VirtualInputManager")
        input:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.delay(0.025, function()
            pcall(function() input:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end)
        end)
    end)
    return ok, ok and "VirtualInputManager Space" or nil
end

function UntitledBoxingGame:ExecuteDodge(attack)
    local character = self.ctx.LocalPlayer.Character
    local root = humanoidRoot(character)
    local attackerRoot = humanoidRoot(attack.Attacker)
    if not root or not attackerRoot then return false end

    local inputOk, inputSource = self:SendDodgeInput()
    if inputOk then
        if not self.DodgeInputReported then
            self.DodgeInputReported = true
            self:AddDiagnostic("Dodge выполняется через штатный ввод игры: " .. tostring(inputSource) .. ".", false)
        end
        self.NextDodgeAt = self.ctx.Workspace:GetServerTimeNow() + 0.12
        return true
    end

    local remote = self:ResolveDodgeRemote()
    if not remote then return false end
    local direction = root.Position - attackerRoot.Position
    if direction.Magnitude < 0.01 then direction = root.CFrame.RightVector end
    self.DodgeSide = self.DodgeSide == "Right" and "Left" or "Right"
    remote:FireServer({{direction, self.DodgeSide}, "\21"})
    if not self.DodgeInputReported then
        self.DodgeInputReported = true
        self:AddDiagnostic("Space input недоступен; используется BridgeNet2 dodge fallback.", false)
    end
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
