local AutoDodgeController = {}
AutoDodgeController.__index = AutoDodgeController

local TERMINAL = {Cancelled = true, Recovery = true}

local function validAttackType(value)
    return value == "M1" or value == "M2"
end

function AutoDodgeController.new(options)
    assert(type(options) == "table", "AutoDodgeController options are required")
    assert(type(options.Now) == "function", "AutoDodgeController requires Now")
    assert(type(options.Delay) == "function", "AutoDodgeController requires Delay")
    assert(type(options.CanHit) == "function", "AutoDodgeController requires CanHit")
    assert(type(options.CanDodge) == "function", "AutoDodgeController requires CanDodge")
    assert(type(options.Dodge) == "function", "AutoDodgeController requires Dodge")
    return setmetatable({
        Options = options,
        Settings = options.Settings or {},
        Current = {},
        Handled = {},
        HandledOrder = {},
        Scheduled = {},
        Enabled = false,
        Generation = 0,
    }, AutoDodgeController)
end

function AutoDodgeController:Log(message)
    if self.Settings.Debug and self.Options.Log then self.Options.Log("[AutoDodge] " .. message) end
end

function AutoDodgeController:IdText(attackId)
    return tostring(attackId)
end

function AutoDodgeController:SetEnabled(value)
    self.Enabled = value == true
    if self.Enabled then return end
    self.Generation += 1
    for _, attack in pairs(self.Current) do
        if not TERMINAL[attack.State] then attack.State = "Cancelled" end
    end
    self.Current, self.Scheduled, self.Handled, self.HandledOrder = {}, {}, {}, {}
end

function AutoDodgeController:GetCurrent(attacker)
    return self.Current[attacker]
end

function AutoDodgeController:Start(attacker, attackId, attackType, startTime, impactTime, hitboxData)
    if not self.Enabled or attacker == nil or attackId == nil then return nil end
    if attackType ~= nil and not validAttackType(attackType) then return nil end
    local old = self.Current[attacker]
    if old and old.AttackId == attackId then
        if attackType then old.AttackType = attackType end
        if impactTime then old.ImpactTime = impactTime end
        if hitboxData then old.HitboxData = hitboxData end
        return old
    end
    if old and not TERMINAL[old.State] then
        local oldType = old.AttackType
        self:Cancel(attacker, old.AttackId, "replaced")
        if oldType and attackType and oldType ~= attackType then
            self:Log(oldType .. " -> " .. attackType .. " detected")
        end
    end
    local attack = {
        AttackId = attackId,
        Attacker = attacker,
        AttackType = attackType,
        State = "Started",
        StartTime = startTime or self.Options.Now(),
        ImpactTime = impactTime,
        HitboxData = hitboxData,
        Revision = 0,
    }
    self.Current[attacker] = attack
    self:Log((attackType or "Attack") .. " started | AttackId " .. self:IdText(attackId))
    return attack
end

function AutoDodgeController:Cancel(attacker, attackId, reason)
    local attack = self.Current[attacker]
    if not attack or (attackId ~= nil and attack.AttackId ~= attackId) then return false end
    attack.State = "Cancelled"
    attack.Revision += 1
    self.Scheduled[attack.AttackId] = nil
    self.Current[attacker] = nil
    self:Log("Attack " .. self:IdText(attack.AttackId) .. " cancelled" .. (reason and " | " .. reason or ""))
    return true
end

function AutoDodgeController:Commit(attacker, attackId, attackType, impactTime, hitboxData)
    local attack = self.Current[attacker]
    if not attack or attack.AttackId ~= attackId then
        self:Log("Ignore " .. self:IdText(attackId) .. " | stale AttackId")
        return false
    end
    if attackType ~= nil then
        if not validAttackType(attackType) then return false end
        attack.AttackType = attackType
    end
    if not validAttackType(attack.AttackType) or type(impactTime or attack.ImpactTime) ~= "number" then return false end
    attack.ImpactTime = impactTime or attack.ImpactTime
    if hitboxData then attack.HitboxData = hitboxData end
    attack.State = "Committed"
    attack.Revision += 1
    self:Log(attack.AttackType .. " committed | AttackId " .. self:IdText(attackId))
    self:Schedule(attack)
    return true
