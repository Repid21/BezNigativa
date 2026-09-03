local ViolenceDistrict = {}
ViolenceDistrict.__index = ViolenceDistrict

local KILLER_RED = Color3.fromRGB(255, 45, 45)
local GENERATOR_YELLOW = Color3.fromRGB(255, 210, 55)
local GENERATOR_GREEN = Color3.fromRGB(55, 225, 110)

local function basePart(instance)
    if not instance then return nil end
    if instance:IsA("BasePart") then return instance end
    local primary = instance:IsA("Model") and instance.PrimaryPart
    if primary then return primary end
    local material = instance:FindFirstChild("defaultMaterial", true)
    if material and material:IsA("BasePart") then return material end
    return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function teamContains(player, name)
    local team = player and player.Team
    return team and string.find(string.lower(team.Name), name, 1, true) ~= nil
end

function ViolenceDistrict.new(ctx)
    local self = setmetatable({
        ctx = ctx,
        KillerESP = false,
        GeneratorESP = false,
        AutoReaction = false,
        Elapsed = 0,
        Generators = {},
        ReactionTriggered = false,
        ReactionCheck = nil,
        ReactionGoalRotation = nil,
        ReactionLineRotation = nil,
        ReactionTouchId = 8822,
    }, ViolenceDistrict)

    local RoleChams = ctx.LoadModule("games/RoleChams")
    self.KillerChams = RoleChams.new("BezNigativaVDKiller")
    self.GeneratorChams = RoleChams.new("BezNigativaVDGenerator")

    local page = ctx.Window:AddPage("VIOLENCE DISTRICT", "Killer ESP, Generator ESP и Auto Reaction")
    local stack = ctx.Window:ModuleStack(page, 70)

    local killer = stack:Add("Подсветка маньяка", 126)
    self.KillerESPControl = ctx.Window:Toggle(killer.Settings, UDim2.fromOffset(10, 4), 260, "Красная подсветка", false, function(value)
        self.KillerESP = value
        if not value then self.KillerChams:Clear() end
        self:RefreshHeartbeat()
        ctx.Touch()
    end)
    self:AddHint(killer.Settings, "Показывает игрока из команды Killer сквозь стены.")

    local generators = stack:Add("Подсветка генераторов", 126)
    self.GeneratorESPControl = ctx.Window:Toggle(generators.Settings, UDim2.fromOffset(10, 4), 260, "Генераторы", false, function(value)
        self.GeneratorESP = value
        if not value then self.GeneratorChams:Clear() end
        self:RefreshHeartbeat()
        ctx.Touch()
    end)
    self:AddHint(generators.Settings, "Жёлтый — требует починки; зелёный — завершён.")

    local reaction = stack:Add("Auto Reaction", 126)
    self.AutoReactionControl = ctx.Window:Toggle(reaction.Settings, UDim2.fromOffset(10, 4), 260, "Реакция генератора", false, function(value)
        self.AutoReaction = value
        self:ResetReactionState()
        self:RefreshHeartbeat()
        ctx.Touch()
    end)
    self:AddHint(reaction.Settings, "Автоматически нажимает реакцию в зелёной зоне во время починки.")

    ctx.Janitor:Add(function()
        if self.HeartbeatLoop then self.HeartbeatLoop:Disconnect(); self.HeartbeatLoop = nil end
    end)
    return self
end

function ViolenceDistrict:AddHint(parent, text)
    local hint = Instance.new("TextLabel")
    hint.Position = UDim2.fromOffset(10, 48)
    hint.Size = UDim2.new(1, -20, 0, 38)
    hint.BackgroundTransparency = 1
    hint.Font = Enum.Font.Code
    hint.Text, hint.TextWrapped = text, true
    hint.TextColor3 = Color3.fromRGB(165, 165, 165)
    hint.TextSize = 12
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.Parent = parent
end

function ViolenceDistrict:RefreshHeartbeat()
    local active = self.KillerESP or self.GeneratorESP or self.AutoReaction
    if active and not self.HeartbeatLoop then
        self.HeartbeatLoop = self.ctx.RunService.RenderStepped:Connect(function(delta)
            local ok, message = pcall(function() self:Heartbeat(delta) end)
            if not ok and not self.Warned then
                self.Warned = true
                warn("[BezNigativa/ViolenceDistrict] " .. tostring(message))
            end
        end)
    elseif not active and self.HeartbeatLoop then
        self.HeartbeatLoop:Disconnect()
        self.HeartbeatLoop = nil
    end
