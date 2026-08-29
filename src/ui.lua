local UI = {}

function UI.Create(parent)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ClickGui"
	gui.ResetOnSpawn = false
	gui.Parent = parent

	local window = Instance.new("Frame")
	window.Name = "MainWindow"
	window.Size = UDim2.fromOffset(420, 300)
	window.Position = UDim2.new(0.5, -210, 0.5, -150)
	window.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	window.BorderSizePixel = 0
	window.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = window

	local topbar = Instance.new("Frame")
	topbar.Name = "Topbar"
	topbar.Size = UDim2.new(1, 0, 0, 35)
	topbar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	topbar.BorderSizePixel = 0
	topbar.Parent = window

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 1, 0)
	title.Position = UDim2.fromOffset(10, 0)
	title.BackgroundTransparency = 1
	title.Text = "ClickGUI"
	title.TextColor3 = Color3.fromRGB(235, 235, 235)
	title.TextSize = 16
	title.Font = Enum.Font.Code
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = topbar

	return {
		Gui = gui,
		Window = window,
		Topbar = topbar,
	}
end

return UI
