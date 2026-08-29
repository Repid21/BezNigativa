local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Удаляем старую копию GUI при повторном запуске
local oldGui = playerGui:FindFirstChild("ClickGui")
if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "ClickGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = playerGui

local window = Instance.new("Frame")
window.Name = "MainWindow"
window.Size = UDim2.fromOffset(420, 300)
window.Position = UDim2.new(0.5, -210, 0.5, -150)
window.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
window.BorderSizePixel = 0
window.Parent = gui

local windowCorner = Instance.new("UICorner")
windowCorner.CornerRadius = UDim.new(0, 6)
windowCorner.Parent = window

local topbar = Instance.new("Frame")
topbar.Name = "Topbar"
topbar.Size = UDim2.new(1, 0, 0, 35)
topbar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
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
title.Name = "Title"
title.Size = UDim2.new(1, -20, 1, 0)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.Text = "ClickGUI"
title.TextColor3 = Color3.fromRGB(235, 235, 235)
title.TextSize = 16
title.Font = Enum.Font.Code
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topbar

local button = Instance.new("TextButton")
button.Name = "TestModule"
button.Size = UDim2.fromOffset(150, 32)
button.Position = UDim2.fromOffset(15, 55)
button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
button.TextColor3 = Color3.fromRGB(230, 230, 230)
button.Text = "Test Module: OFF"
button.TextSize = 14
button.Font = Enum.Font.Code
button.BorderSizePixel = 0
button.AutoButtonColor = false
button.Parent = window

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 4)
buttonCorner.Parent = button

local enabled = false

button.MouseButton1Click:Connect(function()
	enabled = not enabled

	if enabled then
		button.Text = "Test Module: ON"
		button.BackgroundColor3 = Color3.fromRGB(70, 110, 70)
	else
		button.Text = "Test Module: OFF"
		button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	end
end)

-- Перетаскивание окна
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

-- Right Shift — открыть / закрыть ClickGUI
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.RightShift then
		window.Visible = not window.Visible
	end
end)