end

function ViolenceDistrict:ScanKillers()
    local seen = {}
    for _, player in ipairs(self.ctx.Players:GetPlayers()) do
        if player ~= self.ctx.LocalPlayer and teamContains(player, "killer") and player.Character then
            self.KillerChams:Show(player.Character, KILLER_RED, seen)
        end
    end
    self.KillerChams:Finish(seen)
end

function ViolenceDistrict:IsGenerator(item)
    if not item:IsA("Model") then return false end
    return item.Name == "Generator" or item:GetAttribute("RepairProgress") ~= nil
end

function ViolenceDistrict:ScanGenerators()
    local map = self.ctx.Workspace:FindFirstChild("Map")
    local seen, generators = {}, {}
    if map then
        for _, item in ipairs(map:GetDescendants()) do
            if self:IsGenerator(item) then
                table.insert(generators, item)
                if self.GeneratorESP then
                    local progress = tonumber(item:GetAttribute("RepairProgress") or item:GetAttribute("Progress")) or 0
                    self.GeneratorChams:Show(item, progress >= 100 and GENERATOR_GREEN or GENERATOR_YELLOW, seen)
                end
            end
        end
    end
    self.Generators = generators
    if self.GeneratorESP then self.GeneratorChams:Finish(seen) end
end

function ViolenceDistrict:IsRepairingGenerator()
    if not teamContains(self.ctx.LocalPlayer, "survivor") then return false end
    local character = self.ctx.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    for _, generator in ipairs(self.Generators) do
        local part = generator.Parent and basePart(generator)
        local progress = tonumber(generator:GetAttribute("RepairProgress") or generator:GetAttribute("Progress")) or 0
        if part and progress < 100 and (part.Position - root.Position).Magnitude <= 18 then return true end
    end
    return false
end

function ViolenceDistrict:GetReactionPrompt()
    local playerGui = self.ctx.LocalPlayer:FindFirstChild("PlayerGui")
    local prompt = playerGui and playerGui:FindFirstChild("SkillCheckPromptGui")
    local check = prompt and prompt:FindFirstChild("Check")
    if not check or not check:IsA("GuiObject") then return nil end
    return check, check:FindFirstChild("Line"), check:FindFirstChild("Goal")
end

function ViolenceDistrict:GetActionButton()
    local current = self.ctx.LocalPlayer:FindFirstChild("PlayerGui")
    for _, name in ipairs({"Survivor-mob", "Controls", "action", "check"}) do
        current = current and current:FindFirstChild(name)
    end
    return current
end

function ViolenceDistrict:PressReaction()
    local button = self:GetActionButton()
    if button and type(firesignal) == "function" then
        local ok = pcall(function() firesignal(button.Activated) end)
        if ok then return true end
    end

    if not self.VirtualInput then
        local ok, service = pcall(game.GetService, game, "VirtualInputManager")
        if ok then self.VirtualInput = service end
    end
    if not self.VirtualInput then return false end

    if button and button:IsA("GuiObject") then
        local position, size = button.AbsolutePosition, button.AbsoluteSize
        local x, y = position.X + size.X * 0.5, position.Y + size.Y * 0.5
        local okInset, guiService = pcall(game.GetService, game, "GuiService")
        local inset = okInset and guiService:GetGuiInset() or Vector2.new(0, 0)
        x, y = x + inset.X, y + inset.Y
        local ok = pcall(function()
            self.VirtualInput:SendTouchEvent(self.ReactionTouchId, 0, x, y)
            task.delay(0.015, function()
                pcall(function() self.VirtualInput:SendTouchEvent(self.ReactionTouchId, 2, x, y) end)
            end)
        end)
        if ok then return true end
    end

    return pcall(function()
        self.VirtualInput:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        self.VirtualInput:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end)
end

