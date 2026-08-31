local MurderMystery2 = {}
MurderMystery2.__index = MurderMystery2

local RED = Color3.fromRGB(255, 45, 45)
local BLUE = Color3.fromRGB(55, 135, 255)
local YELLOW = Color3.fromRGB(255, 225, 45)

local function findTool(player, names)
    local character = player and player.Character
    local backpack = player and (player:FindFirstChildOfClass("Backpack") or player:FindFirstChild("Backpack"))
    for _, name in ipairs(names) do
        local tool = character and character:FindFirstChild(name)
        if tool then return tool end
        tool = backpack and backpack:FindFirstChild(name)
        if tool then return tool end
    end
    return nil
end

local function basePart(instance)
    if not instance then return nil end
    if instance:IsA("BasePart") then return instance end
    return instance:FindFirstChildWhichIsA("BasePart", true)
end

function MurderMystery2.new(ctx)
    local self = setmetatable({
        ctx = ctx,
        RoleChamsEnabled = false,
        RoleAimOnly = false,
        TriggerBot = false,
        AutoGun = false,
        GunESP = false,
        AutoFarm = false,
        Elapsed = 0,
        FarmBagElapsed = 0,
        FarmSpeed = 20,
        FarmCollision = setmetatable({}, {__mode = "k"}),
        LastTrigger = 0,
        PlayerData = {},
        TouchedCoins = setmetatable({}, {__mode = "k"}),
    }, MurderMystery2)
    local RoleChams = ctx.LoadModule("games/RoleChams")
    self.RoleChams = RoleChams.new("BezNigativaMM2Role")
    self.GunChams = RoleChams.new("BezNigativaMM2Gun")

    local page = ctx.Window:AddPage("Murder Mystery 2", "Role Aim, TriggerBot, Gun и Auto Farm")
    local stack = ctx.Window:ModuleStack(page, 70)

    local roles = stack:Add("Role Chams", 126)
    self.RoleChamsControl = ctx.Window:Toggle(roles.Settings, UDim2.fromOffset(10, 4), 260, "Маньяк и шериф", false, function(value)
        self.RoleChamsEnabled = value
        if not value then self.RoleChams:Clear() end
        self:RefreshHeartbeat()
        ctx.Touch()
    end)
    self:AddHint(roles.Settings, "Маньяк — красный, игрок с Gun — синий.")

    local aim = stack:Add("Role AimBot", 88)
    self.RoleAimControl = ctx.Window:Toggle(aim.Settings, UDim2.fromOffset(10, 4), 300, "Только вражеская роль", false, function(value)
        self.RoleAimOnly = value; ctx.Touch()
    end)

    local trigger = stack:Add("TriggerBot", 126)
    self.TriggerBotControl = ctx.Window:Toggle(trigger.Settings, UDim2.fromOffset(10, 4), 260, "Маньяк / шериф", false, function(value)
        self.TriggerBot = value; self:RefreshHeartbeat(); ctx.Touch()
    end)
    self:AddHint(trigger.Settings, "Атакует только когда прицел на вражеской роли и нужное оружие в руках.")

    local gun = stack:Add("Dropped Gun", 132)
    self.AutoGunControl = ctx.Window:Toggle(gun.Settings, UDim2.fromOffset(10, 4), 220, "Auto Pickup", false, function(value)
        self.AutoGun = value; self:RefreshHeartbeat(); ctx.Touch()
    end)
    self.GunESPControl = ctx.Window:Toggle(gun.Settings, UDim2.fromOffset(240, 4), 220, "Gun ESP", false, function(value)
        self.GunESP = value
        if not value then self:ClearGunVisual() end
        self:RefreshHeartbeat()
        ctx.Touch()
    end)

    local farm = stack:Add("Coin Auto Farm", 126)
    self.AutoFarmControl = ctx.Window:Toggle(farm.Settings, UDim2.fromOffset(10, 4), 220, "Enabled", false, function(value)
        self:SetAutoFarm(value); ctx.Touch()
    end)
    self:AddHint(farm.Settings, "Летает под картой; полный мешок — возврат на безопасный spawn лобби.")

    ctx.Janitor:Add(function()
        if self.HeartbeatLoop then self.HeartbeatLoop:Disconnect(); self.HeartbeatLoop = nil end
    end)
    self:ConnectPlayerData()
    task.defer(function() self:CaptureLobbyPivot() end)
    return self
