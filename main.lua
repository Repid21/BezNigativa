-- BezNigativa | categorized Roblox ClickGUI
-- RightShift toggles the menu.
-- Visual ESP uses Drawing API when available.
-- Movement controls are intentionally limited to Studio or a private server owned by LocalPlayer.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

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

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

local function disconnectAll()
    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(connections)
end

local function removeDrawing(object)
    if not object then
        return
    end
    pcall(function()
        object.Visible = false
        object:Remove()
    end)
end

local function removePlayerDrawings(targetPlayer)
    local bundle = playerDrawings[targetPlayer]
    if not bundle then
        return
    end

    for _, object in pairs(bundle) do
        removeDrawing(object)
    end
    playerDrawings[targetPlayer] = nil
end

local function removeAllDrawings()
    for targetPlayer in pairs(playerDrawings) do
        removePlayerDrawings(targetPlayer)
    end
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
        if old then
            old:Destroy()
        end
    end
end

local gui = Instance.new("ScreenGui")
gui.Name = "BezNigativaGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = guiParent

local window = Instance.new("Frame")
window.Name = "MainWindow"
window.Size = UDim2.fromOffset(620, 390)
window.Position = UDim2.new(0.5, -310, 0.5, -195)
window.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
window.BorderSizePixel = 0
window.Parent = gui

local windowCorner = Instance.new("UICorner")
windowCorner.CornerRadius = UDim.new(0, 7)
windowCorner.Parent = window

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(58, 58, 58)
stroke.Thickness = 1
stroke.Parent = window

local topbar = Instance.new("Frame")
topbar.Name = "Topbar"
topbar.Size = UDim2.new(1, 0, 0, 38)
topbar.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
topbar.BorderSizePixel = 0
topbar.Parent = window

local topbarCorner = Instance.new("UICorner")
topbarCorner.CornerRadius = UDim.new(0, 7)
topbarCorner.Parent = topbar

local topbarFix = Instance.new("Frame")
topbarFix.Size = UDim2.new(1, 0, 0, 7)
topbarFix.Position = UDim2.new(0, 0, 1, -7)
topbarFix.BackgroundColor3 = topbar.BackgroundColor3
topbarFix.BorderSizePixel = 0
topbarFix.Parent = topbar

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(13, 0)
title.Size = UDim2.new(1, -26, 1, 0)
title.Font = Enum.Font.Code
title.Text = "BezNigativa"
title.TextColor3 = Color3.fromRGB(238, 238, 238)
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topbar

local sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.Position = UDim2.fromOffset(0, 38)
sidebar.Size = UDim2.new(0, 145, 1, -38)
sidebar.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
sidebar.BorderSizePixel = 0
sidebar.Parent = window

local divider = Instance.new("Frame")
divider.Size = UDim2.new(0, 1, 1, -38)
divider.Position = UDim2.fromOffset(145, 38)
divider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
divider.BorderSizePixel = 0
divider.Parent = window

local content = Instance.new("Frame")
content.Name = "Content"
content.Position = UDim2.fromOffset(146, 38)
content.Size = UDim2.new(1, -146, 1, -38)
content.BackgroundTransparency = 1
content.Parent = window

local function makeCategoryButton(name, y)
    local button = Instance.new("TextButton")
    button.Name = name .. "Tab"
    button.Position = UDim2.fromOffset(10, y)
    button.Size = UDim2.fromOffset(125, 36)
    button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Font = Enum.Font.Code
    button.Text = name
    button.TextColor3 = Color3.fromRGB(190, 190, 190)
    button.TextSize = 14
    button.Parent = sidebar

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button

    return button
end

local categoryButtons = {
    Combat = makeCategoryButton("Combat", 16),
    Movement = makeCategoryButton("Movement", 60),
    Visual = makeCategoryButton("Visual", 104),
    Other = makeCategoryButton("Other", 148),
}

local pages = {}

local function makePage(name)
    local page = Instance.new("Frame")
    page.Name = name .. "Page"
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = content

    local heading = Instance.new("TextLabel")
    heading.BackgroundTransparency = 1
    heading.Position = UDim2.fromOffset(20, 14)
    heading.Size = UDim2.new(1, -40, 0, 28)
    heading.Font = Enum.Font.Code
    heading.Text = name
    heading.TextColor3 = Color3.fromRGB(235, 235, 235)
    heading.TextSize = 20
    heading.TextXAlignment = Enum.TextXAlignment.Left
    heading.Parent = page

    pages[name] = page
    return page
end

local combatPage = makePage("Combat")
local movementPage = makePage("Movement")
local visualPage = makePage("Visual")
local otherPage = makePage("Other")

local function makeEmptyLabel(page, text)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(20, 58)
    label.Size = UDim2.new(1, -40, 0, 24)
    label.Font = Enum.Font.Code
    label.Text = text
    label.TextColor3 = Color3.fromRGB(135, 135, 135)
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = page
end

