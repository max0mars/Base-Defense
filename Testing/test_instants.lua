-- test_instants.lua
-- Standalone script to verify the InstantCard logic

local InstantCardRegistry = require("Instants.InstantCardRegistry")
local InstantCard = require("Instants.instant")

print("--- Starting Instant Cards Tests ---")

-- Mock Base
_G.Base = {
    hp = 100,
    maxHp = 200
}

-- Mock GameManager
_G.GameManager = {
    playerEffectManager = {
        applyEffect = function(self, buff)
            _G.GlobalBuffs = _G.GlobalBuffs or {}
            table.insert(_G.GlobalBuffs, buff)
        end
    },
    registerActiveGlobalBuff = function(self, buff)
        -- mock
    end
}

local failures = 0

local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

-- 1. Test Registry Loading
assert(InstantCardRegistry.Overclock ~= nil, "Overclock card loaded")
assert(InstantCardRegistry.EmergencyRepairs ~= nil, "EmergencyRepairs card loaded")

-- 2. Test Execution Type validation
assert(InstantCardRegistry.Overclock.executionType == InstantCard.ExecutionType.Targeted, "Overclock is Targeted")
assert(InstantCardRegistry.Frenzy.executionType == InstantCard.ExecutionType.Global, "Frenzy is Global")

-- 3. Test isValidTarget
local overclock = InstantCardRegistry.Overclock
local validTurret = { 
    isType = function(self, t) return t == "turret" end,
    effectManager = {
        applyEffect = function(self, buff)
            self.parent.buffs = self.parent.buffs or {}
            table.insert(self.parent.buffs, buff)
        end
    }
}
validTurret.effectManager.parent = validTurret

local invalidTarget = { isType = function(self, t) return false end }

assert(overclock:isValidTarget(validTurret) == true, "Overclock allows valid turret target")
assert(overclock:isValidTarget(invalidTarget) == false, "Overclock rejects invalid target")
assert(overclock:isValidTarget(nil) == false, "Overclock rejects nil target")

local frenzy = InstantCardRegistry.Frenzy
assert(frenzy:isValidTarget(nil) == true, "Global Frenzy allows nil target")

-- Test Targeted execute
overclock:execute(validTurret)
assert(validTurret.buffs and validTurret.buffs[1].statModifiers.damage.mult == 0.10, "Overclock applied buff to target")

-- Test Global execute
frenzy:execute(_G.GameManager)
assert(_G.GlobalBuffs and _G.GlobalBuffs[1].statModifiers.fireRate.mult == 0.15, "Frenzy applied global buff")

-- Test custom execute
local initialHp = _G.Base.hp
InstantCardRegistry.EmergencyRepairs:execute(nil)
assert(_G.Base.hp == initialHp + 10, "Emergency Repairs healed the base")

print("--- Instant Cards Tests Completed with " .. failures .. " failures ---")
