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

-- Bright filled sparks with a white-hot core, so the glow pass picks them up.
-- They stay bright for most of their life and fade out at the end.
function ParticleExplosion:draw()
    local life = self.lifetime / self.maxLifetime
    local alpha = math.min(1, life * 2.5)
    local r, g, b = unpack(self.color)
    local hr, hg, hb = r + (1 - r) * 0.6, g + (1 - g) * 0.6, b + (1 - b) * 0.6

    for _, shard in ipairs(self.shards) do
        local size = math.max(2, shard.size) * (0.5 + 0.5 * life)
        love.graphics.push()
        love.graphics.translate(self.x + shard.offX, self.y + shard.offY)
        love.graphics.rotate(shard.angle)
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.rectangle("fill", -size / 2, -size / 2, size, size)
        love.graphics.setColor(hr, hg, hb, alpha)
        love.graphics.rectangle("fill", -size / 4, -size / 4, size / 2, size / 2)
        love.graphics.pop()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return ParticleExplosion
