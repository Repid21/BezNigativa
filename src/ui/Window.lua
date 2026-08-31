local Window = {}
Window.__index = Window

local function corner(parent, radius)
    local value = Instance.new("UICorner")
    value.CornerRadius = UDim.new(0, radius or 4)
    value.Parent = parent
end

function Window.new(player, coreGui, janitor)
    local self = setmetatable({pages = {}, tabs = {}, janitor = janitor, tabCounter = 0}, Window)
    local parent = player:WaitForChild("PlayerGui")
    if typeof(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and result then parent = result end
    else
        local ok = pcall(function() return coreGui.Name end)
        if ok then parent = coreGui end
    end

    for _, candidate in ipairs({parent, player:FindFirstChild("PlayerGui"), coreGui}) do
        local old = candidate and candidate:FindFirstChild("BezNigativaGUI")
        if old then old:Destroy() end
        local oldOverlay = candidate and candidate:FindFirstChild("BezNigativaOverlay")
        if oldOverlay then oldOverlay:Destroy() end
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "BezNigativaGUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 10
    gui:SetAttribute("Build", "9.8-modular")
    gui.Parent = parent
    self.Gui = gui
    janitor:Add(gui)

    local overlayGui = Instance.new("ScreenGui")
    overlayGui.Name = "BezNigativaOverlay"
    overlayGui.ResetOnSpawn = false
    overlayGui.IgnoreGuiInset = true
    overlayGui.DisplayOrder = 5
    overlayGui.Parent = parent
    self.OverlayGui = overlayGui
    janitor:Add(overlayGui)

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(680, 450)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    corner(frame, 7)
    self.Frame = frame

    local uiScale = Instance.new("UIScale")
    uiScale.Parent = frame
    self.Scale = uiScale
    local function updateScale()
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(700, 470)
        uiScale.Scale = math.clamp(math.min((viewport.X - 20) / 680, (viewport.Y - 20) / 450), 0.45, 1)
    end
    updateScale()
    if workspace.CurrentCamera then
        janitor:Add(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))
    end

    local top = Instance.new("Frame")
    top.Size = UDim2.new(1, 0, 0, 38)
    top.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
    top.BorderSizePixel = 0
    top.Parent = frame
    self.Top = top

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -24, 1, 0)
    title.Position = UDim2.fromOffset(12, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.Code
    title.Text = "BezNigativa v9.8"
    title.TextColor3 = Color3.fromRGB(240, 240, 240)
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = top

    local sidebar = Instance.new("ScrollingFrame")
    sidebar.Position = UDim2.fromOffset(0, 38)
    sidebar.Size = UDim2.new(0, 150, 1, -38)
    sidebar.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
    sidebar.BorderSizePixel = 0
    sidebar.ScrollBarThickness = 3
    sidebar.CanvasSize = UDim2.fromOffset(0, 0)
    sidebar.Parent = frame
    self.Sidebar = sidebar

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.Padding = UDim.new(0, 8)
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Parent = sidebar
    local tabPadding = Instance.new("UIPadding")
    tabPadding.PaddingTop = UDim.new(0, 14)
    tabPadding.PaddingBottom = UDim.new(0, 14)
    tabPadding.Parent = sidebar
    janitor:Add(tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        sidebar.CanvasSize = UDim2.fromOffset(0, tabLayout.AbsoluteContentSize.Y + 28)
    end))

    local content = Instance.new("Frame")
    content.Position = UDim2.fromOffset(150, 38)
    content.Size = UDim2.new(1, -150, 1, -38)
    content.BackgroundTransparency = 1
    content.Parent = frame
    self.Content = content

    local dragging, dragStart, startPosition = false, nil, nil
    janitor:Add(top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, dragStart, startPosition = true, input.Position, frame.Position
        end
    end))
    janitor:Add(game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
        end
    end))
    janitor:Add(game:GetService("UserInputService").InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))
    return self
end

function Window:AddPage(name, subtitle)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollingDirection = Enum.ScrollingDirection.Y
    page.CanvasSize = UDim2.fromOffset(0, 412)
    page.Visible = false
    page.Parent = self.Content

    local heading = Instance.new("TextLabel")
    heading.Position = UDim2.fromOffset(18, 14)
    heading.Size = UDim2.new(1, -36, 0, 44)
    heading.BackgroundTransparency = 1
    heading.Font = Enum.Font.Code
    heading.Text = name .. "\n" .. (subtitle or "")
    heading.TextColor3 = Color3.fromRGB(235, 235, 235)
    heading.TextSize = 15
    heading.TextXAlignment = Enum.TextXAlignment.Left
    heading.TextYAlignment = Enum.TextYAlignment.Top
    heading.Parent = page

    local tab = Instance.new("TextButton")
    tab.Size = UDim2.fromOffset(130, 36)
    tab.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    tab.BorderSizePixel = 0
    tab.AutoButtonColor = false
    tab.Font = Enum.Font.Code
    tab.Text = name
    tab.TextColor3 = Color3.fromRGB(175, 175, 175)
    tab.TextSize = 14
    self.tabCounter += 1
    local preferredOrder = {
        Combat = 1,
        Movement = 2,
        Visuals = 3,
        Friend = 4,
        Other = 5,
        Forsaken = 6,
        ["Murder Mystery 2"] = 6,
        ["Untitled Boxing Game"] = 6,
    }
    tab.LayoutOrder = preferredOrder[name] or (100 + self.tabCounter)
    tab.Parent = self.Sidebar
    corner(tab, 5)

    self.pages[name], self.tabs[name] = page, tab
    self.janitor:Add(tab.MouseButton1Click:Connect(function() self:ShowPage(name) end))
    return page