end

function MurderMystery2:ConnectPlayerData()
    local storage = self.ctx.ReplicatedStorage
    if not storage then return end
    local function attach(changed)
        if self.PlayerDataConnection or not changed or not changed:IsA("RemoteEvent") or changed.Name ~= "PlayerDataChanged" then return end
        local gameplay = changed.Parent
        if not gameplay or gameplay.Name ~= "Gameplay" then return end
        self.PlayerDataConnection = changed.OnClientEvent:Connect(function(data)
            if type(data) == "table" then self.PlayerData = data end
            self:CaptureLobbyPivot()
        end)
        self.ctx.Janitor:Add(self.PlayerDataConnection)
    end
    local remotes = storage:FindFirstChild("Remotes")
    local gameplay = remotes and remotes:FindFirstChild("Gameplay")
    attach(gameplay and gameplay:FindFirstChild("PlayerDataChanged"))
    self.ctx.Janitor:Add(storage.DescendantAdded:Connect(function(item) attach(item) end))
end

function MurderMystery2:CaptureLobbyPivot()
    if self:FindMap() then return end
    local character = self.ctx.LocalPlayer.Character
    if character then self.LobbyPivot = character:GetPivot() end
end

function MurderMystery2:RefreshHeartbeat()
    local active = self.RoleChamsEnabled or self.TriggerBot or self.AutoGun or self.GunESP or self.AutoFarm
    if active and not self.HeartbeatLoop then
        self.HeartbeatLoop = self.ctx.RunService.Heartbeat:Connect(function(delta)
            local ok, message = pcall(function() self:Heartbeat(delta) end)
            if not ok and not self.Warned then self.Warned = true; warn("[BezNigativa/MM2] " .. tostring(message)) end
        end)
    elseif not active and self.HeartbeatLoop then
        self.HeartbeatLoop:Disconnect()
        self.HeartbeatLoop = nil
    end
end

function MurderMystery2:AddHint(parent, text, y)
    local hint = Instance.new("TextLabel")
    hint.Position = UDim2.fromOffset(10, y or 48)
    hint.Size = UDim2.new(1, -20, 0, 38)
    hint.BackgroundTransparency = 1
    hint.Font = Enum.Font.Code
    hint.Text, hint.TextWrapped = text, true
    hint.TextColor3 = Color3.fromRGB(165, 165, 165)
    hint.TextSize = 12
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.Parent = parent
end

function MurderMystery2:GetRole(player)
    if findTool(player, {"Knife"}) then return "Murderer" end
    if findTool(player, {"Gun", "Revolver"}) then return "Sheriff" end
    local direct = self.PlayerData[player] or self.PlayerData[player.Name] or self.PlayerData[tostring(player.UserId)]
    if type(direct) == "table" and (direct.Role == "Murderer" or direct.Role == "Sheriff") then return direct.Role end
    for key, data in pairs(self.PlayerData) do
        if type(data) == "table" then
            local matches = key == player or tostring(key) == player.Name or tostring(key) == tostring(player.UserId)
            matches = matches or data.Name == player.Name or tonumber(data.UserId) == player.UserId
            if matches and (data.Role == "Murderer" or data.Role == "Sheriff") then return data.Role end
        end
    end
    return "Innocent"
end

function MurderMystery2:FindRole(role)
    for _, player in ipairs(self.ctx.Players:GetPlayers()) do
        if self:GetRole(player) == role then return player end
    end
    return nil
end

function MurderMystery2:IsAimTarget(player)
    if not self.RoleAimOnly then return true end
    local localRole = self:GetRole(self.ctx.LocalPlayer)
    if localRole == "Murderer" then return self:GetRole(player) == "Sheriff" end
    return self:GetRole(player) == "Murderer"
end

function MurderMystery2:ScanRoles()
    if not self.RoleChamsEnabled then return end
    local seen = {}
    for _, player in ipairs(self.ctx.Players:GetPlayers()) do
        if player ~= self.ctx.LocalPlayer and player.Character then
            local role = self:GetRole(player)
            if role == "Murderer" then self.RoleChams:Show(player.Character, RED, seen)
            elseif role == "Sheriff" then self.RoleChams:Show(player.Character, BLUE, seen) end
        end
    end
    self.RoleChams:Finish(seen)
