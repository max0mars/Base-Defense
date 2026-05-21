local Turret = require("Buildings.Turrets.Turret")
local Utils = require("Classes.Utils")

local Gator = setmetatable({}, { __index = Turret })
Gator.__index = Gator

-- Source of Truth: All stats in a single flat table
Gator.template = {
    name = "GTR-55 Gator",
    size = 18,
    rotation = 0,
    turnSpeed = math.huge,
    fireRate = 0.8,
    range = 500,
    barrel = 15,
    color = {0.15, 0.5, 0.15, 1}, -- Dark Green
    types = { turret = true, gator = true },
    shapePattern = {{0,0}},
    sfx = "gunshot_02",
    firingArc = {
        direction = 0,
        minRange = 0,
        angle = math.pi/6
    },
    `
    -- Bullet properties (now flat)
    bulletName = "Gator Rounds",
    bulletSpeed = 500,
    damageType = "normal",
    damage = 40, 
    pierce = 2,
    lifespan = 3,
    bulletW = 8,
    bulletH = 8,
    bulletShape = "rectangle",
    hitEffects = {}
}

function Gator:new(config)
    local baseConfig = Utils.deepCopy(Gator.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    return t
end

function Gator:drawCustomBase(cx, cy)
    -- More robust diamond base
    love.graphics.polygon("line", cx, cy - 10, cx + 10, cy, cx, cy + 10, cx - 10, cy)
    love.graphics.rectangle("line", cx - 4, cy - 4, 8, 8)
end

function Gator:drawCustomBarrel()
    -- Thicker barrel
    love.graphics.setLineWidth(2)
    love.graphics.line(0, 0, self.barrel, 0)
    love.graphics.setLineWidth(1)
end

return Gator
