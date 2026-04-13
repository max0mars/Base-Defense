-- ParticleExplosion.lua
-- A generic particle explosion effect for deaths, impacts, and transitions.

local ParticleExplosion = {}
ParticleExplosion.__index = ParticleExplosion

function ParticleExplosion:new(color, size, x, y, lifetime, numParticles)
    local obj = setmetatable({}, self)
    
    obj.color = color or {1, 1, 1}
    obj.x = x
    obj.y = y
    obj.size = size or 25
    obj.maxLifetime = lifetime or 0.6
    obj.lifetime = obj.maxLifetime
    obj.destroyed = false
    
    obj.shards = {}
    local n = numParticles or love.math.random(8, 12)
    
    for i = 1, n do
        local shard = {
            offX = love.math.random(-obj.size/4, obj.size/4),
            offY = love.math.random(-obj.size/4, obj.size/4),
            velX = love.math.random(-6*obj.size, 6*obj.size),
            velY = love.math.random(-6*obj.size, 6*obj.size),
            angle = love.math.random() * math.pi * 2,
            rotSpeed = love.math.random(-10, 10),
            size = (0.1 + love.math.random() * 0.2) * obj.size
        }
        table.insert(obj.shards, shard)
    end
    
    return obj
end

function ParticleExplosion:update(dt)
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then
        self.destroyed = true
        return
    end
    
    for _, shard in ipairs(self.shards) do
        shard.offX = shard.offX + shard.velX * dt
        shard.offY = shard.offY + shard.velY * dt
        shard.angle = shard.angle + shard.rotSpeed * dt
    end
end

function ParticleExplosion:draw()
    local alpha = self.lifetime / self.maxLifetime
    local r, g, b = unpack(self.color)
    
    love.graphics.setColor(r, g, b, alpha)
    love.graphics.setLineWidth(1)
    
    for _, shard in ipairs(self.shards) do
        love.graphics.push()
        love.graphics.translate(self.x + shard.offX, self.y + shard.offY)
        love.graphics.rotate(shard.angle)
        love.graphics.rectangle("line", -shard.size/2, -shard.size/2, shard.size, shard.size)
        love.graphics.pop()
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

return ParticleExplosion
