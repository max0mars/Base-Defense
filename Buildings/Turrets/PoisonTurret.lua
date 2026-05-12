local Turret = require("Buildings.Turrets.Turret")
local PoisonEffect = require("Game.Effects.StatusEffects.Poison")
local Utils = require("Classes.Utils")

local PoisonTurret = setmetatable({}, { __index = Turret })
PoisonTurret.__index = PoisonTurret

-- Source of Truth: Flat table
PoisonTurret.template = {
    name = "Poison Turret",
    rotation = 0,
    turnSpeed = 5,
    fireRate = 0.5,
    range = 400,
    barrel = 15,
    firingArc = { direction = 0, minRange = 0, angle = math.pi/4 },
    shapePattern = {{0,0}},
    color = {0.5, 1, 0.5, 1},
    types = { turret = true, poison = true },
    
    -- Bullet Properties
    bulletName = "Poison Dart",
    bulletSpeed = 500,
    damageType = "poison",
    damage = 5,
    pierce = 1,
    lifespan = 2,
    bulletW = 4, 
    bulletH = 4, 
    bulletShape = "rectangle",
    
    -- Values for effect initialization (can be overridden by inherent buff or external buffs)
    duration_poison = 4,
    dps_poison = 15,
    maxStacks = 5,
}

function PoisonTurret:new(config)
    local baseConfig = Utils.deepCopy(PoisonTurret.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    -- Initialize hit effects from the config values
    local poisonEffectConfig = Utils.deepCopy(baseConfig)
    poisonEffectConfig.name = "poison"
    baseConfig.hitEffects = {PoisonEffect:new(poisonEffectConfig)}
    
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    
    -- Add inherent stats via a hidden buff to follow the new unified buff system
    t.effectManager:applyEffect({
        name = "Inherent Poison",
        statModifiers = {
            dps_poison = {max = 10, hidden = true},
            duration_poison = {max = 4, hidden = true},
            maxStacks = {max = 5, hidden = true}
        }
    })
    
    return t
end

return PoisonTurret
