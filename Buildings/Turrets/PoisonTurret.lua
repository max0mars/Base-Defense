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
    
    -- Placeholder values for effect initialization (overridden by inherent buff)
    duration_poison = 0,
    dps_poison = 0,
    maxStacks = 0,
}

function PoisonTurret:new(config)
    local baseConfig = Utils.deepCopy(PoisonTurret.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    -- Initialize hit effects from the config values
    baseConfig.hitEffects = {PoisonEffect:new(baseConfig)}
    
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    
    -- Add inherent stats via a hidden buff to follow the new unified buff system
    t.effectManager:applyEffect({
        name = "Inherent Poison",
        statModifiers = {
            dps_poison = {max = 15, hidden = true},
            duration_poison = {max = 4, hidden = true},
            maxStacks = {max = math.huge, hidden = true}
        }
    })
    
    return t
end

return PoisonTurret
