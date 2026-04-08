local Turret = require("Buildings.Turrets.Turret")
local Split = require("Game.Effects.IndependantEffects.split")
local Utils = require("Classes.Utils")

local Splitter = setmetatable({}, { __index = Turret })
Splitter.__index = Splitter

-- Source of Truth: Flat table
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
    
    -- Specific Splitter Stats
    spread = 0.1,
    splitamount = 5,
    splitDamage = 25,
    
    -- Bullet Properties
    bulletName = "Splitter Bullet",
    bulletSpeed = 400,
    damage = 10,
    damageType = "normal",
    pierce = 1,
    lifespan = 3,
}

function Splitter:new(config)
    local baseConfig = Utils.deepCopy(Splitter.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    -- Special effect setup
    baseConfig.hitEffects = { Split:new{} }
    
    local instance = Turret:new(baseConfig)
    setmetatable(instance, Splitter)
    return instance
end

function Splitter:fire(args)
    args = args or {}
    args.spread = self:getStat("spread")
    args.splitamount = self:getStat("splitamount")
    args.splitDamage = self:getStat("splitDamage")
    Turret.fire(self, args)
end

return Splitter