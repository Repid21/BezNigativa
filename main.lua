-- BezNigativa | categorized Roblox ClickGUI
-- RightShift toggles the menu.
-- Visual ESP uses Drawing API when available.
-- Movement and Combat controls are restricted to Roblox Studio or a private server owned by LocalPlayer.

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

local safeEnvironment = RunService:IsStudio()
    or (game.PrivateServerId ~= "" and game.PrivateServerOwnerId == LocalPlayer.UserId)

local env = (getgenv and getgenv()) or _G
if type(env.BezNigativaCleanup) == "function" then
    pcall(env.BezNigativaCleanup)
end

local connections = {}
local drawings = {}
local playerDrawings = {}
local destroyed = false

local function bind(connection)
    table.insert(connections, connection)
    return connection
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
title.Text = "BezNigativa"
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
    local page = Instance.new("Frame")
    page.Name = name
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = content
    pages[name] = page
    return page
end

local CombatPage = createPage("Combat")
local MovementPage = createPage("Movement")
local VisualPage = createPage("Visual")
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
createTab("Other", 146)

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

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(18, y)
    label.Size = UDim2.fromOffset(210, 32)
    label.Font = Enum.Font.Code
    label.TextColor3 = Color3.fromRGB(215, 215, 215)
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent

    local minus = Instance.new("TextButton")
    minus.Position = UDim2.fromOffset(260, y)
    minus.Size = UDim2.fromOffset(34, 32)
    minus.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
    minus.BorderSizePixel = 0
    minus.Font = Enum.Font.Code
    minus.Text = "-"
    minus.TextColor3 = Color3.fromRGB(230, 230, 230)
    minus.TextSize = 16
    minus.Parent = parent

    local plus = minus:Clone()
    plus.Position = UDim2.fromOffset(370, y)
    plus.Text = "+"
    plus.Parent = parent

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Position = UDim2.fromOffset(302, y)
    valueLabel.Size = UDim2.fromOffset(60, 32)
    valueLabel.BackgroundColor3 = Color3.fromRGB(34, 34, 34)
    valueLabel.BorderSizePixel = 0
    valueLabel.Font = Enum.Font.Code
    valueLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
    valueLabel.TextSize = 13
    valueLabel.Parent = parent

    for _, control in ipairs({minus, plus, valueLabel}) do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = control
    end

    local function refresh()
        label.Text = labelText
        valueLabel.Text = tostring(value)
    end

    local function setValue(newValue)
        value = math.clamp(newValue, minimum, maximum)
        refresh()
        if onChanged then onChanged(value) end
    end

    bind(minus.MouseButton1Click:Connect(function()
        setValue(value - step)
    end))
    bind(plus.MouseButton1Click:Connect(function()
        setValue(value + step)
    end))

    refresh()
    return function() return value end, setValue
end

local drawingSupported = false
local drawingOk, drawingResult = pcall(function()
    return Drawing ~= nil and type(Drawing.new) == "function"
end)
drawingSupported = drawingOk and drawingResult == true

local function newDrawing(className)
    if not drawingSupported then return nil end
    local ok, object = pcall(function()
        return Drawing.new(className)
    end)
    if not ok or not object then
        drawingSupported = false
        return nil
    end
    table.insert(drawings, object)
    return object
end

-- VISUAL
pageTitle(VisualPage, "Visual", drawingSupported and "Drawing API ready" or "Drawing API unavailable")

local espEnabled = false
local healthBarEnabled = false

local espToggle = createToggle(VisualPage, 18, 78, 190, "ESP", false, function(value)
    if value and not drawingSupported then return false end
    espEnabled = value
    if not value then
        for _, bundle in pairs(playerDrawings) do
            bundle.Box.Visible = false
            bundle.HpBackground.Visible = false
            bundle.HpFill.Visible = false
        end
    end
end)

