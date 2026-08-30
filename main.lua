-- BezNigativa | categorized Roblox ClickGUI
-- RightShift toggles the menu.
-- Visual ESP uses Drawing API when available.
-- All features work everywhere.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

if not LocalPlayer then
    warn("[BezNigativa] LocalPlayer not found")
    return
end

local env = (getgenv and getgenv()) or _G
if type(env.BezNigativaCleanup) == "function" then
    pcall(env.BezNigativaCleanup)
end

local connections = {}
local drawings = {}
local playerDrawings = {}
local destroyed = false
local lastRuntimeErrors = {}
local cleanup = nil

local function bind(connection)
    table.insert(connections, connection)
    return connection
end

-- Keep one broken feature from stopping the rest of the update loop. Roblox
-- event callbacks do not provide isolation when several updates share the
-- same function, so every subsystem is guarded independently.
local function runSafely(name, callback, ...)
    local ok, err = pcall(callback, ...)
    if ok then return true end

    local now = os.clock()
    if not lastRuntimeErrors[name] or now - lastRuntimeErrors[name] >= 5 then
        lastRuntimeErrors[name] = now
        warn(string.format("[BezNigativa] %s update failed: %s", name, tostring(err)))
    end
    return false
end

local function removeDrawing(object)
    if not object then return end
    pcall(function()
        object.Visible = false
        object:Remove()
    end)
end

local function cleanupDrawings()
    for _, bundle in pairs(playerDrawings) do
        for _, object in pairs(bundle) do
            removeDrawing(object)
        end
    end
    table.clear(playerDrawings)

    for _, object in ipairs(drawings) do
        removeDrawing(object)
    end
    table.clear(drawings)
end

local function getGuiParent()
    if typeof(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and result then
            return result
        end
    end

    local ok = pcall(function()
        return CoreGui.Name
    end)
    if ok then
        return CoreGui
    end

    return LocalPlayer:WaitForChild("PlayerGui")
end

local guiParent = getGuiParent()
for _, parent in ipairs({guiParent, LocalPlayer:FindFirstChild("PlayerGui"), CoreGui}) do
    if parent then
        local old = parent:FindFirstChild("BezNigativaGUI")
        if old then old:Destroy() end
    end
end

local gui = Instance.new("ScreenGui")
gui.Name = "BezNigativaGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui:SetAttribute("Build", "5.0-modules")
gui.Parent = guiParent

local window = Instance.new("Frame")
window.Name = "MainWindow"
window.Size = UDim2.fromOffset(650, 430)
window.Position = UDim2.new(0.5, -325, 0.5, -215)
window.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
window.BorderSizePixel = 0
window.Parent = gui

local windowCorner = Instance.new("UICorner")
windowCorner.CornerRadius = UDim.new(0, 7)
windowCorner.Parent = window

local windowStroke = Instance.new("UIStroke")
windowStroke.Color = Color3.fromRGB(55, 55, 55)
windowStroke.Thickness = 1
windowStroke.Parent = window

local topbar = Instance.new("Frame")
topbar.Size = UDim2.new(1, 0, 0, 38)
topbar.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
topbar.BorderSizePixel = 0
topbar.Parent = window

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 7)
topCorner.Parent = topbar

local topFix = Instance.new("Frame")
topFix.Size = UDim2.new(1, 0, 0, 7)
topFix.Position = UDim2.new(0, 0, 1, -7)
topFix.BackgroundColor3 = topbar.BackgroundColor3
topFix.BorderSizePixel = 0
topFix.Parent = topbar

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(13, 0)
title.Size = UDim2.new(1, -26, 1, 0)
title.Font = Enum.Font.Code
title.Text = "BezNigativa v5.0"
title.TextColor3 = Color3.fromRGB(238, 238, 238)
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topbar

local sidebar = Instance.new("Frame")
sidebar.Position = UDim2.fromOffset(0, 38)
sidebar.Size = UDim2.new(0, 150, 1, -38)
sidebar.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
sidebar.BorderSizePixel = 0
sidebar.Parent = window

local content = Instance.new("Frame")
content.Position = UDim2.fromOffset(150, 38)
content.Size = UDim2.new(1, -150, 1, -38)
content.BackgroundTransparency = 1
content.Parent = window

local pages = {}
local tabs = {}

local function createPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = Color3.fromRGB(75, 100, 80)
    page.ScrollingDirection = Enum.ScrollingDirection.Y
    page.CanvasSize = UDim2.fromOffset(0, 392)
    page.Visible = false
    page.Parent = content
    pages[name] = page
    return page
end

local CombatPage = createPage("Combat")
local MovementPage = createPage("Movement")
local VisualPage = createPage("Visual")
local FriendPage = createPage("Friend")
local OtherPage = createPage("Other")

local function setPage(name)
    for pageName, page in pairs(pages) do
        page.Visible = pageName == name
    end
    for tabName, tab in pairs(tabs) do
        tab.BackgroundColor3 = tabName == name and Color3.fromRGB(48, 48, 48) or Color3.fromRGB(32, 32, 32)
        tab.TextColor3 = tabName == name and Color3.fromRGB(240, 240, 240) or Color3.fromRGB(170, 170, 170)
    end
end

local function createTab(name, y)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Position = UDim2.fromOffset(10, y)
    button.Size = UDim2.fromOffset(130, 36)
    button.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Font = Enum.Font.Code
    button.Text = name
    button.TextColor3 = Color3.fromRGB(170, 170, 170)
    button.TextSize = 14
    button.Parent = sidebar

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = button

    tabs[name] = button
    bind(button.MouseButton1Click:Connect(function()
        setPage(name)
    end))
end

createTab("Combat", 14)
createTab("Movement", 58)
createTab("Visual", 102)
createTab("Friend", 146)
createTab("Other", 190)

local function pageTitle(parent, text, subtext)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(18, 15)
    label.Size = UDim2.new(1, -36, 0, 24)
    label.Font = Enum.Font.Code
    label.Text = text
    label.TextColor3 = Color3.fromRGB(235, 235, 235)
    label.TextSize = 17
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent

    local sub = Instance.new("TextLabel")
    sub.BackgroundTransparency = 1
    sub.Position = UDim2.fromOffset(18, 40)
    sub.Size = UDim2.new(1, -36, 0, 20)
    sub.Font = Enum.Font.Code
    sub.Text = subtext or ""
    sub.TextColor3 = Color3.fromRGB(140, 140, 140)
    sub.TextSize = 12
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = parent
end

local requestConfigSave = nil

local function createToggle(parent, x, y, width, labelText, initial, callback)
    local state = initial == true
    local button = Instance.new("TextButton")
    button.Position = UDim2.fromOffset(x, y)
    button.Size = UDim2.fromOffset(width, 34)
    button.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Font = Enum.Font.Code
    button.TextColor3 = Color3.fromRGB(230, 230, 230)
    button.TextSize = 13
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button

    local function refresh()
        button.Text = labelText .. (state and ": ON" or ": OFF")
        button.BackgroundColor3 = state and Color3.fromRGB(55, 95, 65) or Color3.fromRGB(43, 43, 43)
    end

    refresh()

    bind(button.MouseButton1Click:Connect(function()
        local requested = not state
        local accepted = callback and callback(requested)
        if accepted == false then
            return
        end
        state = requested
        refresh()
        if requestConfigSave then requestConfigSave() end
    end))

    return {
        Button = button,
        Get = function() return state end,
        Set = function(value)
            state = value == true
            refresh()
        end,
    }
end