makeEmptyLabel(combatPage, "No modules yet.")
makeEmptyLabel(otherPage, "No modules yet.")

local function setToggleVisual(button, label, enabled)
    button.Text = label .. (enabled and ": ON" or ": OFF")
    button.BackgroundColor3 = enabled and Color3.fromRGB(55, 95, 65) or Color3.fromRGB(43, 43, 43)
end

local function makeToggle(page, name, label, y)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Position = UDim2.fromOffset(20, y)
    button.Size = UDim2.fromOffset(195, 34)
    button.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Font = Enum.Font.Code
    button.Text = label .. ": OFF"
    button.TextColor3 = Color3.fromRGB(230, 230, 230)
    button.TextSize = 14
    button.Parent = page

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button

    return button
end

local function makeInfoLabel(page, text, y)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(20, y)
    label.Size = UDim2.new(1, -40, 0, 22)
    label.Font = Enum.Font.Code
    label.Text = text
    label.TextColor3 = Color3.fromRGB(140, 140, 140)
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = page
    return label
end

-- Visual page ---------------------------------------------------------------
local espButton = makeToggle(visualPage, "ESP", "ESP", 58)
local hpButton = makeToggle(visualPage, "HealthBar", "Health Bar", 102)
local drawingStatus = makeInfoLabel(visualPage, "Drawing API: checking...", 150)

local espEnabled = false
local healthBarEnabled = false
local drawingSupported = false

local drawingOk, drawingResult = pcall(function()
    return Drawing ~= nil and type(Drawing.new) == "function"
end)

drawingSupported = drawingOk and drawingResult == true

if drawingSupported then
    drawingStatus.Text = "Drawing API: ready"
    drawingStatus.TextColor3 = Color3.fromRGB(125, 190, 135)
else
    drawingStatus.Text = "Drawing API: unavailable in this Xeno build"
    drawingStatus.TextColor3 = Color3.fromRGB(205, 120, 120)
end

local function newDrawing(className)
    if not drawingSupported then
        return nil
    end

    local success, object = pcall(function()
        return Drawing.new(className)
    end)

    if not success or not object then
        drawingSupported = false
        drawingStatus.Text = "Drawing API error - check Xeno build"
        drawingStatus.TextColor3 = Color3.fromRGB(205, 120, 120)
        return nil
    end

    table.insert(drawings, object)
    return object
end

local function createPlayerDrawings(targetPlayer)
    if targetPlayer == LocalPlayer or playerDrawings[targetPlayer] or not drawingSupported then
        return
    end

    local box = newDrawing("Square")
    local hpBackground = newDrawing("Square")
    local hpFill = newDrawing("Square")

    if not box or not hpBackground or not hpFill then
        if box then removeDrawing(box) end
        if hpBackground then removeDrawing(hpBackground) end
        if hpFill then removeDrawing(hpFill) end
        return
    end

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

    playerDrawings[targetPlayer] = {
        Box = box,
        HpBackground = hpBackground,
        HpFill = hpFill,
    }
end

local function hideBundle(bundle)
    if not bundle then
        return
    end
    bundle.Box.Visible = false
    bundle.HpBackground.Visible = false
    bundle.HpFill.Visible = false
end

local function getCharacterScreenBounds(character)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root or not Camera then
        return nil
    end

    local rootPoint, rootVisible = Camera:WorldToViewportPoint(root.Position)
    if not rootVisible or rootPoint.Z <= 0 then
        return nil
    end

    local boxCFrame, boxSize = character:GetBoundingBox()
    local half = boxSize * 0.5
    local corners = {
        Vector3.new(-half.X, -half.Y, -half.Z),
        Vector3.new(-half.X, -half.Y, half.Z),
        Vector3.new(-half.X, half.Y, -half.Z),
        Vector3.new(-half.X, half.Y, half.Z),
        Vector3.new(half.X, -half.Y, -half.Z),
        Vector3.new(half.X, -half.Y, half.Z),
        Vector3.new(half.X, half.Y, -half.Z),
        Vector3.new(half.X, half.Y, half.Z),
    }

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local validPoints = 0

    for _, offset in ipairs(corners) do
        local worldPoint = boxCFrame:PointToWorldSpace(offset)
        local point = Camera:WorldToViewportPoint(worldPoint)
        if point.Z > 0 then
            validPoints += 1
            minX = math.min(minX, point.X)
            minY = math.min(minY, point.Y)
            maxX = math.max(maxX, point.X)
            maxY = math.max(maxY, point.Y)
        end
    end

    if validPoints < 2 then
        return nil
    end

    local width = maxX - minX
    local height = maxY - minY
    if width <= 1 or height <= 1 or width > 3000 or height > 3000 then
        return nil
    end

    return minX, minY, width, height
