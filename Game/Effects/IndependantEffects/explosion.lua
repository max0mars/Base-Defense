local object = require("Classes.object")

local Explosion = setmetatable({}, object)
Explosion.__index = Explosion

function Explosion:new(config)
    if not config then
        error("Developer Error: Explosion effect called with nil config.")
    end

    -- explosionDamage and radius are expected in trigger, but for instances 
    -- they are passed into the config here.
    config.effectManager = true -- Required for stat propagation
    local instance = setmetatable(object:new(config), Explosion)
    
    instance.isIndependent = true
    instance.name = config.name or "Explosion"
    instance.color = config.color or {1, 0.5, 0, 1} -- Default orange/fire
    
    -- Visual & Damage Falloff Config
    instance.maxLifetime = config.maxLifetime or 0.4
    instance.lifetime = instance.maxLifetime
    instance.minDamagePercent = config.minDamagePercent or 0.25
    
    return instance
end

function Explosion:trigger(target, source)
    if AUDIO then AUDIO:playSFX("explosion_02") end
    
    -- Link our EffectManager to the source (Bullet) to inherit its stats temporarily
    -- This allows us to calculate the final radius/damage based on turret buffs.
    if source and source.effectManager then
        self.effectManager.parent = source.effectManager
    end

    -- Calculate final damage and radius using the dynamic stat system
    local radius = self.effectManager:getStat("radius", source:getStat("radius"))
    local damage = self.effectManager:getStat("explosionDamage", source:getStat("explosionDamage"))
    
    -- Check for percentage-based scaling from the source bullet
    local explosionMult = source:getStat("explosion_from_damage")
    if explosionMult > 0 then
        damage = source:getStat("damage") * explosionMult
    end

    if radius <= 0 or damage <= 0 then return end

    -- Create a fresh instance for the visual animation and damage event
    local event = Explosion:new({
        game = source.game,
        x = source.x,
        y = source.y,
        radius = radius,
        explosionDamage = damage,
        color = self.color,
        minDamagePercent = 0.25,
        maxLifetime = 0.4
    })
    
    -- Apply damage logic immediately
    event:applyDamage(source)
    
    -- Add to animations table for visual feedback
    table.insert(source.game.animations, event)
    
    -- Unlink to avoid potential reference leaks
    self.effectManager.parent = nil
end

function Explosion:applyDamage(source)
    if self.radius <= 0 then return end
    local r2 = self.radius * self.radius
    local game = self.game
    
    for _, obj in ipairs(game.objects) do
        if obj:isType("enemy") and not obj.destroyed then
            -- Find distance to enemy (considering their size for accuracy)
            local halfW = (obj.w or 0) / 2
            local halfH = (obj.h or 0) / 2
            local closestX = math.max(obj.x - halfW, math.min(self.x, obj.x + halfW))
            local closestY = math.max(obj.y - halfH, math.min(self.y, obj.y + halfH))
            
            local dx = self.x - closestX
            local dy = self.y - closestY
            local distSq = dx*dx + dy*dy
            
            if distSq <= r2 then
                local distance = math.sqrt(distSq)
                
                -- Calculate Damage Falloff
                -- 1.0 at center, scaling down linearly to 0.0 at radius
                local falloff = 1 - (distance / self.radius)
                -- Clamp to minimum threshold
                falloff = math.max(self.minDamagePercent or 0.25, falloff)
                
                local finalDamage = self.explosionDamage * falloff
                obj:takeDamage(finalDamage, "explosive")

                -- Apply auxiliary hit effects (Poison, Burn, etc.)
                if source.hitEffects then
                    for _, effect in ipairs(source.hitEffects) do
                        if not effect.isIndependent and obj.effectManager then
                            obj.effectManager:applyEffect(effect, source)
                        end
                    end
                end
            end
        end
    end
end

function Explosion:update(dt)
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then
        self.destroyed = true
    end
end

function Explosion:draw()
    local alpha = math.max(0, self.lifetime / self.maxLifetime)
    local r, g, b = unpack(self.color or {1, 0.5, 0})
    
    -- 1. Outer Falloff Area (Fading ring)
    love.graphics.setColor(r, g, b, alpha * 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", self.x, self.y, self.radius)
    
    -- Subtle soft fill
    love.graphics.setColor(r, g, b, alpha * 0.1)
    love.graphics.circle("fill", self.x, self.y, self.radius)
    
    -- 2. Bright Core (Max Damage Zone - 20% of radius)
    love.graphics.setColor(r, g, b, alpha * 0.8)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", self.x, self.y, self.radius * 0.2)
    
    -- White-hot center
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.circle("fill", self.x, self.y, self.radius * 0.1)
    
    -- Reset graphics state
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return Explosion
