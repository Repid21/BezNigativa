local Visuals = {}
Visuals.__index = Visuals

local WHITE = Color3.fromRGB(255, 255, 255)
local GREEN = Color3.fromRGB(65, 255, 105)

local function removeDrawing(item)
    if item then pcall(function() item:Remove() end) end
end

local function newDrawing(kind)
    if not Drawing or type(Drawing.new) ~= "function" then return nil end
    local ok, result = pcall(Drawing.new, kind)
    return ok and result or nil
end

function Visuals.new(ctx)
    local self = setmetatable({
        ctx = ctx,
        ESP = false,
        Health = false,
        NameTags = false,
        ShowDisplay = true,
        ShowReal = false,
        ShowDistance = true,
        Chams = false,
        ChamsTransparency = 0.35,
        Lighting = false,
        LightR = 255,
        LightG = 220,
        LightB = 190,
        LightStrength = 15,
        Bundles = {},
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
    self.TransparencyControl = ctx.Window:Slider(chams.Settings, 48, "Transparency", 35, 0, 100, 1, function(v)
        self.ChamsTransparency = v / 100; ctx.Touch()
    end)

    local lighting = stack:Add("Lighting", 252)
    self.LightingControl = ctx.Window:Toggle(lighting.Settings, UDim2.fromOffset(10, 4), 190, "Enabled", false, function(v)
        self.Lighting = v; self:UpdateLighting(); ctx.Touch()
    end)
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
    ctx.Janitor:Add(ctx.RunService.RenderStepped:Connect(function() self:Step() end))
    return self
end

function Visuals:Bundle(player)
    local bundle = self.Bundles[player]
    if bundle then return bundle end
    bundle = {
        Box = newDrawing("Square"),
        HealthBack = newDrawing("Square"),
        HealthFill = newDrawing("Square"),
        Tag = newDrawing("Text"),
    }
    if bundle.Box then bundle.Box.Filled = false; bundle.Box.Thickness = 1.5 end
    if bundle.HealthBack then bundle.HealthBack.Filled = true; bundle.HealthBack.Color = Color3.fromRGB(20, 20, 20) end
    if bundle.HealthFill then bundle.HealthFill.Filled = true end
    if bundle.Tag then bundle.Tag.Center = true; bundle.Tag.Outline = true; bundle.Tag.Size = 14; bundle.Tag.Font = 2 end
    self.Bundles[player] = bundle
    return bundle
end

function Visuals:Remove(player)
    local bundle = self.Bundles[player]
    if not bundle then return end
    removeDrawing(bundle.Box); removeDrawing(bundle.HealthBack); removeDrawing(bundle.HealthFill); removeDrawing(bundle.Tag)
    if bundle.Highlight then bundle.Highlight:Destroy() end
    self.Bundles[player] = nil
end

function Visuals:Hide(bundle)
    for _, name in ipairs({"Box", "HealthBack", "HealthFill", "Tag"}) do
        if bundle[name] then bundle[name].Visible = false end
    end
    if bundle.Highlight then bundle.Highlight.Enabled = false end
end

function Visuals:Bounds(character, camera)
    local cf, size = character:GetBoundingBox()
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local visible = false
    for x = -1, 1, 2 do
        for y = -1, 1, 2 do
            for z = -1, 1, 2 do
                local point = cf:PointToWorldSpace(Vector3.new(size.X * x, size.Y * y, size.Z * z) / 2)
                local screen, onScreen = camera:WorldToViewportPoint(point)
                if screen.Z > 0 then
                    visible = visible or onScreen
                    minX, minY = math.min(minX, screen.X), math.min(minY, screen.Y)
                    maxX, maxY = math.max(maxX, screen.X), math.max(maxY, screen.Y)
                end
            end
        end
    end
    if not visible then return nil end
    return minX, minY, maxX, maxY
end

function Visuals:TagText(player, distance)
    local parts = {}
    if self.ShowDisplay then table.insert(parts, player.DisplayName) end
    if self.ShowReal and (not self.ShowDisplay or player.DisplayName ~= player.Name) then table.insert(parts, "@" .. player.Name) end
    if self.ShowDistance then table.insert(parts, tostring(math.floor(distance + 0.5)) .. "m") end
    return table.concat(parts, "  ")
end

function Visuals:Step()
    local camera = workspace.CurrentCamera
    local localRoot = self.ctx.LocalPlayer.Character and self.ctx.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not camera then return end
    for _, player in ipairs(self.ctx.Players:GetPlayers()) do
        if player ~= self.ctx.LocalPlayer then
            local bundle = self:Bundle(player)
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local bounds = character and humanoid and humanoid.Health > 0 and table.pack(self:Bounds(character, camera)) or nil
            if not bounds or bounds.n == 0 or not bounds[1] then
                self:Hide(bundle)
            else
                local minX, minY, maxX, maxY = bounds[1], bounds[2], bounds[3], bounds[4]
                local color = self.ctx.Friends:IsFriend(player) and GREEN or WHITE
                if bundle.Box then
                    bundle.Box.Visible = self.ESP
                    bundle.Box.Position = Vector2.new(minX, minY)
                    bundle.Box.Size = Vector2.new(maxX - minX, maxY - minY)
                    bundle.Box.Color = color
                end
                local healthRatio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
                if bundle.HealthBack and bundle.HealthFill then
                    bundle.HealthBack.Visible, bundle.HealthFill.Visible = self.Health, self.Health
                    bundle.HealthBack.Position = Vector2.new(minX - 7, minY)
                    bundle.HealthBack.Size = Vector2.new(4, maxY - minY)
                    local height = (maxY - minY) * healthRatio
                    bundle.HealthFill.Position = Vector2.new(minX - 6, maxY - height + 1)
                    bundle.HealthFill.Size = Vector2.new(2, math.max(0, height - 2))
                    bundle.HealthFill.Color = Color3.fromRGB(255 * (1 - healthRatio), 255 * healthRatio, 40)
                end
                if bundle.Tag then
                    local distance = localRoot and root and (localRoot.Position - root.Position).Magnitude or 0
                    local text = self:TagText(player, distance)
                    bundle.Tag.Visible = self.NameTags and text ~= ""
                    bundle.Tag.Position = Vector2.new((minX + maxX) / 2, minY - 22)
                    bundle.Tag.Text, bundle.Tag.Color = text, color
                end
                if not bundle.Highlight or bundle.Highlight.Parent ~= character then
                    if bundle.Highlight then bundle.Highlight:Destroy() end
                    local highlight = Instance.new("Highlight")
                    highlight.Name = "BezNigativaChams"
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.OutlineTransparency = 1
                    highlight.Parent = character
                    bundle.Highlight = highlight
                end
                bundle.Highlight.Enabled = self.Chams
                bundle.Highlight.FillColor = color
                bundle.Highlight.FillTransparency = self.ChamsTransparency
            end
        end
    end
end

function Visuals:UpdateLighting()
    self.Effect.Enabled = self.Lighting
    self.Effect.TintColor = Color3.fromRGB(self.LightR, self.LightG, self.LightB)
    self.Effect.Brightness = self.LightStrength / 100
end

function Visuals:GetConfig()
    return {
        esp = self.ESP, health = self.Health, nameTags = self.NameTags,
        showDisplay = self.ShowDisplay, showReal = self.ShowReal, showDistance = self.ShowDistance,
        chams = self.Chams, chamsTransparency = self.ChamsTransparency,
        lighting = self.Lighting, lightR = self.LightR, lightG = self.LightG,
        lightB = self.LightB, lightStrength = self.LightStrength,
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
    self.BControl.Set(self.LightB); self.StrengthControl.Set(self.LightStrength)
    self:UpdateLighting()
end

function Visuals:Destroy()
    for player in pairs(self.Bundles) do self:Remove(player) end
end

return Visuals
