local Bullet = require("Bullets.Bullet")
local ToxicEffect = require("Game.Effects.StatusEffects.Toxic")

local ToxicShard = setmetatable({}, Bullet)
ToxicShard.__index = ToxicShard

function ToxicShard:new(config)
    config = config or {}
    config.name = "Toxic Shard"
    config.bulletSpeed = config.bulletSpeed or 350
    config.damage = config.damage or 5
    config.pierce = config.pierce or 1
    config.lifespan = config.lifespan or 0.25 -- Very short lifespan
    config.w = config.w or 8
    config.h = config.h or 3
    config.shape = "rectangle"
    config.color = {0.7, 0.2, 0.9, 1}
    config.damageType = "toxic"
    
    -- Add the Toxic effect as a hit effect so the base Bullet:onHit handles it
    config.hitEffects = { ToxicEffect:new() }
    config.hitbox = true
    config.types = { bullet = true }
    
    local obj = Bullet:new(config)
    setmetatable(obj, self)
    return obj
end

-- Override draw for a shard-like look
function ToxicShard:draw()
    local r, g, b = unpack(self.color)
    local angle = self.angle
    
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(angle)
    
    -- Neon purple shard
    love.graphics.setColor(r, g, b, 0.3)
    love.graphics.rectangle("fill", -self.w/2 - 2, -self.h/2 - 2, self.w + 4, self.h + 4)
    
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("fill", -self.w/2, -self.h/2, self.w, self.h)
    
    -- Bright tip
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", self.w/2 - 2, -self.h/2, 2, self.h)
    
    love.graphics.pop()
end

return ToxicShard
