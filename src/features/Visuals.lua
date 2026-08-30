local Visuals = {}
Visuals.__index = Visuals

local WHITE = Color3.fromRGB(255, 255, 255)
local GREEN = Color3.fromRGB(65, 255, 105)

local function corner(parent, radius)
    local item = Instance.new("UICorner")
    item.CornerRadius = UDim.new(0, radius or 3)
    item.Parent = parent
end

local drawingSupported = false
local drawingCheck, drawingResult = pcall(function()
    return Drawing ~= nil and type(Drawing.new) == "function"
end)
drawingSupported = drawingCheck and drawingResult == true

local function newDrawing(kind)
    if not drawingSupported then return nil end
    local ok, result = pcall(function() return Drawing.new(kind) end)
    if not ok then drawingSupported = false end
    return ok and result or nil
end

local function removeDrawing(item)
    if item then pcall(function() item:Remove() end) end
end

function Visuals.new(ctx)
    local self = setmetatable({
        ctx = ctx, Bundles = {},
        ESP = false, Health = false,
        NameTags = false, ShowDisplay = true, ShowReal = false, ShowDistance = true,
        Chams = false, ChamsTransparency = 0.35,
        Lighting = false, LightR = 255, LightG = 220, LightB = 190, LightStrength = 15,
    }, Visuals)

    local page = ctx.Window:AddPage("Visuals", "ESP, NameTags, Chams и освещение")
    local stack = ctx.Window:ModuleStack(page, 70)
    local esp = stack:Add("ESP", 88)
    self.ESPControl = ctx.Window:Toggle(esp.Settings, UDim2.fromOffset(10, 4), 180, "Box", false, function(v) self.ESP = v; ctx.Touch() end)
    self.HealthControl = ctx.Window:Toggle(esp.Settings, UDim2.fromOffset(200, 4), 180, "Health Bar", false, function(v) self.Health = v; ctx.Touch() end)

    local tags = stack:Add("NameTags", 138)
    self.TagsControl = ctx.Window:Toggle(tags.Settings, UDim2.fromOffset(10, 4), 155, "Enabled", false, function(v) self.NameTags = v; ctx.Touch() end)
    self.DisplayControl = ctx.Window:Toggle(tags.Settings, UDim2.fromOffset(175, 4), 155, "Display name", true, function(v) self.ShowDisplay = v; ctx.Touch() end)
    self.RealControl = ctx.Window:Toggle(tags.Settings, UDim2.fromOffset(340, 4), 155, "Real name", false, function(v) self.ShowReal = v; ctx.Touch() end)
    self.DistanceControl = ctx.Window:Toggle(tags.Settings, UDim2.fromOffset(10, 48), 155, "Meters", true, function(v) self.ShowDistance = v; ctx.Touch() end)

    local chams = stack:Add("Chams", 132)
    self.ChamsControl = ctx.Window:Toggle(chams.Settings, UDim2.fromOffset(10, 4), 190, "Enabled", false, function(v) self.Chams = v; ctx.Touch() end)
    self.TransparencyControl = ctx.Window:Slider(chams.Settings, 48, "Transparency", 35, 0, 100, 1, function(v) self.ChamsTransparency = v / 100; ctx.Touch() end)

    local lighting = stack:Add("Lighting", 252)
    self.LightingControl = ctx.Window:Toggle(lighting.Settings, UDim2.fromOffset(10, 4), 190, "Enabled", false, function(v) self.Lighting = v; self:UpdateLighting(); ctx.Touch() end)
    self.RControl = ctx.Window:Slider(lighting.Settings, 48, "Red", 255, 0, 255, 1, function(v) self.LightR = v; self:UpdateLighting(); ctx.Touch() end)
    self.GControl = ctx.Window:Slider(lighting.Settings, 88, "Green", 220, 0, 255, 1, function(v) self.LightG = v; self:UpdateLighting(); ctx.Touch() end)
    self.BControl = ctx.Window:Slider(lighting.Settings, 128, "Blue", 190, 0, 255, 1, function(v) self.LightB = v; self:UpdateLighting(); ctx.Touch() end)
    self.StrengthControl = ctx.Window:Slider(lighting.Settings, 168, "Strength", 15, -100, 100, 1, function(v) self.LightStrength = v; self:UpdateLighting(); ctx.Touch() end)

    local effect = Instance.new("ColorCorrectionEffect")
    effect.Name = "BezNigativaLighting"
    effect.Enabled = false
    effect.Parent = ctx.Lighting
    ctx.Janitor:Add(effect)
    self.Effect = effect

    ctx.Janitor:Add(ctx.Players.PlayerRemoving:Connect(function(player) self:Remove(player) end))
    ctx.Janitor:Add(ctx.RunService.RenderStepped:Connect(function()
        local ok, message = pcall(function() self:Step() end)
        if not ok then
            drawingSupported = false
            self:ResetBundles()
            if not self.Warned then self.Warned = true; warn("[BezNigativa/Visuals] " .. tostring(message)) end
        end
    end))
    return self