local function createStepper(parent, y, labelText, initial, minimum, maximum, step, onChanged)
    local value = initial
    local dragging = false

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(18, y)
    label.Size = UDim2.fromOffset(112, 32)
    label.Font = Enum.Font.Code
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(215, 215, 215)
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent

    local bar = Instance.new("Frame")
    bar.Position = UDim2.fromOffset(140, y + 11)
    bar.Size = UDim2.fromOffset(190, 10)
    bar.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
    bar.BorderSizePixel = 0
    bar.Active = true
    bar.Parent = parent

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(1, 0)
    barCorner.Parent = bar

    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = Color3.fromRGB(70, 115, 78)
    fill.BorderSizePixel = 0
    fill.Parent = bar

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local valueBox = Instance.new("TextBox")
    valueBox.Position = UDim2.fromOffset(342, y)
    valueBox.Size = UDim2.fromOffset(72, 32)
    valueBox.BackgroundColor3 = Color3.fromRGB(34, 34, 34)
    valueBox.BorderSizePixel = 0
    valueBox.ClearTextOnFocus = false
    valueBox.Font = Enum.Font.Code
    valueBox.TextColor3 = Color3.fromRGB(230, 230, 230)
    valueBox.TextSize = 13
    valueBox.Parent = parent

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 4)
    boxCorner.Parent = valueBox

    local function cleanNumber(n)
        if math.abs(n - math.round(n)) < 0.0001 then
            return tostring(math.round(n))
        end
        return string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", "")
    end

    local function refresh()
        local ratio = maximum == minimum and 0 or ((value - minimum) / (maximum - minimum))
        fill.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)
        valueBox.Text = cleanNumber(value)
    end

    local function setValue(newValue, snap)
        newValue = tonumber(newValue)
        if not newValue then
            refresh()
            return
        end
        newValue = math.clamp(newValue, minimum, maximum)
        if snap and step and step > 0 then
            newValue = minimum + math.round((newValue - minimum) / step) * step
            newValue = math.clamp(newValue, minimum, maximum)
        end
        value = newValue
        refresh()
        if onChanged then onChanged(value) end
        if requestConfigSave then requestConfigSave() end
    end

    local function setFromMouseX(x)
        local ratio = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        setValue(minimum + (maximum - minimum) * ratio, true)
    end

    bind(bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            setFromMouseX(input.Position.X)
        end
    end))

    bind(UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            setFromMouseX(input.Position.X)
        end
    end))

    bind(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))

    bind(valueBox.FocusLost:Connect(function()
        setValue(valueBox.Text, false)
    end))

    refresh()
    return function() return value end, function(v) setValue(v, false) end
end

local function createModuleStack(page, startY)
    local stack = Instance.new("Frame")
    stack.Position = UDim2.fromOffset(18, startY)
    stack.Size = UDim2.fromOffset(430, 0)
    stack.BackgroundTransparency = 1
    stack.Parent = page

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = stack

    local modules = {}
    local function refreshLayout()
        local totalHeight = 0
        for index, module in ipairs(modules) do
            if index > 1 then totalHeight += 8 end
            totalHeight += module.Frame.Size.Y.Offset
        end
        stack.Size = UDim2.fromOffset(430, totalHeight)
        page.CanvasSize = UDim2.fromOffset(0, math.max(392, startY + totalHeight + 18))
    end

    local function addModule(name, expandedHeight)
        local module = {Open = false}
        local frame = Instance.new("Frame")
        frame.Name = name .. "Module"
        frame.Size = UDim2.fromOffset(430, 38)
        frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        frame.BorderSizePixel = 0
        frame.LayoutOrder = #modules + 1
        frame.Parent = stack
        module.Frame = frame

        local frameCorner = Instance.new("UICorner")
        frameCorner.CornerRadius = UDim.new(0, 5)
        frameCorner.Parent = frame

        local header = Instance.new("TextButton")
        header.Size = UDim2.new(1, 0, 0, 38)
        header.BackgroundTransparency = 1
        header.AutoButtonColor = false
        header.Font = Enum.Font.Code
        header.TextColor3 = Color3.fromRGB(225, 225, 225)
        header.TextSize = 13
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.Parent = frame
        module.Header = header

        local headerPadding = Instance.new("UIPadding")
        headerPadding.PaddingLeft = UDim.new(0, 12)
        headerPadding.Parent = header

        local settings = Instance.new("Frame")
        settings.Position = UDim2.fromOffset(0, 40)
        settings.Size = UDim2.new(1, 0, 0, expandedHeight - 40)
        settings.BackgroundTransparency = 1
        settings.Visible = false
        settings.Parent = frame
        module.Settings = settings

        local function refreshHeader()
            header.Text = (module.Open and "v  " or ">  ") .. name
        end

        bind(header.MouseButton1Click:Connect(function()
            module.Open = not module.Open
            settings.Visible = module.Open
            frame.Size = UDim2.fromOffset(430, module.Open and expandedHeight or 38)
            refreshHeader()
            refreshLayout()
        end))

        table.insert(modules, module)
        refreshHeader()
        refreshLayout()
        return module
    end

    return {Add = addModule, Refresh = refreshLayout}
end

-- FRIENDS
pageTitle(FriendPage, "Friends", "AimBot ignores friends | ESP marks them green")

local friends = {}

local function normalizeFriendName(rawName)
    if type(rawName) ~= "string" then return nil, nil end
    local displayName = rawName:match("^%s*(.-)%s*$") or ""
    if displayName:sub(1, 1) == "@" then
        displayName = displayName:sub(2):match("^%s*(.-)%s*$") or ""
    end
    if displayName == "" then return nil, nil end
    return string.lower(displayName), displayName
end

local function isFriend(player)
    if not player then return false end
    local userKey = normalizeFriendName(player.Name)
    local displayKey = normalizeFriendName(player.DisplayName)
    return (userKey and friends[userKey] ~= nil) or (displayKey and friends[displayKey] ~= nil)
end

local friendInput = Instance.new("TextBox")
friendInput.Position = UDim2.fromOffset(18, 78)
friendInput.Size = UDim2.fromOffset(282, 36)
friendInput.BackgroundColor3 = Color3.fromRGB(34, 34, 34)
friendInput.BorderSizePixel = 0
friendInput.ClearTextOnFocus = false
friendInput.PlaceholderText = "@username or username"
friendInput.Text = ""
friendInput.Font = Enum.Font.Code
friendInput.TextColor3 = Color3.fromRGB(230, 230, 230)
friendInput.PlaceholderColor3 = Color3.fromRGB(125, 125, 125)
friendInput.TextSize = 13
friendInput.Parent = FriendPage

local friendInputCorner = Instance.new("UICorner")
friendInputCorner.CornerRadius = UDim.new(0, 4)
friendInputCorner.Parent = friendInput

local addFriendButton = Instance.new("TextButton")
addFriendButton.Position = UDim2.fromOffset(312, 78)
addFriendButton.Size = UDim2.fromOffset(100, 36)
addFriendButton.BackgroundColor3 = Color3.fromRGB(55, 95, 65)
addFriendButton.BorderSizePixel = 0
addFriendButton.AutoButtonColor = false
addFriendButton.Font = Enum.Font.Code
addFriendButton.Text = "Add"
addFriendButton.TextColor3 = Color3.fromRGB(235, 235, 235)
addFriendButton.TextSize = 13
addFriendButton.Parent = FriendPage

local addFriendCorner = Instance.new("UICorner")
addFriendCorner.CornerRadius = UDim.new(0, 4)
addFriendCorner.Parent = addFriendButton

local friendStatus = Instance.new("TextLabel")
friendStatus.BackgroundTransparency = 1
friendStatus.Position = UDim2.fromOffset(18, 120)
friendStatus.Size = UDim2.new(1, -36, 0, 20)
friendStatus.Font = Enum.Font.Code
friendStatus.Text = "Add a Roblox username or display name"
friendStatus.TextColor3 = Color3.fromRGB(140, 140, 140)
friendStatus.TextSize = 11
friendStatus.TextXAlignment = Enum.TextXAlignment.Left
friendStatus.Parent = FriendPage

local friendList = Instance.new("ScrollingFrame")
friendList.Position = UDim2.fromOffset(18, 148)
friendList.Size = UDim2.fromOffset(394, 224)
friendList.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
friendList.BorderSizePixel = 0
friendList.ScrollBarThickness = 4
friendList.ScrollBarImageColor3 = Color3.fromRGB(85, 115, 90)
friendList.CanvasSize = UDim2.fromOffset(0, 0)
friendList.Parent = FriendPage

local friendListCorner = Instance.new("UICorner")
friendListCorner.CornerRadius = UDim.new(0, 4)
friendListCorner.Parent = friendList

local function sortedFriendKeys()
    local keys = {}
    for key in pairs(friends) do table.insert(keys, key) end
    table.sort(keys, function(a, b)
        return string.lower(friends[a]) < string.lower(friends[b])
    end)
    return keys
end

local function friendConfigList()
    local result = {}
    for _, key in ipairs(sortedFriendKeys()) do
        table.insert(result, friends[key])
    end
    return result
end