end

local function updateESP()
    if destroyed or not drawingSupported then
        return
    end

    Camera = workspace.CurrentCamera or Camera
    if not Camera then
        return
    end

    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= LocalPlayer then
            createPlayerDrawings(targetPlayer)
            local bundle = playerDrawings[targetPlayer]
            if bundle then
                local character = targetPlayer.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")

                if not espEnabled or not character or not humanoid or humanoid.Health <= 0 then
                    hideBundle(bundle)
                else
                    local minX, minY, width, height = getCharacterScreenBounds(character)
                    if not minX then
                        hideBundle(bundle)
                    else
                        bundle.Box.Position = Vector2.new(minX, minY)
                        bundle.Box.Size = Vector2.new(width, height)
                        bundle.Box.Visible = true

                        if healthBarEnabled then
                            local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
                            local barWidth = 4
                            local barX = minX - 8
                            bundle.HpBackground.Position = Vector2.new(barX, minY)
                            bundle.HpBackground.Size = Vector2.new(barWidth, height)
                            bundle.HpBackground.Visible = true

                            local fillHeight = math.max(1, height * ratio)
                            bundle.HpFill.Position = Vector2.new(barX, minY + (height - fillHeight))
                            bundle.HpFill.Size = Vector2.new(barWidth, fillHeight)
                            bundle.HpFill.Color = Color3.fromRGB(
                                math.floor(255 * (1 - ratio)),
                                math.floor(220 * ratio),
                                55
                            )
                            bundle.HpFill.Visible = true
                        else
                            bundle.HpBackground.Visible = false
                            bundle.HpFill.Visible = false
                        end
                    end
                end
            end
        end
    end
end

connect(espButton.MouseButton1Click, function()
    if not drawingSupported then
        drawingStatus.Text = "ESP unavailable: Drawing API missing"
        return
    end

    espEnabled = not espEnabled
    setToggleVisual(espButton, "ESP", espEnabled)

    if not espEnabled then
        for _, bundle in pairs(playerDrawings) do
            hideBundle(bundle)
        end
    end
end)

connect(hpButton.MouseButton1Click, function()
    healthBarEnabled = not healthBarEnabled
    setToggleVisual(hpButton, "Health Bar", healthBarEnabled)

    if not healthBarEnabled then
        for _, bundle in pairs(playerDrawings) do
            bundle.HpBackground.Visible = false
            bundle.HpFill.Visible = false
        end
    end
end)

for _, targetPlayer in ipairs(Players:GetPlayers()) do
    createPlayerDrawings(targetPlayer)
end

connect(Players.PlayerAdded, function(targetPlayer)
    task.defer(createPlayerDrawings, targetPlayer)
end)

connect(Players.PlayerRemoving, function(targetPlayer)
    removePlayerDrawings(targetPlayer)
end)

connect(RunService.RenderStepped, updateESP)

-- Movement page -------------------------------------------------------------
local movementAllowed = RunService:IsStudio()
    or (game.PrivateServerId ~= "" and game.PrivateServerOwnerId == LocalPlayer.UserId)

local movementInfo = makeInfoLabel(
    movementPage,
    movementAllowed and "Movement controls: enabled for this test session" or "Movement controls: locked in public servers",
    58
)
movementInfo.TextColor3 = movementAllowed and Color3.fromRGB(125, 190, 135) or Color3.fromRGB(205, 150, 100)

local speedEnabled = false
local jumpEnabled = false
local speedValue = 24
local jumpValue = 70

local speedButton = makeToggle(movementPage, "Speed", "Speed", 94)
local jumpButton = makeToggle(movementPage, "Jump", "Jump", 182)

local function makeValueControls(page, y, initialText)
    local minus = Instance.new("TextButton")
    minus.Position = UDim2.fromOffset(230, y)
    minus.Size = UDim2.fromOffset(34, 34)
    minus.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
    minus.BorderSizePixel = 0
    minus.AutoButtonColor = false
    minus.Font = Enum.Font.Code
    minus.Text = "-"
    minus.TextColor3 = Color3.fromRGB(230, 230, 230)
    minus.TextSize = 18
    minus.Parent = page

    local value = Instance.new("TextLabel")
    value.Position = UDim2.fromOffset(270, y)
    value.Size = UDim2.fromOffset(70, 34)
    value.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    value.BorderSizePixel = 0
    value.Font = Enum.Font.Code
    value.Text = initialText
    value.TextColor3 = Color3.fromRGB(225, 225, 225)
    value.TextSize = 14
    value.Parent = page

    local plus = Instance.new("TextButton")
    plus.Position = UDim2.fromOffset(346, y)
    plus.Size = UDim2.fromOffset(34, 34)
    plus.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
    plus.BorderSizePixel = 0
    plus.AutoButtonColor = false
    plus.Font = Enum.Font.Code
    plus.Text = "+"
    plus.TextColor3 = Color3.fromRGB(230, 230, 230)
    plus.TextSize = 18
    plus.Parent = page

    for _, object in ipairs({minus, value, plus}) do
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = object
    end

    return minus, value, plus
