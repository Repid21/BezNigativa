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
        AutoShoot = false,
        AutoGun = false,
        GunESP = false,
        AutoFarm = false,
        Elapsed = 0,
        FarmBagElapsed = 0,
        FarmSpeed = 42,
        FarmCollision = setmetatable({}, {__mode = "k"}),
        LastShot = 0,
        TouchedCoins = setmetatable({}, {__mode = "k"}),
    }, MurderMystery2)
    local RoleChams = ctx.LoadModule("games/RoleChams")
    self.RoleChams = RoleChams.new("BezNigativaMM2Role")
    self.GunChams = RoleChams.new("BezNigativaMM2Gun")

    local page = ctx.Window:AddPage("Murder Mystery 2", "Role Aim, Auto Shoot, Gun и Auto Farm")
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

    local shoot = stack:Add("Auto Shoot", 126)
    self.AutoShootControl = ctx.Window:Toggle(shoot.Settings, UDim2.fromOffset(10, 4), 220, "Enabled", false, function(value)
        self.AutoShoot = value; self:RefreshHeartbeat(); ctx.Touch()
    end)
    self:AddHint(shoot.Settings, "Стреляет, только если луч первым попал в видимую часть маньяка.")

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
    self:AddHint(farm.Settings, "Летает под картой; при полном мешке возвращает на spawn.")

    ctx.Janitor:Add(function()
        if self.HeartbeatLoop then self.HeartbeatLoop:Disconnect(); self.HeartbeatLoop = nil end
    end)
    return self
end

function MurderMystery2:RefreshHeartbeat()
    local active = self.RoleChamsEnabled or self.AutoShoot or self.AutoGun or self.GunESP or self.AutoFarm
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

function MurderMystery2:AddHint(parent, text)
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

function MurderMystery2:GetRole(player)
    if findTool(player, {"Knife"}) then return "Murderer" end
    if findTool(player, {"Gun", "Revolver"}) then return "Sheriff" end
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
    if self.AutoFarm or findTool(self.ctx.LocalPlayer, {"Gun", "Revolver"}) or os.clock() - (self.LastPickupAttempt or 0) < 0.25 then return end
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

function MurderMystery2:VisibleBodyPoint(target)
    local character = target and target.Character
    local camera = self.ctx.Workspace.CurrentCamera
    if not character or not camera then return nil end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {self.ctx.LocalPlayer.Character, camera}
    params.IgnoreWater = true
    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") and part.Transparency < 1 then
            local half = part.Size * 0.45
            local samples = {
                part.Position,
                part.CFrame:PointToWorldSpace(Vector3.new(half.X, 0, 0)),
                part.CFrame:PointToWorldSpace(Vector3.new(-half.X, 0, 0)),
                part.CFrame:PointToWorldSpace(Vector3.new(0, half.Y, 0)),
                part.CFrame:PointToWorldSpace(Vector3.new(0, -half.Y, 0)),
            }
            for _, point in ipairs(samples) do
                local screen, onScreen = camera:WorldToViewportPoint(point)
                if onScreen and screen.Z > 0 then
                    local result = self.ctx.Workspace:Raycast(camera.CFrame.Position, point - camera.CFrame.Position, params)
                    if not result or result.Instance:IsDescendantOf(character) then return point end
                end
            end
        end
    end
    return nil
end

function MurderMystery2:GetEquippedGun()
    local character = self.ctx.LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local gun = character and findTool(self.ctx.LocalPlayer, {"Gun", "Revolver"})
    if gun and gun.Parent ~= character and humanoid then humanoid:EquipTool(gun) end
    return character and character:FindFirstChild("Gun") or character and character:FindFirstChild("Revolver")
end

