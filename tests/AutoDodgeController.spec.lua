local AutoDodgeController = require("../src/games/AutoDodgeController")

local passed = 0

local function expectEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function test(name, callback)
    local ok, message = pcall(callback)
    if not ok then error("[FAIL] " .. name .. "\n" .. tostring(message), 0) end
    passed += 1
    print("[PASS] " .. name)
end

local function harness()
    local clock = 0
    local queue = {}
    local state = {canHit = true, canDodge = true, dodges = 0, dodgeTimes = {}}

    local function delay(seconds, callback)
        table.insert(queue, {at = clock + math.max(0, seconds), callback = callback})
    end

    local function advance(target)
        while true do
            table.sort(queue, function(a, b) return a.at < b.at end)
            local nextItem = queue[1]
            if not nextItem or nextItem.at > target then break end
            table.remove(queue, 1)
            clock = nextItem.at
            nextItem.callback()
        end
        clock = target
    end

    local controller = AutoDodgeController.new({
        Settings = {LatencyCompensation = 0.045, DodgeStartupTime = 0, Debug = false},
        Now = function() return clock end,
        Delay = delay,
        CanHit = function()
            return state.canHit, state.canHit and nil or "out of range"
        end,
        CanDodge = function()
            return state.canDodge, state.canDodge and nil or "dodge cooldown"
        end,
        Dodge = function()
            state.dodges += 1
            table.insert(state.dodgeTimes, clock)
            return true
        end,
    })
    controller:SetEnabled(true)
    return controller, state, advance
end

test("1 - ordinary M1", function()
    local controller, state, advance = harness()
    controller:Start("enemy", 101, "M1", 0, 1)
    controller:Commit("enemy", 101, "M1", 1)
    advance(1)
    expectEqual(state.dodges, 1, "M1 must dodge once")
    if state.dodgeTimes[1] >= 1 then error("M1 dodge must execute before ImpactTime") end
end)

test("2 - ordinary M2", function()
    local controller, state, advance = harness()
    controller:Start("enemy", 201, "M2", 0, 1)
    controller:Commit("enemy", 201, "M2", 1)
    advance(1)
    expectEqual(state.dodges, 1, "M2 must dodge once")
end)

test("3 - M1 to M2 invalidates old attack", function()
    local controller, state, advance = harness()
    controller:Start("enemy", 301, "M1", 0, 0.8)
    controller:Commit("enemy", 301, "M1", 0.8)
    controller:Cancel("enemy", 301, "switched")
    controller:Start("enemy", 302, "M2", 0.1, 1)
    controller:Commit("enemy", 302, "M2", 1)
    advance(1)
    expectEqual(state.dodges, 1, "only replacement M2 may dodge")
    expectEqual(controller.Handled[301], nil, "cancelled M1 must stay unhandled")
    expectEqual(controller.Handled[302], true, "replacement M2 must be handled")
end)

test("4 - M2 to M1 invalidates old attack", function()
    local controller, state, advance = harness()
    controller:Start("enemy", 401, "M2", 0, 0.8)
    controller:Commit("enemy", 401, "M2", 0.8)
    controller:Cancel("enemy", 401, "switched")
    controller:Start("enemy", 402, "M1", 0.1, 1)
    controller:Commit("enemy", 402, "M1", 1)
    advance(1)
    expectEqual(state.dodges, 1, "only replacement M1 may dodge")
    expectEqual(controller.Handled[401], nil, "cancelled M2 must stay unhandled")
    expectEqual(controller.Handled[402], true, "replacement M1 must be handled")
end)

test("5 - attack outside hitbox", function()
    local controller, state, advance = harness()
    state.canHit = false
    controller:Start("enemy", 501, "M1", 0, 1)
    controller:Commit("enemy", 501, "M1", 1)
    advance(1)
    expectEqual(state.dodges, 0, "out-of-hitbox attack must not dodge")
end)

test("6 - cancellation immediately before callback", function()
    local controller, state, advance = harness()
    controller:Start("enemy", 601, "M1", 0, 1)
    controller:Commit("enemy", 601, "M1", 1)
    advance(0.95)
    controller:Cancel("enemy", 601, "late cancel")
    advance(1)
    expectEqual(state.dodges, 0, "cancelled scheduled attack must not dodge")
end)

test("7 - dodge unavailable", function()
    local controller, state, advance = harness()
    state.canDodge = false
    controller:Start("enemy", 701, "M2", 0, 1)
    controller:Commit("enemy", 701, "M2", 1)
    advance(1)
    expectEqual(state.dodges, 0, "unavailable dodge must not be attempted")
end)

test("8 - repeated state updates", function()
    local controller, state, advance = harness()
    controller:Start("enemy", 801, "M1", 0, 1)
    controller:Start("enemy", 801, "M1", 0, 1)
    controller:Commit("enemy", 801, "M1", 1)
    controller:Commit("enemy", 801, "M1", 1)
    advance(1)
    expectEqual(state.dodges, 1, "one AttackId may produce at most one dodge")
end)

print("AutoDodgeController: " .. tostring(passed) .. "/8 acceptance tests passed")
