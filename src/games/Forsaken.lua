local Forsaken = {}
Forsaken.__index = Forsaken

local KILLER_RED = Color3.fromRGB(255, 45, 45)
local GENERATOR_YELLOW = Color3.fromRGB(255, 210, 55)
local GENERATOR_GREEN = Color3.fromRGB(55, 225, 110)
local ITEM_HEAL = Color3.fromRGB(70, 235, 120)
local ITEM_SPEED = Color3.fromRGB(55, 190, 255)
local ITEM_FOOD = Color3.fromRGB(255, 155, 55)
local ITEM_SPECIAL = Color3.fromRGB(190, 105, 255)
local ITEM_FAKE = Color3.fromRGB(255, 70, 110)

local ITEM_COLORS = {
    medkit = ITEM_HEAL,
    fakemedkit = ITEM_FAKE,
    bloxycola = ITEM_SPEED,
    bloxycolaitem = ITEM_SPEED,
    bloxycolatest = ITEM_SPEED,
    bloxiade = ITEM_SPEED,
    cola = ITEM_SPEED,
    fakebloxycola = ITEM_FAKE,
    pizza = ITEM_FOOD,
    pizza2 = ITEM_FOOD,
    pizzaslice = ITEM_FOOD,
    epicsauce = ITEM_FOOD,
    flashlight = ITEM_SPECIAL,
    glock = ITEM_SPECIAL,
    glock19 = ITEM_SPECIAL,
    assaultrifle = ITEM_SPECIAL,
    broadsword = ITEM_SPECIAL,
    gravitygun = ITEM_SPECIAL,
    greenkey = ITEM_SPECIAL,
}

local function normalizedName(instance)
    return string.lower(instance.Name):gsub("[^%w]", "")
end

function Forsaken.new(ctx)
    local self = setmetatable({
        ctx = ctx,
        KillerESP = false,
        GeneratorESP = false,
        ItemESP = false,
        Elapsed = 0,
    }, Forsaken)
    local RoleChams = ctx.LoadModule("games/RoleChams")
    self.KillerChams = RoleChams.new("BezNigativaForsakenKiller")
    self.GeneratorChams = RoleChams.new("BezNigativaForsakenGenerator")
    self.ItemChams = RoleChams.new("BezNigativaForsakenItem")

    local page = ctx.Window:AddPage("Forsaken", "Функции только для текущей игры")
    local stack = ctx.Window:ModuleStack(page, 70)
    local killer = stack:Add("Killer Chams", 126)
    self.KillerESPControl = ctx.Window:Toggle(killer.Settings, UDim2.fromOffset(10, 4), 220, "Красный маньяк", false, function(value)
        self.KillerESP = value
        if not value then self.KillerChams:Clear() end
        self:RefreshHeartbeat()
        ctx.Touch()
    end)
    self:AddHint(killer.Settings, "Работает только когда вы находитесь в Survivors.")

    local generators = stack:Add("Подсветка генераторов", 126)
    self.GeneratorESPControl = ctx.Window:Toggle(generators.Settings, UDim2.fromOffset(10, 4), 260, "Генераторы", false, function(value)
        self.GeneratorESP = value
        if not value then self.GeneratorChams:Clear() end
        self:RefreshHeartbeat()
        ctx.Touch()
    end)
    self:AddHint(generators.Settings, "Жёлтый — не завершён; зелёный — завершён.")

    local items = stack:Add("Подсветка предметов", 126)
    self.ItemESPControl = ctx.Window:Toggle(items.Settings, UDim2.fromOffset(10, 4), 260, "Предметы на земле", false, function(value)
        self.ItemESP = value
        if not value then self.ItemChams:Clear() end
        self:RefreshHeartbeat()
        ctx.Touch()
    end)
    self:AddHint(items.Settings, "Аптечки, Bloxy Cola, пицца и редкие предметы.")

    ctx.Janitor:Add(function()
        if self.HeartbeatLoop then self.HeartbeatLoop:Disconnect(); self.HeartbeatLoop = nil end
    end)
    return self
end

function Forsaken:AddHint(parent, text)
    local hint = Instance.new("TextLabel")
    hint.Position = UDim2.fromOffset(10, 48)
    hint.Size = UDim2.new(1, -20, 0, 38)
    hint.BackgroundTransparency = 1
    hint.Font = Enum.Font.Code
    hint.Text = text
    hint.TextWrapped = true
    hint.TextColor3 = Color3.fromRGB(165, 165, 165)
    hint.TextSize = 12
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.Parent = parent
end

function Forsaken:RefreshHeartbeat()
    local active = self.KillerESP or self.GeneratorESP or self.ItemESP
    if active and not self.HeartbeatLoop then
        self.HeartbeatLoop = self.ctx.RunService.Heartbeat:Connect(function(delta)
            self.Elapsed += delta
            if self.Elapsed < 0.15 then return end
            self.Elapsed = 0
            local ok, message = pcall(function() self:Scan() end)
            if not ok and not self.Warned then self.Warned = true; warn("[BezNigativa/Forsaken] " .. tostring(message)) end
        end)
    elseif not active and self.HeartbeatLoop then
        self.HeartbeatLoop:Disconnect()
        self.HeartbeatLoop = nil
    end
end

function Forsaken:RoleFolders()
    local container = self.ctx.Workspace:FindFirstChild("Players")
    return container and container:FindFirstChild("Survivors"), container and container:FindFirstChild("Killers")
