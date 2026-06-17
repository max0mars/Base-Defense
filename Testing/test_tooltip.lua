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

-- Mock ballistic turret
local mockBallisticTurret = {
    types = { turret = true, ballistic = true },
    isType = function(self, t) return self.types[t] == true end
}
local emBallistic = EffectManager:new(mockBallisticTurret, nil)
mockBallisticTurret.effectManager = emBallistic

-- Industrial Battery Buff
local buff = {
    name = "Industrial Battery Power",
    statModifiers = { damage = { mult = 0.20 } },
    targetTypes = { energy = true }
}

emEnergy:applyEffect(buff)
emBallistic:applyEffect(buff)

local energyStrings = emEnergy:getTooltipStrings()
local ballisticStrings = emBallistic:getTooltipStrings()

local energyHasDmg = false
for _, s in ipairs(energyStrings) do
    if s:find("Damage") then
        energyHasDmg = true
    end
end

local ballisticHasDmg = false
for _, s in ipairs(ballisticStrings) do
    if s:find("Damage") then
        ballisticHasDmg = true
    end
end

assert(energyHasDmg == true, "Energy turret tooltip shows Damage buff")
assert(ballisticHasDmg == false, "Ballistic turret tooltip DOES NOT show Damage buff")

os.exit(failures == 0 and 0 or 1)