local refreshFriendList
refreshFriendList = function()
    for _, child in ipairs(friendList:GetChildren()) do
        if child.Name == "FriendRow" then child:Destroy() end
    end

    local keys = sortedFriendKeys()
    for index, key in ipairs(keys) do
        local friendKey = key
        local row = Instance.new("Frame")
        row.Name = "FriendRow"
        row.Position = UDim2.fromOffset(6, 6 + ((index - 1) * 38))
        row.Size = UDim2.new(1, -12, 0, 32)
        row.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
        row.BorderSizePixel = 0
        row.Parent = friendList

        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 4)
        rowCorner.Parent = row

        local nameLabel = Instance.new("TextLabel")
        nameLabel.BackgroundTransparency = 1
        nameLabel.Position = UDim2.fromOffset(10, 0)
        nameLabel.Size = UDim2.new(1, -100, 1, 0)
        nameLabel.Font = Enum.Font.Code
        nameLabel.Text = "@" .. friends[friendKey]
        nameLabel.TextColor3 = Color3.fromRGB(90, 225, 115)
        nameLabel.TextSize = 12
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = row

        local removeButton = Instance.new("TextButton")
        removeButton.Position = UDim2.new(1, -82, 0, 4)
        removeButton.Size = UDim2.fromOffset(74, 24)
        removeButton.BackgroundColor3 = Color3.fromRGB(82, 43, 43)
        removeButton.BorderSizePixel = 0
        removeButton.Font = Enum.Font.Code
        removeButton.Text = "Remove"
        removeButton.TextColor3 = Color3.fromRGB(235, 220, 220)
        removeButton.TextSize = 11
        removeButton.Parent = row

        local removeCorner = Instance.new("UICorner")
        removeCorner.CornerRadius = UDim.new(0, 3)
        removeCorner.Parent = removeButton

        removeButton.MouseButton1Click:Connect(function()
            friends[friendKey] = nil
            friendStatus.Text = "Friend removed"
            refreshFriendList()
            if requestConfigSave then requestConfigSave() end
        end)
    end

    friendList.CanvasSize = UDim2.fromOffset(0, 12 + (#keys * 38))
end

local function addFriend(rawName)
    local key, displayName = normalizeFriendName(rawName)
    if not key then
        friendStatus.Text = "Enter a valid username"
        return false
    end

    friends[key] = displayName
    friendInput.Text = ""
    friendStatus.Text = "Added @" .. displayName
    refreshFriendList()
    if requestConfigSave then requestConfigSave() end
    return true
end

bind(addFriendButton.MouseButton1Click:Connect(function()
    addFriend(friendInput.Text)
end))
bind(friendInput.FocusLost:Connect(function(enterPressed)
    if enterPressed then addFriend(friendInput.Text) end
end))
refreshFriendList()

local drawingSupported = false
local drawingOk, drawingResult = pcall(function()
    return Drawing ~= nil and type(Drawing.new) == "function"
end)
drawingSupported = drawingOk and drawingResult == true

local function newDrawing(className, optional)
    if not drawingSupported then return nil end
    local ok, object = pcall(function()
        return Drawing.new(className)
    end)
    if not ok or not object then
        if not optional then drawingSupported = false end
        return nil
    end
    table.insert(drawings, object)
    return object
end

-- VISUAL
pageTitle(VisualPage, "Visual", drawingSupported and "Drawing API ready" or "Drawing API unavailable")

local espEnabled = false
local healthBarEnabled = false
local nameTagsEnabled = false
local nameTagTextSize = 14
local chamsEnabled = false
local chamsTransparency = 0.55
local playerHighlights = {}

local espToggle = createToggle(VisualPage, 18, 78, 190, "ESP", false, function(value)
    espEnabled = value
    if not value then
        for _, bundle in pairs(playerDrawings) do
            if bundle.Box then bundle.Box.Visible = false end
            if bundle.HpBackground then bundle.HpBackground.Visible = false end
            if bundle.HpFill then bundle.HpFill.Visible = false end
        end
    end
end)

local hpToggle = createToggle(VisualPage, 222, 78, 190, "Health Bar", false, function(value)
    healthBarEnabled = value
    if not value then
        for _, bundle in pairs(playerDrawings) do
            if bundle.HpBackground then bundle.HpBackground.Visible = false end
            if bundle.HpFill then bundle.HpFill.Visible = false end
        end
    end
end)

local visualModules = createModuleStack(VisualPage, 122)
local nameTagsModule = visualModules.Add("NameTags", 132)
local nameTagsToggle = createToggle(nameTagsModule.Settings, 8, 8, 190, "Enabled", false, function(value)
    nameTagsEnabled = value
end)
local getNameTagSize, setNameTagSize = createStepper(nameTagsModule.Settings, 50, "Text size", nameTagTextSize, 10, 24, 1, function(value)
    nameTagTextSize = value
end)

local chamsModule = visualModules.Add("Chams", 132)
local chamsToggle = createToggle(chamsModule.Settings, 8, 8, 190, "Enabled", false, function(value)
    chamsEnabled = value
end)
local getChamsTransparency, setChamsTransparency = createStepper(chamsModule.Settings, 50, "Transparency", chamsTransparency, 0.1, 0.9, 0.05, function(value)
    chamsTransparency = value
end)

local function createPlayerDrawings(targetPlayer)
    if destroyed or targetPlayer == LocalPlayer or playerDrawings[targetPlayer] or not drawingSupported then return end

    local box = newDrawing("Square")
    local hpBackground = newDrawing("Square")
    local hpFill = newDrawing("Square")
    if not box or not hpBackground or not hpFill then return end

    local ok = pcall(function()
        box.Visible = false
        box.Filled = false
        box.Thickness = 1.5
        box.Color = Color3.fromRGB(235, 235, 235)
        box.Transparency = 1

        hpBackground.Visible = false
        hpBackground.Filled = true
        hpBackground.Color = Color3.fromRGB(18, 18, 18)
        hpBackground.Transparency = 0.9

        hpFill.Visible = false
        hpFill.Filled = true
        hpFill.Color = Color3.fromRGB(80, 220, 100)
        hpFill.Transparency = 1
    end)

    if not ok then
        -- A few executors expose Drawing.new but only implement a subset of
        -- its properties. ESP should become unavailable instead of aborting
        -- the whole script before Movement and Combat are initialized.
        drawingSupported = false
        removeDrawing(box)
        removeDrawing(hpBackground)
        removeDrawing(hpFill)
        return
    end

    local nameTag = newDrawing("Text", true)
    if nameTag then
        local nameTagOk = pcall(function()
            nameTag.Visible = false
            nameTag.Center = true
            nameTag.Outline = true
            nameTag.Color = Color3.fromRGB(235, 235, 235)
            nameTag.Size = nameTagTextSize
            nameTag.Transparency = 1
            nameTag.Text = ""
        end)
        if not nameTagOk then
            removeDrawing(nameTag)
            nameTag = nil
        end
    end

    playerDrawings[targetPlayer] = {
        Box = box,
        HpBackground = hpBackground,
        HpFill = hpFill,
        NameTag = nameTag,
    }
end

local function removePlayerDrawings(targetPlayer)
    local bundle = playerDrawings[targetPlayer]
    if not bundle then return end
    for _, object in pairs(bundle) do removeDrawing(object) end
    playerDrawings[targetPlayer] = nil
end

local function screenBounds(character)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root or not Camera then return nil end

    local _, visible = Camera:WorldToViewportPoint(root.Position)
    if not visible then return nil end

    local cframe, size = character:GetBoundingBox()
    local half = size * 0.5
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local valid = 0

    for _, x in ipairs({-half.X, half.X}) do
        for _, y in ipairs({-half.Y, half.Y}) do
            for _, z in ipairs({-half.Z, half.Z}) do
                local point = Camera:WorldToViewportPoint(cframe:PointToWorldSpace(Vector3.new(x, y, z)))
                if point.Z > 0 then
                    valid += 1
                    minX = math.min(minX, point.X)
                    minY = math.min(minY, point.Y)
                    maxX = math.max(maxX, point.X)
                    maxY = math.max(maxY, point.Y)
                end
            end
        end
    end

    if valid < 2 then return nil end
    local width, height = maxX - minX, maxY - minY
    if width <= 1 or height <= 1 or width > 3000 or height > 3000 then return nil end
    return minX, minY, width, height
end

local function updateESP()
    if not drawingSupported or not Camera then return end

    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= LocalPlayer then
            createPlayerDrawings(targetPlayer)
            local bundle = playerDrawings[targetPlayer]
            local character = targetPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local friend = isFriend(targetPlayer)

            if not bundle or not espEnabled or not character or not humanoid or humanoid.Health <= 0 then
                if bundle then
                    if bundle.Box then bundle.Box.Visible = false end
                    if bundle.HpBackground then bundle.HpBackground.Visible = false end
                    if bundle.HpFill then bundle.HpFill.Visible = false end
                end
            else
                local x, y, width, height = screenBounds(character)
                if not x then
                    if bundle.Box then bundle.Box.Visible = false end
                    if bundle.HpBackground then bundle.HpBackground.Visible = false end
                    if bundle.HpFill then bundle.HpFill.Visible = false end
                else
                    bundle.Box.Position = Vector2.new(x, y)
                    bundle.Box.Size = Vector2.new(width, height)
                    bundle.Box.Color = friend and Color3.fromRGB(75, 230, 105) or Color3.fromRGB(235, 235, 235)
                    bundle.Box.Visible = true

                    if healthBarEnabled then
                        local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
                        local fillHeight = math.max(1, height * ratio)
                        local barX = x - 8

                        bundle.HpBackground.Position = Vector2.new(barX, y)
                        bundle.HpBackground.Size = Vector2.new(4, height)
                        bundle.HpBackground.Visible = true

                        bundle.HpFill.Position = Vector2.new(barX, y + height - fillHeight)
                        bundle.HpFill.Size = Vector2.new(4, fillHeight)
                        if friend then
                            bundle.HpFill.Color = Color3.fromRGB(75, 230, 105)
                        else
                            bundle.HpFill.Color = Color3.fromRGB(
                                math.floor(255 * (1 - ratio)),
                                math.floor(220 * ratio),
                                55
                            )
                        end
                        bundle.HpFill.Visible = true
                    else
                        if bundle.HpBackground then bundle.HpBackground.Visible = false end
                        if bundle.HpFill then bundle.HpFill.Visible = false end
                    end
                end
            end

            if bundle and bundle.NameTag then
                local head = character and character:FindFirstChild("Head")
                if nameTagsEnabled and humanoid and humanoid.Health > 0 and head and head:IsA("BasePart") then
                    local screenPosition, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 1.15, 0))
                    if onScreen and screenPosition.Z > 0 then
                        local localCharacter = LocalPlayer.Character
                        local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
                        local distance = localRoot and math.floor((localRoot.Position - head.Position).Magnitude + 0.5) or nil
                        bundle.NameTag.Text = targetPlayer.DisplayName .. " (@" .. targetPlayer.Name .. ")" .. (distance and (" [" .. distance .. "m]") or "")
                        bundle.NameTag.Position = Vector2.new(screenPosition.X, screenPosition.Y)
                        bundle.NameTag.Size = nameTagTextSize
                        bundle.NameTag.Color = friend and Color3.fromRGB(75, 230, 105) or Color3.fromRGB(245, 245, 245)
                        bundle.NameTag.Visible = true
                    else
                        bundle.NameTag.Visible = false
                    end
                else
                    bundle.NameTag.Visible = false
                end
            end
        end
    end
