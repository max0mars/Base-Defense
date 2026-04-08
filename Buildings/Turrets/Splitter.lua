local Turret = require("Buildings.Turrets.Turret")
local Split = require("Game.Effects.IndependantEffects.split")
local Utils = require("Classes.Utils")

local Splitter = setmetatable({}, { __index = Turret })
Splitter.__index = Splitter

-- Source of Truth: All stats for the splitter turret and its fragmenting bullets
Splitter.template = {
    name = "Splitter Turret",
    rotation = 0,
    turnSpeed = 10,
    fireRate = 0.5,
    range = 500,
    barrel = 20,
    firingArc = { direction = 0, minRange = 0, angle = math.pi/10 },
    shapePattern = {{0,0}},
    color = {0, 0, 1, 1},
    types = { turret = true },
    
    -- Properties passed to fragments via effect
    spread = 0.1,
    splitamount = 5,
    splitDamage = 25,
    
    -- Bullet Stats
    bulletStats = {
        name = "Splitter Bullet",
        speed = 400,
        damage = 10,
        pierce = 1,
        lifespan = 3,
        w = 6, h = 6, shape = "rectangle",
        hitEffects = {
             -- Note: Split is an independent effect, its trigger accesses turret properties
        }
    }
}

function Splitter:new(config)
    local baseConfig = Utils.deepCopy(Splitter.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    baseConfig.bulletSpeed = baseConfig.bulletStats.speed
    baseConfig.damage = baseConfig.bulletStats.damage
    baseConfig.hitEffects = { Split:new{} }
    
    local instance = Turret:new(baseConfig)
    setmetatable(instance, Splitter)
    return instance
end

function Splitter:fire(args)
    -- Inject split properties correctly into the bullet args 
    -- so they work with getStat in the Split effect trigger
    args = args or {}
    args.spread = self:getStat("spread")
    args.splitamount = self:getStat("splitamount")
    args.splitDamage = self:getStat("splitDamage")
    Turret.fire(self, args)
end

return Splitter