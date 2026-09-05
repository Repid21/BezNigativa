local Window = {}
Window.__index = Window

local Theme = {
    Shell = Color3.fromRGB(13, 15, 22),
    Sidebar = Color3.fromRGB(18, 21, 30),
    Toolbar = Color3.fromRGB(11, 13, 20),
    Surface = Color3.fromRGB(17, 19, 27),
    SurfaceHover = Color3.fromRGB(31, 38, 54),
    SurfaceActive = Color3.fromRGB(39, 43, 54),
    Field = Color3.fromRGB(25, 28, 38),
    Border = Color3.fromRGB(28, 31, 40),
    BorderLight = Color3.fromRGB(31, 34, 44),
    Accent = Color3.fromRGB(75, 126, 255),
    AccentSoft = Color3.fromRGB(31, 38, 54),
    Text = Color3.fromRGB(228, 230, 236),
    TextMuted = Color3.fromRGB(170, 173, 184),
    TextDim = Color3.fromRGB(91, 96, 108),
    RowText = Color3.fromRGB(207, 209, 218),
}

local BASE_WIDTH, BASE_HEIGHT = 748, 576
local SIDEBAR_WIDTH, TOOLBAR_HEIGHT = 158, 56

local TAB_META = {
    Combat = {order = 1, icon = "⊙", group = "COMBAT"},
    Movement = {order = 2, icon = "↗", group = "COMMON"},
    Visuals = {order = 3, icon = "▣", group = "COMMON"},
    Friend = {order = 4, icon = "●", group = "COMMON"},
    Other = {order = 5, icon = "≡", group = "COMMON"},
    Forsaken = {order = 6, icon = "◆", group = "GAME"},
    ["Murder Mystery 2"] = {order = 6, icon = "◆", group = "GAME"},
    ["VIOLENCE DISTRICT"] = {order = 6, icon = "◆", group = "GAME"},
}

local function corner(parent, radius)
    local item = Instance.new("UICorner")
    item.CornerRadius = UDim.new(0, radius or 6)
    item.Parent = parent
    return item
end

local function stroke(parent, color, transparency, thickness)
    local item = Instance.new("UIStroke")
    item.Color = color or Theme.Border
    item.Transparency = transparency or 0
    item.Thickness = thickness or 1
    item.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    item.Parent = parent
    return item
end

local function padding(parent, left, right, top, bottom)
    local item = Instance.new("UIPadding")
    item.PaddingLeft = UDim.new(0, left or 0)
    item.PaddingRight = UDim.new(0, right or 0)
    item.PaddingTop = UDim.new(0, top or 0)
    item.PaddingBottom = UDim.new(0, bottom or 0)
    item.Parent = parent
    return item
end

local function label(parent, text, position, size, textSize, color, font)
    local item = Instance.new("TextLabel")
    item.BackgroundTransparency = 1
    item.Position = position or UDim2.new()
    item.Size = size or UDim2.fromScale(1, 1)
    item.Font = font or Enum.Font.Gotham
    item.Text = text or ""
    item.TextColor3 = color or Theme.Text
    item.TextSize = textSize or 13
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.Parent = parent
    return item
end