end

local function removePlayerHighlight(player)
    local highlight = playerHighlights[player]
    if highlight then
        pcall(function() highlight:Destroy() end)
        playerHighlights[player] = nil
    end
end

local function cleanupHighlights()
    for player in pairs(playerHighlights) do
        removePlayerHighlight(player)
    end
end

local function updateChams()
    if not chamsEnabled then
        if next(playerHighlights) then cleanupHighlights() end
        return
    end

    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= LocalPlayer then
            local character = targetPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local highlight = playerHighlights[targetPlayer]

            if highlight and (not highlight.Parent or highlight.Adornee ~= character) then
                removePlayerHighlight(targetPlayer)
                highlight = nil
            end

            if character and humanoid and humanoid.Health > 0 then
                if not highlight then
                    highlight = Instance.new("Highlight")
                    highlight.Name = "BezNigativaChams"
                    highlight.Adornee = character
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.Parent = character
                    playerHighlights[targetPlayer] = highlight
                end

                local color = isFriend(targetPlayer) and Color3.fromRGB(75, 230, 105) or Color3.fromRGB(245, 245, 245)
                highlight.Enabled = true
                highlight.FillColor = color
                highlight.FillTransparency = chamsTransparency
                highlight.OutlineColor = color
                highlight.OutlineTransparency = math.clamp(chamsTransparency + 0.15, 0, 1)
            else
                removePlayerHighlight(targetPlayer)
            end
        end
    end
end

for _, player in ipairs(Players:GetPlayers()) do createPlayerDrawings(player) end
bind(Players.PlayerAdded:Connect(function(player) task.defer(createPlayerDrawings, player) end))
bind(Players.PlayerRemoving:Connect(function(player)
    removePlayerDrawings(player)
    removePlayerHighlight(player)
end))

-- MOVEMENT
pageTitle(MovementPage, "Movement", "All movement features enabled")

local speedEnabled = false
local jumpEnabled = false
local noclipEnabled = false
local flyEnabled = false
local speedValue = 24
local jumpValue = 70
local flySpeed = 45
local defaults = {WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2}
local noclipOriginalCollide = {}
local flyVelocity = nil
local flyGyro = nil
local flyRoot = nil
local activeHumanoid = nil
local humanoidConnections = {}
local applyingMovement = false

