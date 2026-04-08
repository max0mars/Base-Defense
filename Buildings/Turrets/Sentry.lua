local Turret = require("Buildings.Turrets.Turret")
local Utils = require("Classes.Utils")

local Sentry = setmetatable({}, { __index = Turret })
Sentry.__index = Sentry

-- Source of Truth: All stats in a single flat table
Sentry.template = {
    name = "Sentry",
    size = 15,
    rotation = 0,
    turnSpeed = math.huge,
    fireRate = 1,
    range = 500,
    barrel = 15,
    color = {1, 1, 1, 1},
    types = { turret = true, sentry = true },
    shapePattern = {{0,0}},
    firingArc = {
        direction = 0,
        minRange = 0,
        angle = math.pi/6
    },
    
    -- Bullet properties (now flat)
    bulletName = "Sentry Bullet",
    bulletSpeed = 400,
    damageType = "normal",
    damage = 15, 
    pierce = 1,
    lifespan = 3,
    bulletW = 4,
    bulletH = 4,
    bulletShape = "rectangle",
    hitEffects = {}
}

function Sentry:new(config)
    local baseConfig = Utils.deepCopy(Sentry.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    return t
end

return Sentry
