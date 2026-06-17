local FireballVisual = {}
FireballVisual.__index = FireballVisual

function FireballVisual:new(x, y, radius, damage, game)
    local obj = setmetatable({}, self)
    obj.x = x
    obj.targetY = y
    obj.startY = y - 400
    obj.radius = radius or 60
    obj.damage = damage or 80
    obj.game = game
    obj.maxLifetime = 0.4
    obj.lifetime = obj.maxLifetime
    obj.destroyed = false
    return obj
end

function FireballVisual:update(dt)
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then
        self.destroyed = true
        self:onImpact()
    end
end

function FireballVisual:onImpact()
    local game = self.game
    if not game then return end

    -- Play sound
    if AUDIO then
        AUDIO:playSFX("explosion_02")
    end

    -- Trigger visuals
    if game.spawnParticleExplosion then
        game:spawnParticleExplosion({1, 0.3, 0, 1}, 10, self.x, self.targetY, 0.5, 30)
    end
    if game.spawnCircleFade then
        game:spawnCircleFade(self.x, self.targetY, self.radius, {1, 0.4, 0, 1}, 0.3)
    end

    -- Deal Damage to enemies in radius
    local r2 = self.radius * self.radius
    for _, obj in ipairs(game.objects) do
        if obj:isType("enemy") and not obj.destroyed then
            local dx = obj.x - self.x
            local dy = obj.y - self.targetY
            local distSq = dx*dx + dy*dy
            if distSq <= r2 then
                -- Calculate simple falloff (max damage at center, down to 50% at radius)
                local distance = math.sqrt(distSq)
                local falloff = 1 - (distance / self.radius) * 0.5
                local finalDamage = self.damage * falloff
                
                obj:takeDamage(finalDamage, "explosive")
            end
        end
    end
end

function FireballVisual:draw()
    local progress = 1 - (self.lifetime / self.maxLifetime)
    local currentY = self.startY + (self.targetY - self.startY) * progress
    
    -- Draw flame trail/tail
    love.graphics.setColor(1, 0.3, 0, 0.4)
    love.graphics.circle("fill", self.x, currentY - 15, 12)
    love.graphics.setColor(1, 0.6, 0, 0.6)
    love.graphics.circle("fill", self.x, currentY - 8, 16)
    
    -- Draw fireball core
    love.graphics.setColor(1, 0.8, 0, 1)
    love.graphics.circle("fill", self.x, currentY, 20)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", self.x, currentY, 10)
    
    love.graphics.setColor(1, 1, 1, 1)
end

return FireballVisual
