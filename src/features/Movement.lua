local Movement = {}
Movement.__index = Movement

local function corner(parent, radius)
    local item = Instance.new("UICorner")
    item.CornerRadius = UDim.new(0, radius or 4)
    item.Parent = parent
end

local function inputName(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then return input.KeyCode.Name end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then return "MouseButton1" end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then return "MouseButton2" end
    return nil
end

local function isTyping(ctx)
    local ok, focused = pcall(function() return ctx.UserInputService:GetFocusedTextBox() end)
    return ok and focused ~= nil
end

local BINDABLE = {"Speed", "Jump", "Noclip", "Fly"}

function Movement.new(ctx)
    local self = setmetatable({
        ctx = ctx,
        Speed = false, SpeedValue = 24,
        Jump = false, JumpValue = 80,
        Noclip = false,
        Fly = false, FlySpeed = 55,
        Bindings = {Speed = nil, Jump = nil, Noclip = nil, Fly = nil},
        BindModes = {Speed = "Toggle", Jump = "Toggle", Noclip = "Toggle", Fly = "Toggle"},
        BindHeld = {}, BindControls = {}, ModeControls = {},
        OriginalCollision = {}, HumanoidConnections = {},
    }, Movement)

    local page = ctx.Window:AddPage("Movement", "Движение и телепорт к игроку")
    local stack = ctx.Window:ModuleStack(page, 70)
    local speed = stack:Add("Speed", 172)
    self.SpeedControl = ctx.Window:Toggle(speed.Settings, UDim2.fromOffset(10, 4), 190, "Enabled", false, function(v)
        self:SetFeature("Speed", v, true, false)
    end)
    self.SpeedValueControl = ctx.Window:Slider(speed.Settings, 48, "Strength", 24, 0, 200, 1, function(v) self.SpeedValue = v; self:ApplyHumanoid(); ctx.Touch() end)
    self:BuildBinding(speed.Settings, 88, "Speed")

    local jump = stack:Add("Jump", 172)
    self.JumpControl = ctx.Window:Toggle(jump.Settings, UDim2.fromOffset(10, 4), 190, "Enabled", false, function(v)
        self:SetFeature("Jump", v, true, false)
    end)
    self.JumpValueControl = ctx.Window:Slider(jump.Settings, 48, "Strength", 80, 25, 250, 1, function(v) self.JumpValue = v; self:ApplyHumanoid(); ctx.Touch() end)
    self:BuildBinding(jump.Settings, 88, "Jump")

    local noclip = stack:Add("NoClip", 132)
    self.NoclipControl = ctx.Window:Toggle(noclip.Settings, UDim2.fromOffset(10, 4), 190, "Enabled", false, function(v)
        self:SetFeature("Noclip", v, true, false)
    end)
    self:BuildBinding(noclip.Settings, 48, "Noclip")

    local fly = stack:Add("Fly", 172)
    self.FlyControl = ctx.Window:Toggle(fly.Settings, UDim2.fromOffset(10, 4), 190, "Enabled", false, function(v)
        self:SetFeature("Fly", v, true, false)
    end)
    self.FlyValueControl = ctx.Window:Slider(fly.Settings, 48, "Strength", 55, 10, 250, 1, function(v) self.FlySpeed = v; ctx.Touch() end)
    self:BuildBinding(fly.Settings, 88, "Fly")

    local teleport = stack:Add("Teleport", 310)
    self:BuildTeleport(teleport.Settings)

    ctx.Janitor:Add(ctx.Players.PlayerAdded:Connect(function() self:RenderPlayers() end))
    ctx.Janitor:Add(ctx.Players.PlayerRemoving:Connect(function() task.defer(function() self:RenderPlayers() end) end))
    ctx.Janitor:Add(ctx.LocalPlayer.CharacterAdded:Connect(function()
        self:StopFly(); table.clear(self.OriginalCollision)
        self:DisconnectHumanoid()
        task.defer(function() self:WatchHumanoid(); self:ApplyHumanoid() end)
    end))
    ctx.Janitor:Add(ctx.UserInputService.InputBegan:Connect(function(input)
        self:HandleBindBegan(input)
    end))
    ctx.Janitor:Add(ctx.UserInputService.InputEnded:Connect(function(input)
        self:HandleBindEnded(input)
    end))
    ctx.Janitor:Add(function() self:DisconnectLoops() end)
    self:WatchHumanoid()
    return self
end

function Movement:BuildBinding(parent, y, feature)
    local mode = self.ctx.Window:Button(parent, UDim2.fromOffset(10, y), UDim2.new(0.5, -15, 0, 34), "Mode: Toggle", function()
        if self.BindHeld[feature] then
            self.BindHeld[feature] = false
            self:SetFeature(feature, false, false, true)
        end
        self.BindModes[feature] = self.BindModes[feature] == "Hold" and "Toggle" or "Hold"
        self:DrawBinding(feature)
        self.ctx.Touch()
    end)
    local bind = self.ctx.Window:Button(parent, UDim2.new(0.5, 5, 0, y), UDim2.new(0.5, -15, 0, 34), "Bind: None", function()
        if self.CapturingBind and self.CapturingBind ~= feature then self:DrawBinding(self.CapturingBind) end
        self.CapturingBind = feature
        self:DrawBinding(feature)
    end)
    self.ModeControls[feature], self.BindControls[feature] = mode, bind
    self:DrawBinding(feature)
end

function Movement:DrawBinding(feature)
    local mode = self.ModeControls[feature]
    local bind = self.BindControls[feature]
    if mode then mode.Text = "Mode: " .. (self.BindModes[feature] or "Toggle") end
    if bind then
        bind.Text = self.CapturingBind == feature and "ESC / Del / key..." or "Bind: " .. (self.Bindings[feature] or "None")
    end
end

function Movement:SetFeature(feature, value, touchConfig, updateControl)
    value = value == true
    self[feature] = value
    if feature == "Speed" then
        if value then self:ApplyHumanoid() else self:RestoreSpeed() end
    elseif feature == "Jump" then
        if value then self:ApplyHumanoid() else self:RestoreJump() end
    elseif feature == "Noclip" then
        if not value then self:RestoreCollision() end
    elseif feature == "Fly" and not value then
        self:StopFly()
    end
    if updateControl then
        local control = self[feature .. "Control"]
        if control then control.Set(value) end
    end
    self:RefreshLoops()
    if touchConfig then self.ctx.Touch() end
end

function Movement:HandleBindBegan(input)
    if self.CapturingBind then
        local feature = self.CapturingBind
        if input.KeyCode == Enum.KeyCode.Escape then
            self.CapturingBind = nil
        elseif input.KeyCode == Enum.KeyCode.Delete or input.KeyCode == Enum.KeyCode.Backspace then
            self.Bindings[feature] = nil
            if self.BindHeld[feature] then self:SetFeature(feature, false, false, true) end
            self.BindHeld[feature] = false
            self.CapturingBind = nil
            self.ctx.Touch()
        else
            local name = inputName(input)
            if name then
                self.Bindings[feature] = name
                self.CapturingBind = nil
                self.ctx.Touch()
            end
        end
        self:DrawBinding(feature)
        return
    end
    -- Game actions (for example Forsaken sprint on LeftShift) set
    -- gameProcessedEvent. Custom binds must still receive the same key.
    if isTyping(self.ctx) then return end
    local name = inputName(input)
    if not name then return end
    for _, feature in ipairs(BINDABLE) do
        if self.Bindings[feature] == name then
            if self.BindModes[feature] == "Hold" then
                self.BindHeld[feature] = true
                self:SetFeature(feature, true, false, true)
            else
                self:SetFeature(feature, not self[feature], true, true)
            end
        end
    end
end

function Movement:HandleBindEnded(input)
    local name = inputName(input)
    if not name then return end
    for _, feature in ipairs(BINDABLE) do
        if self.BindModes[feature] == "Hold" and self.BindHeld[feature] and self.Bindings[feature] == name then
            self.BindHeld[feature] = false
            self:SetFeature(feature, false, false, true)
        end
    end
end

function Movement:DisconnectLoops()
    if self.NoclipLoop then self.NoclipLoop:Disconnect(); self.NoclipLoop = nil end
    if self.MovementLoop then self.MovementLoop:Disconnect(); self.MovementLoop = nil end
end

function Movement:RefreshLoops()
    if self.Noclip and not self.NoclipLoop then
        self.NoclipLoop = self.ctx.RunService.Stepped:Connect(function() self:StepNoclip() end)
    elseif not self.Noclip and self.NoclipLoop then
        self.NoclipLoop:Disconnect(); self.NoclipLoop = nil
    end

    local active = self.Speed or self.Jump or self.Fly
    if active and not self.MovementLoop then
        self.MovementLoop = self.ctx.RunService.Heartbeat:Connect(function()
            local ok, message = pcall(function() self:StepMovement() end)
            if not ok and not self.Warned then self.Warned = true; warn("[BezNigativa/Movement] " .. tostring(message)) end
        end)
    elseif not active and self.MovementLoop then
        self.MovementLoop:Disconnect(); self.MovementLoop = nil
    end
end

function Movement:CharacterParts()
    local character = self.ctx.LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return character, humanoid, root
end

function Movement:DisconnectHumanoid()
    for _, connection in ipairs(self.HumanoidConnections) do pcall(function() connection:Disconnect() end) end
    table.clear(self.HumanoidConnections)
    self.ActiveHumanoid = nil
end

function Movement:WatchHumanoid()
    local _, humanoid = self:CharacterParts()
    if not humanoid or self.ActiveHumanoid == humanoid then return humanoid end
    self:DisconnectHumanoid()
    self.ActiveHumanoid = humanoid
    self.DefaultWalkSpeed = humanoid.WalkSpeed
    self.DefaultJumpPower = humanoid.JumpPower
    self.DefaultJumpHeight = humanoid.JumpHeight
    local function enforce()
        if (self.Speed or self.Jump) and not self.ApplyingMovement then self:ApplyHumanoid() end
    end
    for _, property in ipairs({"WalkSpeed", "JumpPower", "JumpHeight", "UseJumpPower"}) do
        local connection = humanoid:GetPropertyChangedSignal(property):Connect(enforce)
        table.insert(self.HumanoidConnections, connection)
        self.ctx.Janitor:Add(connection)
    end
    return humanoid
end

function Movement:ApplyHumanoid()
    local humanoid = self:WatchHumanoid()
    if not humanoid or self.ApplyingMovement then return end
    self.ApplyingMovement = true
    local ok, message = pcall(function()
        if self.Speed and humanoid.WalkSpeed ~= self.SpeedValue then humanoid.WalkSpeed = self.SpeedValue end
        if self.Jump then
            if humanoid.UseJumpPower then
                if humanoid.JumpPower ~= self.JumpValue then humanoid.JumpPower = self.JumpValue end
            elseif humanoid.JumpHeight ~= math.max(7.2, self.JumpValue / 7) then
                humanoid.JumpHeight = math.max(7.2, self.JumpValue / 7)
            end
        end
    end)
    self.ApplyingMovement = false
    if not ok then error(message) end
end

function Movement:RestoreSpeed()
    local _, humanoid = self:CharacterParts()
    if not humanoid then return end
    humanoid.WalkSpeed = self.DefaultWalkSpeed or 16
end

function Movement:RestoreJump()
    local _, humanoid = self:CharacterParts()
    if not humanoid then return end
    if humanoid.UseJumpPower then humanoid.JumpPower = self.DefaultJumpPower or 50
    else humanoid.JumpHeight = self.DefaultJumpHeight or 7.2 end
end

function Movement:StepNoclip()
    if not self.Noclip then return end
    local character = self.ctx.LocalPlayer.Character
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            if self.OriginalCollision[part] == nil then self.OriginalCollision[part] = part.CanCollide end
            part.CanCollide = false
        end
    end
end

function Movement:RestoreCollision()
    for part, value in pairs(self.OriginalCollision) do
        if part.Parent then part.CanCollide = value end
    end
    table.clear(self.OriginalCollision)
end

function Movement:FlyObjects(root)
    if self.FlyRoot ~= root or not self.FlyVelocity or not self.FlyGyro then
        self:StopFly()
        local velocity = Instance.new("BodyVelocity")
        velocity.Name = "BezNigativaFlyVelocity"
        velocity.MaxForce = Vector3.new(1, 1, 1) * math.huge
        velocity.Velocity = Vector3.new(0, 0, 0)
        velocity.Parent = root
        local gyro = Instance.new("BodyGyro")
        gyro.Name = "BezNigativaFlyGyro"
        gyro.MaxTorque = Vector3.new(1, 1, 1) * math.huge
        gyro.P = 90000
        gyro.CFrame = root.CFrame
        gyro.Parent = root
        self.FlyRoot, self.FlyVelocity, self.FlyGyro = root, velocity, gyro
    end
end

function Movement:StopFly()
    if self.FlyVelocity then self.FlyVelocity:Destroy() end
    if self.FlyGyro then self.FlyGyro:Destroy() end
    self.FlyRoot, self.FlyVelocity, self.FlyGyro = nil, nil, nil
end

function Movement:StepMovement()
    if self.Speed or self.Jump then self:ApplyHumanoid() end
    local _, humanoid, root = self:CharacterParts()
    if not self.Fly then return end
    local camera = workspace.CurrentCamera
    if not humanoid or not root or not camera then return end
    self:FlyObjects(root)
    humanoid.PlatformStand = false
    local input = self.ctx.UserInputService
    local direction = Vector3.new(0, 0, 0)
    if input:IsKeyDown(Enum.KeyCode.W) then direction += camera.CFrame.LookVector end
    if input:IsKeyDown(Enum.KeyCode.S) then direction -= camera.CFrame.LookVector end
    if input:IsKeyDown(Enum.KeyCode.D) then direction += camera.CFrame.RightVector end
    if input:IsKeyDown(Enum.KeyCode.A) then direction -= camera.CFrame.RightVector end
    if input:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.new(0, 1, 0) end
    if input:IsKeyDown(Enum.KeyCode.LeftControl) then direction -= Vector3.new(0, 1, 0) end
    self.FlyVelocity.Velocity = direction.Magnitude > 0 and direction.Unit * self.FlySpeed or Vector3.new(0, 0, 0)
    self.FlyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + camera.CFrame.LookVector)