end

function Forsaken:IsLocalSurvivor(folder)
    if not folder then return false end
    local character = self.ctx.LocalPlayer.Character
    if character and character:IsDescendantOf(folder) then return true end
    for _, model in ipairs(folder:GetDescendants()) do
        if model:IsA("Model") and (model == character or model.Name == self.ctx.LocalPlayer.Name or model:GetAttribute("UserId") == self.ctx.LocalPlayer.UserId) then
            return true
        end
    end
    return false
end

function Forsaken:ScanKillers()
    local survivors, killers = self:RoleFolders()
    if not self:IsLocalSurvivor(survivors) or not killers then self.KillerChams:Clear(); return end
    local seen = {}
    for _, model in ipairs(killers:GetDescendants()) do
        if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
            self.KillerChams:Show(model, KILLER_RED, seen)
        end
    end
    self.KillerChams:Finish(seen)
end

function Forsaken:GeneratorMap()
    local map = self.ctx.Workspace:FindFirstChild("Map")
    local ingame = map and map:FindFirstChild("Ingame")
    return ingame and ingame:FindFirstChild("Map")
end

function Forsaken:IngameFolder()
    local map = self.ctx.Workspace:FindFirstChild("Map")
    return map and map:FindFirstChild("Ingame")
end

function Forsaken:IsGenerator(instance)
    return instance:IsA("Model") and string.lower(instance.Name) == "generator"
end

function Forsaken:GeneratorProgress(generator)
    local progress = generator:GetAttribute("Progress") or generator:GetAttribute("RepairProgress")
    if progress == nil then
        local value = generator:FindFirstChild("Progress") or generator:FindFirstChild("RepairProgress")
        if value and value:IsA("ValueBase") then progress = value.Value end
    end
    return tonumber(progress)
end

function Forsaken:ScanGenerators()
    local seen = {}
    local map = self:GeneratorMap()
    if map then
        for _, instance in ipairs(map:GetDescendants()) do
            if self:IsGenerator(instance) then
                local progress = self:GeneratorProgress(instance)
                local completed = instance:GetAttribute("Completed") == true
                    or instance:GetAttribute("Finished") == true
                    or progress ~= nil and progress >= 100
                self.GeneratorChams:Show(instance, completed and GENERATOR_GREEN or GENERATOR_YELLOW, seen)
            end
        end
    end
    self.GeneratorChams:Finish(seen)
end

function Forsaken:HasItemAncestor(instance, ingame)
    local parent = instance.Parent
    while parent and parent ~= ingame do
        if ITEM_COLORS[normalizedName(parent)] then return true end
        parent = parent.Parent
    end
    return false
end

function Forsaken:ItemAdornee(instance)
    if instance:IsA("Model") or instance:IsA("BasePart") then return instance end
    local itemRoot = instance:FindFirstChild("ItemRoot", true)
    if itemRoot and itemRoot:IsA("BasePart") then return itemRoot end
    local handle = instance:FindFirstChild("Handle", true)
    if handle and handle:IsA("BasePart") then return handle end
    return instance:FindFirstChildWhichIsA("Model", true)
        or instance:FindFirstChildWhichIsA("BasePart", true)
end

function Forsaken:ScanItems()
    local seen = {}
    local ingame = self:IngameFolder()
    if ingame then
        local function inspect(instance)
            local color = ITEM_COLORS[normalizedName(instance)]
            if color and not self:HasItemAncestor(instance, ingame) then
                local adornee = self:ItemAdornee(instance)
                if adornee then self.ItemChams:Show(adornee, color, seen) end
            end
        end
        for _, child in ipairs(ingame:GetChildren()) do
            -- The level geometry lives in Ingame.Map, while pickups are its
            -- siblings. Skipping the level keeps this frequent scan cheap.
            if child.Name ~= "Map" then
                inspect(child)
                for _, instance in ipairs(child:GetDescendants()) do inspect(instance) end
            end
        end
    end
    self.ItemChams:Finish(seen)
end

function Forsaken:Scan()
    if self.KillerESP then self:ScanKillers() end
    if self.GeneratorESP then self:ScanGenerators() end
    if self.ItemESP then self:ScanItems() end
end

function Forsaken:GetConfig()
    return {
        killerESP = self.KillerESP,
        generatorESP = self.GeneratorESP,
        itemESP = self.ItemESP,
    }
end

function Forsaken:ApplyConfig(data)
    if type(data) ~= "table" then return end
    -- `enabled` keeps configs made before the Forsaken page gained
    -- independent ESP switches working.
    self.KillerESP = data.killerESP == true or data.killerESP == nil and data.enabled == true
    self.GeneratorESP = data.generatorESP == true
    self.ItemESP = data.itemESP == true
    self.KillerESPControl.Set(self.KillerESP)
    self.GeneratorESPControl.Set(self.GeneratorESP)
    self.ItemESPControl.Set(self.ItemESP)
    if not self.KillerESP then self.KillerChams:Clear() end
    if not self.GeneratorESP then self.GeneratorChams:Clear() end
    if not self.ItemESP then self.ItemChams:Clear() end
    self:RefreshHeartbeat()
end

function Forsaken:Destroy()
    self.KillerESP, self.GeneratorESP, self.ItemESP = false, false, false
    self:RefreshHeartbeat()
    self.KillerChams:Clear()
    self.GeneratorChams:Clear()
    self.ItemChams:Clear()
end

return Forsaken