end

function MurderMystery2:FindGunDrop()
    return self.ctx.Workspace:FindFirstChild("GunDrop", true) or self.ctx.Workspace:FindFirstChild("DroppedGun", true)
end

function MurderMystery2:ClearGunVisual()
    self.GunChams:Clear()
    if self.GunLabel then self.GunLabel:Destroy(); self.GunLabel = nil end
    self.GunLabelTarget = nil
end

function MurderMystery2:UpdateGunVisual(gunDrop)
    if not self.GunESP or not gunDrop then self:ClearGunVisual(); return end
    local seen = {}
    self.GunChams:Show(gunDrop, YELLOW, seen)
    self.GunChams:Finish(seen)
    local part = basePart(gunDrop)
    if not part then return end
    if not self.GunLabel or not self.GunLabel.Parent or self.GunLabelTarget ~= gunDrop then
        if self.GunLabel then self.GunLabel:Destroy() end
        local gui = Instance.new("BillboardGui")
        gui.Name = "BezNigativaGunLabel"
        gui.Adornee = part
        gui.AlwaysOnTop = true
        gui.Size = UDim2.fromOffset(100, 28)
        gui.StudsOffsetWorldSpace = Vector3.new(0, 1.2, 0)
        gui.Parent = self.ctx.Window.Gui.Parent
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Code
        label.Text = "GUN"
        label.TextColor3 = YELLOW
        label.TextStrokeTransparency = 0.2
        label.TextSize = 15
        label.Parent = gui
        self.GunLabel, self.GunLabelTarget = gui, gunDrop
    end
end

function MurderMystery2:PickupGun(gunDrop)
    if self.AutoFarm or self:GetRole(self.ctx.LocalPlayer) == "Murderer" or findTool(self.ctx.LocalPlayer, {"Gun", "Revolver"}) or os.clock() - (self.LastPickupAttempt or 0) < 0.25 then return end
    local part = basePart(gunDrop)
    local character = self.ctx.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not part or not root then return end
    self.LastPickupAttempt = os.clock()
    if type(firetouchinterest) == "function" then
        pcall(function()
            firetouchinterest(root, part, 0)
            firetouchinterest(root, part, 1)
        end)
    elseif not self.TouchWarning then
        self.TouchWarning = true
        warn("[BezNigativa/MM2] Auto Pickup requires firetouchinterest; teleport fallback is intentionally disabled")
    end
end

function MurderMystery2:GetEquippedWeapon(role)
    local character = self.ctx.LocalPlayer.Character
    if not character then return nil end
    local names = role == "Murderer" and {"Knife"} or {"Gun", "Revolver"}
    local weapon = findTool(self.ctx.LocalPlayer, names)
    if weapon and weapon.Parent == character and weapon.Enabled ~= false then return weapon end
    return nil
end

function MurderMystery2:GetPlayerUnderCrosshair()
    if not self.Mouse then
        local ok, mouse = pcall(function() return self.ctx.LocalPlayer:GetMouse() end)
        if ok then self.Mouse = mouse end
    end
    local item = self.Mouse and self.Mouse.Target
    while item and item ~= self.ctx.Workspace do
        local player = self.ctx.Players:GetPlayerFromCharacter(item)
        if player then return player end
        item = item.Parent
    end
    return nil
end

function MurderMystery2:ClickWeapon()
    if type(mouse1click) == "function" then
        return pcall(mouse1click)
    end
    if not self.VirtualInput then
        local ok, service = pcall(game.GetService, game, "VirtualInputManager")
        if ok then self.VirtualInput = service end
    end
    if not self.VirtualInput then return false end
    local position = self.ctx.UserInputService:GetMouseLocation()
    local ok = pcall(function()
        self.VirtualInput:SendMouseButtonEvent(position.X, position.Y, 0, true, game, 0)
        task.delay(0.025, function()
            pcall(function() self.VirtualInput:SendMouseButtonEvent(position.X, position.Y, 0, false, game, 0) end)
        end)
    end)
    return ok
end

