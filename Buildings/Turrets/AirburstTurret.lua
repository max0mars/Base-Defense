local Turret = require("Buildings.Turrets.Turret")
local AirburstBullet = require("Bullets.AirburstBullet")
local Utils = require("Classes.Utils")

local AirburstTurret = setmetatable({}, { __index = Turret })
AirburstTurret.__index = AirburstTurret

AirburstTurret.template = {
    name = "Airburst Turret",
    rotation = 0,
    turnSpeed = 10,
    fireRate = 0.8,
    range = 550,
    barrel = 22,
    firingArc = { direction = 0, minRange = 0, angle = math.pi/8 },
    shapePattern = {{0,0}},
    color = {1, 0.4, 0.2, 1}, -- Neon orange
    types = { turret = true },
    
    -- Visual Design
    baseShape = "square",
    barrelShape = "thick", -- Mortar-tube look
    
    -- Bullet Properties
    bulletType = AirburstBullet,
    bulletName = "Airburst Shell",
    bulletSpeed = 350,
    damage = 10,
    damageType = "normal",
    pierce = 1,
    lifespan = 3,
    bulletW = 8, 
    bulletH = 8, 
    bulletShape = "rectangle"
}

function AirburstTurret:new(config)
    local baseConfig = Utils.deepCopy(AirburstTurret.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    local instance = Turret:new(baseConfig)
    setmetatable(instance, { __index = self })
    
    return instance
end

return AirburstTurret
