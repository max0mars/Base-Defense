local Turret = require("Buildings.Turrets.Turret")
local HitscanBullet = require("Bullets.HitscanBullet")
local Utils = require("Classes.Utils")

local Sniper = setmetatable({}, { __index = Turret })
Sniper.__index = Sniper

-- Source of Truth: Flat table
Sniper.template = {
    name = "Sniper Turret",
    rotation = 0,
    turnSpeed = 2,
    fireRate = 0.2,
    range = 1000,
    barrel = 25,
    firingArc = { direction = 0, minRange = 0, angle = math.pi/32 },
    shapePattern = {{0,0}},
    color = {0.8, 0.2, 0.2, 1},
    baseShape = "diamond",
    barrelShape = "long",
    types = { turret = true, sniper = true },
    
    -- Bullet Properties (Hitscan)
    bulletName = "Sniper Shot",
    bulletColor = {1, 1, 1},
    bulletSpeed = 0, 
    damage = 200,
    damageType = "normal",
    pierce = 1,
    lifespan = 0.3,
    maxLifespan = 0.3, -- Hitscan specific
    bulletW = 1, 
    bulletH = 1,
    bulletShape = "ray",
    hitEffects = {}
}

function Sniper:new(config)
    local baseConfig = Utils.deepCopy(Sniper.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    baseConfig.bulletType = HitscanBullet
    
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    return t
end

function Sniper:fire(args)
    args.maxLifespan = self:getStat("maxLifespan")
    args.color = self:getStat("bulletColor")
    Turret.fire(self, args)
end

return Sniper
