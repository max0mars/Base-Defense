local Turret = require("Buildings.Turrets.Turret")
local HitscanBullet = require("Bullets.HitscanBullet")
local Utils = require("Classes.Utils")

local Sniper = setmetatable({}, { __index = Turret })
Sniper.__index = Sniper

-- Source of Truth: All stats for the sniper turret and its railgun shot
Sniper.template = {
    name = "Sniper Turret",
    rotation = 0,
    turnSpeed = 2,
    fireRate = 0.5,
    range = 1000,
    barrel = 25,
    firingArc = { direction = 0, minRange = 0, angle = math.pi/32 },
    shapePattern = {{0,0}},
    color = {0.8, 0.2, 0.2, 1},
    types = { turret = true, sniper = true },
    
    -- Bullet Stats (Hitscan)
    bulletStats = {
        name = "Railgun Shot",
        speed = 0, -- Hitscan doesn't use speed for travel
        damage = 100,
        pierce = 5,
        lifespan = 0.3,
        w = 1, h = 1, shape = "rectangle", -- For hitbox/visual if any
        range = 1000,
        hitEffects = {}
    }
}

function Sniper:new(config)
    -- Injected stats from template
    local baseConfig = Utils.deepCopy(Sniper.template)
    
    -- Merge overrides
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    -- Map bullet stats
    baseConfig.bulletSpeed = baseConfig.bulletStats.speed
    baseConfig.damage = baseConfig.bulletStats.damage
    baseConfig.range = baseConfig.bulletStats.range or baseConfig.range
    baseConfig.bulletType = HitscanBullet
    
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    return t
end

return Sniper
