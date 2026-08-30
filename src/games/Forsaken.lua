local Forsaken = {}
Forsaken.__index = Forsaken

local RED = Color3.fromRGB(255, 45, 45)

function Forsaken.new(ctx)
    local self = setmetatable({ctx = ctx, Enabled = false, Elapsed = 0}, Forsaken)
    self.Chams = ctx.LoadModule("games/RoleChams").new("BezNigativaForsakenKiller")

    local page = ctx.Window:AddPage("Forsaken", "Функции только для текущей игры")
    local stack = ctx.Window:ModuleStack(page, 70)
    local module = stack:Add("Killer Chams", 126)
    self.EnabledControl = ctx.Window:Toggle(module.Settings, UDim2.fromOffset(10, 4), 220, "Красный маньяк", false, function(value)
        self.Enabled = value
        if not value then self.Chams:Clear() end
        self:RefreshHeartbeat()
        ctx.Touch()
    end)
    local hint = Instance.new("TextLabel")
    hint.Position = UDim2.fromOffset(10, 48)
    hint.Size = UDim2.new(1, -20, 0, 38)
    hint.BackgroundTransparency = 1
    hint.Font = Enum.Font.Code
    hint.Text = "Работает только когда вы находитесь в Survivors."
    hint.TextWrapped = true
    hint.TextColor3 = Color3.fromRGB(165, 165, 165)
    hint.TextSize = 12
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.Parent = module.Settings

    ctx.Janitor:Add(function()
        if self.HeartbeatLoop then self.HeartbeatLoop:Disconnect(); self.HeartbeatLoop = nil end
    end)
    return self
end

function Forsaken:RefreshHeartbeat()
    if self.Enabled and not self.HeartbeatLoop then
        self.HeartbeatLoop = self.ctx.RunService.Heartbeat:Connect(function(delta)
            self.Elapsed += delta
            if self.Elapsed < 0.15 then return end
            self.Elapsed = 0
            local ok, message = pcall(function() self:Scan() end)
            if not ok and not self.Warned then self.Warned = true; warn("[BezNigativa/Forsaken] " .. tostring(message)) end
        end)
    elseif not self.Enabled and self.HeartbeatLoop then
        self.HeartbeatLoop:Disconnect()
        self.HeartbeatLoop = nil
    end
end

function Forsaken:RoleFolders()
    local container = self.ctx.Workspace:FindFirstChild("Players")
    return container and container:FindFirstChild("Survivors"), container and container:FindFirstChild("Killers")
end

function Forsaken:IsLocalSurvivor(folder)
    if not folder then return false end
    local character = self.ctx.LocalPlayer.Character
    if character and character:IsDescendantOf(folder) then return true end
    for _, model in ipairs(folder:GetDescendants()) do
        if model:IsA("Model") and (model == character or model.Name == self.ctx.LocalPlayer.Name or model:GetAttribute("UserId") == self.ctx.LocalPlayer.UserId) then
            return true
        end
    end
    return false
end

function Forsaken:Scan()
    if not self.Enabled then return end
    local survivors, killers = self:RoleFolders()
    if not self:IsLocalSurvivor(survivors) or not killers then self.Chams:Clear(); return end
    local seen = {}
    for _, model in ipairs(killers:GetDescendants()) do
        if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then self.Chams:Show(model, RED, seen) end
    end
    self.Chams:Finish(seen)
end

function Forsaken:GetConfig()
    return {enabled = self.Enabled}
end

function Forsaken:ApplyConfig(data)
    self.Enabled = type(data) == "table" and data.enabled == true
    self.EnabledControl.Set(self.Enabled)
    if not self.Enabled then self.Chams:Clear() end
    self:RefreshHeartbeat()
end

function Forsaken:Destroy()
    self.Enabled = false
    self:RefreshHeartbeat()
    self.Chams:Clear()
end

return Forsaken
