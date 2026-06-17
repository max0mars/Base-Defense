-- Testing/test_target_types.lua
-- Standalone script to verify the targetTypes effect filtering logic

package.path = package.path .. ";./?.lua"

local EffectManager = require("Game.Effects.EffectManager")

print("--- Starting targetTypes System Tests ---")

local failures = 0

local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

-- 1. Test local effect matching
do
    local function createMockTurret(baseDmg, types)
        local turret = {
            damage = baseDmg,
            types = types,
            isType = function(self, t) return self.types[t] == true end,
            getStat = function(self, statName, defaultVal)
                local baseValue = self[statName] or defaultVal or 0
                if self.effectManager then
                    return self.effectManager:getStat(statName, baseValue)
                end
                return baseValue
            end
        }
        return turret
    end

    local energyTurret = createMockTurret(10, { turret = true, energy = true })
    local ballisticTurret = createMockTurret(10, { turret = true, ballistic = true })
    
    local emEnergy = EffectManager:new(energyTurret, nil)
    energyTurret.effectManager = emEnergy
    
    local emBallistic = EffectManager:new(ballisticTurret, nil)
    ballisticTurret.effectManager = emBallistic
    
    -- Buff: +20% damage only for energy types
    local buff = {
        name = "energy_dmg",
        statModifiers = { damage = { mult = 0.20 } },
        targetTypes = { energy = true }
    }
    
    emEnergy:applyEffect(buff)
    emBallistic:applyEffect(buff)
    
    -- Recalculate
    emEnergy:recalculateStats()
    emBallistic:recalculateStats()
    
    local energyDmg = energyTurret:getStat("damage", energyTurret.damage)
    local ballisticDmg = ballisticTurret:getStat("damage", ballisticTurret.damage)
    
    assert(energyDmg == 12, "Energy turret successfully gained +20% damage (10 -> 12)")
    assert(ballisticDmg == 10, "Ballistic turret ignored energy damage buff (remained 10)")
end

-- 2. Test parent/global effect matching propagation
do
    -- Mock global parent manager
    local parentEM = EffectManager:new(nil, nil)
    
    local function createMockTurret(baseDmg, types)
        local turret = {
            damage = baseDmg,
            types = types,
            isType = function(self, t) return self.types[t] == true end,
            getStat = function(self, statName, defaultVal)
                local baseValue = self[statName] or defaultVal or 0
                if self.effectManager then
                    return self.effectManager:getStat(statName, baseValue)
                end
                return baseValue
            end
        }
        return turret
    end

    local energyTurret = createMockTurret(10, { turret = true, energy = true })
    local ballisticTurret = createMockTurret(10, { turret = true, ballistic = true })
    
    local emEnergy = EffectManager:new(energyTurret, nil)
    emEnergy.parent = parentEM
    energyTurret.effectManager = emEnergy
    
    local emBallistic = EffectManager:new(ballisticTurret, nil)
    emBallistic.parent = parentEM
    ballisticTurret.effectManager = emBallistic
    
    -- Apply global buff to the parent manager
    local globalBuff = {
        name = "global_energy_dmg",
        statModifiers = { damage = { mult = 0.50 } },
        targetTypes = { energy = true }
    }
    parentEM:applyEffect(globalBuff)
    
    -- Recalculate child stats
    emEnergy:recalculateStats()
    emBallistic:recalculateStats()
    
    local energyDmg = energyTurret:getStat("damage", energyTurret.damage)
    local ballisticDmg = ballisticTurret:getStat("damage", ballisticTurret.damage)
    
    assert(energyDmg == 15, "Energy turret inherited +50% global damage (10 -> 15)")
    assert(ballisticDmg == 10, "Ballistic turret ignored global energy damage buff (remained 10)")
end

print("--- targetTypes System Tests Completed with " .. failures .. " failures ---")
os.exit(failures == 0 and 0 or 1)
