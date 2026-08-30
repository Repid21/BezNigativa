local Friends = {}
Friends.__index = Friends

local function normalize(value)
    return string.lower((tostring(value or ""):gsub("^%s*@?", ""):gsub("%s+$", "")))
end

local function corner(parent, radius)
    local item = Instance.new("UICorner")
    item.CornerRadius = UDim.new(0, radius or 4)
    item.Parent = parent
end

function Friends.new(ctx)
    local self = setmetatable({ctx = ctx, names = {}}, Friends)
    local page = ctx.Window:AddPage("Friend", "Игнор AimBot и зелёные Visuals")
    local stack = ctx.Window:ModuleStack(page, 70)
    local module = stack:Add("Friends", 310)

    local input = Instance.new("TextBox")
    input.Position = UDim2.fromOffset(10, 4)
    input.Size = UDim2.new(1, -120, 0, 34)
    input.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    input.BorderSizePixel = 0
    input.ClearTextOnFocus = false
    input.PlaceholderText = "Ник или @ник"
    input.Text = ""
    input.Font = Enum.Font.Code
    input.TextColor3 = Color3.fromRGB(235, 235, 235)
    input.PlaceholderColor3 = Color3.fromRGB(135, 135, 135)
    input.TextSize = 12
    input.Parent = module.Settings
    corner(input)

    local list = Instance.new("ScrollingFrame")
    list.Position = UDim2.fromOffset(10, 48)
    list.Size = UDim2.new(1, -20, 0, 208)
    list.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 3
    list.CanvasSize = UDim2.fromOffset(0, 0)
    list.Parent = module.Settings
    corner(list)
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.Parent = list

    self.Input, self.List, self.Layout = input, list, layout
    ctx.Window:Button(module.Settings, UDim2.new(1, -100, 0, 4), UDim2.fromOffset(90, 34), "Добавить", function()
        self:Add(input.Text)
        input.Text = ""
    end, Color3.fromRGB(48, 85, 58))
    ctx.Janitor:Add(input.FocusLost:Connect(function(enterPressed)
        if enterPressed then self:Add(input.Text); input.Text = "" end
    end))
    ctx.Janitor:Add(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 4)
    end))
    return self
end

function Friends:Resolve(value)
    local wanted = normalize(value)
    if wanted == "" then return nil end
    for _, player in ipairs(self.ctx.Players:GetPlayers()) do
        if normalize(player.Name) == wanted or normalize(player.DisplayName) == wanted then return player.Name end
    end
    return tostring(value):gsub("^%s*@?", ""):gsub("%s+$", "")
end

function Friends:IsFriend(player)
    return player and self.names[normalize(player.Name)] == true
end

function Friends:Add(value, silent)
    local resolved = self:Resolve(value)
    local key = normalize(resolved)
    if key == "" or self.names[key] then return end
    self.names[key] = true
    self:Render()
    if not silent then self.ctx.Touch() end
end

function Friends:Remove(name)
    self.names[normalize(name)] = nil
    self:Render()
    self.ctx.Touch()
end

function Friends:Render()
    for _, child in ipairs(self.List:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local values = {}
    for name in pairs(self.names) do table.insert(values, name) end
    table.sort(values)
    for index, name in ipairs(values) do
        local row = self.ctx.Window:Button(self.List, UDim2.new(), UDim2.new(1, -4, 0, 30), "@" .. name .. "    [удалить]", function()
            self:Remove(name)
        end)
        row.LayoutOrder = index
        row.TextXAlignment = Enum.TextXAlignment.Left
    end
end

function Friends:GetConfig()
    local result = {}
    for name in pairs(self.names) do table.insert(result, name) end
    table.sort(result)
    return result
end

function Friends:ApplyConfig(data)
    table.clear(self.names)
    for _, name in ipairs(type(data) == "table" and data or {}) do self:Add(name, true) end
    self:Render()
end

return Friends
