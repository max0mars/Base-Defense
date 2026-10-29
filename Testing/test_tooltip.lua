-- Testing/test_tooltip.lua
local EffectManager = require("Game.Effects.EffectManager")

local failures = 0
local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

-- Mock energy turret
local mockEnergyTurret = {
    types = { turret = true, energy = true },
    isType = function(self, t) return self.types[t] == true end
}
local emEnergy = EffectManager:new(mockEnergyTurret, nil)
mockEnergyTurret.effectManager = emEnergy

-- Mock physical turret
local mockPhysicalTurret = {
    types = { turret = true, physical = true },
    isType = function(self, t) return self.types[t] == true end
}
local emPhysical = EffectManager:new(mockPhysicalTurret, nil)
mockPhysicalTurret.effectManager = emPhysical

-- Industrial Battery Buff
local buff = {
    name = "Industrial Battery Power",
    statModifiers = { damage = { mult = 0.20 } },
    targetTypes = { energy = true }
}

emEnergy:applyEffect(buff)
emPhysical:applyEffect(buff)

local energyStrings = emEnergy:getTooltipStrings()
local physicalStrings = emPhysical:getTooltipStrings()

local energyHasDmg = false
for _, s in ipairs(energyStrings) do
    if s:find("Damage") then
        energyHasDmg = true
    end
end

local physicalHasDmg = false
for _, s in ipairs(physicalStrings) do
    if s:find("Damage") then
        physicalHasDmg = true
    end
end

assert(energyHasDmg == true, "Energy turret tooltip shows Damage buff")
assert(physicalHasDmg == false, "Physical turret tooltip DOES NOT show Damage buff")

os.exit(failures == 0 and 0 or 1)