end

local speedMinus, speedLabel, speedPlus = makeValueControls(movementPage, 94, tostring(speedValue))
local jumpMinus, jumpLabel, jumpPlus = makeValueControls(movementPage, 182, tostring(jumpValue))

makeInfoLabel(movementPage, "WalkSpeed value", 134)
makeInfoLabel(movementPage, "JumpPower / approximate jump strength", 222)

local baseWalkSpeed = 16
local baseJumpPower = 50
local baseJumpHeight = 7.2

local function getHumanoid()
    local character = LocalPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function captureMovementDefaults()
    local humanoid = getHumanoid()
    if not humanoid then
        return
    end

    baseWalkSpeed = humanoid.WalkSpeed
    baseJumpPower = humanoid.JumpPower
    baseJumpHeight = humanoid.JumpHeight
end

local function applyMovement()
    if not movementAllowed then
        return
    end

    local humanoid = getHumanoid()
    if not humanoid then
        return
    end

    humanoid.WalkSpeed = speedEnabled and speedValue or baseWalkSpeed

    if humanoid.UseJumpPower then
        humanoid.JumpPower = jumpEnabled and jumpValue or baseJumpPower
    else
        local scaledHeight = math.clamp(7.2 * (jumpValue / 50), 2, 30)
        humanoid.JumpHeight = jumpEnabled and scaledHeight or baseJumpHeight
    end
end

captureMovementDefaults()

connect(LocalPlayer.CharacterAdded, function()
    task.wait(0.2)
    captureMovementDefaults()
    applyMovement()
end)

connect(speedButton.MouseButton1Click, function()
    if not movementAllowed then
        movementInfo.Text = "Blocked: use Studio or your own private server"
        return
    end
    speedEnabled = not speedEnabled
    setToggleVisual(speedButton, "Speed", speedEnabled)
    applyMovement()
end)

connect(jumpButton.MouseButton1Click, function()
    if not movementAllowed then
        movementInfo.Text = "Blocked: use Studio or your own private server"
        return
    end
    jumpEnabled = not jumpEnabled
    setToggleVisual(jumpButton, "Jump", jumpEnabled)
    applyMovement()
end)

connect(speedMinus.MouseButton1Click, function()
    speedValue = math.clamp(speedValue - 4, 8, 60)
    speedLabel.Text = tostring(speedValue)
    applyMovement()
end)

connect(speedPlus.MouseButton1Click, function()
    speedValue = math.clamp(speedValue + 4, 8, 60)
    speedLabel.Text = tostring(speedValue)
    applyMovement()
end)

connect(jumpMinus.MouseButton1Click, function()
    jumpValue = math.clamp(jumpValue - 10, 20, 120)
    jumpLabel.Text = tostring(jumpValue)
    applyMovement()
end)

connect(jumpPlus.MouseButton1Click, function()
    jumpValue = math.clamp(jumpValue + 10, 20, 120)
    jumpLabel.Text = tostring(jumpValue)
    applyMovement()
end)

-- Category switching --------------------------------------------------------
local selectedCategory = "Visual"

local function selectCategory(name)
    selectedCategory = name

    for pageName, page in pairs(pages) do
        page.Visible = pageName == name
    end

    for buttonName, button in pairs(categoryButtons) do
        local selected = buttonName == name
        button.BackgroundColor3 = selected and Color3.fromRGB(52, 72, 58) or Color3.fromRGB(35, 35, 35)
        button.TextColor3 = selected and Color3.fromRGB(235, 235, 235) or Color3.fromRGB(190, 190, 190)
    end
end

for name, button in pairs(categoryButtons) do
    connect(button.MouseButton1Click, function()
        selectCategory(name)
    end)
end

selectCategory(selectedCategory)

-- Window dragging -----------------------------------------------------------
local dragging = false
local dragStart
local startPosition

connect(topbar.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPosition = window.Position
    end
end)

connect(UserInputService.InputChanged, function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        window.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

connect(UserInputService.InputBegan, function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.KeyCode == Enum.KeyCode.RightShift then
        window.Visible = not window.Visible
    end
end)

local function cleanup()
    if destroyed then
        return
    end
    destroyed = true

    if movementAllowed then
        speedEnabled = false
        jumpEnabled = false
        applyMovement()
    end

    disconnectAll()
    removeAllDrawings()

    pcall(function()
        gui:Destroy()
    end)
end

env.BezNigativaCleanup = cleanup

print("[BezNigativa] Loaded | Combat / Movement / Visual / Other")