local function getHumanoid()
    local character = LocalPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function disconnectHumanoidConnections()
    for _, connection in ipairs(humanoidConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(humanoidConnections)
end

local function bindHumanoid(connection)
    table.insert(humanoidConnections, connection)
    return connection
end

local function restoreNoclip()
    for part, oldValue in pairs(noclipOriginalCollide) do
        if part and part.Parent then
            pcall(function() part.CanCollide = oldValue end)
        end
    end
    table.clear(noclipOriginalCollide)
end

local function destroyFlyControllers()
    if flyVelocity then
        pcall(function() flyVelocity:Destroy() end)
        flyVelocity = nil
    end
    if flyGyro then
        pcall(function() flyGyro:Destroy() end)
        flyGyro = nil
    end
    flyRoot = nil
end

local function setFlyState(enabled)
    local humanoid = getHumanoid()
    local root = getRoot()

    if not enabled then
        destroyFlyControllers()
        if humanoid then
            humanoid.PlatformStand = false
            humanoid.AutoRotate = true
            humanoid.Sit = false
        end
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        return
    end

    if not humanoid or not root then return end

    humanoid.PlatformStand = false
    humanoid.Sit = false
    humanoid.AutoRotate = false

    if flyRoot ~= root or not flyVelocity or not flyVelocity.Parent or not flyGyro or not flyGyro.Parent then
        destroyFlyControllers()
        flyRoot = root

        flyVelocity = Instance.new("BodyVelocity")
        flyVelocity.Name = "BezNigativaFlyVelocity"
        flyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        flyVelocity.P = 15000
        flyVelocity.Velocity = Vector3.zero
        flyVelocity.Parent = root

        flyGyro = Instance.new("BodyGyro")
        flyGyro.Name = "BezNigativaFlyGyro"
        flyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
        flyGyro.P = 20000
        flyGyro.D = 700
        flyGyro.CFrame = root.CFrame
        flyGyro.Parent = root
    end
end

local function captureDefaults(humanoid)
    humanoid = humanoid or getHumanoid()
    if not humanoid then return end

    defaults.WalkSpeed = humanoid.WalkSpeed
    defaults.JumpPower = humanoid.JumpPower
    defaults.JumpHeight = humanoid.JumpHeight
end

local function applyMovementToHumanoid(humanoid)
    if not humanoid or applyingMovement then return end

    applyingMovement = true
    local ok, err = pcall(function()
        if speedEnabled and humanoid.WalkSpeed ~= speedValue then
            humanoid.WalkSpeed = speedValue
        end

        if jumpEnabled then
            if humanoid.UseJumpPower then
                if humanoid.JumpPower ~= jumpValue then
                    humanoid.JumpPower = jumpValue
                end
            else
                local gravity = math.max(workspace.Gravity, 0.001)
                local desiredHeight = math.max(defaults.JumpHeight, (jumpValue * jumpValue) / (2 * gravity))
                if math.abs(humanoid.JumpHeight - desiredHeight) > 0.001 then
                    humanoid.JumpHeight = desiredHeight
                end
            end
        end
    end)
    applyingMovement = false
    if not ok then error(err, 0) end
end

local function watchHumanoid(humanoid)
    if not humanoid or activeHumanoid == humanoid then return end

    disconnectHumanoidConnections()
    activeHumanoid = humanoid
    -- Capture before applying enabled modifiers. This prevents an enabled
    -- Speed/Jump value from becoming the restore value after a respawn.
    captureDefaults(humanoid)

    local function enforceMovement()
        if destroyed or applyingMovement or humanoid ~= activeHumanoid or not humanoid.Parent then return end
        runSafely("Movement enforce", applyMovementToHumanoid, humanoid)
    end

    bindHumanoid(humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(enforceMovement))
    bindHumanoid(humanoid:GetPropertyChangedSignal("JumpPower"):Connect(enforceMovement))
    bindHumanoid(humanoid:GetPropertyChangedSignal("JumpHeight"):Connect(enforceMovement))
    bindHumanoid(humanoid:GetPropertyChangedSignal("UseJumpPower"):Connect(enforceMovement))
    bindHumanoid(humanoid.AncestryChanged:Connect(function(_, parent)
        if not parent and activeHumanoid == humanoid then
            disconnectHumanoidConnections()
            activeHumanoid = nil
        end
    end))
end

watchHumanoid(getHumanoid())
bind(LocalPlayer.CharacterAdded:Connect(function(character)
    restoreNoclip()
    destroyFlyControllers()
    disconnectHumanoidConnections()
    activeHumanoid = nil

    task.defer(function()
        local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
        if destroyed or character ~= LocalPlayer.Character or not humanoid or not humanoid:IsA("Humanoid") then return end
        watchHumanoid(humanoid)
        runSafely("Movement respawn", applyMovementToHumanoid, humanoid)
        if flyEnabled then runSafely("Fly respawn", setFlyState, true) end
    end)
end))

local speedToggle = createToggle(MovementPage, 18, 78, 190, "Speed", false, function(value)
    speedEnabled = value
    local humanoid = getHumanoid()
    if humanoid then
        watchHumanoid(humanoid)
        if value then
            runSafely("Speed toggle", applyMovementToHumanoid, humanoid)
        else
            humanoid.WalkSpeed = defaults.WalkSpeed
        end
    end
end)

local jumpToggle = createToggle(MovementPage, 222, 78, 190, "Jump", false, function(value)
    jumpEnabled = value
    local humanoid = getHumanoid()
    if humanoid then
        watchHumanoid(humanoid)
        if value then
            runSafely("Jump toggle", applyMovementToHumanoid, humanoid)
        elseif humanoid.UseJumpPower then
            humanoid.JumpPower = defaults.JumpPower
        else
            humanoid.JumpHeight = defaults.JumpHeight
        end
    end
end)

local noclipToggle = createToggle(MovementPage, 18, 122, 190, "NoClip", false, function(value)
    noclipEnabled = value
    if not value then
        restoreNoclip()
    end
end)

local flyToggle = createToggle(MovementPage, 222, 122, 190, "Fly", false, function(value)
    flyEnabled = value
    setFlyState(value)
end)

local getSpeed, setSpeed = createStepper(MovementPage, 174, "Speed", speedValue, 0, 200, 1, function(v) speedValue = v end)
local getJump, setJump = createStepper(MovementPage, 216, "Jump", jumpValue, 0, 250, 1, function(v) jumpValue = v end)
local getFlySpeed, setFlySpeed = createStepper(MovementPage, 258, "Fly speed", flySpeed, 0, 300, 1, function(v) flySpeed = v end)

local flyHint = Instance.new("TextLabel")
flyHint.BackgroundTransparency = 1
flyHint.Position = UDim2.fromOffset(18, 306)
flyHint.Size = UDim2.new(1, -36, 0, 42)
flyHint.Font = Enum.Font.Code
flyHint.Text = "Fly controls: WASD | Space: up | LeftCtrl: down"
flyHint.TextColor3 = Color3.fromRGB(140, 140, 140)
flyHint.TextSize = 12
flyHint.TextWrapped = true
flyHint.TextXAlignment = Enum.TextXAlignment.Left
flyHint.TextYAlignment = Enum.TextYAlignment.Top
flyHint.Parent = MovementPage

local teleportTargetText = ""
local movementModules = createModuleStack(MovementPage, 356)
local teleportModule = movementModules.Add("Teleport", 136)

local teleportInput = Instance.new("TextBox")
teleportInput.Position = UDim2.fromOffset(8, 8)
teleportInput.Size = UDim2.fromOffset(290, 34)
teleportInput.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
teleportInput.BorderSizePixel = 0
teleportInput.ClearTextOnFocus = false
teleportInput.PlaceholderText = "@username or display name"
teleportInput.Text = teleportTargetText
teleportInput.Font = Enum.Font.Code
teleportInput.TextColor3 = Color3.fromRGB(230, 230, 230)
teleportInput.PlaceholderColor3 = Color3.fromRGB(125, 125, 125)
teleportInput.TextSize = 12
teleportInput.Parent = teleportModule.Settings

local teleportInputCorner = Instance.new("UICorner")
teleportInputCorner.CornerRadius = UDim.new(0, 4)
teleportInputCorner.Parent = teleportInput

local teleportButton = Instance.new("TextButton")
teleportButton.Position = UDim2.fromOffset(306, 8)
teleportButton.Size = UDim2.fromOffset(116, 34)
teleportButton.BackgroundColor3 = Color3.fromRGB(55, 80, 95)
teleportButton.BorderSizePixel = 0
teleportButton.AutoButtonColor = false
teleportButton.Font = Enum.Font.Code
teleportButton.Text = "Teleport"
teleportButton.TextColor3 = Color3.fromRGB(235, 235, 235)
teleportButton.TextSize = 12
teleportButton.Parent = teleportModule.Settings

local teleportButtonCorner = Instance.new("UICorner")
teleportButtonCorner.CornerRadius = UDim.new(0, 4)
teleportButtonCorner.Parent = teleportButton

local teleportStatus = Instance.new("TextLabel")
teleportStatus.BackgroundTransparency = 1
teleportStatus.Position = UDim2.fromOffset(8, 50)
teleportStatus.Size = UDim2.new(1, -16, 0, 28)
teleportStatus.Font = Enum.Font.Code
teleportStatus.Text = "Enter a player name"
teleportStatus.TextColor3 = Color3.fromRGB(140, 140, 140)
teleportStatus.TextSize = 11
teleportStatus.TextXAlignment = Enum.TextXAlignment.Left
teleportStatus.TextWrapped = true
teleportStatus.Parent = teleportModule.Settings

local function findTeleportPlayer(rawName)
    local key = normalizeFriendName(rawName)
    if not key then return nil end

    local prefixMatches = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local userKey = normalizeFriendName(player.Name)
            local displayKey = normalizeFriendName(player.DisplayName)
            if userKey == key or displayKey == key then return player end
            if (userKey and userKey:sub(1, #key) == key) or (displayKey and displayKey:sub(1, #key) == key) then
                table.insert(prefixMatches, player)
            end
        end
    end
    return #prefixMatches == 1 and prefixMatches[1] or nil
end

local function teleportToInputPlayer()
    teleportTargetText = teleportInput.Text
    local targetPlayer = findTeleportPlayer(teleportTargetText)
    if not targetPlayer then
        teleportStatus.Text = "Player not found or prefix is ambiguous"
        return false
    end

    local character = LocalPlayer.Character
    local targetCharacter = targetPlayer.Character
    local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
    if not character or not targetRoot then
        teleportStatus.Text = "Target character is not ready"
        return false
    end

    local ok, err = pcall(function()
        character:PivotTo(targetRoot.CFrame * CFrame.new(0, 0, 3))
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end)
    teleportStatus.Text = ok and ("Teleported to @" .. targetPlayer.Name) or ("Teleport failed: " .. tostring(err))
    if requestConfigSave then requestConfigSave() end
    return ok
end

bind(teleportButton.MouseButton1Click:Connect(teleportToInputPlayer))
bind(teleportInput.FocusLost:Connect(function(enterPressed)
    teleportTargetText = teleportInput.Text
    if requestConfigSave then requestConfigSave() end
    if enterPressed then teleportToInputPlayer() end
end))

local function updateNoclip()
    if not noclipEnabled then return end
    local character = LocalPlayer.Character
    if not character then return end

    for _, object in ipairs(character:GetDescendants()) do
        if object:IsA("BasePart") then
            if noclipOriginalCollide[object] == nil then
                noclipOriginalCollide[object] = object.CanCollide
            end
            object.CanCollide = false
        end
    end
end

local function updateFly()
    if not flyEnabled then return end

    local humanoid = getHumanoid()
    local root = getRoot()
    Camera = workspace.CurrentCamera or Camera
    if not humanoid or not root or not Camera then return end

    setFlyState(true)
    if not flyVelocity or not flyGyro then return end

    humanoid.PlatformStand = false
    humanoid.Sit = false
    humanoid.AutoRotate = false

    local look = Camera.CFrame.LookVector
    local right = Camera.CFrame.RightVector

    local forward = look.Magnitude > 0.001 and look.Unit or Vector3.new(0, 0, -1)
    local strafe = right.Magnitude > 0.001 and right.Unit or Vector3.new(1, 0, 0)

    local direction = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction += forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction -= forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction += strafe end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction -= strafe end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.yAxis end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then direction -= Vector3.yAxis end

    if direction.Magnitude > 0.001 then
        direction = direction.Unit
    end

    flyVelocity.Velocity = direction * flySpeed

    local face = Vector3.new(look.X, 0, look.Z)
    if face.Magnitude <= 0.001 then
        face = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
    end
    if face.Magnitude > 0.001 then
        flyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + face.Unit)
    end
end

local function updateMovement()
    local humanoid = getHumanoid()
    if humanoid then
        watchHumanoid(humanoid)
        applyMovementToHumanoid(humanoid)
    end
end

-- COMBAT / CAMERA ASSIST
pageTitle(CombatPage, "Combat", "AimBot | camera modes supported")

local cameraAssistEnabled = false
local fovRadius = 140
local smoothValue = 4
local wallCheckEnabled = true
local smoothedAimDirection = nil
local lastRawCameraYaw = nil
local lastRawCameraPitch = nil
local aimBind = nil
local aimBindMode = "Toggle"
local waitingForAimBind = false
local aimGroups = {
    Head = true,
    Neck = false,
    Body = true,
    Arms = false,
    Legs = false,
}

local cameraToggle = createToggle(CombatPage, 18, 78, 190, "AimBot", false, function(value)
    cameraAssistEnabled = value
    if not value then
        smoothedAimDirection = nil
        lastRawCameraYaw = nil
        lastRawCameraPitch = nil
    end
end)

local getFov, setFov = createStepper(CombatPage, 128, "FOV", fovRadius, 20, 600, 5, function(v) fovRadius = v end)
local getSmooth, setSmooth = createStepper(CombatPage, 172, "Smooth", smoothValue, 1, 20, 1, function(v) smoothValue = v end)

local wallCheckToggle = createToggle(CombatPage, 222, 78, 190, "Wall Check", true, function(value)
    wallCheckEnabled = value
end)

local function setAimEnabledFromBind(value, saveState)
    cameraAssistEnabled = value == true
    cameraToggle.Set(cameraAssistEnabled)
    if not cameraAssistEnabled then
        smoothedAimDirection = nil
        lastRawCameraYaw = nil
        lastRawCameraPitch = nil
    end
    if saveState and requestConfigSave then requestConfigSave() end
end

local function inputToAimBind(input)
    if input.KeyCode and input.KeyCode ~= Enum.KeyCode.Unknown then
        return {kind = "KeyCode", name = input.KeyCode.Name}
    end

    local inputType = input.UserInputType
    if inputType == Enum.UserInputType.MouseButton1
        or inputType == Enum.UserInputType.MouseButton2
        or inputType == Enum.UserInputType.MouseButton3 then
        return {kind = "UserInputType", name = inputType.Name}
    end
    return nil
end

local function inputMatchesAimBind(input)
    if not aimBind then return false end
    if aimBind.kind == "KeyCode" then
        return input.KeyCode and input.KeyCode.Name == aimBind.name
    end
    return input.UserInputType and input.UserInputType.Name == aimBind.name
end

local groupsLabel = Instance.new("TextLabel")
groupsLabel.BackgroundTransparency = 1
groupsLabel.Position = UDim2.fromOffset(18, 220)
groupsLabel.Size = UDim2.fromOffset(410, 20)
groupsLabel.Font = Enum.Font.Code
groupsLabel.Text = "Aim zones (multi-select)"
groupsLabel.TextColor3 = Color3.fromRGB(185, 185, 185)
groupsLabel.TextSize = 12
groupsLabel.TextXAlignment = Enum.TextXAlignment.Left
groupsLabel.Parent = CombatPage

local groupButtons = {}
local groupPositions = {
    Head = {18, 248},
    Neck = {150, 248},
    Body = {282, 248},
    Arms = {18, 290},
    Legs = {150, 290},
}

for groupName, pos in pairs(groupPositions) do
    groupButtons[groupName] = createToggle(CombatPage, pos[1], pos[2], 118, groupName, aimGroups[groupName], function(value)
        aimGroups[groupName] = value
    end)
end

local aimBindButton = Instance.new("TextButton")
aimBindButton.Position = UDim2.fromOffset(18, 334)
aimBindButton.Size = UDim2.fromOffset(260, 34)
aimBindButton.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
aimBindButton.BorderSizePixel = 0
aimBindButton.AutoButtonColor = false
aimBindButton.Font = Enum.Font.Code
aimBindButton.TextColor3 = Color3.fromRGB(230, 230, 230)
aimBindButton.TextSize = 12
aimBindButton.Parent = CombatPage

local aimModeButton = aimBindButton:Clone()
aimModeButton.Position = UDim2.fromOffset(290, 334)
aimModeButton.Size = UDim2.fromOffset(122, 34)
aimModeButton.Parent = CombatPage

for _, button in ipairs({aimBindButton, aimModeButton}) do
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button
end

local function aimBindDisplayName()
    if not aimBind then return "NONE" end
    if aimBind.name == "MouseButton1" then return "Mouse1" end
    if aimBind.name == "MouseButton2" then return "Mouse2" end
    if aimBind.name == "MouseButton3" then return "Mouse3" end
    return aimBind.name
end

local function refreshAimBindUI()
    aimBindButton.Text = waitingForAimBind and "Bind: press key (ESC cancel)" or ("Bind: " .. aimBindDisplayName())
    aimBindButton.BackgroundColor3 = waitingForAimBind and Color3.fromRGB(70, 75, 45) or Color3.fromRGB(43, 43, 43)
    aimModeButton.Text = "Mode: " .. aimBindMode
end

bind(aimBindButton.MouseButton1Click:Connect(function()
    waitingForAimBind = true
    refreshAimBindUI()
end))

bind(aimModeButton.MouseButton1Click:Connect(function()
    waitingForAimBind = false
    aimBindMode = aimBindMode == "Hold" and "Toggle" or "Hold"
    if aimBindMode == "Hold" then setAimEnabledFromBind(false, false) end
    refreshAimBindUI()
    if requestConfigSave then requestConfigSave() end
end))

refreshAimBindUI()

local combatStatus = Instance.new("TextLabel")
combatStatus.BackgroundTransparency = 1
combatStatus.Position = UDim2.fromOffset(18, 372)
combatStatus.Size = UDim2.new(1, -36, 0, 18)
combatStatus.Font = Enum.Font.Code
combatStatus.Text = "AimBot ready"
combatStatus.TextColor3 = Color3.fromRGB(140, 140, 140)
combatStatus.TextSize = 11
combatStatus.TextXAlignment = Enum.TextXAlignment.Left
combatStatus.Parent = CombatPage

local fovCircle = newDrawing("Circle", true)
if fovCircle then
    local ok = pcall(function()
        fovCircle.Visible = false
        fovCircle.Filled = false
        fovCircle.Thickness = 1
        fovCircle.NumSides = 64
        fovCircle.Color = Color3.fromRGB(210, 210, 210)
        fovCircle.Transparency = 0.75
    end)
    if not ok then
        removeDrawing(fovCircle)
        fovCircle = nil
    end
end

local function addPartCandidate(list, character, name)
    local part = character:FindFirstChild(name)
    if part and part:IsA("BasePart") then
        table.insert(list, part.Position)
    end
end

local function candidatePositions(character)
    local result = {}

    if aimGroups.Head then
        addPartCandidate(result, character, "Head")
    end

    if aimGroups.Neck then
        local head = character:FindFirstChild("Head")
        local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
        if head and torso and head:IsA("BasePart") and torso:IsA("BasePart") then
            table.insert(result, (head.Position + torso.Position) * 0.5)
        end
    end

    if aimGroups.Body then
        for _, name in ipairs({"UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart"}) do
            addPartCandidate(result, character, name)
        end
    end

    if aimGroups.Arms then
        for _, name in ipairs({
            "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
            "LeftHand", "RightHand", "Left Arm", "Right Arm"
        }) do
            addPartCandidate(result, character, name)
        end
    end

    if aimGroups.Legs then
        for _, name in ipairs({
            "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
            "LeftFoot", "RightFoot", "Left Leg", "Right Leg"
        }) do
            addPartCandidate(result, character, name)
        end
    end

    return result
end

local function hasLineOfSight(targetCharacter, worldPosition)
    if not wallCheckEnabled or not Camera then return true end

    local ok, visible = pcall(function()
        local origin = Camera.CFrame.Position
        local direction = worldPosition - origin
        if direction.Magnitude <= 0.01 then return true end

        local ignored = {}
        if LocalPlayer.Character then
            table.insert(ignored, LocalPlayer.Character)
        end

        -- Raycast again through fully transparent helper parts. Many games put
        -- invisible triggers or view-model geometry in front of the camera;
        -- treating those as walls made AimBot reject every target.
        for _ = 1, 12 do
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = ignored
            params.IgnoreWater = true

            local hit = workspace:Raycast(origin, direction, params)
            if not hit then return true end

            local instance = hit.Instance
            if instance and instance:IsDescendantOf(targetCharacter) then
                return true
            end

            if instance and instance:IsA("BasePart") and instance.Transparency >= 0.95 then
                table.insert(ignored, instance)
            else
                return false
            end
        end

        return true
    end)

    -- If an executor has an incomplete Raycast implementation, Wall Check
    -- fails open instead of disabling all target acquisition.
    return not ok or visible == true
end

local function getBestAimPoint()
    if not Camera then return nil end

    local viewport = Camera.ViewportSize
    local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    local bestPosition = nil
    local bestDistance = fovRadius

    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= LocalPlayer and not isFriend(targetPlayer) then
            local character = targetPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")

            if character and humanoid and humanoid.Health > 0 then
                for _, worldPosition in ipairs(candidatePositions(character)) do
                    local screenPosition = Camera:WorldToViewportPoint(worldPosition)
                    -- The second WorldToViewportPoint return value is a
                    -- viewport hint, not an occlusion test. FOV distance is
                    -- sufficient here and keeps through-wall aiming truly
                    -- independent from Wall Check.
                    if screenPosition.Z > 0 and hasLineOfSight(character, worldPosition) then
                        local distance = (Vector2.new(screenPosition.X, screenPosition.Y) - center).Magnitude
                        if distance <= bestDistance then
                            bestDistance = distance
                            bestPosition = worldPosition
                        end
                    end
                end
            end
        end
    end

    return bestPosition
end

local function directionAngles(direction)
    local unit = direction.Magnitude > 0.001 and direction.Unit or Vector3.new(0, 0, -1)
    return math.atan2(-unit.X, -unit.Z), math.asin(math.clamp(unit.Y, -1, 1))
end

local function shortestAngleDelta(from, to)
    return (to - from + math.pi) % (math.pi * 2) - math.pi
end

local function updateCombat(deltaTime)
    Camera = workspace.CurrentCamera or Camera
    if not Camera then return end

    if fovCircle then
        local circleOk = pcall(function()
            fovCircle.Position = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
            fovCircle.Radius = fovRadius
            fovCircle.Visible = cameraAssistEnabled
        end)
        if not circleOk then
            removeDrawing(fovCircle)
            fovCircle = nil
        end
    end

    if not cameraAssistEnabled then
        smoothedAimDirection = nil
        lastRawCameraYaw = nil
        lastRawCameraPitch = nil
        return
    end

    -- Keep only yaw/pitch deltas from CameraScript. Accumulating its full CFrame
    -- also accumulated roll and could make the camera orbit after target loss.
    local rawCameraCFrame = Camera.CFrame
    local cameraPosition = rawCameraCFrame.Position
    local rawYaw, rawPitch = directionAngles(rawCameraCFrame.LookVector)
    local manualCameraInput = UserInputService:GetMouseDelta().Magnitude > 0.01
    if manualCameraInput and smoothedAimDirection and lastRawCameraYaw and lastRawCameraPitch then
        local heldYaw, heldPitch = directionAngles(smoothedAimDirection)
        local maxInputDelta = math.rad(18)
        local yawDelta = math.clamp(shortestAngleDelta(lastRawCameraYaw, rawYaw), -maxInputDelta, maxInputDelta)
        local pitchDelta = math.clamp(rawPitch - lastRawCameraPitch, -maxInputDelta, maxInputDelta)
        heldYaw += yawDelta
        heldPitch = math.clamp(heldPitch + pitchDelta, math.rad(-89), math.rad(89))
        smoothedAimDirection = CFrame.fromOrientation(heldPitch, heldYaw, 0).LookVector
        Camera.CFrame = CFrame.lookAt(cameraPosition, cameraPosition + smoothedAimDirection)
    end
    lastRawCameraYaw = rawYaw
    lastRawCameraPitch = rawPitch

    local targetPosition = getBestAimPoint()
    if not targetPosition then
        combatStatus.Text = "No selected target inside FOV"
        if smoothedAimDirection then
            Camera.CFrame = CFrame.lookAt(cameraPosition, cameraPosition + smoothedAimDirection)
        end
        return
    end

    combatStatus.Text = "Tracking closest selected zone inside FOV"
    local desiredDirection = targetPosition - cameraPosition
    if desiredDirection.Magnitude <= 0.001 then return end
    desiredDirection = desiredDirection.Unit

    local dt = math.clamp(deltaTime or (1 / 60), 1 / 240, 1 / 15)
    local smooth = math.max(1, smoothValue)

    if smooth <= 1 then
        smoothedAimDirection = desiredDirection
    else
        -- CameraScript restores its own angle before this callback every
        -- frame. Keep a separate accumulated direction so smoothing continues
        -- from the previous aimed angle instead of restarting every frame.
        local startDirection = smoothedAimDirection or Camera.CFrame.LookVector
        -- Slightly softer than the previous lock: the player can pull away
        -- with mouse input without making higher Smooth values unresponsive.
        local alphaAt60Fps = 1 / (smooth * 2)
        local alpha = 1 - math.pow(1 - alphaAt60Fps, dt * 60)
        local blended = startDirection:Lerp(desiredDirection, math.clamp(alpha, 0, 1))
        smoothedAimDirection = blended.Magnitude > 0.001 and blended.Unit or desiredDirection
    end

    Camera.CFrame = CFrame.lookAt(cameraPosition, cameraPosition + smoothedAimDirection)
end

-- OTHER / CONFIG
pageTitle(OtherPage, "Other", "Settings are loaded and saved automatically")

local CONFIG_FOLDER = "BezNigativa"
local CONFIG_FILE = CONFIG_FOLDER .. "/config.json"
local configLoading = false
local configSaveToken = 0
local fileApiAvailable = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"

local configStatus = Instance.new("TextLabel")
configStatus.BackgroundTransparency = 1
configStatus.Position = UDim2.fromOffset(18, 132)
configStatus.Size = UDim2.new(1, -36, 0, 60)
configStatus.Font = Enum.Font.Code
configStatus.Text = fileApiAvailable and "Config ready" or "Config unavailable: executor file API missing"
configStatus.TextColor3 = Color3.fromRGB(145, 145, 145)
configStatus.TextSize = 12
configStatus.TextWrapped = true
configStatus.TextXAlignment = Enum.TextXAlignment.Left
configStatus.TextYAlignment = Enum.TextYAlignment.Top
configStatus.Parent = OtherPage

local function buildConfig()
    return {
        version = 5,
        friends = friendConfigList(),
        visual = {
            esp = espEnabled,
            healthBar = healthBarEnabled,
            nameTagsEnabled = nameTagsEnabled,
            nameTagTextSize = nameTagTextSize,
            chamsEnabled = chamsEnabled,
            chamsTransparency = chamsTransparency,
        },
        movement = {
            speedEnabled = speedEnabled,
            jumpEnabled = jumpEnabled,
            noclipEnabled = noclipEnabled,
            flyEnabled = flyEnabled,
            speed = speedValue,
            jump = jumpValue,
            flySpeed = flySpeed,
            teleportTarget = teleportTargetText,
        },
        combat = {
            enabled = cameraAssistEnabled,
            wallCheck = wallCheckEnabled,
            fov = fovRadius,
            smooth = smoothValue,
            aimBind = aimBind and {kind = aimBind.kind, name = aimBind.name} or nil,
            aimBindMode = aimBindMode,
            aimGroups = aimGroups,
        },
    }
end

local function saveConfig(silent)
    if configLoading or not fileApiAvailable then return false end
    local ok, err = pcall(function()
        if type(makefolder) == "function" then pcall(makefolder, CONFIG_FOLDER) end
        writefile(CONFIG_FILE, HttpService:JSONEncode(buildConfig()))
    end)
    if not silent then
        configStatus.Text = ok and "Config saved" or ("Save failed: " .. tostring(err))
    end
    return ok
end

local function applyConfig(data)
    if type(data) ~= "table" then return end
    configLoading = true

    local visual = type(data.visual) == "table" and data.visual or {}
    local movement = type(data.movement) == "table" and data.movement or {}
    local combat = type(data.combat) == "table" and data.combat or {}

    table.clear(friends)
    if type(data.friends) == "table" then
        for _, rawName in ipairs(data.friends) do
            local key, displayName = normalizeFriendName(rawName)
            if key then friends[key] = displayName end
        end
    end
    refreshFriendList()

    if type(visual.esp) == "boolean" then espEnabled = visual.esp; espToggle.Set(espEnabled) end
    if type(visual.healthBar) == "boolean" then healthBarEnabled = visual.healthBar; hpToggle.Set(healthBarEnabled) end
    if type(visual.nameTagTextSize) == "number" then setNameTagSize(visual.nameTagTextSize) end
    if type(visual.chamsTransparency) == "number" then setChamsTransparency(visual.chamsTransparency) end
    if type(visual.nameTagsEnabled) == "boolean" then nameTagsEnabled = visual.nameTagsEnabled; nameTagsToggle.Set(nameTagsEnabled) end
    if type(visual.chamsEnabled) == "boolean" then chamsEnabled = visual.chamsEnabled; chamsToggle.Set(chamsEnabled) end

    if type(movement.speed) == "number" then setSpeed(movement.speed) end
    if type(movement.jump) == "number" then setJump(movement.jump) end
    if type(movement.flySpeed) == "number" then setFlySpeed(movement.flySpeed) end
    if type(movement.teleportTarget) == "string" then
        teleportTargetText = movement.teleportTarget
        teleportInput.Text = teleportTargetText
    end

    if type(movement.speedEnabled) == "boolean" then speedEnabled = movement.speedEnabled; speedToggle.Set(speedEnabled) end
    if type(movement.jumpEnabled) == "boolean" then jumpEnabled = movement.jumpEnabled; jumpToggle.Set(jumpEnabled) end
    if type(movement.noclipEnabled) == "boolean" then noclipEnabled = movement.noclipEnabled; noclipToggle.Set(noclipEnabled) end
    if type(movement.flyEnabled) == "boolean" then flyEnabled = movement.flyEnabled; flyToggle.Set(flyEnabled); setFlyState(flyEnabled) end

    if type(combat.fov) == "number" then setFov(combat.fov) end
    if type(combat.smooth) == "number" then
        setSmooth(combat.smooth)
    elseif type(combat.aimSpeed) == "number" then
        -- Convert version 1's inverted Aim Speed into the new Smooth scale.
        local oldSpeed = math.clamp(combat.aimSpeed, 1, 100)
        local oldAlphaAt60Fps = 1 - math.exp(-(2 + oldSpeed * 0.45) / 60)
        setSmooth(math.clamp(math.round(1 / math.max(oldAlphaAt60Fps, 0.01)), 1, 20))
    end
    if type(combat.wallCheck) == "boolean" then wallCheckEnabled = combat.wallCheck; wallCheckToggle.Set(wallCheckEnabled) end
    if type(combat.enabled) == "boolean" then cameraAssistEnabled = combat.enabled; cameraToggle.Set(cameraAssistEnabled) end

    if type(combat.aimBind) == "table"
        and (combat.aimBind.kind == "KeyCode" or combat.aimBind.kind == "UserInputType")
        and type(combat.aimBind.name) == "string" then
        aimBind = {kind = combat.aimBind.kind, name = combat.aimBind.name}
    else
        aimBind = nil
    end
    if combat.aimBindMode == "Hold" or combat.aimBindMode == "Toggle" then
        aimBindMode = combat.aimBindMode
    end
    waitingForAimBind = false
    if aimBind and aimBindMode == "Hold" then
        setAimEnabledFromBind(false, false)
    end
    refreshAimBindUI()

    if type(combat.aimGroups) == "table" then
        for name, toggle in pairs(groupButtons) do
            local value = combat.aimGroups[name]
            if type(value) == "boolean" then
                aimGroups[name] = value
                toggle.Set(value)
            end
        end
    end

    if not noclipEnabled then restoreNoclip() end
    configLoading = false
end

local function loadConfig(silent)
    if not fileApiAvailable then return false end
    local ok, err = pcall(function()
        if not isfile(CONFIG_FILE) then return end
        applyConfig(HttpService:JSONDecode(readfile(CONFIG_FILE)))
    end)
    if not silent then
        configStatus.Text = ok and "Config loaded" or ("Load failed: " .. tostring(err))
    end
    return ok
end

requestConfigSave = function()
    if configLoading or not fileApiAvailable then return end
    configSaveToken += 1
    local token = configSaveToken
    task.delay(0.35, function()
        if token == configSaveToken then saveConfig(true) end
    end)
end

local unloadButton = Instance.new("TextButton")
unloadButton.Position = UDim2.fromOffset(18, 78)
unloadButton.Size = UDim2.fromOffset(396, 36)
unloadButton.BackgroundColor3 = Color3.fromRGB(92, 45, 45)
unloadButton.BorderSizePixel = 0
unloadButton.Font = Enum.Font.Code
unloadButton.Text = "Unload Script"
unloadButton.TextColor3 = Color3.fromRGB(230, 230, 230)
unloadButton.TextSize = 13
unloadButton.Parent = OtherPage

local unloadCorner = Instance.new("UICorner")
unloadCorner.CornerRadius = UDim.new(0, 4)
unloadCorner.Parent = unloadButton

bind(unloadButton.MouseButton1Click:Connect(function()
    -- Saving is synchronous for executor file APIs, so cleanup can safely run
    -- immediately afterward without losing the current UI state.
    saveConfig(true)
    task.defer(function()
        if cleanup then cleanup() end
    end)
end))

task.defer(function()
    loadConfig(true)
    if fileApiAvailable and isfile(CONFIG_FILE) then
        configStatus.Text = "Config auto-loaded"
    end
end)

-- MAIN UPDATE LOOP
bind(RunService.RenderStepped:Connect(function()
    Camera = workspace.CurrentCamera or Camera
    runSafely("ESP", updateESP)
    runSafely("Chams", updateChams)
    runSafely("Movement", updateMovement)
    runSafely("NoClip", updateNoclip)
    runSafely("Fly", updateFly)
end))

-- Apply AimBot after Roblox's normal camera update so CameraScript does not overwrite it.
local AIMBOT_RENDER_NAME = "BezNigativaAimBotCamera"
-- Unbind defensively as an interrupted previous execution may not have reached
-- its cleanup function. Last priority also wins over custom camera scripts that
-- run later than Roblox's default CameraScript.
pcall(function() RunService:UnbindFromRenderStep(AIMBOT_RENDER_NAME) end)
local function aimRenderCallback(deltaTime)
    Camera = workspace.CurrentCamera or Camera
    runSafely("AimBot", updateCombat, deltaTime)
end

local aimBindOk = pcall(function()
    RunService:BindToRenderStep(AIMBOT_RENDER_NAME, Enum.RenderPriority.Last.Value, aimRenderCallback)
end)
if not aimBindOk then
    -- Compatibility fallback for environments that reject named render-step
    -- bindings. This connection is also tracked by the normal cleanup path.
    bind(RunService.RenderStepped:Connect(aimRenderCallback))
end

bind(RunService.Heartbeat:Connect(function()
    runSafely("Movement heartbeat", updateMovement)
end))

-- Window dragging
local dragging = false
local dragStart
local startPosition

bind(topbar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPosition = window.Position
    end
end))

bind(UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        window.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end))

