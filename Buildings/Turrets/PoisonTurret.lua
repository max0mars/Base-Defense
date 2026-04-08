local Turret = require("Buildings.Turrets.Turret")
local PoisonEffect = require("Game.Effects.StatusEffects.Poison")
local Utils = require("Classes.Utils")

local PoisonTurret = setmetatable({}, { __index = Turret })
PoisonTurret.__index = PoisonTurret

-- Source of Truth: All stats for the turret, its bullets, and its effects
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
    
    -- Bullet Stats
    bulletStats = {
        name = "Poison Dart",
        speed = 500,
        damage = 5,
        pierce = 1,
        lifespan = 2,
        w = 4, h = 4, 
        shape = "rectangle",
        -- Effects applied by this bullet
        effects = {
            {
                name = "poison",
                duration = 4,
                dps = 15,
                maxStacks = 10
            }
        }
    }
}

function PoisonTurret:new(config)
    -- Injected stats from template
    local baseConfig = Utils.deepCopy(PoisonTurret.template)
    
    -- Merge with instance-specific config overrides
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    -- Map nested bullet stats to Turret expected properties
    baseConfig.bulletSpeed = baseConfig.bulletStats.speed
    baseConfig.damage = baseConfig.bulletStats.damage
    
    -- Initialize hit effects from template
    baseConfig.hitEffects = {}
    for _, effectConfig in ipairs(baseConfig.bulletStats.effects) do
        table.insert(baseConfig.hitEffects, PoisonEffect:new(effectConfig))
    end
    
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    return t
end

return PoisonTurret
