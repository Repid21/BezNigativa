local MurderMystery2 = {}
MurderMystery2.__index = MurderMystery2

local RED = Color3.fromRGB(255, 45, 45)
local BLUE = Color3.fromRGB(55, 135, 255)

local function hasTool(player, names)
    local character = player.Character
    local backpack = player:FindFirstChildOfClass("Backpack") or player:FindFirstChild("Backpack")
    for _, name in ipairs(names) do
        if character and character:FindFirstChild(name) then return true end
        if backpack and backpack:FindFirstChild(name) then return true end
    end
    return false
end

function MurderMystery2.new(ctx)
    local self = setmetatable({ctx = ctx, Enabled = false, Elapsed = 0}, MurderMystery2)
    self.Chams = ctx.LoadModule("games/RoleChams").new("BezNigativaMM2Role")

    local page = ctx.Window:AddPage("Murder Mystery 2", "Распознавание ролей по оружию")
    local stack = ctx.Window:ModuleStack(page, 70)
    local module = stack:Add("Role Chams", 126)
    self.EnabledControl = ctx.Window:Toggle(module.Settings, UDim2.fromOffset(10, 4), 260, "Маньяк и шериф", false, function(value)
        self.Enabled = value
        if not value then self.Chams:Clear() end
        ctx.Touch()
    end)
    local hint = Instance.new("TextLabel")
    hint.Position = UDim2.fromOffset(10, 48)
    hint.Size = UDim2.new(1, -20, 0, 38)
    hint.BackgroundTransparency = 1
    hint.Font = Enum.Font.Code
    hint.Text = "Маньяк — красный, шериф/герой с Gun — синий."
    hint.TextColor3 = Color3.fromRGB(165, 165, 165)
    hint.TextSize = 12
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.Parent = module.Settings

    ctx.Janitor:Add(ctx.RunService.Heartbeat:Connect(function(delta)
        self.Elapsed += delta
        if self.Elapsed < 0.15 then return end
        self.Elapsed = 0
        local ok, message = pcall(function() self:Scan() end)
        if not ok and not self.Warned then self.Warned = true; warn("[BezNigativa/MM2] " .. tostring(message)) end
    end))
    return self
end

function MurderMystery2:Scan()
    if not self.Enabled then return end
    local seen = {}
    for _, player in ipairs(self.ctx.Players:GetPlayers()) do
        if player ~= self.ctx.LocalPlayer and player.Character then
            if hasTool(player, {"Knife"}) then self.Chams:Show(player.Character, RED, seen)
            elseif hasTool(player, {"Gun", "Revolver"}) then self.Chams:Show(player.Character, BLUE, seen) end
        end
    end
    self.Chams:Finish(seen)
end

function MurderMystery2:GetConfig()
    return {enabled = self.Enabled}
end

function MurderMystery2:ApplyConfig(data)
    self.Enabled = type(data) == "table" and data.enabled == true
    self.EnabledControl.Set(self.Enabled)
    if not self.Enabled then self.Chams:Clear() end
end

function MurderMystery2:Destroy()
    self.Chams:Clear()
end

return MurderMystery2
