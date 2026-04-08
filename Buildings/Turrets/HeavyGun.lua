local Turret = require("Buildings.Turrets.Turret")
local Utils = require("Classes.Utils")

local HeavyGun = setmetatable({}, { __index = Turret })
HeavyGun.__index = HeavyGun

HeavyGun.template = {
    name = "Heavy Gun",
    rotation = 0,
    turnSpeed = 3,
    fireRate = 0.5,
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
    
    -- Bullet Properties
    bulletName = "Heavy Shell",
    bulletSpeed = 500,
    damage = 65,
    damageType = "normal",
    pierce = 3,
    lifespan = 4,
    bulletW = 8, 
    bulletH = 8, 
    bulletShape = "rectangle",
    hitEffects = {}
}

function HeavyGun:new(config)
    local baseConfig = Utils.deepCopy(HeavyGun.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    return t
end

return HeavyGun