function MurderMystery2:TryAutoShoot()
    if not self.AutoShoot or self.Shooting or os.clock() - self.LastShot < 0.12 then return end
    local targetRole = self:GetRole(self.ctx.LocalPlayer) == "Murderer" and "Sheriff" or "Murderer"
    local target = self:FindRole(targetRole)
    if not target or target == self.ctx.LocalPlayer then return end
    local point = self:VisibleBodyPoint(target)
    if not point then return end
    local gun = self:GetEquippedGun()
    if not gun or gun.Enabled == false then return end
    local knifeLocal = gun:FindFirstChild("KnifeLocal")
    local createBeam = knifeLocal and knifeLocal:FindFirstChild("CreateBeam")
    local remote = createBeam and createBeam:FindFirstChild("RemoteFunction")
    if not remote or not remote:IsA("RemoteFunction") then return end
    self.Shooting, self.LastShot = true, os.clock()
    task.spawn(function()
        pcall(function() remote:InvokeServer(1, point, "AH2") end)
        self.Shooting = false
    end)
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
    local map = self:FindMap()
    local spawns = map and map:FindFirstChild("Spawns", true)
    if not character or not spawns then return end
    local choices = {}
    for _, item in ipairs(spawns:GetDescendants()) do if item:IsA("BasePart") then table.insert(choices, item) end end
    if #choices > 0 then
        local spawnPart = choices[math.random(1, #choices)]
        character:PivotTo(spawnPart.CFrame * CFrame.new(0, 3, 0))
    end
end

function MurderMystery2:SetAutoFarm(value)
    self.AutoFarm = value
    self.BagHandled = false
    self.FarmBagElapsed = 0
    self.FarmBagFull = false
    self.FarmTarget = nil
    self.FarmUnderground = false
    if value then
        self.FarmStopToken = (self.FarmStopToken or 0) + 1
    else
        self:StopFarmMotion(true)
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
    self:SetFarmCollision(character, false)
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
    local regularActive = self.RoleChamsEnabled or self.AutoShoot or self.AutoGun or self.GunESP
    if not regularActive and not self.AutoFarm then return end
    self.Elapsed += delta
    if regularActive and self.Elapsed >= 0.12 then
        self.Elapsed = 0
        if self.RoleChamsEnabled then self:ScanRoles() end
        if self.AutoGun or self.GunESP then
            local gunDrop = self:FindGunDrop()
            if self.GunESP then self:UpdateGunVisual(gunDrop) end
            if self.AutoGun and gunDrop then self:PickupGun(gunDrop) end
        end
        if self.AutoShoot then self:TryAutoShoot() end
    end
    if self.AutoFarm then self:FarmStep(delta) end
end

function MurderMystery2:GetConfig()
    return {
        roleChams = self.RoleChamsEnabled,
        roleAimOnly = self.RoleAimOnly,
        autoShoot = self.AutoShoot,
        autoGun = self.AutoGun,
        gunESP = self.GunESP,
        autoFarm = self.AutoFarm,
    }
end

function MurderMystery2:ApplyConfig(data)
    if type(data) ~= "table" then return end
    self.RoleChamsEnabled = data.roleChams == true or data.enabled == true
    self.RoleAimOnly = data.roleAimOnly == true
    self.AutoShoot, self.AutoGun = data.autoShoot == true, data.autoGun == true
    self.GunESP = data.gunESP == true
    self:SetAutoFarm(data.autoFarm == true)
    self.RoleChamsControl.Set(self.RoleChamsEnabled)
    self.RoleAimControl.Set(self.RoleAimOnly)
    self.AutoShootControl.Set(self.AutoShoot)
    self.AutoGunControl.Set(self.AutoGun)
    self.GunESPControl.Set(self.GunESP)
    self.AutoFarmControl.Set(self.AutoFarm)
end

function MurderMystery2:Destroy()
    self.AutoFarm = false
    self:StopFarmMotion(false)
    self.AutoShoot, self.AutoGun, self.AutoFarm = false, false, false
    self.RoleChamsEnabled, self.GunESP = false, false
    self:RefreshHeartbeat()
    self.RoleChams:Clear(); self:ClearGunVisual()
end

return MurderMystery2
