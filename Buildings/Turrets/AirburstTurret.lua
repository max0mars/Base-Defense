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
    barrel = 12,
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
    BurstDamage = 20,
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

function AirburstTurret:drawCustomBase(cx, cy)
    -- Hexagonal base
    local pts = {}
    for i = 0, 5 do
        local angle = i * (math.pi * 2 / 6)
        table.insert(pts, cx + math.cos(angle) * 10)
        table.insert(pts, cy + math.sin(angle) * 10)
    end
    love.graphics.polygon("line", pts)
end

function AirburstTurret:drawCustomBarrel()
    -- Wide funnel barrel
    -- Base of barrel at x=2, width 6 (y from -3 to 3)
    -- End of barrel at x=self.barrel, width 12 (y from -6 to 6)
    love.graphics.polygon("line", 2, -3, self.barrel, -6, self.barrel, 6, 2, 3)
end

return AirburstTurret
