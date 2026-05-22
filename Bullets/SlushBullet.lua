local Bullet = require("Bullets.Bullet")
local SlowEffect = require("Game.Effects.StatusEffects.Slow")
local Utils = require("Classes.Utils")

local SlushBullet = setmetatable({}, { __index = Bullet })
SlushBullet.__index = SlushBullet

function SlushBullet:new(config)
    config = config or {}
    
    -- Enforce visual constraints
    config.w = config.w or 16
    config.h = config.h or 16
    config.color = config.color or {0.6, 0.9, 1, 1} -- Light blue/icy color
    config.shape = "rectangle" -- Large chunk of slush
    
    local instance = Bullet:new(config)
    setmetatable(instance, SlushBullet)
    
    return instance
end

function SlushBullet:draw()
    -- Add some custom drawing if desired, or just use the base bullet draw
    Bullet.draw(self)
    
    -- Optional: add extra icy particle/glow aesthetic around the slush bullet
    local r, g, b, a = unpack(self.color or {0.6, 0.9, 1, 1})
    love.graphics.setColor(r, g, b, 0.5)
    love.graphics.circle("fill", self.x, self.y, self.w / 1.5)
    love.graphics.setColor(1, 1, 1, 1)
end

return SlushBullet