function Window:Tween(object, duration, properties)
    local tween = self.TweenService:Create(
        object,
        TweenInfo.new(duration or 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        properties
    )
    tween:Play()
    return tween
end

function Window:Hover(button, normalColor, hoverColor)
    self.janitor:Add(button.MouseEnter:Connect(function()
        self:Tween(button, 0.12, {BackgroundColor3 = hoverColor})
    end))
    self.janitor:Add(button.MouseLeave:Connect(function()
        self:Tween(button, 0.16, {BackgroundColor3 = normalColor})
    end))
end

function Window.new(player, coreGui, janitor)
    local self = setmetatable({
        pages = {}, tabs = {}, groupLabels = {}, tabCounter = 0,
        janitor = janitor, Visible = true, Theme = Theme,
        TweenService = game:GetService("TweenService"),
        UserInputService = game:GetService("UserInputService"),
    }, Window)

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
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui:SetAttribute("Build", "10.0-neverlose-ui")
    gui.Parent = parent
    self.Gui = gui
    janitor:Add(gui)

    local overlayGui = Instance.new("ScreenGui")
    overlayGui.Name = "BezNigativaOverlay"
    overlayGui.ResetOnSpawn = false
    overlayGui.IgnoreGuiInset = true
    overlayGui.DisplayOrder = 5
    overlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    overlayGui.Parent = parent
    self.OverlayGui = overlayGui
    janitor:Add(overlayGui)

    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.fromOffset(BASE_WIDTH + 68, BASE_HEIGHT + 68)
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.Position = UDim2.new(0.5, 0, 0.5, 10)
    shadow.BackgroundTransparency = 1
    shadow.BorderSizePixel = 0
    shadow.Image = "rbxassetid://1316045217"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.16
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(10, 10, 118, 118)
    shadow.Parent = gui

    local frame = Instance.new("Frame")
    frame.Name = "Shell"
    frame.Size = UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.BackgroundColor3 = Theme.Shell
    frame.BackgroundTransparency = 0.13
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
    frame.Parent = gui
    corner(frame, 14)
    stroke(frame, Color3.fromRGB(5, 7, 11), 0.05, 2)
    self.Frame, self.Shadow = frame, shadow

    local lighting = game:GetService("Lighting")
    local previousBlur = lighting:FindFirstChild("BezNigativaMenuBlur")
    if previousBlur then previousBlur:Destroy() end
    local blur = Instance.new("BlurEffect")
    blur.Name = "BezNigativaMenuBlur"
    blur.Size = 9
    blur.Enabled = true
    blur.Parent = lighting
    self.Blur = blur
    janitor:Add(blur)

    local uiScale = Instance.new("UIScale")
    uiScale.Parent = frame
    local shadowScale = Instance.new("UIScale")
    shadowScale.Parent = shadow
    self.Scale = uiScale
    local function updateScale()
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(BASE_WIDTH + 32, BASE_HEIGHT + 32)
        local scale = math.clamp(math.min((viewport.X - 24) / BASE_WIDTH, (viewport.Y - 24) / BASE_HEIGHT), 0.45, 1)
        uiScale.Scale, shadowScale.Scale = scale, scale
    end
    updateScale()
    if workspace.CurrentCamera then
        janitor:Add(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))
    end

    local sidebarBack = Instance.new("Frame")
    sidebarBack.Name = "SidebarBackground"
    sidebarBack.Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0)
    sidebarBack.BackgroundColor3 = Theme.Sidebar
    sidebarBack.BackgroundTransparency = 0.09
    sidebarBack.BorderSizePixel = 0
    sidebarBack.Parent = frame
    local divider = Instance.new("Frame")
    divider.Position = UDim2.new(1, -1, 0, 0)
    divider.Size = UDim2.new(0, 1, 1, 0)
    divider.BackgroundColor3 = Theme.Border
    divider.BorderSizePixel = 0
    divider.Parent = sidebarBack

    local logo = Instance.new("Frame")
    logo.Position = UDim2.fromOffset(14, 12)
    logo.Size = UDim2.fromOffset(34, 34)
    logo.BackgroundColor3 = Color3.fromRGB(8, 27, 48)
    logo.BorderSizePixel = 0
    logo.Parent = sidebarBack
    corner(logo, 8)
    stroke(logo, Theme.Accent, 0.65)
    local logoText = label(logo, "BN", UDim2.new(), UDim2.fromScale(1, 1), 14, Color3.fromRGB(94, 185, 255), Enum.Font.GothamBold)
    logoText.TextXAlignment = Enum.TextXAlignment.Center
    label(sidebarBack, "BezNigativa", UDim2.fromOffset(57, 13), UDim2.fromOffset(98, 18), 14, Theme.Text, Enum.Font.GothamBold)
    label(sidebarBack, "universal", UDim2.fromOffset(57, 31), UDim2.fromOffset(98, 14), 9, Theme.TextDim, Enum.Font.GothamMedium)

    local brandLine = Instance.new("Frame")
    brandLine.Position = UDim2.fromOffset(10, 57)
    brandLine.Size = UDim2.new(1, -20, 0, 1)
    brandLine.BackgroundColor3 = Theme.Border
    brandLine.BorderSizePixel = 0
    brandLine.Parent = sidebarBack

    local sidebar = Instance.new("ScrollingFrame")
    sidebar.Name = "Navigation"
    sidebar.Position = UDim2.fromOffset(7, 66)
    sidebar.Size = UDim2.new(1, -14, 1, -118)
    sidebar.BackgroundTransparency = 1
    sidebar.BorderSizePixel = 0
    sidebar.ScrollBarThickness = 2
    sidebar.ScrollBarImageColor3 = Theme.BorderLight
    sidebar.CanvasSize = UDim2.fromOffset(0, 0)
    sidebar.Parent = sidebarBack
    self.Sidebar = sidebar
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.Padding = UDim.new(0, 5)
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Parent = sidebar
    padding(sidebar, 0, 0, 0, 6)
    janitor:Add(tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        sidebar.CanvasSize = UDim2.fromOffset(0, tabLayout.AbsoluteContentSize.Y + 6)
    end))

    local hotkey = Instance.new("Frame")
    hotkey.Position = UDim2.new(0, 10, 1, -43)
    hotkey.Size = UDim2.new(1, -20, 0, 32)
    hotkey.BackgroundColor3 = Theme.Field
    hotkey.BorderSizePixel = 0
    hotkey.Parent = sidebarBack
    corner(hotkey, 7)
    stroke(hotkey, Theme.Border, 0.15)
    label(hotkey, "MENU", UDim2.fromOffset(10, 0), UDim2.fromOffset(52, 32), 9, Theme.TextDim, Enum.Font.GothamBold)
    local key = label(hotkey, "RSHIFT", UDim2.new(1, -67, 0, 0), UDim2.fromOffset(57, 32), 10, Theme.TextMuted, Enum.Font.GothamMedium)
    key.TextXAlignment = Enum.TextXAlignment.Right

    local top = Instance.new("Frame")
    top.Name = "Toolbar"
    top.Position = UDim2.fromOffset(SIDEBAR_WIDTH, 0)
    top.Size = UDim2.new(1, -SIDEBAR_WIDTH, 0, TOOLBAR_HEIGHT)
    top.BackgroundColor3 = Theme.Toolbar
    top.BackgroundTransparency = 0.12
    top.BorderSizePixel = 0
    top.Parent = frame
    self.Top = top
    local toolbarLine = Instance.new("Frame")
    toolbarLine.Position = UDim2.new(0, 0, 1, -1)
    toolbarLine.Size = UDim2.new(1, 0, 0, 1)
    toolbarLine.BackgroundColor3 = Theme.Border
    toolbarLine.BorderSizePixel = 0
    toolbarLine.Parent = top

    local profile = Instance.new("Frame")
    profile.Position = UDim2.fromOffset(14, 13)
    profile.Size = UDim2.fromOffset(188, 32)
    profile.BackgroundColor3 = Theme.Field
    profile.BorderSizePixel = 0
    profile.Parent = top
    corner(profile, 7)
    stroke(profile, Theme.Border, 0.1)
    local dot = Instance.new("Frame")
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Position = UDim2.fromOffset(16, 16)
    dot.Size = UDim2.fromOffset(7, 7)
    dot.BackgroundColor3 = Theme.Accent
    dot.BorderSizePixel = 0
    dot.Parent = profile
    corner(dot, 7)
    label(profile, "Default config", UDim2.fromOffset(29, 0), UDim2.new(1, -39, 1, 0), 11, Theme.TextMuted, Enum.Font.GothamMedium)

    local status = Instance.new("Frame")
    status.AnchorPoint = Vector2.new(1, 0)
    status.Position = UDim2.new(1, -54, 0, 13)
    status.Size = UDim2.fromOffset(99, 32)
    status.BackgroundColor3 = Theme.Field
    status.BorderSizePixel = 0
    status.Parent = top
    corner(status, 7)
    stroke(status, Theme.Border, 0.1)
    local statusText = label(status, "AUTOSAVE", UDim2.new(), UDim2.fromScale(1, 1), 9, Theme.TextDim, Enum.Font.GothamBold)
    statusText.TextXAlignment = Enum.TextXAlignment.Center

    local hide = Instance.new("TextButton")
    hide.AnchorPoint = Vector2.new(1, 0)
    hide.Position = UDim2.new(1, -13, 0, 13)
    hide.Size = UDim2.fromOffset(32, 32)
    hide.BackgroundColor3 = Theme.Field
    hide.BorderSizePixel = 0
    hide.AutoButtonColor = false
    hide.Font = Enum.Font.GothamBold
    hide.Text = "–"
    hide.TextColor3 = Theme.TextMuted
    hide.TextSize = 18
    hide.Parent = top
    corner(hide, 7)
    stroke(hide, Theme.Border, 0.1)
    self:Hover(hide, Theme.Field, Theme.SurfaceHover)
    janitor:Add(hide.MouseButton1Click:Connect(function() self:SetVisible(false) end))

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Position = UDim2.fromOffset(SIDEBAR_WIDTH, TOOLBAR_HEIGHT)
    content.Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, -TOOLBAR_HEIGHT)
    content.BackgroundTransparency = 1
    content.ClipsDescendants = true
    content.Parent = frame
    self.Content = content

    local dragging, dragStart, startPosition = false, nil, nil
    janitor:Add(top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, dragStart, startPosition = true, input.Position, frame.Position
        end
    end))
    janitor:Add(self.UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            local nextPosition = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
            frame.Position = nextPosition
            shadow.Position = nextPosition + UDim2.fromOffset(0, 10)
        end
    end))
    janitor:Add(self.UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))
    return self