function MurderMystery2:TryTriggerBot()
    local now = os.clock()
    if not self.TriggerBot or now - self.LastTrigger < 0.14 then return end
    local localRole = self:GetRole(self.ctx.LocalPlayer)
    if localRole ~= "Murderer" and localRole ~= "Sheriff" then return end
    if not self:GetEquippedWeapon(localRole) then return end
    local target = self:GetPlayerUnderCrosshair()
    if not target or target == self.ctx.LocalPlayer then return end
    local targetRole = localRole == "Murderer" and "Sheriff" or "Murderer"
    if self:GetRole(target) ~= targetRole then return end
    self.LastTrigger = now
    self:ClickWeapon()
end

function MurderMystery2:FindMap()
    if self.MapCache and self.MapCache.Parent and self.MapCache:FindFirstChild("CoinContainer", true) then
        return self.MapCache
    end
    for _, item in ipairs(self.ctx.Workspace:GetChildren()) do
        if item:IsA("Model") and item.Name ~= "Lobby" and item:FindFirstChild("CoinContainer", true) then
            self.MapCache = item
            return item
        end
    end
    self.MapCache = nil
    return nil
end

function MurderMystery2:IsBagFull()
    local playerGui = self.ctx.LocalPlayer:FindFirstChild("PlayerGui")
    local main = playerGui and playerGui:FindFirstChild("MainGUI")
    local bags = main and main:FindFirstChild("Game") and main.Game:FindFirstChild("CoinBags")
    if not bags then return false end
    for _, item in ipairs(bags:GetDescendants()) do
        if item.Name == "FullBagIcon" and item:IsA("GuiObject") and item.Visible then return true end
    end
    for _, item in ipairs(bags:GetDescendants()) do
        if item.Name == "Coins" and (item:IsA("TextLabel") or item:IsA("TextButton")) then
            local current, maximum = string.match(item.Text, "(%d+)%s*/%s*(%d+)")
            if current and maximum and tonumber(current) >= tonumber(maximum) then return true end
            local value = tonumber(string.match(item.Text, "%d+"))
            local limit = self.ctx.LocalPlayer:GetAttribute("Elite") and 50 or 40
            if value and value >= limit then return true end
        end
    end
    return false
end

function MurderMystery2:FindNearestCoin(root)
    local map = self:FindMap()
    local container = self.CoinContainer
    if not container or not container.Parent or not map or not container:IsDescendantOf(map) then
        container = map and map:FindFirstChild("CoinContainer", true)
        self.CoinContainer = container
    end
    if not container then return nil end
    local nearest, nearestDistance = nil, math.huge
    local now = os.clock()
    for _, item in ipairs(container:GetDescendants()) do
        if item:IsA("BasePart") and item:FindFirstChildWhichIsA("TouchTransmitter") then
            local touchedAt = self.TouchedCoins[item]
            local distance = (item.Position - root.Position).Magnitude
            if (not touchedAt or now - touchedAt > 0.6) and distance < nearestDistance then
                nearest, nearestDistance = item, distance
            end
        end
    end
    return nearest
end

function MurderMystery2:TeleportToSpawn()
    local character = self.ctx.LocalPlayer.Character
    if not character then return end
    local lobby = self.ctx.Workspace:FindFirstChild("Lobby")
    local spawnPart = lobby and lobby:FindFirstChildWhichIsA("SpawnLocation", true)
    if not spawnPart and lobby then
        for _, item in ipairs(lobby:GetDescendants()) do
            if item:IsA("BasePart") and string.find(string.lower(item.Name), "spawn", 1, true) then
                spawnPart = item
                break
            end
        end
    end
    if not spawnPart then
        local map = self:FindMap()
        for _, item in ipairs(self.ctx.Workspace:GetDescendants()) do
            if item:IsA("SpawnLocation") and (not map or not item:IsDescendantOf(map)) then
                spawnPart = item
                break
            end
        end
    end
    if spawnPart then
        character:PivotTo(spawnPart.CFrame * CFrame.new(0, 4, 0))
    elseif self.LobbyPivot then
        character:PivotTo(self.LobbyPivot)
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    if root then root.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
end

