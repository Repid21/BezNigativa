local Combat = {}
Combat.__index = Combat

local function alive(player)
    local character = player and player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return character and humanoid and humanoid.Health > 0
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

function Combat.new(ctx)
    local self = setmetatable({
        ctx = ctx,
        Enabled = false,
        WallCheck = true,
        Fov = 180,
        ShowFov = true,
        Smooth = 5,
        AimPart = "Head",
        Mode = "Hold",
        Bind = "MouseButton2",
        Held = false,
        Toggled = false,
        Capturing = false,
        Target = nil,
    }, Combat)

    local page = ctx.Window:AddPage("Combat", "AimBot и привязка клавиши")
    local stack = ctx.Window:ModuleStack(page, 70)
    local module = stack:Add("AimBot", 342)
    self.EnabledControl = ctx.Window:Toggle(module.Settings, UDim2.fromOffset(10, 4), 160, "Enabled", false, function(value)
        self.Enabled = value; self.Target = nil; self:RefreshRenderBinding(); ctx.Touch()
    end)
    self.WallControl = ctx.Window:Toggle(module.Settings, UDim2.fromOffset(180, 4), 160, "Wall Check", true, function(value)
        self.WallCheck = value; self.Target = nil; ctx.Touch()
    end)
    self.PartControl = ctx.Window:Button(module.Settings, UDim2.fromOffset(350, 4), UDim2.new(1, -360, 0, 34), "Part: Head", function()
        self.AimPart = self.AimPart == "Head" and "HumanoidRootPart" or "Head"
        self.PartControl.Text = "Part: " .. (self.AimPart == "Head" and "Head" or "Body")
        ctx.Touch()
    end)
    self.FovControl = ctx.Window:Slider(module.Settings, 48, "FOV", self.Fov, 30, 600, 1, function(value)
        self.Fov = value; ctx.Touch()
    end)
    self.SmoothControl = ctx.Window:Slider(module.Settings, 88, "Smooth", self.Smooth, 1, 20, 1, function(value)
        self.Smooth = value; ctx.Touch()
    end)
    self.ModeControl = ctx.Window:Button(module.Settings, UDim2.fromOffset(10, 132), UDim2.new(0.5, -15, 0, 34), "Mode: Hold", function()
        self.Mode = self.Mode == "Hold" and "Toggle" or "Hold"
        self.Held, self.Toggled = false, false
        self.ModeControl.Text = "Mode: " .. self.Mode
        ctx.Touch()
    end)
    self.BindControl = ctx.Window:Button(module.Settings, UDim2.new(0.5, 5, 0, 132), UDim2.new(0.5, -15, 0, 34), "Bind: MouseButton2", function()
        self.Capturing = true
        self.BindControl.Text = "Нажмите кнопку..."
    end)

    local hint = Instance.new("TextLabel")
    hint.Position = UDim2.fromOffset(10, 176)
    hint.Size = UDim2.new(1, -20, 0, 50)
    hint.BackgroundTransparency = 1
    hint.Font = Enum.Font.Code
    hint.Text = "ESC — отмена выбора\nDel / Backspace — удалить бинд"
    hint.TextColor3 = Color3.fromRGB(160, 160, 160)
    hint.TextSize = 12
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextYAlignment = Enum.TextYAlignment.Top
    hint.Parent = module.Settings
    self.FovCircleControl = ctx.Window:Toggle(module.Settings, UDim2.fromOffset(10, 232), 190, "FOV Circle", true, function(value)
        self.ShowFov = value; ctx.Touch()
    end)

    local fovCircle = Instance.new("Frame")
    fovCircle.Name = "BezNigativaFovCircle"
    fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
    fovCircle.BackgroundTransparency = 1
    fovCircle.BorderSizePixel = 0
    fovCircle.Active = false
    fovCircle.Visible = false
    fovCircle.ZIndex = 0
    fovCircle.Parent = ctx.Window.OverlayGui or ctx.Window.Gui
    local circleCorner = Instance.new("UICorner")
    circleCorner.CornerRadius = UDim.new(1, 0)
    circleCorner.Parent = fovCircle
    local circleStroke = Instance.new("UIStroke")
    circleStroke.Color = Color3.fromRGB(235, 235, 235)
    circleStroke.Thickness = 1
    circleStroke.Transparency = 0.2
    circleStroke.Parent = fovCircle
    self.FovCircle = fovCircle

    ctx.Janitor:Add(ctx.UserInputService.InputBegan:Connect(function(input)
        if self.Capturing then
            if input.KeyCode == Enum.KeyCode.Escape then
                self.Capturing = false
            elseif input.KeyCode == Enum.KeyCode.Delete or input.KeyCode == Enum.KeyCode.Backspace then
                self.Bind = nil; self.Capturing = false; self.Held = false; self.Toggled = false; ctx.Touch()
            else
                local name = inputName(input)
                if name then self.Bind = name; self.Capturing = false; ctx.Touch() end
            end
            self:DrawBind()
            return
        end
        -- Do not discard keys consumed by the game: users can intentionally
        -- share a key between a game action and an AimBot bind.
        if isTyping(ctx) or inputName(input) ~= self.Bind then return end
        if self.Mode == "Hold" then self.Held = true else self.Toggled = not self.Toggled end
    end))
    ctx.Janitor:Add(ctx.UserInputService.InputEnded:Connect(function(input)
        if self.Mode == "Hold" and inputName(input) == self.Bind then self.Held = false; self.Target = nil end
    end))

    self.RenderName = "BezNigativaAimBot"
    ctx.Janitor:Add(function()
        if self.RenderBound then ctx.RunService:UnbindFromRenderStep(self.RenderName) end
        self.RenderBound = false
    end)
    return self