local hpToggle = createToggle(VisualPage, 222, 78, 190, "Health Bar", false, function(value)
    healthBarEnabled = value
    if not value then
        for _, bundle in pairs(playerDrawings) do
            bundle.HpBackground.Visible = false
            bundle.HpFill.Visible = false
        end
    end
end)

local function createPlayerDrawings(targetPlayer)
    if targetPlayer == LocalPlayer or playerDrawings[targetPlayer] or not drawingSupported then return end

    local box = newDrawing("Square")
    local hpBackground = newDrawing("Square")
    local hpFill = newDrawing("Square")
    if not box or not hpBackground or not hpFill then return end

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

            if not bundle or not espEnabled or not character or not humanoid or humanoid.Health <= 0 then
                if bundle then
                    bundle.Box.Visible = false
                    bundle.HpBackground.Visible = false
                    bundle.HpFill.Visible = false
                end
            else
                local x, y, width, height = screenBounds(character)
                if not x then
                    bundle.Box.Visible = false
                    bundle.HpBackground.Visible = false
                    bundle.HpFill.Visible = false
                else
                    bundle.Box.Position = Vector2.new(x, y)
                    bundle.Box.Size = Vector2.new(width, height)
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

for _, player in ipairs(Players:GetPlayers()) do createPlayerDrawings(player) end
bind(Players.PlayerAdded:Connect(function(player) task.defer(createPlayerDrawings, player) end))
bind(Players.PlayerRemoving:Connect(removePlayerDrawings))

-- MOVEMENT
pageTitle(MovementPage, "Movement", safeEnvironment and "Enabled in this test environment" or "Locked: Studio / your private server only")

local speedEnabled = false
local jumpEnabled = false
local speedValue = 24
local jumpValue = 70
local defaults = {WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2}

local function getHumanoid()
    local character = LocalPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function captureDefaults()
    local humanoid = getHumanoid()
    if humanoid then
        defaults.WalkSpeed = humanoid.WalkSpeed
        defaults.JumpPower = humanoid.JumpPower
        defaults.JumpHeight = humanoid.JumpHeight
    end
end

captureDefaults()
bind(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.2)
    captureDefaults()
end))

local speedToggle = createToggle(MovementPage, 18, 78, 190, "Speed", false, function(value)
    if value and not safeEnvironment then return false end
    speedEnabled = value
    local humanoid = getHumanoid()
    if humanoid and not value then humanoid.WalkSpeed = defaults.WalkSpeed end
end)

local jumpToggle = createToggle(MovementPage, 222, 78, 190, "Jump", false, function(value)
    if value and not safeEnvironment then return false end
    jumpEnabled = value
    local humanoid = getHumanoid()
    if humanoid and not value then
        if humanoid.UseJumpPower then humanoid.JumpPower = defaults.JumpPower else humanoid.JumpHeight = defaults.JumpHeight end
    end
end)

local getSpeed = createStepper(MovementPage, 130, "Speed value", speedValue, 16, 100, 4, function(v) speedValue = v end)
local getJump = createStepper(MovementPage, 174, "Jump value", jumpValue, 30, 150, 5, function(v) jumpValue = v end)

local function updateMovement()
    if not safeEnvironment then return end
    local humanoid = getHumanoid()
    if not humanoid then return end
    if speedEnabled then humanoid.WalkSpeed = speedValue end
    if jumpEnabled then
        if humanoid.UseJumpPower then humanoid.JumpPower = jumpValue else humanoid.JumpHeight = math.max(7.2, jumpValue / 10) end
    end
end

-- COMBAT / SAFE CAMERA ASSIST
pageTitle(CombatPage, "Combat", safeEnvironment and "AimBot test | first person" or "Locked: Studio / your private server only")

local cameraAssistEnabled = false
local fovRadius = 140
local smoothness = 8
local aimGroups = {
    Head = true,
    Neck = false,
    Body = true,
    Arms = false,
    Legs = false,
}

local cameraToggle = createToggle(CombatPage, 18, 78, 190, "AimBot", false, function(value)
    if value and not safeEnvironment then return false end
    cameraAssistEnabled = value
end)

