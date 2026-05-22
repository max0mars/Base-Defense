local Turret = require("Buildings.Turrets.Turret")
local SlushBullet = require("Bullets.SlushBullet")
local Utils = require("Classes.Utils")

local SlushCannon = setmetatable({}, { __index = Turret })
SlushCannon.__index = SlushCannon

-- Source of Truth: All stats in a single flat table
SlushCannon.template = {
    name = "Slush Cannon",
    rotation = 0,
    turnSpeed = 6,
    fireRate = 0.25,
    range = 450,
    barrel = 14,
    color = {0.8, 0.95, 1, 1}, -- Icy/watery white-blue
    baseShape = "hexagon",
    barrelShape = "thick",
    types = { turret = true, ice = true },
    shapePattern = {{0,0}},
    firingArc = {
        direction = 0,
        minRange = 0,
        angle = math.pi/6
    },
    sfx = "laser_02", -- or another suitable sound effect
    
    -- Bullet properties
    bulletName = "Slush Clump",
    bulletSpeed = 400,
    damageType = "normal",
    damage = 5,
    pierce = 1,
    lifespan = 2.0,
    bulletW = 16,
    bulletH = 16,
    bulletShape = "rectangle",
    
    -- Values for effect initialization
    duration = 4.1,
    amount = 0.5,
    maxStacks = 5,
    globalStacks = 5,
    isIndependent = false,
    
    hitEffects = {}
}

function SlushCannon:new(config)
    local baseConfig = Utils.deepCopy(SlushCannon.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    -- Initialize hit effects from the config values
    local slowEffectConfig = {
        name = "slush_slow",
        duration = baseConfig.duration,
        amount = baseConfig.amount,
        maxStacks = baseConfig.maxStacks,
        globalStacks = baseConfig.globalStacks,
        isIndependent = baseConfig.isIndependent
    }
    local SlowEffect = require("Game.Effects.StatusEffects.Slow")
    baseConfig.hitEffects = {SlowEffect:new(slowEffectConfig)}
    
    -- Override bullet type
    baseConfig.bulletType = SlushBullet
    
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    return t
end

function SlushCannon:drawCustomBase(cx, cy)
    -- Icy hexagonal base
    local pts = {}
    for i = 0, 5 do
        local angle = i * (math.pi * 2 / 6)
        table.insert(pts, cx + math.cos(angle) * 12)
        table.insert(pts, cy + math.sin(angle) * 12)
    end
    love.graphics.polygon("fill", pts)
    love.graphics.setColor(0.4, 0.7, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", pts)
    love.graphics.setLineWidth(1)
end

function SlushCannon:drawCustomBarrel()
    -- Thick frosty barrel
    love.graphics.setColor(0.7, 0.9, 1, 1)
    love.graphics.rectangle("fill", 0, -5, self.barrel, 10, 2, 2)
    love.graphics.setColor(0.3, 0.6, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 0, -5, self.barrel, 10, 2, 2)
    love.graphics.setLineWidth(1)
end

return SlushCannon