end

function Window:ShowPage(name)
    for pageName, page in pairs(self.pages) do page.Visible = pageName == name end
    for tabName, tab in pairs(self.tabs) do
        local active = tabName == name
        tab.BackgroundColor3 = active and Color3.fromRGB(48, 48, 48) or Color3.fromRGB(32, 32, 32)
        tab.TextColor3 = active and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(175, 175, 175)
    end
end

function Window:ReportError(name, message)
    local page = self.pages[name] or self:AddPage(name, "Модуль не загрузился")
    local notice = page:FindFirstChild("ModuleError") or Instance.new("TextLabel")
    notice.Name = "ModuleError"
    notice.Position = UDim2.fromOffset(18, 64)
    notice.Size = UDim2.new(1, -36, 0, 90)
    notice.BackgroundColor3 = Color3.fromRGB(75, 32, 32)
    notice.BorderSizePixel = 0
    notice.Font = Enum.Font.Code
    notice.Text = "Ошибка модуля:\n" .. tostring(message)
    notice.TextWrapped = true
    notice.TextColor3 = Color3.fromRGB(255, 205, 205)
    notice.TextSize = 12
    notice.Parent = page
    corner(notice, 5)
end

function Window:ModuleStack(page, y)
    local owner = self
    local stack = Instance.new("Frame")
    stack.Position = UDim2.fromOffset(18, y or 70)
    stack.Size = UDim2.new(1, -40, 0, 0)
    stack.BackgroundTransparency = 1
    stack.Parent = page
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.Parent = stack
    local modules = {}

    local function refresh()
        local height = 0
        for index, module in ipairs(modules) do height += module.Frame.Size.Y.Offset + (index > 1 and 8 or 0) end
        stack.Size = UDim2.new(1, -40, 0, height)
        page.CanvasSize = UDim2.fromOffset(0, math.max(412, (y or 70) + height + 18))
    end

    local api = {}
    function api:Add(name, expandedHeight)
        local module = {Open = false}
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 38)
        frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        frame.BorderSizePixel = 0
        frame.Parent = stack
        corner(frame, 5)
        module.Frame = frame

        local header = Instance.new("TextButton")
        header.Size = UDim2.new(1, 0, 0, 38)
        header.BackgroundTransparency = 1
        header.Font = Enum.Font.Code
        header.TextColor3 = Color3.fromRGB(230, 230, 230)
        header.TextSize = 13
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.Parent = frame
        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 12)
        padding.Parent = header

        local settings = Instance.new("Frame")
        settings.Position = UDim2.fromOffset(0, 40)
        settings.Size = UDim2.new(1, 0, 0, expandedHeight - 40)
        settings.BackgroundTransparency = 1
        settings.Visible = false
        settings.Parent = frame
        module.Settings = settings

        local function draw() header.Text = (module.Open and "v  " or ">  ") .. name end
        owner.janitor:Add(header.MouseButton1Click:Connect(function()
            module.Open = not module.Open
            settings.Visible = module.Open
            frame.Size = UDim2.new(1, 0, 0, module.Open and expandedHeight or 38)
            draw(); refresh()
        end))
        table.insert(modules, module)
        draw(); refresh()
        return module
    end
    return api
end

function Window:Toggle(parent, position, width, text, initial, callback)
    local state = initial == true
    local button = Instance.new("TextButton")
    button.Position = position
    button.Size = UDim2.fromOffset(width or 190, 34)
    button.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.Code
    button.TextColor3 = Color3.fromRGB(235, 235, 235)
    button.TextSize = 12
    button.Parent = parent
    corner(button, 4)
    local function draw()
        button.Text = text .. (state and ": ON" or ": OFF")
        button.BackgroundColor3 = state and Color3.fromRGB(55, 95, 65) or Color3.fromRGB(43, 43, 43)
    end
    self.janitor:Add(button.MouseButton1Click:Connect(function()
        state = not state; draw(); if callback then callback(state) end
    end))
    draw()
    return {Set = function(value) state = value == true; draw() end, Get = function() return state end, Button = button}
end

function Window:Slider(parent, y, text, initial, minimum, maximum, step, callback)
    local value = initial
    local label = Instance.new("TextLabel")
    label.Position = UDim2.fromOffset(10, y)
    label.Size = UDim2.fromOffset(110, 32)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Code
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
    local box = Instance.new("TextBox")
    box.Position = UDim2.fromOffset(130, y)
    box.Size = UDim2.new(1, -140, 0, 32)
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    box.BorderSizePixel = 0
    box.Font = Enum.Font.Code
    box.TextColor3 = Color3.fromRGB(235, 235, 235)
    box.TextSize = 12
    box.Parent = parent
    corner(box, 4)
    local function set(newValue)
        newValue = math.clamp(tonumber(newValue) or value, minimum, maximum)
        if step then newValue = minimum + math.round((newValue - minimum) / step) * step end
        value = newValue
        box.Text = tostring(value)
        if callback then callback(value) end
    end
    self.janitor:Add(box.FocusLost:Connect(function() set(box.Text) end))
    set(value)
    return {Set = set, Get = function() return value end, Box = box}
end

function Window:Button(parent, position, size, text, callback, color)
    local button = Instance.new("TextButton")
    button.Position, button.Size = position, size
    button.BackgroundColor3 = color or Color3.fromRGB(43, 43, 43)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.Code
    button.Text, button.TextColor3, button.TextSize = text, Color3.fromRGB(235, 235, 235), 12
    button.Parent = parent
    corner(button, 4)
    if callback then self.janitor:Add(button.MouseButton1Click:Connect(callback)) end
    return button
end

return Window
