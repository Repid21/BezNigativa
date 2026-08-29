-- BezNigativa | basic Roblox ClickGUI test
-- Designed to use only common Luau/Roblox APIs so it can be used as a simple executor compatibility test.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
if not player then
    warn("[BezNigativa] LocalPlayer not found")
    return
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

    return player:WaitForChild("PlayerGui")
end

local guiParent = getGuiParent()

-- Remove old copy after re-execution.
for _, parent in ipairs({guiParent, player:FindFirstChild("PlayerGui"), CoreGui}) do
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
window.Size = UDim2.fromOffset(430, 300)
window.Position = UDim2.new(0.5, -215, 0.5, -150)
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
subtitle.Position = UDim2.fromOffset(15, 50)
subtitle.Size = UDim2.new(1, -30, 0, 20)
subtitle.Font = Enum.Font.Code
subtitle.Text = "GUI loaded successfully | RightShift: toggle"
subtitle.TextColor3 = Color3.fromRGB(155, 155, 155)
subtitle.TextSize = 14
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = window

local testButton = Instance.new("TextButton")
testButton.Name = "TestToggle"
testButton.Position = UDim2.fromOffset(15, 85)
testButton.Size = UDim2.fromOffset(165, 34)
testButton.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
testButton.BorderSizePixel = 0
testButton.AutoButtonColor = false
testButton.Font = Enum.Font.Code
testButton.Text = "Test Module: OFF"
testButton.TextColor3 = Color3.fromRGB(230, 230, 230)
testButton.TextSize = 14
testButton.Parent = window

local testCorner = Instance.new("UICorner")
testCorner.CornerRadius = UDim.new(0, 4)
testCorner.Parent = testButton

local enabled = false
testButton.MouseButton1Click:Connect(function()
    enabled = not enabled

    if enabled then
        testButton.Text = "Test Module: ON"
        testButton.BackgroundColor3 = Color3.fromRGB(55, 95, 65)
    else
        testButton.Text = "Test Module: OFF"
        testButton.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
    end
end)

-- Drag window by the top bar.
local dragging = false
local dragStart
local startPosition

topbar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPosition = window.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
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

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- Right Shift toggles the whole window.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.KeyCode == Enum.KeyCode.RightShift then
        window.Visible = not window.Visible
    end
end)

print("[BezNigativa] ClickGUI loaded successfully")
