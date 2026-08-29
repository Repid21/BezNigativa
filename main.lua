-- BezNigativa | Xeno-friendly ESP test
-- RightShift toggles ClickGUI.
-- ESP uses executor Drawing API when available.

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

-- Clean up a previous execution, including Drawing objects/connections.
local env = (getgenv and getgenv()) or _G
if type(env.BezNigativaCleanup) == "function" then
    pcall(env.BezNigativaCleanup)
end

local connections = {}
local drawings = {}
local playerDrawings = {}
local destroyed = false

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
window.Size = UDim2.fromOffset(430, 225)
window.Position = UDim2.new(0.5, -215, 0.5, -112)
window.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
window.BorderSizePixel = 0
window.Parent = gui

local windowCorner = Instance.new("UICorner")
windowCorner.CornerRadius = UDim.new(0, 6)
windowCorner.Parent = window

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(55, 55, 55)
stroke.Thickness = 1
stroke.Parent = window

local topbar = Instance.new("Frame")
topbar.Name = "Topbar"
topbar.Size = UDim2.new(1, 0, 0, 36)
topbar.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
topbar.BorderSizePixel = 0
topbar.Parent = window

local topbarCorner = Instance.new("UICorner")
topbarCorner.CornerRadius = UDim.new(0, 6)
topbarCorner.Parent = topbar

local topbarFix = Instance.new("Frame")
topbarFix.Size = UDim2.new(1, 0, 0, 6)
topbarFix.Position = UDim2.new(0, 0, 1, -6)
topbarFix.BackgroundColor3 = topbar.BackgroundColor3
topbarFix.BorderSizePixel = 0
topbarFix.Parent = topbar

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 0)
title.Size = UDim2.new(1, -24, 1, 0)
title.Font = Enum.Font.Code
title.Text = "BezNigativa"
title.TextColor3 = Color3.fromRGB(235, 235, 235)
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topbar

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(15, 48)
subtitle.Size = UDim2.new(1, -30, 0, 20)
subtitle.Font = Enum.Font.Code
subtitle.Text = "Visuals | RightShift: toggle menu"
subtitle.TextColor3 = Color3.fromRGB(155, 155, 155)
subtitle.TextSize = 14
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = window

local function createToggle(name, y, text)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Position = UDim2.fromOffset(15, y)
    button.Size = UDim2.fromOffset(185, 34)
    button.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Font = Enum.Font.Code
    button.Text = text .. ": OFF"
    button.TextColor3 = Color3.fromRGB(230, 230, 230)
    button.TextSize = 14
    button.Parent = window

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button

    return button
end

local espButton = createToggle("ESP", 82, "ESP")
local hpButton = createToggle("HealthBar", 126, "Health Bar")

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(15, 174)
status.Size = UDim2.new(1, -30, 0, 22)
status.Font = Enum.Font.Code
status.TextColor3 = Color3.fromRGB(145, 145, 145)
status.TextSize = 13
status.TextXAlignment = Enum.TextXAlignment.Left
status.Text = "Drawing API: checking..."
status.Parent = window

local espEnabled = false
local healthBarEnabled = false

local function setToggleVisual(button, label, enabled)
    button.Text = label .. (enabled and ": ON" or ": OFF")
    button.BackgroundColor3 = enabled and Color3.fromRGB(55, 95, 65) or Color3.fromRGB(43, 43, 43)
end

local drawingSupported = false
local drawingError = nil

local ok, result = pcall(function()
    return Drawing ~= nil and type(Drawing.new) == "function"
end)

drawingSupported = ok and result == true

if drawingSupported then
    status.Text = "Drawing API: ready"
    status.TextColor3 = Color3.fromRGB(125, 190, 135)
else
    drawingError = "Drawing.new is unavailable"
    status.Text = "Drawing API: unavailable in this Xeno build"
    status.TextColor3 = Color3.fromRGB(205, 120, 120)
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
        drawingError = tostring(object)
        status.Text = "Drawing API error - check Xeno build"
        status.TextColor3 = Color3.fromRGB(205, 120, 120)
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
    if not root then
        return nil
    end

    local _, rootVisible = Camera:WorldToViewportPoint(root.Position)
    if not rootVisible then
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
        local viewportPoint = Camera:WorldToViewportPoint(worldPoint)

        if viewportPoint.Z > 0 then
            validPoints += 1
            minX = math.min(minX, viewportPoint.X)
            minY = math.min(minY, viewportPoint.Y)
            maxX = math.max(maxX, viewportPoint.X)
            maxY = math.max(maxY, viewportPoint.Y)
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

espButton.MouseButton1Click:Connect(function()
    if not drawingSupported then
        status.Text = "ESP unavailable: Drawing API missing"
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

hpButton.MouseButton1Click:Connect(function()
    healthBarEnabled = not healthBarEnabled
    setToggleVisual(hpButton, "Health Bar", healthBarEnabled)

    if not healthBarEnabled then
        for _, bundle in pairs(playerDrawings) do
            bundle.HpBackground.Visible = false
            bundle.HpFill.Visible = false
        end
    end
end)

-- Create bundles for current players and maintain them on join/leave.
for _, targetPlayer in ipairs(Players:GetPlayers()) do
    createPlayerDrawings(targetPlayer)
end

table.insert(connections, Players.PlayerAdded:Connect(function(targetPlayer)
    task.defer(createPlayerDrawings, targetPlayer)
end))

table.insert(connections, Players.PlayerRemoving:Connect(function(targetPlayer)
    removePlayerDrawings(targetPlayer)
end))

table.insert(connections, RunService.RenderStepped:Connect(updateESP))

-- Drag window by topbar.
local dragging = false
local dragStart
local startPosition

table.insert(connections, topbar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPosition = window.Position
    end
end))

table.insert(connections, UserInputService.InputChanged:Connect(function(input)
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

table.insert(connections, UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end))

table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.KeyCode == Enum.KeyCode.RightShift then
        window.Visible = not window.Visible
    end
end))

local function cleanup()
    if destroyed then
        return
    end
    destroyed = true

    disconnectAll()
    removeAllDrawings()

    pcall(function()
        gui:Destroy()
    end)
end

env.BezNigativaCleanup = cleanup

print("[BezNigativa] Loaded | ESP + optional health bars")