end

function Window:SetVisible(value)
    value = value == true
    if self.Visible == value then return end
    self.Visible = value
    if value then
        self.Gui.Enabled = true
        self.Frame.Position += UDim2.fromOffset(0, 10)
        self.Frame.BackgroundTransparency = 0.3
        self.Shadow.ImageTransparency = 1
        if self.Blur then self.Blur.Enabled = true; self.Blur.Size = 0 end
        self:Tween(self.Frame, 0.2, {Position = self.Frame.Position - UDim2.fromOffset(0, 10), BackgroundTransparency = 0.13})
        self:Tween(self.Shadow, 0.24, {ImageTransparency = 0.16})
        if self.Blur then self:Tween(self.Blur, 0.22, {Size = 9}) end
    else
        local tween = self:Tween(self.Frame, 0.14, {Position = self.Frame.Position + UDim2.fromOffset(0, 8), BackgroundTransparency = 0.3})
        self:Tween(self.Shadow, 0.12, {ImageTransparency = 1})
        if self.Blur then self:Tween(self.Blur, 0.14, {Size = 0}) end
        local connection
        connection = tween.Completed:Connect(function()
            connection:Disconnect()
            if self.Visible then return end
            self.Gui.Enabled = false
            self.Frame.Position -= UDim2.fromOffset(0, 8)
            self.Frame.BackgroundTransparency = 0.13
            self.Shadow.ImageTransparency = 0.16
            if self.Blur then self.Blur.Enabled = false end
        end)
    end