end

function Visuals:CreateBundle(player, character, root)
    local bundle = {Character = character}
    local highlight = Instance.new("Highlight")
    highlight.Name = "BezNigativaVisual"
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = false
    highlight.Parent = character
    bundle.Highlight = highlight
    bundle.Box = newDrawing("Square")
    bundle.HealthBack = bundle.Box and newDrawing("Square") or nil
    bundle.HealthFill = bundle.Box and newDrawing("Square") or nil
    bundle.Tag = bundle.Box and newDrawing("Text") or nil
    local drawingReady = bundle.Box and bundle.HealthBack and bundle.HealthFill and bundle.Tag
    if drawingReady then
        drawingReady = pcall(function()
            bundle.Box.Filled, bundle.Box.Thickness = false, 1.5
            bundle.HealthBack.Filled, bundle.HealthBack.Color = true, Color3.fromRGB(20, 20, 20)
            bundle.HealthFill.Filled = true
            bundle.Tag.Center, bundle.Tag.Outline, bundle.Tag.Size = true, true, 14
        end)
    end
    if not drawingReady then
        drawingSupported = false
        removeDrawing(bundle.Box); removeDrawing(bundle.HealthBack); removeDrawing(bundle.HealthFill); removeDrawing(bundle.Tag)
        bundle.Box, bundle.HealthBack, bundle.HealthFill, bundle.Tag = nil, nil, nil, nil
        local gui = Instance.new("BillboardGui")
        gui.Name = "BezNigativaPlayerInfo"
        gui.Adornee = root
        gui.AlwaysOnTop = true
        gui.LightInfluence = 0
        gui.Size = UDim2.fromOffset(180, 48)
        gui.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
        gui.Enabled = false
        gui.Parent = self.ctx.Window.Gui.Parent
        bundle.Gui = gui
        local tag = Instance.new("TextLabel")
        tag.Size = UDim2.new(1, 0, 0, 20)
        tag.BackgroundTransparency = 1
        tag.Font = Enum.Font.Code
        tag.TextSize = 14
        tag.TextStrokeTransparency = 0.25
        tag.Parent = gui
        bundle.GuiTag = tag
        local healthBack = Instance.new("Frame")
        healthBack.Position = UDim2.new(0.5, -35, 0, 24)
        healthBack.Size = UDim2.fromOffset(70, 5)
        healthBack.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        healthBack.BorderSizePixel = 0
        healthBack.Parent = gui
        corner(healthBack, 2)
        local healthFill = Instance.new("Frame")
        healthFill.Size = UDim2.fromScale(1, 1)
        healthFill.BorderSizePixel = 0
        healthFill.Parent = healthBack
        corner(healthFill, 2)
        bundle.GuiHealthBack, bundle.GuiHealthFill = healthBack, healthFill
    end
    self.Bundles[player] = bundle
    return bundle
end