function MurderMystery2:SetAutoFarm(value)
    local wasEnabled = self.AutoFarm
    self.AutoFarm = value
    self.BagHandled = false
    self.FarmBagElapsed = 0
    self.FarmBagFull = false
    self.FarmTarget = nil
    self.FarmUnderground = false
    if value then
        if not wasEnabled then
            local movement = self.ctx.Movement
            self.AutoFarmPreviousNoclip = movement and movement.Noclip == true
            self.AutoFarmForcedNoclip = movement and type(movement.SetFeature) == "function"
            if self.AutoFarmForcedNoclip then movement.ForcedNoclipPrevious = self.AutoFarmPreviousNoclip end
        end
        local movement = self.ctx.Movement
        if movement and type(movement.SetFeature) == "function" then movement:SetFeature("Noclip", true, false, true) end
        self.FarmStopToken = (self.FarmStopToken or 0) + 1
    else
        self:StopFarmMotion(true)
        if wasEnabled and self.AutoFarmForcedNoclip then
            local movement = self.ctx.Movement
            local restoreValue = self.AutoFarmPreviousNoclip == true
            local stopToken = self.FarmStopToken
            task.delay(0.38, function()
                if self.AutoFarm or self.FarmStopToken ~= stopToken then return end
                if movement and type(movement.SetFeature) == "function" then
                    movement:SetFeature("Noclip", restoreValue, false, true)
                    movement.ForcedNoclipPrevious = nil
                end
            end)
        end
        self.AutoFarmForcedNoclip, self.AutoFarmPreviousNoclip = nil, nil
    end
    self:RefreshHeartbeat()
end

function MurderMystery2:SetFarmCollision(character, enabled)
    if not character then return end
    if enabled then
        for part, original in pairs(self.FarmCollision) do
            if part and part.Parent then part.CanCollide = original end
            self.FarmCollision[part] = nil
        end
        return
    end

    for _, item in ipairs(character:GetDescendants()) do
        if item:IsA("BasePart") then
            if self.FarmCollision[item] == nil then self.FarmCollision[item] = item.CanCollide end
            item.CanCollide = false
        end
    end
end

function MurderMystery2:EnsureFarmVelocity(root, character)
    if self.FarmVelocity and self.FarmVelocity.Parent == root then return self.FarmVelocity end
    if self.FarmVelocity then self.FarmVelocity:Destroy() end
    if self.FarmCharacter and self.FarmCharacter ~= character then self:SetFarmCollision(self.FarmCharacter, true) end
    if self.FarmCharacter ~= character then self.FarmUnderground = false end
    self.FarmCharacter = character
    local movement = self.ctx.Movement
    if not movement or type(movement.SetFeature) ~= "function" then self:SetFarmCollision(character, false) end
    local velocity = Instance.new("BodyVelocity")
    velocity.Name = "BezNigativaCoinFlight"
    velocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    velocity.P = 1500
    velocity.Velocity = Vector3.new(0, 0, 0)
    velocity.Parent = root
    self.FarmVelocity = velocity
    return velocity
end

function MurderMystery2:StopFarmMotion(liftToSurface)
    self.FarmTarget = nil
    self.FarmUnderground = false
    local velocity = self.FarmVelocity
    self.FarmVelocity = nil
    local character = self.FarmCharacter or self.ctx.LocalPlayer.Character
    self.FarmCharacter = nil
    local token = (self.FarmStopToken or 0) + 1
    self.FarmStopToken = token

    if liftToSurface and velocity and velocity.Parent then
        velocity.Velocity = Vector3.new(0, 55, 0)
        task.delay(0.35, function()
            if self.FarmStopToken ~= token then
                if velocity.Parent then velocity:Destroy() end
                return
            end
            if velocity.Parent then velocity:Destroy() end
            self:SetFarmCollision(character, true)
        end)
    else
        if velocity and velocity.Parent then velocity:Destroy() end
        self:SetFarmCollision(character, true)
    end
end