end

function Combat:RefreshRenderBinding()
    if self.Enabled and not self.RenderBound then
        self.ctx.RunService:BindToRenderStep(self.RenderName, Enum.RenderPriority.Camera.Value + 1, function() self:Step() end)
        self.RenderBound = true
    elseif not self.Enabled and self.RenderBound then
        self.ctx.RunService:UnbindFromRenderStep(self.RenderName)
        self.RenderBound = false
        if self.FovCircle then self.FovCircle.Visible = false end
    end
end

function Combat:DrawBind()
    self.BindControl.Text = "Bind: " .. (self.Bind or "None")
end

function Combat:IsActive()
    return self.Enabled and (self.Mode == "Hold" and self.Held or self.Mode == "Toggle" and self.Toggled)
end

function Combat:Visible(part)
    if not self.WallCheck then return true end
    local camera = workspace.CurrentCamera
    if not camera then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {self.ctx.LocalPlayer.Character, camera}
    params.IgnoreWater = true
    local result = workspace:Raycast(camera.CFrame.Position, part.Position - camera.CFrame.Position, params)
    return not result or result.Instance:IsDescendantOf(part.Parent)
end

function Combat:Candidate(player)
    if player == self.ctx.LocalPlayer or self.ctx.Friends:IsFriend(player) or not alive(player) then return nil end
    local profile = self.ctx.GetGameProfile and self.ctx.GetGameProfile()
    if profile and type(profile.IsAimTarget) == "function" and not profile:IsAimTarget(player) then return nil end
    local part = player.Character:FindFirstChild(self.AimPart) or player.Character:FindFirstChild("Head")
    if not part or not self:Visible(part) then return nil end
    local camera = workspace.CurrentCamera
    local point, onScreen = camera:WorldToViewportPoint(part.Position)
    if not onScreen or point.Z <= 0 then return nil end
    local mouse = self.ctx.UserInputService:GetMouseLocation()
    local distance = (Vector2.new(point.X, point.Y) - mouse).Magnitude
    return part, distance
end

function Combat:SelectTarget()
    local bestPlayer, bestPart, bestDistance = nil, nil, self.Fov
    for _, player in ipairs(self.ctx.Players:GetPlayers()) do
        local part, distance = self:Candidate(player)
        if part and distance < bestDistance then
            bestPlayer, bestPart, bestDistance = player, part, distance
        end
    end
    if self.Target then
        local currentPart, currentDistance = self:Candidate(self.Target)
        if currentPart and currentDistance <= self.Fov * 1.15 and (not bestPart or currentDistance <= bestDistance * 1.12) then
            return self.Target, currentPart
        end
    end
    return bestPlayer, bestPart
end

function Combat:Step()
    if not self.Enabled then
        if self.FovCircle and self.FovCircle.Visible then self.FovCircle.Visible = false end
        self.Target = nil
        return
    end

    if self.FovCircle then
        self.FovCircle.Visible = self.ShowFov
        if self.ShowFov then
            local mouse = self.ctx.UserInputService:GetMouseLocation()
            self.FovCircle.Position = UDim2.fromOffset(mouse.X, mouse.Y)
            self.FovCircle.Size = UDim2.fromOffset(self.Fov * 2, self.Fov * 2)
        end
    end
    if not self:IsActive() then self.Target = nil; return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local target, part = self:SelectTarget()
    self.Target = target
    if not part then return end
    local desired = CFrame.lookAt(camera.CFrame.Position, part.Position)
    local alpha = self.Smooth <= 1 and 1 or (1 / self.Smooth)
    camera.CFrame = camera.CFrame:Lerp(desired, alpha)
end

function Combat:GetConfig()
    return {
        enabled = self.Enabled, wallCheck = self.WallCheck, fov = self.Fov, showFov = self.ShowFov,
        smooth = self.Smooth, aimPart = self.AimPart, mode = self.Mode, bind = self.Bind,
    }
end

function Combat:ApplyConfig(data)
    if type(data) ~= "table" then return end
    self.Enabled = data.enabled == true
    self.WallCheck = data.wallCheck ~= false
    self.Fov = math.clamp(tonumber(data.fov) or self.Fov, 30, 600)
    self.ShowFov = data.showFov ~= false
    self.Smooth = math.clamp(tonumber(data.smooth) or self.Smooth, 1, 20)
    self.AimPart = data.aimPart == "HumanoidRootPart" and "HumanoidRootPart" or "Head"
    self.Mode = data.mode == "Toggle" and "Toggle" or "Hold"
    self.Bind = type(data.bind) == "string" and data.bind or nil
    self.EnabledControl.Set(self.Enabled)
    self.WallControl.Set(self.WallCheck)
    self.FovControl.Set(self.Fov)
    self.FovCircleControl.Set(self.ShowFov)
    self.SmoothControl.Set(self.Smooth)
    self.PartControl.Text = "Part: " .. (self.AimPart == "Head" and "Head" or "Body")
    self.ModeControl.Text = "Mode: " .. self.Mode
    self:DrawBind()
    self:RefreshRenderBinding()
end

return Combat