bind(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
    if aimBindMode == "Hold" and inputMatchesAimBind(input) then
        setAimEnabledFromBind(false, false)
    end
end))

bind(UserInputService.WindowFocusReleased:Connect(function()
    if aimBindMode == "Hold" then
        setAimEnabledFromBind(false, false)
    end
end))

bind(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if waitingForAimBind then
        if input.KeyCode == Enum.KeyCode.Escape then
            waitingForAimBind = false
            refreshAimBindUI()
            return
        end

        if input.KeyCode == Enum.KeyCode.Delete or input.KeyCode == Enum.KeyCode.Backspace then
            aimBind = nil
            waitingForAimBind = false
            refreshAimBindUI()
            if requestConfigSave then requestConfigSave() end
            return
        end

        local selectedBind = inputToAimBind(input)
        if selectedBind then
            aimBind = selectedBind
            waitingForAimBind = false
            if aimBindMode == "Hold" then setAimEnabledFromBind(false, false) end
            refreshAimBindUI()
            if requestConfigSave then requestConfigSave() end
        end
        return
    end

    if gameProcessed then return end

    if inputMatchesAimBind(input) then
        if aimBindMode == "Hold" then
            setAimEnabledFromBind(true, false)
        else
            setAimEnabledFromBind(not cameraAssistEnabled, true)
        end
        return
    end

    if input.KeyCode == Enum.KeyCode.RightShift then
        window.Visible = not window.Visible
    end
end))

setPage("Combat")

cleanup = function()
    if destroyed then return end
    destroyed = true

    pcall(function()
        RunService:UnbindFromRenderStep("BezNigativaAimBotCamera")
    end)

    restoreNoclip()
    setFlyState(false)
    disconnectHumanoidConnections()

    local humanoid = getHumanoid()
    if humanoid then
        pcall(function() humanoid.WalkSpeed = defaults.WalkSpeed end)
        pcall(function()
            if humanoid.UseJumpPower then humanoid.JumpPower = defaults.JumpPower else humanoid.JumpHeight = defaults.JumpHeight end
        end)
        pcall(function() humanoid.PlatformStand = false end)
    end

    local root = getRoot()
    if root then
        pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
        pcall(function() root.AssemblyAngularVelocity = Vector3.zero end)
    end
    restoreNoclip()

    for _, connection in ipairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(connections)

    cleanupDrawings()
    cleanupHighlights()
    pcall(function() gui:Destroy() end)
    if env.BezNigativaCleanup == cleanup then
        env.BezNigativaCleanup = nil
    end
end

env.BezNigativaCleanup = cleanup

print("[BezNigativa v5.0] Loaded | Combat / Movement / Visual / Friend / Other")
