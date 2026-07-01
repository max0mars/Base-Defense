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
    end,
    objects = {},
    base = _G.Base
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
assert(InstantCardRegistry.Frenzy.executionType == InstantCard.ExecutionType.Group, "Frenzy is Group")

-- 3. Test isValidTarget
local overclock = InstantCardRegistry.Overclock
local validTurret = { 
    isType = function(self, t) return t == "turret" end,
    effectManager = {
        applyEffect = function(self, buff)
            self.parent.buffs = self.parent.buffs or {}
            table.insert(self.parent.buffs, buff)
        end,
        recalculateStats = function() end
    }
}
validTurret.effectManager.parent = validTurret

local invalidTarget = { isType = function(self, t) return false end }

assert(overclock:isValidTarget(validTurret) == true, "Overclock allows valid turret target")
assert(overclock:isValidTarget(invalidTarget) == false, "Overclock rejects invalid target")
assert(overclock:isValidTarget(nil) == false, "Overclock rejects nil target")

local frenzy = InstantCardRegistry.Frenzy
assert(frenzy:isValidTarget(nil) == true, "Group Frenzy allows nil target")

-- Test Targeted execute
overclock:execute(validTurret)
assert(validTurret.buffs and validTurret.buffs[1].statModifiers.damage.mult == 0.25, "Overclock applied buff to target")

-- Test Group execute
_G.GameManager.objects = { validTurret }
frenzy:execute(_G.GameManager)
assert(validTurret.buffs and validTurret.buffs[2].statModifiers.fireRate.mult == 0.2, "Frenzy applied group buff to active turret")

-- Test Global execute (affects playerEffectManager)
local mockGlobal = InstantCard.new({
    id = "mock_global",
    executionType = InstantCard.ExecutionType.Global,
    statModifiers = { damage = { mult = 0.50 } }
})
mockGlobal:execute(_G.GameManager)
assert(_G.GlobalBuffs and _G.GlobalBuffs[1].statModifiers.damage.mult == 0.50, "Global card applied buff to playerEffectManager")

-- Test Group execute with targetTypes filtering (e.g. Energy Surge)
local energySurge = InstantCard.new({
    id = "inst_energy_surge_1",
    executionType = InstantCard.ExecutionType.Group,
    statModifiers = { damage = { mult = 0.20 } },
    targetTypes = { energy = true }
})
local energyTurret = {
    isType = function(self, t) return t == "turret" or t == "energy" end,
    effectManager = {
        applyEffect = function(self, buff)
            self.parent.buffs = self.parent.buffs or {}
            table.insert(self.parent.buffs, buff)
        end,
        recalculateStats = function() end
    }
}
energyTurret.effectManager.parent = energyTurret

local ballisticTurret = {
    isType = function(self, t) return t == "turret" or t == "ballistic" end,
    effectManager = {
        applyEffect = function(self, buff)
            self.parent.buffs = self.parent.buffs or {}
            table.insert(self.parent.buffs, buff)
        end,
        recalculateStats = function() end
    }
}
ballisticTurret.effectManager.parent = ballisticTurret

_G.GameManager.objects = { energyTurret, ballisticTurret }
energySurge:execute(_G.GameManager)

assert(energyTurret.buffs and #energyTurret.buffs == 1 and energyTurret.buffs[1].statModifiers.damage.mult == 0.20, "Energy Surge successfully applied to energy turret")
assert(ballisticTurret.buffs == nil or #ballisticTurret.buffs == 0, "Energy Surge ignored ballistic turret")

-- Test custom execute
local initialHp = _G.Base.hp
InstantCardRegistry.EmergencyRepairs:execute(_G.GameManager)
assert(_G.Base.hp == initialHp + 15, "Emergency Repairs healed the base")

-- Test Instant Injection into RewardIndex
local RewardIndex = require("Game.Rewards.RewardIndex")
local prevCount = 0
for rarityKey, _ in pairs(RewardIndex) do
    if type(RewardIndex[rarityKey]) == "table" then
        prevCount = prevCount + #RewardIndex[rarityKey]
    end
end

RewardIndex.injectInstants(InstantCardRegistry)

-- Verify that instants are present in RewardIndex under their lowercased rarities
for key, inst in pairs(InstantCardRegistry) do
    local rarityKey = inst.rarity:lower()
    local found = false
    for _, item in ipairs(RewardIndex[rarityKey] or {}) do
        if item.id == inst.id then
            found = true
            assert(item.type == "instant", "Injected instant " .. inst.id .. " has type='instant'")
            assert(item.name == inst.name, "Injected instant name matches")
            break
        end
    end
    assert(found, "Instant " .. inst.id .. " should be dynamically injected into RewardIndex")
end

-- Injecting again should not create duplicates
local prevCount2 = 0
for rarityKey, _ in pairs(RewardIndex) do
    if type(RewardIndex[rarityKey]) == "table" then
        prevCount2 = prevCount2 + #RewardIndex[rarityKey]
    end
end

RewardIndex.injectInstants(InstantCardRegistry)

local postCount = 0
for rarityKey, _ in pairs(RewardIndex) do
    if type(RewardIndex[rarityKey]) == "table" then
        postCount = postCount + #RewardIndex[rarityKey]
    end
end
assert(prevCount2 == postCount, "Re-injecting instants should not create duplicate entries")

print("--- Instant Cards Tests Completed with " .. failures .. " failures ---")
os.exit(failures == 0 and 0 or 1)