end

function Window:ToggleVisible()
    self:SetVisible(not self.Visible)
end

function Window:AddGroupLabel(name, order)
    if self.groupLabels[name] then return end
    local item = label(self.Sidebar, name, UDim2.new(), UDim2.new(1, -18, 0, 18), 9, Theme.TextDim, Enum.Font.GothamBold)
    item.Name = name .. "Group"
    item.LayoutOrder = order
    padding(item, 9)
    self.groupLabels[name] = item
end

function Window:AddPage(name, subtitle)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Theme.BorderLight
    page.ScrollingDirection = Enum.ScrollingDirection.Y
    page.CanvasSize = UDim2.fromOffset(0, 484)
    page.Visible = false
    page.Parent = self.Content
    local heading = label(page, name, UDim2.fromOffset(18, 14), UDim2.new(1, -36, 0, 22), 18, Theme.Text, Enum.Font.GothamBold)
    heading.Name = "PageTitle"
    heading.Visible = false
    local subheading = label(page, subtitle or "", UDim2.fromOffset(18, 38), UDim2.new(1, -36, 0, 18), 10, Theme.TextDim, Enum.Font.GothamMedium)
    subheading.Name = "PageSubtitle"
    subheading.Visible = false

    local meta = TAB_META[name] or {order = 100 + self.tabCounter, icon = string.sub(name, 1, 1), group = "GAME"}
    if meta.group == "COMBAT" then self:AddGroupLabel("COMBAT", 0) end
    if meta.group == "COMMON" then self:AddGroupLabel("COMMON", 15) end
    if meta.group == "GAME" then self:AddGroupLabel("GAME", 55) end

    local tab = Instance.new("TextButton")
    tab.Name = name .. "Tab"
    tab.Size = UDim2.new(1, -2, 0, 34)
    tab.BackgroundColor3 = Theme.Sidebar
    tab.BackgroundTransparency = 1
    tab.BorderSizePixel = 0
    tab.AutoButtonColor = false
    tab.Text = ""
    tab.LayoutOrder = meta.order * 10
    tab.Parent = self.Sidebar
    corner(tab, 7)
    self.tabCounter += 1

    local iconBack = Instance.new("Frame")
    iconBack.Name = "Icon"
    iconBack.AnchorPoint = Vector2.new(0, 0.5)
    iconBack.Position = UDim2.fromOffset(9, 17)
    iconBack.Size = UDim2.fromOffset(20, 20)
    iconBack.BackgroundColor3 = Theme.Field
    iconBack.BorderSizePixel = 0
    iconBack.Parent = tab
    corner(iconBack, 5)
    local icon = label(iconBack, meta.icon, UDim2.new(), UDim2.fromScale(1, 1), 9, Theme.TextMuted, Enum.Font.GothamBold)
    icon.TextXAlignment = Enum.TextXAlignment.Center
    local tabLabel = label(tab, name, UDim2.fromOffset(39, 0), UDim2.new(1, -46, 1, 0), #name > 18 and 10 or 12, Theme.TextMuted, Enum.Font.GothamMedium)
    tabLabel.Name = "Label"
    tabLabel.TextTruncate = Enum.TextTruncate.AtEnd
    local accent = Instance.new("Frame")
    accent.Name = "Accent"
    accent.Position = UDim2.fromOffset(0, 8)
    accent.Size = UDim2.fromOffset(2, 18)
    accent.BackgroundColor3 = Theme.Accent
    accent.BackgroundTransparency = 1
    accent.BorderSizePixel = 0
    accent.Parent = tab
    corner(accent, 2)

    self.pages[name], self.tabs[name] = page, tab
    self.janitor:Add(tab.MouseEnter:Connect(function()
        if self.ActivePage ~= name then self:Tween(tab, 0.12, {BackgroundTransparency = 0.48}) end
    end))
    self.janitor:Add(tab.MouseLeave:Connect(function()
        if self.ActivePage ~= name then self:Tween(tab, 0.16, {BackgroundTransparency = 1}) end
    end))
    self.janitor:Add(tab.MouseButton1Click:Connect(function() self:ShowPage(name) end))
    return page
end

function Window:RestylePage(page)
    for _, item in ipairs(page:GetDescendants()) do
        if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
            if item.Font == Enum.Font.Code then item.Font = Enum.Font.Gotham end
            if item.TextColor3 == Color3.fromRGB(235, 235, 235) or item.TextColor3 == Color3.fromRGB(230, 230, 230) then
                item.TextColor3 = Theme.Text
            elseif item.TextColor3 == Color3.fromRGB(165, 165, 165) or item.TextColor3 == Color3.fromRGB(160, 160, 160) then
                item.TextColor3 = Theme.TextMuted
            end
            if item:IsA("TextBox") and item.PlaceholderColor3 == Color3.fromRGB(135, 135, 135) then
                item.PlaceholderColor3 = Theme.TextDim
            end
        end
        if item:IsA("GuiObject") and item.BackgroundColor3 == Color3.fromRGB(28, 28, 28) then
            item.BackgroundColor3 = Theme.Field
        end
        if item:IsA("ScrollingFrame") then item.ScrollBarImageColor3 = Theme.BorderLight end
    end
end

function Window:ShowPage(name)
    if not self.pages[name] then return end
    self.ActivePage = name
    for pageName, page in pairs(self.pages) do
        local active = pageName == name
        page.Visible = active
        if active then
            self:RestylePage(page)
            page.Position = UDim2.fromOffset(7, 0)
            self:Tween(page, 0.18, {Position = UDim2.new()})
        end
    end
    for tabName, tab in pairs(self.tabs) do
        local active = tabName == name
        local iconBack = tab:FindFirstChild("Icon")
        local icon = iconBack and iconBack:FindFirstChildOfClass("TextLabel")
        local tabLabel = tab:FindFirstChild("Label")
        local accent = tab:FindFirstChild("Accent")
        self:Tween(tab, 0.15, {BackgroundColor3 = active and Theme.SurfaceActive or Theme.Sidebar, BackgroundTransparency = active and 0 or 1})
        if iconBack then self:Tween(iconBack, 0.15, {BackgroundColor3 = active and Theme.AccentSoft or Theme.Field}) end
        if icon then self:Tween(icon, 0.15, {TextColor3 = active and Theme.Accent or Theme.TextMuted}) end
        if tabLabel then self:Tween(tabLabel, 0.15, {TextColor3 = active and Theme.Text or Theme.TextMuted}) end
        if accent then self:Tween(accent, 0.15, {BackgroundTransparency = active and 0 or 1}) end
    end
end

function Window:ReportError(name, message)
    local page = self.pages[name] or self:AddPage(name, "Модуль не загрузился")
    local notice = page:FindFirstChild("ModuleError") or Instance.new("TextLabel")
    notice.Name = "ModuleError"
    notice.Position = UDim2.fromOffset(18, 70)
    notice.Size = UDim2.new(1, -36, 0, 90)
    notice.BackgroundColor3 = Color3.fromRGB(58, 25, 32)
    notice.BorderSizePixel = 0
    notice.Font = Enum.Font.Gotham
    notice.Text = "Ошибка модуля:\n" .. tostring(message)
    notice.TextWrapped = true
    notice.TextColor3 = Color3.fromRGB(255, 185, 195)
    notice.TextSize = 11
    notice.Parent = page
    corner(notice, 8)
    stroke(notice, Color3.fromRGB(116, 44, 55), 0.15)
end

function Window:ModuleStack(page, y)
    local owner = self
    local stackY = math.max(28, (y or 70) - 40)
    local stack = Instance.new("Frame")
    stack.Position = UDim2.fromOffset(18, stackY)
    stack.Size = UDim2.new(1, -40, 0, 0)
    stack.BackgroundTransparency = 1
    stack.Parent = page
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 9)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = stack
    local modules = {}

    local function refresh()
        local height = 0
        for index, module in ipairs(modules) do
            height += module.Frame.Size.Y.Offset + (index > 1 and 9 or 0)
        end
        stack.Size = UDim2.new(1, -40, 0, height)
        page.CanvasSize = UDim2.fromOffset(0, math.max(500, stackY + height + 18))
    end

    local api = {}
    function api:Add(name, expandedHeight)
        local module = {Open = false}
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 40)
        frame.BackgroundColor3 = Theme.Surface
        frame.BackgroundTransparency = 0.12
        frame.BorderSizePixel = 0
        frame.ClipsDescendants = true
        frame.Parent = stack
        corner(frame, 14)
        stroke(frame, Theme.BorderLight, 0)
        module.Frame = frame

        local header = Instance.new("TextButton")
        header.Size = UDim2.new(1, 0, 0, 40)
        header.BackgroundTransparency = 1
        header.BorderSizePixel = 0
        header.AutoButtonColor = false
        header.Font = Enum.Font.GothamBold
        header.Text = string.upper(name)
        header.TextColor3 = Theme.TextDim
        header.TextSize = 9
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.Parent = frame
        padding(header, 14, 44)

        local indicator = Instance.new("Frame")
        indicator.Size = UDim2.fromOffset(0, 0)
        indicator.BackgroundColor3 = Theme.Accent
        indicator.BackgroundTransparency = 1
        indicator.BorderSizePixel = 0
        indicator.Parent = frame
        local chevron = label(frame, ">", UDim2.new(1, -38, 0, 0), UDim2.fromOffset(28, 40), 13, Theme.TextDim, Enum.Font.GothamBold)
        chevron.TextXAlignment = Enum.TextXAlignment.Center
        local separator = Instance.new("Frame")
        separator.Position = UDim2.fromOffset(12, 39)
        separator.Size = UDim2.new(1, -24, 0, 1)
        separator.BackgroundColor3 = Theme.Border
        separator.BackgroundTransparency = 1
        separator.BorderSizePixel = 0
        separator.Parent = frame
        local settings = Instance.new("Frame")
        settings.Position = UDim2.fromOffset(0, 40)
        settings.Size = UDim2.new(1, 0, 0, math.max(0, expandedHeight - 40))
        settings.BackgroundTransparency = 1
        settings.Visible = false
        settings.Parent = frame
        module.Settings = settings

        local function setOpen(value, instant)
            module.Open = value == true
            if module.Open then settings.Visible = true end
            local targetSize = UDim2.new(1, 0, 0, module.Open and expandedHeight or 40)
            if instant then
                frame.Size = targetSize
                chevron.Rotation = module.Open and 90 or 0
                chevron.TextColor3 = module.Open and Theme.Accent or Theme.TextDim
                indicator.BackgroundTransparency = 1
                separator.BackgroundTransparency = module.Open and 0.2 or 1
                if not module.Open then settings.Visible = false end
            else
                owner:Tween(frame, 0.18, {Size = targetSize})
                owner:Tween(chevron, 0.18, {Rotation = module.Open and 90 or 0, TextColor3 = module.Open and Theme.Accent or Theme.TextDim})
                owner:Tween(indicator, 0.18, {BackgroundTransparency = 1})
                owner:Tween(separator, 0.18, {BackgroundTransparency = module.Open and 0.2 or 1})
                task.delay(0.18, function()
                    if not module.Open then settings.Visible = false end
                    refresh()
                end)
            end
            refresh()
        end
        owner.janitor:Add(header.MouseEnter:Connect(function() owner:Tween(header, 0.12, {TextColor3 = Theme.Text}) end))
        owner.janitor:Add(header.MouseLeave:Connect(function() owner:Tween(header, 0.16, {TextColor3 = module.Open and Theme.Text or Theme.TextMuted}) end))
        owner.janitor:Add(header.MouseButton1Click:Connect(function() setOpen(not module.Open, false) end))
        table.insert(modules, module)
        module.SetOpen = setOpen
        if #modules == 1 then setOpen(true, true) else refresh() end
        return module
    end
    return api
