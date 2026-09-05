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
    medkititem = ITEM_HEAL,
    medkitpickup = ITEM_HEAL,
    droppedmedkit = ITEM_HEAL,
    fakemedkit = ITEM_FAKE,
    fakemedkititem = ITEM_FAKE,
    bloxycola = ITEM_SPEED,
    bloxycolaitem = ITEM_SPEED,
    bloxycolatest = ITEM_SPEED,
    bloxycolapickup = ITEM_SPEED,
    droppedbloxycola = ITEM_SPEED,
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

local function normalizedText(value)
    return string.lower(tostring(value)):gsub("[^%w]", "")
end

function Forsaken.new(ctx)
    local self = setmetatable({
        ctx = ctx,
        KillerESP = false,
        GeneratorESP = false,
        ItemESP = false,
        InfiniteStamina = false,
        AutoGenerator = false,
        RepairDelay = 3,
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
        self.NextItemScanAt = nil
        if value then self:ScanItems(true) else self.ItemChams:Clear() end
        self:RefreshHeartbeat()
        ctx.Touch()
    end)
    self:AddHint(items.Settings, "Аптечки, Bloxy Cola, пицца и редкие предметы.")

    local stamina = stack:Add("Infinite Stamina", 126)
    self.InfiniteStaminaControl = ctx.Window:Toggle(stamina.Settings, UDim2.fromOffset(10, 4), 260, "Бесконечная стамина", false, function(value)
        self.InfiniteStamina = value
        if value then self:ApplyInfiniteStamina() else self:RestoreStamina() end
        self:RefreshHeartbeat()
        ctx.Touch()
    end)
    self:AddHint(stamina.Settings, "Стамина не расходуется во время спринта.")

    local autoGenerator = stack:Add("Auto Generator", 166)
    self.AutoGeneratorControl = ctx.Window:Toggle(autoGenerator.Settings, UDim2.fromOffset(10, 4), 260, "Автопочинка", false, function(value)
        self.AutoGenerator = value
        self:ResetAutoGenerator()
        self:RefreshHeartbeat()
        ctx.Touch()
    end)
    self.RepairDelayControl = ctx.Window:Slider(autoGenerator.Settings, 48, "Задержка (сек)", self.RepairDelay, 0.5, 10, 0.5, function(value)
        self.RepairDelay = value
        self:ResetAutoGenerator()
        ctx.Touch()
    end)
    self:AddHint(autoGenerator.Settings, "Подойдите к генератору: меньшая задержка чинит быстрее.", 88)

    ctx.Janitor:Add(function()
        if self.HeartbeatLoop then self.HeartbeatLoop:Disconnect(); self.HeartbeatLoop = nil end
    end)
    return self
end

function Forsaken:AddHint(parent, text, y)
    local hint = Instance.new("TextLabel")
    hint.Position = UDim2.fromOffset(10, y or 48)
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
    local active = self.KillerESP or self.GeneratorESP or self.ItemESP or self.InfiniteStamina or self.AutoGenerator
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

function Forsaken:GeneratorPart(generator)
    if generator.PrimaryPart then return generator.PrimaryPart end
    local main = generator:FindFirstChild("Main", true)
    if main and main:IsA("BasePart") then return main end
    return generator:FindFirstChildWhichIsA("BasePart", true)
end

function Forsaken:FindRepairGenerator()
    local survivors = self:RoleFolders()
    if not self:IsLocalSurvivor(survivors) then return nil end

    local map = self:GeneratorMap()
    local character = self.ctx.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not map or not root then return nil end

    local closest, closestDistance
    for _, generator in ipairs(map:GetChildren()) do
        if self:IsGenerator(generator) then
            local progress = self:GeneratorProgress(generator)
            local completed = generator:GetAttribute("Completed") == true
                or generator:GetAttribute("Finished") == true
                or progress ~= nil and progress >= 100
            local part = not completed and self:GeneratorPart(generator)
            if part then
                local distance = (root.Position - part.Position).Magnitude
                if distance <= 18 and (not closestDistance or distance < closestDistance) then
                    closest, closestDistance = generator, distance
                end
            end
        end
    end
    return closest
end

function Forsaken:ResetAutoGenerator()
    self.RepairGenerator = nil
    self.NextRepairAt = nil
end

function Forsaken:TryAutoGenerator()
    local generator = self:FindRepairGenerator()
    if generator ~= self.RepairGenerator then
        self.RepairGenerator = generator
        self.NextRepairAt = generator and os.clock() + self.RepairDelay or nil
        return
    end
    if not generator or os.clock() < (self.NextRepairAt or math.huge) then return end

    local remotes = generator:FindFirstChild("Remotes")
    local remote = remotes and remotes:FindFirstChild("RE")
    if not remote or not remote:IsA("RemoteEvent") then
        self:ResetAutoGenerator()
        return
    end

    remote:FireServer()
    self.NextRepairAt = os.clock() + self.RepairDelay
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

function Forsaken:ItemColor(instance)
    local color = ITEM_COLORS[normalizedName(instance)]
    if color then return color end
    for _, attribute in ipairs({"ItemName", "ItemType", "DisplayName"}) do
        local value = instance:GetAttribute(attribute)
        color = value ~= nil and ITEM_COLORS[normalizedText(value)] or nil
        if color then return color end
    end
    return nil
end

function Forsaken:HasItemAncestor(instance)
    local parent = instance.Parent
    while parent and parent ~= self.ctx.Workspace do
        if self:ItemColor(parent) then return true end
        parent = parent.Parent
    end
    return false
end


function Forsaken:IsGroundItem(instance)
    if not instance:IsDescendantOf(self.ctx.Workspace) then return false end
    local parent = instance.Parent
    while parent and parent ~= self.ctx.Workspace do
        if parent:IsA("Model") and parent:FindFirstChildOfClass("Humanoid") then return false end
        parent = parent.Parent
    end
    return true
end

function Forsaken:ItemAdornee(instance)
    -- Highlight the whole Tool/Model. ItemRoot is often an invisible pickup
    -- hitbox, so using it alone can produce no visible chams.
    if instance:IsA("Tool") or instance:IsA("Model") or instance:IsA("BasePart") then return instance end
    local handle = instance:FindFirstChild("Handle", true)
    if handle and handle:IsA("BasePart") then return handle end
    return instance:FindFirstChildWhichIsA("Model", true)
        or instance:FindFirstChildWhichIsA("BasePart", true)
end

function Forsaken:ScanItems(force)
    local now = os.clock()
    if not force and self.NextItemScanAt and now < self.NextItemScanAt then return end
    self.NextItemScanAt = now + 0.5

    local seen = {}
    for _, instance in ipairs(self.ctx.Workspace:GetDescendants()) do
        local color = self:ItemColor(instance)
        if color and self:IsGroundItem(instance) and not self:HasItemAncestor(instance) then
            local adornee = self:ItemAdornee(instance)
            if adornee then self.ItemChams:Show(adornee, color, seen) end
        end
    end
    self.ItemChams:Finish(seen)
end

function Forsaken:GetSprintingModule()
    local systems = self.ctx.ReplicatedStorage:FindFirstChild("Systems")
    local character = systems and systems:FindFirstChild("Character")
    local gameFolder = character and character:FindFirstChild("Game")
    local scriptModule = gameFolder and gameFolder:FindFirstChild("Sprinting")
    if not scriptModule or not scriptModule:IsA("ModuleScript") then return nil end
    if self.SprintingScript == scriptModule and self.SprintingModule then return self.SprintingModule end

    if self.SprintingModule then self:RestoreStamina() end
    self.SprintingScript, self.SprintingModule = scriptModule, nil
    local ok, module = pcall(require, scriptModule)
    if ok and type(module) == "table" then self.SprintingModule = module end
    return self.SprintingModule
end

function Forsaken:FireStaminaChanged(module)
    local event = module and (module.__staminaChangedEvent or module.StaminaChanged)
    if event then pcall(function() event:Fire(module.Stamina) end) end
end

function Forsaken:ApplyInfiniteStamina()
    if not self.InfiniteStamina then return end
    local module = self:GetSprintingModule()
    if not module then return end
    if not self.OriginalStamina or self.OriginalStamina.module ~= module then
        self.OriginalStamina = {
            module = module,
            lossDisabled = module.StaminaLossDisabled,
        }
    end
    local changed = module.StaminaLossDisabled ~= true
    module.StaminaLossDisabled = true
    if type(module.MaxStamina) == "number" and module.Stamina ~= module.MaxStamina then
        module.Stamina = module.MaxStamina
        changed = true
    end
    if changed then self:FireStaminaChanged(module) end
end

function Forsaken:RestoreStamina()
    local original = self.OriginalStamina
    if not original then return end
    original.module.StaminaLossDisabled = original.lossDisabled
    self:FireStaminaChanged(original.module)
    self.OriginalStamina = nil
end

function Forsaken:Scan()
    if self.InfiniteStamina then self:ApplyInfiniteStamina() end
    if self.AutoGenerator then self:TryAutoGenerator() end
    if self.KillerESP then self:ScanKillers() end
    if self.GeneratorESP then self:ScanGenerators() end
    if self.ItemESP then self:ScanItems() end
end

function Forsaken:GetConfig()
    return {
        killerESP = self.KillerESP,
        generatorESP = self.GeneratorESP,
        itemESP = self.ItemESP,
        infiniteStamina = self.InfiniteStamina,
        autoGenerator = self.AutoGenerator,
        repairDelay = self.RepairDelay,
    }
end

function Forsaken:ApplyConfig(data)
    if type(data) ~= "table" then return end
    -- `enabled` keeps configs made before the Forsaken page gained
    -- independent ESP switches working.
    self.KillerESP = data.killerESP == true or data.killerESP == nil and data.enabled == true
    self.GeneratorESP = data.generatorESP == true
    self.ItemESP = data.itemESP == true
    self.InfiniteStamina = data.infiniteStamina == true
    self.AutoGenerator = data.autoGenerator == true
    self.RepairDelay = math.clamp(tonumber(data.repairDelay) or self.RepairDelay, 0.5, 10)
    self.KillerESPControl.Set(self.KillerESP)
    self.GeneratorESPControl.Set(self.GeneratorESP)
    self.ItemESPControl.Set(self.ItemESP)
    self.InfiniteStaminaControl.Set(self.InfiniteStamina)
    self.AutoGeneratorControl.Set(self.AutoGenerator)
    self.RepairDelayControl.Set(self.RepairDelay)
    if not self.KillerESP then self.KillerChams:Clear() end
    if not self.GeneratorESP then self.GeneratorChams:Clear() end
    self.NextItemScanAt = nil
    if self.ItemESP then self:ScanItems(true) else self.ItemChams:Clear() end
    if self.InfiniteStamina then self:ApplyInfiniteStamina() else self:RestoreStamina() end
    self:ResetAutoGenerator()
    self:RefreshHeartbeat()
end

function Forsaken:Destroy()
    self.KillerESP, self.GeneratorESP, self.ItemESP, self.InfiniteStamina, self.AutoGenerator = false, false, false, false, false
    self:ResetAutoGenerator()
    self.NextItemScanAt = nil
    self:RestoreStamina()
    self:RefreshHeartbeat()
    self.KillerChams:Clear()
    self.GeneratorChams:Clear()
    self.ItemChams:Clear()
end

return Forsaken