end

function Movement:BuildTeleport(parent)
    local input = Instance.new("TextBox")
    input.Position = UDim2.fromOffset(10, 4)
    input.Size = UDim2.new(1, -20, 0, 34)
    input.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    input.BorderSizePixel = 0
    input.ClearTextOnFocus = false
    input.PlaceholderText = "Начните вводить ник..."
    input.Text = ""
    input.Font = Enum.Font.Code
    input.TextColor3 = Color3.fromRGB(235, 235, 235)
    input.PlaceholderColor3 = Color3.fromRGB(135, 135, 135)
    input.TextSize = 12
    input.Parent = parent
    corner(input)
    local list = Instance.new("ScrollingFrame")
    list.Position = UDim2.fromOffset(10, 48)
    list.Size = UDim2.new(1, -20, 0, 214)
    list.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 3
    list.CanvasSize = UDim2.fromOffset(0, 0)
    list.Parent = parent
    corner(list)
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.Parent = list
    self.TeleportInput, self.TeleportList, self.TeleportLayout = input, list, layout
    self.ctx.Janitor:Add(input:GetPropertyChangedSignal("Text"):Connect(function() self:RenderPlayers() end))
    self.ctx.Janitor:Add(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 4)
    end))
    self:RenderPlayers()
end

function Movement:RenderPlayers()
    if not self.TeleportList then return end
    for _, child in ipairs(self.TeleportList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local query = string.lower(self.TeleportInput.Text:gsub("^@", ""))
    local players = {}
    for _, player in ipairs(self.ctx.Players:GetPlayers()) do
        if player ~= self.ctx.LocalPlayer then
            local name, display = string.lower(player.Name), string.lower(player.DisplayName)
            if query == "" or string.sub(name, 1, #query) == query or string.sub(display, 1, #query) == query then
                table.insert(players, player)
            end
        end
    end
    table.sort(players, function(a, b) return string.lower(a.Name) < string.lower(b.Name) end)
    for index, player in ipairs(players) do
        local row = self.ctx.Window:Button(self.TeleportList, UDim2.new(), UDim2.new(1, -4, 0, 32), player.DisplayName .. "  @" .. player.Name, function()
            self:TeleportTo(player)
        end)
        row.LayoutOrder = index
        row.TextXAlignment = Enum.TextXAlignment.Left
    end
end

function Movement:TeleportTo(player)
    local character, _, root = self:CharacterParts()
    local targetRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if character and root and targetRoot then character:PivotTo(targetRoot.CFrame * CFrame.new(0, 0, 3)) end
end

function Movement:GetConfig()
    local savedNoclip = self.Noclip
    if self.ForcedNoclipPrevious ~= nil then savedNoclip = self.ForcedNoclipPrevious == true end
    return {
        speed = self.Speed, speedValue = self.SpeedValue,
        jump = self.Jump, jumpValue = self.JumpValue,
        noclip = savedNoclip, fly = self.Fly, flySpeed = self.FlySpeed,
        binds = {
            Speed = {key = self.Bindings.Speed, mode = self.BindModes.Speed},
            Jump = {key = self.Bindings.Jump, mode = self.BindModes.Jump},
            Noclip = {key = self.Bindings.Noclip, mode = self.BindModes.Noclip},
            Fly = {key = self.Bindings.Fly, mode = self.BindModes.Fly},
        },
    }
end

function Movement:ApplyConfig(data)
    if type(data) ~= "table" then return end
    self.Speed = data.speed == true; self.SpeedValue = math.clamp(tonumber(data.speedValue) or self.SpeedValue, 0, 200)
    self.Jump = data.jump == true; self.JumpValue = math.clamp(tonumber(data.jumpValue) or self.JumpValue, 25, 250)
    self.Noclip = data.noclip == true; self.Fly = data.fly == true
    self.FlySpeed = math.clamp(tonumber(data.flySpeed) or self.FlySpeed, 10, 250)
    local binds = type(data.binds) == "table" and data.binds or {}
    for _, feature in ipairs(BINDABLE) do
        local entry = type(binds[feature]) == "table" and binds[feature] or {}
        self.Bindings[feature] = type(entry.key) == "string" and entry.key or nil
        self.BindModes[feature] = entry.mode == "Hold" and "Hold" or "Toggle"
        self:DrawBinding(feature)
    end
    self.SpeedControl.Set(self.Speed); self.SpeedValueControl.Set(self.SpeedValue)
    self.JumpControl.Set(self.Jump); self.JumpValueControl.Set(self.JumpValue)
    self.NoclipControl.Set(self.Noclip); self.FlyControl.Set(self.Fly); self.FlyValueControl.Set(self.FlySpeed)
    self:ApplyHumanoid()
    self:RefreshLoops()
end

function Movement:Destroy()
    self.Fly = false
    self:StopFly()
    self:RestoreCollision()
    self.Speed, self.Jump = false, false
    self.Noclip = false
    self:DisconnectLoops()
    self:RestoreSpeed(); self:RestoreJump()
    self:DisconnectHumanoid()
end

return Movement