end

function Window:Toggle(parent, position, width, text, initial, callback)
    local state = initial == true
    local button = Instance.new("TextButton")
    button.Position = position
    button.Size = UDim2.fromOffset(width or 190, 34)
    button.BackgroundColor3 = Theme.SurfaceHover
    button.BackgroundTransparency = 1
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Font = Enum.Font.GothamMedium
    button.Text = text
    button.TextColor3 = Theme.RowText
    button.TextSize = 11
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.TextTruncate = Enum.TextTruncate.AtEnd
    button.Parent = parent
    corner(button, 6)
    stroke(button, Theme.Border, 1)
    padding(button, 10, 40)

    local track = Instance.new("Frame")
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, -8, 0.5, 0)
    track.Size = UDim2.fromOffset(29, 18)
    track.BackgroundColor3 = Theme.BorderLight
    track.BorderSizePixel = 0
    track.Parent = button
    corner(track, 8)
    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.fromOffset(9, 9)
    knob.Size = UDim2.fromOffset(14, 14)
    knob.BackgroundColor3 = Color3.fromRGB(133, 144, 156)
    knob.BorderSizePixel = 0
    knob.Parent = track
    corner(knob, 6)

    local function draw(instant)
        local trackColor = state and Theme.Accent or Theme.BorderLight
        local knobPosition = UDim2.fromOffset(state and 20 or 9, 9)
        local knobColor = state and Color3.fromRGB(248, 249, 252) or Color3.fromRGB(133, 144, 156)
        local textColor = state and Theme.Text or Theme.RowText
        if instant then
            track.BackgroundColor3 = trackColor
            knob.Position, knob.BackgroundColor3 = knobPosition, knobColor
            button.TextColor3 = textColor
        else
            self:Tween(track, 0.15, {BackgroundColor3 = trackColor})
            self:Tween(knob, 0.15, {Position = knobPosition, BackgroundColor3 = knobColor})
            self:Tween(button, 0.15, {TextColor3 = textColor})
        end
    end
    self.janitor:Add(button.MouseEnter:Connect(function() self:Tween(button, 0.12, {BackgroundTransparency = 0.72}) end))
    self.janitor:Add(button.MouseLeave:Connect(function() self:Tween(button, 0.16, {BackgroundTransparency = 1}) end))
    self.janitor:Add(button.MouseButton1Click:Connect(function()
        state = not state
        draw(false)
        if callback then callback(state) end
    end))
    draw(true)
    return {Set = function(value) state = value == true; draw(false) end, Get = function() return state end, Button = button}