end

function AutoDodgeController:Active(attacker, attackId)
    local attack = self.Current[attacker]
    if not attack or attack.AttackId ~= attackId or attack.State ~= "Committed" then return false end
    attack.State = "Active"
    return true
end

function AutoDodgeController:Finish(attacker, attackId)
    local attack = self.Current[attacker]
    if not attack or attack.AttackId ~= attackId then return false end
    attack.State = "Recovery"
    attack.Revision += 1
    self.Scheduled[attackId] = nil
    self.Current[attacker] = nil
    return true
end

function AutoDodgeController:MarkHandled(attackId)
    if self.Handled[attackId] then return end
    self.Handled[attackId] = true
    table.insert(self.HandledOrder, attackId)
    if #self.HandledOrder > 256 then
        local expired = table.remove(self.HandledOrder, 1)
        self.Handled[expired] = nil
    end
end

function AutoDodgeController:Schedule(attack)
    if self.Handled[attack.AttackId] then return end
    local revision = attack.Revision
    local generation = self.Generation
    local scheduledImpactTime = attack.ImpactTime
    self.Scheduled[attack.AttackId] = revision
    local lead = tonumber(self.Settings.LatencyCompensation) or 0.045
    local startup = tonumber(self.Settings.DodgeStartupTime) or 0
    local executeAt = attack.ImpactTime - lead - startup
    local remaining = attack.ImpactTime - self.Options.Now()
    self:Log("Impact in " .. tostring(math.max(0, math.floor(remaining * 1000 + 0.5))) .. " ms")
    self:Log("Dodge scheduled | AttackId " .. self:IdText(attack.AttackId))

    local function execute()
        if not self.Enabled or self.Generation ~= generation then return end
        local current = self.Current[attack.Attacker]
        if not current or current.AttackId ~= attack.AttackId then
            self:Log("Ignore " .. self:IdText(attack.AttackId) .. " | stale AttackId")
            return
        end
        if self.Scheduled[attack.AttackId] ~= revision or current.Revision ~= revision then
            self:Log("Ignore " .. self:IdText(attack.AttackId) .. " | stale schedule")
            return
        end
        if current.ImpactTime ~= scheduledImpactTime then
            self:Log("Ignore " .. self:IdText(attack.AttackId) .. " | stale ImpactTime")
            return
        end
        if current.State ~= "Committed" and current.State ~= "Active" then
            self:Log("Ignore " .. self:IdText(attack.AttackId) .. " | " .. string.lower(current.State))
            return
        end
        local now = self.Options.Now()
        if now + 0.002 < executeAt then
            self.Options.Delay(executeAt - now, execute)
            return
        end
        if self.Handled[attack.AttackId] then return end
        local canHit, hitReason = self.Options.CanHit(current)
        if not canHit then
            self.Scheduled[attack.AttackId] = nil
            self:Log("Ignore " .. self:IdText(attack.AttackId) .. " | " .. (hitReason or "out of range"))
            return
        end
        local canDodge, dodgeReason = self.Options.CanDodge(current)
        if not canDodge then
            self.Scheduled[attack.AttackId] = nil
            self:Log("Ignore " .. self:IdText(attack.AttackId) .. " | " .. (dodgeReason or "dodge unavailable"))
            return
        end
        local ok, result = pcall(self.Options.Dodge, current)
        if not ok or result == false then
            self.Scheduled[attack.AttackId] = nil
            self:Log("Ignore " .. self:IdText(attack.AttackId) .. " | dodge failed")
            return
        end
        self:MarkHandled(attack.AttackId)
        self.Scheduled[attack.AttackId] = nil
        self:Log("Dodge request sent | AttackId " .. self:IdText(attack.AttackId))
    end

    self.Options.Delay(math.max(0, executeAt - self.Options.Now()), execute)
end

return AutoDodgeController
