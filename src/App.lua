local App = {}
App.__index = App

function App.start(loadModule)
    local environment = getgenv and getgenv() or _G
    if type(environment.BezNigativaCleanup) == "function" then pcall(environment.BezNigativaCleanup) end

    local Janitor = loadModule("core/Janitor")
    local Config = loadModule("core/Config")
    local Window = loadModule("ui/Window")
    local self = setmetatable({Destroyed = false}, App)
    self.Janitor = Janitor.new()
    self.Services = {
        Players = game:GetService("Players"),
        RunService = game:GetService("RunService"),
        UserInputService = game:GetService("UserInputService"),
        HttpService = game:GetService("HttpService"),
        Lighting = game:GetService("Lighting"),
        CoreGui = game:GetService("CoreGui"),
    }
    local services = self.Services
    local player = services.Players.LocalPlayer
    self.Window = Window.new(player, services.CoreGui, self.Janitor)
    self.Config = Config.new(services.HttpService, self.Janitor)

    local context = {
        Window = self.Window,
        Janitor = self.Janitor,
        Players = services.Players,
        RunService = services.RunService,
        UserInputService = services.UserInputService,
        Lighting = services.Lighting,
        LocalPlayer = player,
    }
    context.Touch = function() self.Config:Touch() end
    context.Unload = function() self:Destroy(true) end

    local function emptyFeature()
        return {
            IsFriend = function() return false end,
            GetConfig = function() return {} end,
            ApplyConfig = function() end,
            Destroy = function() end,
        }
    end
    local function createFeature(moduleName, pageName)
        local loaded, class = pcall(loadModule, moduleName)
        if not loaded then
            warn("[BezNigativa/" .. pageName .. "] download error: " .. tostring(class))
            self.Window:ReportError(pageName, class)
            return emptyFeature()
        end
        local created, feature = pcall(class.new, context)
        if not created then
            warn("[BezNigativa/" .. pageName .. "] startup error: " .. tostring(feature))
            self.Window:ReportError(pageName, feature)
            return emptyFeature()
        end
        return feature
    end

    self.Friends = createFeature("features/Friends", "Friend")
    context.Friends = self.Friends
    self.Visuals = createFeature("features/Visuals", "Visuals")
    self.Movement = createFeature("features/Movement", "Movement")
    self.Combat = createFeature("features/Combat", "Combat")
    self.Other = createFeature("features/Other", "Other")

    self.Config:SetProvider(function()
        return {
            version = 7,
            friends = self.Friends:GetConfig(),
            visuals = self.Visuals:GetConfig(),
            movement = self.Movement:GetConfig(),
            combat = self.Combat:GetConfig(),
        }
    end)
    local saved = self.Config:Load()
    if type(saved) == "table" then
        self.Friends:ApplyConfig(saved.friends)
        self.Visuals:ApplyConfig(saved.visuals)
        self.Movement:ApplyConfig(saved.movement)
        self.Combat:ApplyConfig(saved.combat or saved.aimbot)
    end

    self.Window:ShowPage("Combat")
    self.Janitor:Add(services.UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.RightShift and self.Window.Gui then
            self.Window.Gui.Enabled = not self.Window.Gui.Enabled
        end
    end))
    environment.BezNigativaCleanup = function() self:Destroy(true) end
    environment.BezNigativaApp = self
    print("[BezNigativa] v7.0 modular loaded")
    return self
end

function App:Destroy(save)
    if self.Destroyed then return end
    self.Destroyed = true
    if save and self.Config then self.Config:SaveNow() end
    if self.Combat then self.Combat.Enabled = false end
    if self.Visuals then self.Visuals:Destroy() end
    if self.Movement then self.Movement:Destroy() end
    if self.Janitor then self.Janitor:Cleanup() end
    local environment = getgenv and getgenv() or _G
    if environment.BezNigativaApp == self then environment.BezNigativaApp = nil end
    environment.BezNigativaCleanup = nil
    print("[BezNigativa] unloaded; settings saved")
end

return App