end

function Window:Slider(parent, y, text, initial, minimum, maximum, step, callback)
    local value = tonumber(initial) or minimum
    local dragging = false
    local row = Instance.new("Frame")
    row.Position = UDim2.fromOffset(10, y)
    row.Size = UDim2.new(1, -20, 0, 32)
    row.BackgroundTransparency = 1
    row.Parent = parent
    local title = label(row, text, UDim2.new(), UDim2.fromOffset(112, 32), 11, Theme.RowText, Enum.Font.GothamMedium)
    title.TextTruncate = Enum.TextTruncate.AtEnd

    local field = Instance.new("Frame")
    field.Position = UDim2.fromOffset(120, 0)
    field.Size = UDim2.new(1, -120, 0, 32)
    field.BackgroundColor3 = Theme.Field
    field.BackgroundTransparency = 1
    field.BorderSizePixel = 0
    field.Parent = row
    corner(field, 6)
    stroke(field, Theme.Border, 1)
    local track = Instance.new("Frame")
    track.AnchorPoint = Vector2.new(0, 0.5)
    track.Position = UDim2.fromOffset(9, 16)
    track.Size = UDim2.new(1, -72, 0, 3)
    track.BackgroundColor3 = Color3.fromRGB(34, 38, 48)
    track.BorderSizePixel = 0
    track.Active = true
    track.Parent = field
    corner(track, 3)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    corner(fill, 3)
    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.Size = UDim2.fromOffset(11, 11)
    knob.BackgroundColor3 = Color3.fromRGB(247, 248, 252)
    knob.BorderSizePixel = 0
    knob.Parent = track
    corner(knob, 6)
    stroke(knob, Theme.Accent, 0.15)

    local box = Instance.new("TextBox")
    box.AnchorPoint = Vector2.new(1, 0)
    box.Position = UDim2.new(1, -7, 0, 5)
    box.Size = UDim2.fromOffset(42, 22)
    box.BackgroundColor3 = Theme.Field
    box.BackgroundTransparency = 0
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.Font = Enum.Font.GothamMedium
    box.TextColor3 = Theme.TextMuted
    box.TextSize = 10
    box.TextXAlignment = Enum.TextXAlignment.Right
    box.Parent = field
    corner(box, 5)
    padding(box, 0, 7)

    local function rounded(newValue)
        newValue = math.clamp(tonumber(newValue) or value, minimum, maximum)
        if step and step > 0 then newValue = minimum + math.round((newValue - minimum) / step) * step end
        if step and step < 1 then
            local decimals = math.max(0, math.ceil(-math.log10(step)))
            return tonumber(string.format("%." .. decimals .. "f", newValue))
        end
        return math.round(newValue)
    end
    local function set(newValue, fireCallback)
        value = rounded(newValue)
        local ratio = maximum == minimum and 0 or (value - minimum) / (maximum - minimum)
        box.Text = tostring(value)
        self:Tween(fill, 0.1, {Size = UDim2.new(ratio, 0, 1, 0)})
        self:Tween(knob, 0.1, {Position = UDim2.new(ratio, 0, 0.5, 0)})
        if fireCallback ~= false and callback then callback(value) end
    end
    local function setFromInput(input)
        if track.AbsoluteSize.X <= 0 then return end
        local ratio = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        set(minimum + (maximum - minimum) * ratio)
    end
    self.janitor:Add(track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; setFromInput(input) end
    end))
    self.janitor:Add(self.UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then setFromInput(input) end
    end))
    self.janitor:Add(self.UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))
    self.janitor:Add(box.FocusLost:Connect(function() set(box.Text) end))
    set(value, false)
    return {Set = function(newValue) set(newValue, false) end, Get = function() return value end, Box = box}
end

function Window:Button(parent, position, size, text, callback, color)
    local normal = color or Theme.Field
    local hover = color and color:Lerp(Color3.new(1, 1, 1), 0.08) or Theme.SurfaceHover
    local button = Instance.new("TextButton")
    button.Position, button.Size = position, size
    button.BackgroundColor3 = normal
    button.BackgroundTransparency = 0
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Font = Enum.Font.GothamMedium
    button.Text = text
    button.TextColor3 = color and Theme.Text or Theme.TextMuted
    button.TextSize = 11
    button.TextTruncate = Enum.TextTruncate.AtEnd
    button.Parent = parent
    corner(button, 5)
    stroke(button, color and color:Lerp(Color3.new(1, 1, 1), 0.16) or Theme.Border, 0)
    self:Hover(button, normal, hover)
    if callback then self.janitor:Add(button.MouseButton1Click:Connect(callback)) end
    return button
end

return Window
