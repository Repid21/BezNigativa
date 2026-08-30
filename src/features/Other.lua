local Other = {}
Other.__index = Other

function Other.new(ctx)
    local self = setmetatable({ctx = ctx}, Other)
    local page = ctx.Window:AddPage("Other", "Управление интерфейсом и скриптом")
    local stack = ctx.Window:ModuleStack(page, 70)
    local module = stack:Add("Script", 142)
    ctx.Window:Button(module.Settings, UDim2.fromOffset(10, 4), UDim2.new(1, -20, 0, 36), "Полностью отключить скрипт", function()
        ctx.Unload()
    end, Color3.fromRGB(105, 45, 45))
    local hint = Instance.new("TextLabel")
    hint.Position = UDim2.fromOffset(10, 50)
    hint.Size = UDim2.new(1, -20, 0, 46)
    hint.BackgroundTransparency = 1
    hint.Font = Enum.Font.Code
    hint.Text = "Настройки сохранятся автоматически.\nRightShift — скрыть / показать меню."
    hint.TextColor3 = Color3.fromRGB(160, 160, 160)
    hint.TextSize = 12
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextYAlignment = Enum.TextYAlignment.Top
    hint.Parent = module.Settings
    return self
end

return Other