function Visuals:Remove(player)
    local bundle = self.Bundles[player]
    if not bundle then return end
    if bundle.Highlight then bundle.Highlight:Destroy() end
    if bundle.Gui then bundle.Gui:Destroy() end
    removeDrawing(bundle.Box); removeDrawing(bundle.HealthBack); removeDrawing(bundle.HealthFill); removeDrawing(bundle.Tag)
    self.Bundles[player] = nil
end

function Visuals:ResetBundles()
    local players = {}
    for player in pairs(self.Bundles) do table.insert(players, player) end
    for _, player in ipairs(players) do self:Remove(player) end
end

function Visuals:Bounds(character, camera)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local _, rootVisible = camera:WorldToViewportPoint(root.Position)
    if not rootVisible then return nil end
    local cf, size = character:GetBoundingBox()
    local half = size * 0.5
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local points = 0
    for x = -1, 1, 2 do
        for y = -1, 1, 2 do
            for z = -1, 1, 2 do
                local worldPoint = cf:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
                local screen = camera:WorldToViewportPoint(worldPoint)
                if screen.Z > 0 then
                    points += 1
                    minX, minY = math.min(minX, screen.X), math.min(minY, screen.Y)
                    maxX, maxY = math.max(maxX, screen.X), math.max(maxY, screen.Y)
                end
            end
        end
    end
    local width, height = maxX - minX, maxY - minY
    if points < 2 or width <= 1 or height <= 1 or width > 3000 or height > 3000 then return nil end
    return minX, minY, maxX, maxY
end

function Visuals:HideDrawing(bundle)
    for _, name in ipairs({"Box", "HealthBack", "HealthFill", "Tag"}) do
        if bundle[name] then bundle[name].Visible = false end
    end
end

function Visuals:TagText(player, distance)
    local parts = {}
    if self.ShowDisplay then table.insert(parts, player.DisplayName) end
    if self.ShowReal and (not self.ShowDisplay or player.DisplayName ~= player.Name) then table.insert(parts, "@" .. player.Name) end
    if self.ShowDistance then table.insert(parts, tostring(math.floor(distance + 0.5)) .. "m") end
    return table.concat(parts, "  ")
end

function Visuals:Step()
    local camera = self.ctx.Workspace.CurrentCamera
    if not camera then return end
    local localCharacter = self.ctx.LocalPlayer.Character
    local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    for _, player in ipairs(self.ctx.Players:GetPlayers()) do
        if player ~= self.ctx.LocalPlayer then
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local bundle = self.Bundles[player]
            if bundle and (bundle.Character ~= character or not bundle.Highlight or not bundle.Highlight.Parent or (bundle.Gui and not bundle.Gui.Parent)) then
                self:Remove(player); bundle = nil
            end
            if not character or not humanoid or humanoid.Health <= 0 or not root then
                if bundle then
                    if bundle.Gui then bundle.Gui.Enabled = false end
                    if bundle.Highlight then bundle.Highlight.Enabled = false end
                    self:HideDrawing(bundle)
                end
            else
                bundle = bundle or self:CreateBundle(player, character, root)
                local color = self.ctx.Friends:IsFriend(player) and GREEN or WHITE
                local healthRatio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
                local distance = localRoot and (localRoot.Position - root.Position).Magnitude or 0
                local tagText = self:TagText(player, distance)
                if bundle.Box then
                    local minX, minY, maxX, maxY = self:Bounds(character, camera)
                    if minX then
                        bundle.Box.Visible = self.ESP
                        bundle.Box.Position = Vector2.new(minX, minY)
                        bundle.Box.Size = Vector2.new(maxX - minX, maxY - minY)
                        bundle.Box.Color = color
                        bundle.HealthBack.Visible, bundle.HealthFill.Visible = self.Health, self.Health
                        bundle.HealthBack.Position = Vector2.new(minX - 7, minY)
                        bundle.HealthBack.Size = Vector2.new(4, maxY - minY)
                        local height = (maxY - minY) * healthRatio
                        bundle.HealthFill.Position = Vector2.new(minX - 7, maxY - height)
                        bundle.HealthFill.Size = Vector2.new(4, math.max(1, height))
                        bundle.HealthFill.Color = Color3.fromRGB(255 * (1 - healthRatio), 255 * healthRatio, 40)
                        bundle.Tag.Visible = self.NameTags and tagText ~= ""
                        bundle.Tag.Position = Vector2.new((minX + maxX) / 2, minY - 20)
                        bundle.Tag.Text, bundle.Tag.Color = tagText, color
                    else
                        self:HideDrawing(bundle)
                    end
                else
                    bundle.Gui.Adornee = root
                    bundle.Gui.Enabled = self.Health or (self.NameTags and tagText ~= "")
                    bundle.GuiTag.Visible = self.NameTags and tagText ~= ""
                    bundle.GuiTag.Text, bundle.GuiTag.TextColor3 = tagText, color
                    bundle.GuiHealthBack.Visible = self.Health
                    bundle.GuiHealthFill.Size = UDim2.fromScale(healthRatio, 1)
                    bundle.GuiHealthFill.BackgroundColor3 = Color3.fromRGB(255 * (1 - healthRatio), 255 * healthRatio, 40)
                end
                bundle.Highlight.Enabled = self.Chams or (self.ESP and not bundle.Box)
                bundle.Highlight.FillColor = color
                bundle.Highlight.FillTransparency = self.Chams and self.ChamsTransparency or 1
                bundle.Highlight.OutlineColor = color
                bundle.Highlight.OutlineTransparency = (self.ESP and not bundle.Box) and 0 or (self.Chams and 0.35 or 1)
            end
        end
    end
