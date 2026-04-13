local Turret = require("Buildings.Turrets.Turret")
local Utils = require("Classes.Utils")
local LobberBullet = require("Bullets.LobberBullet")

local Lobber = setmetatable({}, { __index = Turret })
Lobber.__index = Lobber

-- Source of Truth: All stats in a single flat table
Lobber.template = {
    name = "Lobber",
    size = 15,
    rotation = 0,
    turnSpeed = math.huge,
    fireRate = 1,
    range = 500,
    barrel = 15,
    color = {1, 1, 1, 1},
    types = { turret = true, lobber = true },
    shapePattern = {{0,0}},
    firingArc = {
        direction = 0,
        minRange = 200,
        angle = math.pi/3
    },
    
    -- Bullet properties (now flat)
    bulletName = "Lobber Bullet",
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

function Lobber:new(config)
    local baseConfig = Utils.deepCopy(Lobber.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    baseConfig.bulletType = LobberBullet
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    return t
end

return Lobber