function ViolenceDistrict:IsRotationInside(rotation, startRotation, endRotation)
    rotation, startRotation, endRotation = rotation % 360, startRotation % 360, endRotation % 360
    if startRotation > endRotation then return rotation >= startRotation or rotation <= endRotation end
    return rotation >= startRotation and rotation <= endRotation
end

function ViolenceDistrict:RotationDistance(first, second)
    return math.abs(((first - second + 180) % 360) - 180)
end

function ViolenceDistrict:CrossedRotation(previous, current, target)
    local movement = ((current - previous + 180) % 360) - 180
    local targetMovement = ((target - previous + 180) % 360) - 180
    if movement >= 0 then return targetMovement >= 0 and targetMovement <= movement end
    return targetMovement <= 0 and targetMovement >= movement
end

function ViolenceDistrict:ResetReactionState()
    self.ReactionTriggered = false
    self.ReactionCheck = nil
    self.ReactionGoalRotation = nil
    self.ReactionLineRotation = nil
end

function ViolenceDistrict:TryAutoReaction()
    local check, line, goal = self:GetReactionPrompt()
    if not check or not check.Visible then
        self:ResetReactionState()
        return
    end
    if not line or not goal then return end
    if not self:IsRepairingGenerator() then
        self:ResetReactionState()
        return
    end

    local lineRotation = line.Rotation % 360
    local goalRotation = goal.Rotation % 360
    local previousLine = self.ReactionLineRotation
    local checkChanged = self.ReactionCheck ~= check
    local goalChanged = self.ReactionGoalRotation ~= nil
        and self:RotationDistance(goalRotation, self.ReactionGoalRotation) > 1
    local lineJumped = previousLine ~= nil
        and self:RotationDistance(lineRotation, previousLine) > 24

    -- King's Scourge keeps the prompt visible while rapidly replacing its
    -- short checks. Goal changes and large needle jumps mark a new check.
    local newCheck = checkChanged or goalChanged or (self.ReactionTriggered and lineJumped)
    if newCheck then self.ReactionTriggered = false end
    self.ReactionCheck = check
    self.ReactionGoalRotation = goalRotation
    self.ReactionLineRotation = lineRotation
    if self.ReactionTriggered then return end

    -- The full green sector is roughly +101..+115 degrees. Triggering on its
    -- first pixel is unstable because the displayed line can be one frame
    -- ahead of the state processed by the game. Use the inner sector instead.
    local startRotation = (goalRotation + 106) % 360
    local endRotation = (goalRotation + 111) % 360
    local centerRotation = (goalRotation + 108.5) % 360
    local crossedCenter = previousLine ~= nil and not newCheck and not lineJumped
        and self:CrossedRotation(previousLine, lineRotation, centerRotation)
    if self:IsRotationInside(lineRotation, startRotation, endRotation) or crossedCenter then
        self.ReactionTriggered = true
        self:PressReaction()
    end
end

function ViolenceDistrict:Heartbeat(delta)
    if self.AutoReaction then self:TryAutoReaction() end
    self.Elapsed += delta
    if self.Elapsed < 0.2 then return end
    self.Elapsed = 0
    if self.KillerESP then self:ScanKillers() end
    if self.GeneratorESP or self.AutoReaction then self:ScanGenerators() end
end

function ViolenceDistrict:GetConfig()
    return {
        killerESP = self.KillerESP,
        generatorESP = self.GeneratorESP,
        autoReaction = self.AutoReaction,
    }
end

function ViolenceDistrict:ApplyConfig(data)
    if type(data) ~= "table" then return end
    self.KillerESP = data.killerESP == true
    self.GeneratorESP = data.generatorESP == true
    self.AutoReaction = data.autoReaction == true
    self.KillerESPControl.Set(self.KillerESP)
    self.GeneratorESPControl.Set(self.GeneratorESP)
    self.AutoReactionControl.Set(self.AutoReaction)
    self:RefreshHeartbeat()
end

function ViolenceDistrict:Destroy()
    self.KillerESP, self.GeneratorESP, self.AutoReaction = false, false, false
    self:ResetReactionState()
    self:RefreshHeartbeat()
    self.KillerChams:Clear()
    self.GeneratorChams:Clear()
    table.clear(self.Generators)
end

return ViolenceDistrict