end

function Visuals:UpdateLighting()
    if not self.Effect or not self.Effect.Parent then return end
    self.Effect.Enabled = self.Lighting
    self.Effect.TintColor = Color3.fromRGB(self.LightR, self.LightG, self.LightB)
    self.Effect.Brightness = self.LightStrength / 100
end

function Visuals:GetConfig()
    return {
        esp = self.ESP, health = self.Health, nameTags = self.NameTags,
        showDisplay = self.ShowDisplay, showReal = self.ShowReal, showDistance = self.ShowDistance,
        chams = self.Chams, chamsTransparency = self.ChamsTransparency,
        lighting = self.Lighting, lightR = self.LightR, lightG = self.LightG, lightB = self.LightB, lightStrength = self.LightStrength,
    }
end

function Visuals:ApplyConfig(data)
    if type(data) ~= "table" then return end
    self.ESP, self.Health, self.NameTags = data.esp == true, data.health == true, data.nameTags == true
    self.ShowDisplay, self.ShowReal, self.ShowDistance = data.showDisplay ~= false, data.showReal == true, data.showDistance ~= false
    self.Chams = data.chams == true
    self.ChamsTransparency = math.clamp(tonumber(data.chamsTransparency) or self.ChamsTransparency, 0, 1)
    self.Lighting = data.lighting == true
    self.LightR = math.clamp(tonumber(data.lightR) or self.LightR, 0, 255)
    self.LightG = math.clamp(tonumber(data.lightG) or self.LightG, 0, 255)
    self.LightB = math.clamp(tonumber(data.lightB) or self.LightB, 0, 255)
    self.LightStrength = math.clamp(tonumber(data.lightStrength) or self.LightStrength, -100, 100)
    self.ESPControl.Set(self.ESP); self.HealthControl.Set(self.Health); self.TagsControl.Set(self.NameTags)
    self.DisplayControl.Set(self.ShowDisplay); self.RealControl.Set(self.ShowReal); self.DistanceControl.Set(self.ShowDistance)
    self.ChamsControl.Set(self.Chams); self.TransparencyControl.Set(self.ChamsTransparency * 100)
    self.LightingControl.Set(self.Lighting); self.RControl.Set(self.LightR); self.GControl.Set(self.LightG)
    self.BControl.Set(self.LightB); self.StrengthControl.Set(self.LightStrength); self:UpdateLighting()
end

function Visuals:Destroy()
    self:ResetBundles()
end

return Visuals
