local Turret = require("Buildings.Turrets.Turret")
local Utils = require("Classes.Utils")

local HeavyGun = setmetatable({}, { __index = Turret })
HeavyGun.__index = HeavyGun

HeavyGun.template = {
    name = "Heavy Gun",
    rotation = 0,
    turnSpeed = 3,
    fireRate = 0.5,
    bulletSpeed = 500,
    damage = 65,
    range = 600,
    barrel = 20,
    color = {0.8, 0.4, 0.2, 1},
    types = { turret = true },
    shapePattern = {{0,0}},
    firingArc = {
        direction = 0,
        minRange = 0,
        angle = math.pi/8
    },
    
    -- Bullet Stats
    bulletStats = {
        name = "Heavy Shell",
        speed = 500,
        damage = 65,
        pierce = 3,
        lifespan = 4,
        w = 8, h = 8, shape = "rectangle",
        hitEffects = {}
    }
}

function HeavyGun:new(config)
    local baseConfig = Utils.deepCopy(HeavyGun.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    baseConfig.bulletSpeed = baseConfig.bulletStats.speed
    baseConfig.damage = baseConfig.bulletStats.damage
    
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    return t
end

return HeavyGun
