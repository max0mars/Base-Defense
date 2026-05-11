local Turret = require("Buildings.Turrets.Turret")
local Utils = require("Classes.Utils")

local AutoCannon = setmetatable({}, { __index = Turret })
AutoCannon.__index = AutoCannon

AutoCannon.template = {
    name = "Auto Cannon",
    rotation = 0,
    turnSpeed = 10,
    fireRate = 6,
    range = 350,
    barrel = 15,
    color = {0.8, 0.8, 0.2, 1},
    baseShape = "octagon",
    barrelShape = "double",
    types = { turret = true },
    shapePattern = {{0,0}},
    firingArc = {
        direction = 0,
        minRange = 0,
        angle = math.pi/4
    },
    
    -- Bullet Properties
    bulletName = "Cannon Round",
    bulletSpeed = 500,
    damageType = "normal",
    damage = 8,
    pierce = 1,
    lifespan = 3,
    bulletW = 3, 
    bulletH = 3, 
    bulletShape = "rectangle",
    hitEffects = {}
}

function AutoCannon:new(config)
    local baseConfig = Utils.deepCopy(AutoCannon.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    return t
end

return AutoCannon