local getFov = createStepper(CombatPage, 128, "FOV radius", fovRadius, 40, 500, 10, function(v) fovRadius = v end)
local getSmooth = createStepper(CombatPage, 172, "Smoothness", smoothness, 1, 25, 1, function(v) smoothness = v end)

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

local combatStatus = Instance.new("TextLabel")
combatStatus.BackgroundTransparency = 1
combatStatus.Position = UDim2.fromOffset(18, 340)
combatStatus.Size = UDim2.new(1, -36, 0, 24)
combatStatus.Font = Enum.Font.Code
combatStatus.Text = safeEnvironment and "Enter first person to use AimBot" or "AimBot disabled on public servers"
combatStatus.TextColor3 = Color3.fromRGB(140, 140, 140)
combatStatus.TextSize = 12
combatStatus.TextXAlignment = Enum.TextXAlignment.Left
combatStatus.Parent = CombatPage

local fovCircle = newDrawing("Circle")
if fovCircle then
    fovCircle.Visible = false
    fovCircle.Filled = false
    fovCircle.Thickness = 1
    fovCircle.NumSides = 64
    fovCircle.Color = Color3.fromRGB(210, 210, 210)
    fovCircle.Transparency = 0.75
end

local function isFirstPerson()
    if not Camera then return false end
    return (Camera.CFrame.Position - Camera.Focus.Position).Magnitude < 1.2
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

local function getBestAimPoint()
    if not Camera then return nil end

    local viewport = Camera.ViewportSize
    local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    local bestPosition = nil
    local bestDistance = fovRadius

    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= LocalPlayer then
            local character = targetPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")

            if character and humanoid and humanoid.Health > 0 then
                for _, worldPosition in ipairs(candidatePositions(character)) do
                    local screenPosition, visible = Camera:WorldToViewportPoint(worldPosition)
                    if visible and screenPosition.Z > 0 then
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

local function updateCombat()
    Camera = workspace.CurrentCamera or Camera
    if not Camera then return end

    if fovCircle then
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
        fovCircle.Radius = fovRadius
        fovCircle.Visible = cameraAssistEnabled and safeEnvironment
    end

    if not cameraAssistEnabled or not safeEnvironment then return end

    if not isFirstPerson() then
        combatStatus.Text = "Enter first person to use AimBot"
        return
    end

    local targetPosition = getBestAimPoint()
    if not targetPosition then
        combatStatus.Text = "No selected target inside FOV"
        return
    end

    combatStatus.Text = "Tracking closest selected zone inside FOV"
    local desired = CFrame.lookAt(Camera.CFrame.Position, targetPosition)
    local alpha = math.clamp(1 / math.max(smoothness, 1), 0.02, 1)
    Camera.CFrame = Camera.CFrame:Lerp(desired, alpha)
end

-- OTHER
pageTitle(OtherPage, "Other", "No modules yet")

-- MAIN UPDATE LOOP
bind(RunService.RenderStepped:Connect(function()
    Camera = workspace.CurrentCamera or Camera
    updateESP()
    updateCombat()
end))

bind(RunService.Heartbeat:Connect(updateMovement))

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
end))

bind(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        window.Visible = not window.Visible
    end
end))

setPage("Combat")

local function cleanup()
    if destroyed then return end
    destroyed = true

    local humanoid = getHumanoid()
    if humanoid then
        pcall(function() humanoid.WalkSpeed = defaults.WalkSpeed end)
        pcall(function()
            if humanoid.UseJumpPower then humanoid.JumpPower = defaults.JumpPower else humanoid.JumpHeight = defaults.JumpHeight end
        end)
    end

    for _, connection in ipairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(connections)

    cleanupDrawings()
    pcall(function() gui:Destroy() end)
end

env.BezNigativaCleanup = cleanup

print("[BezNigativa] Loaded | Combat / Movement / Visual / Other")