function MurderMystery2:FarmStep(delta)
    if not self.AutoFarm then return end
    local movement = self.ctx.Movement
    if movement and type(movement.SetFeature) == "function" and not movement.Noclip then
        movement:SetFeature("Noclip", true, false, true)
    end
    self.FarmBagElapsed += delta
    if self.FarmBagElapsed >= 0.25 then
        self.FarmBagElapsed = 0
        self.FarmBagFull = self:IsBagFull()
    end
    if self.FarmBagFull then
        if not self.BagHandled then
            self.BagHandled = true
            self:StopFarmMotion(false)
            self:TeleportToSpawn()
        end
        return
    end
    self.BagHandled = false
    local character = self.ctx.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or not root or not humanoid or humanoid.Health <= 0 then return end

    local velocity = self:EnsureFarmVelocity(root, character)
    local coin = self.FarmTarget
    if not coin or not coin.Parent or not coin:IsA("BasePart") or not coin:FindFirstChildWhichIsA("TouchTransmitter") then
        coin = self:FindNearestCoin(root)
        self.FarmTarget = coin
    end
    if not coin then
        velocity.Velocity = Vector3.new(0, 0, 0)
        return
    end

    local destination = coin.Position - Vector3.new(0, 5.5, 0)
    if not self.FarmUnderground then
        local vertical = destination.Y - root.Position.Y
        if math.abs(vertical) > 1.5 then
            velocity.Velocity = Vector3.new(0, math.sign(vertical) * self.FarmSpeed, 0)
            return
        end
        self.FarmUnderground = true
    end
    local offset = destination - root.Position
    local distance = offset.Magnitude
    if distance > 3.4 then
        velocity.Velocity = offset.Unit * self.FarmSpeed
        return
    end

    velocity.Velocity = Vector3.new(0, 0, 0)
    if type(firetouchinterest) == "function" then
        pcall(function()
            firetouchinterest(root, coin, 0)
            firetouchinterest(root, coin, 1)
        end)
    end
    self.TouchedCoins[coin] = os.clock()
    self.FarmTarget = nil
end

function MurderMystery2:Heartbeat(delta)
    local regularActive = self.RoleChamsEnabled or self.AutoGun or self.GunESP
    if not regularActive and not self.TriggerBot and not self.AutoFarm then return end
    if self.TriggerBot then self:TryTriggerBot() end
    self.Elapsed += delta
    if regularActive and self.Elapsed >= 0.12 then
        self.Elapsed = 0
        if self.RoleChamsEnabled then self:ScanRoles() end
        if self.AutoGun or self.GunESP then
            local gunDrop = self:FindGunDrop()
            if self.GunESP then self:UpdateGunVisual(gunDrop) end
            if self.AutoGun and gunDrop then self:PickupGun(gunDrop) end
        end
    end
    if self.AutoFarm then self:FarmStep(delta) end
end

function MurderMystery2:GetConfig()
    return {
        roleChams = self.RoleChamsEnabled,
        roleAimOnly = self.RoleAimOnly,
        triggerBot = self.TriggerBot,
        autoGun = self.AutoGun,
        gunESP = self.GunESP,
        autoFarm = self.AutoFarm,
    }
end

function MurderMystery2:ApplyConfig(data)
    if type(data) ~= "table" then return end
    self.RoleChamsEnabled = data.roleChams == true or data.enabled == true
    self.RoleAimOnly = data.roleAimOnly == true
    self.TriggerBot, self.AutoGun = data.triggerBot == true, data.autoGun == true
    self.GunESP = data.gunESP == true
    self:SetAutoFarm(data.autoFarm == true)
    self.RoleChamsControl.Set(self.RoleChamsEnabled)
    self.RoleAimControl.Set(self.RoleAimOnly)
    self.TriggerBotControl.Set(self.TriggerBot)
    self.AutoGunControl.Set(self.AutoGun)
    self.GunESPControl.Set(self.GunESP)
    self.AutoFarmControl.Set(self.AutoFarm)
end

function MurderMystery2:Destroy()
    local restoreNoclip = self.AutoFarmForcedNoclip and self.AutoFarmPreviousNoclip == true
    self.AutoFarm = false
    self:StopFarmMotion(false)
    local movement = self.ctx.Movement
    if self.AutoFarmForcedNoclip and movement and type(movement.SetFeature) == "function" then
        movement:SetFeature("Noclip", restoreNoclip, false, true)
        movement.ForcedNoclipPrevious = nil
    end
    self.AutoFarmForcedNoclip, self.AutoFarmPreviousNoclip = nil, nil
    self.TriggerBot, self.AutoGun, self.AutoFarm = false, false, false
    self.RoleChamsEnabled, self.GunESP = false, false
    self:RefreshHeartbeat()
    self.RoleChams:Clear(); self:ClearGunVisual()
end

return MurderMystery2
