local object = require("Classes.object")

local Explosion = setmetatable({}, object)
Explosion.__index = Explosion

function Explosion:new(config)
    if not config then
        error("Developer Error: Explosion effect called with nil config.")
    end

    local required = {"explosionDamage", "radius"}
    for _, key in ipairs(required) do
        if config[key] == nil then
            error("Developer Error: Explosion is missing the '" .. key .. "' field in config.")
        end
    end

    config.effectManager = true -- Required for stat propagation
    -- Inherit from object to get getStat functionality
    local instance = setmetatable(object:new(config), Explosion)
    
    instance.isIndependent = true
    instance.name = config.name or "Explosion"
    instance.color = config.color or {1, 0.5, 0, 1} -- Default orange/fire
    
    return instance
end

function Explosion:trigger(target, source)
    -- Stat Propagation: Link our EffectManager to the source (Bullet) to inherit its stats
    if source and source.effectManager then
        self.effectManager.parent = source.effectManager
    end

    -- Retrieve position from source (Bullet, impact point, etc.)
    local x, y = source.x, source.y
    local game = source.game
    
    -- Calculate final damage and radius using the dynamic stat system
    -- We use the source's (Bullet) current stats as our base, then apply our own modifiers
    local radius = self.effectManager:getStat("radius", source:getStat("radius"))
    local damage = self.effectManager:getStat("explosionDamage", source:getStat("explosionDamage"))
    
    -- Check for percentage-based scaling from the source bullet
    local explosionMult = source:getStat("explosion_from_damage")
    if explosionMult > 0 then
        -- Scaled damage takes priority if the multiplier is set
        damage = source:getStat("damage") * explosionMult
    end
    
    -- Visual Feedback
    -- Replace particles with a neon circle that accurately represents the radius
    game:spawnCircleFade(x, y, radius, {1, 0.6, 0.2}, 0.5)
    
    -- AOE Logic: Scan for enemies within range
    local r2 = radius * radius
    for _, obj in ipairs(game.objects) do
        if obj:isType("enemy") and not obj.destroyed then
            -- Find the closest point on the enemy's rectangle to the explosion center
            -- This ensures large enemies are hit correctly by considering their dimensions
            local halfW = (obj.w or 0) / 2
            local halfH = (obj.h or 0) / 2
            
            local closestX = math.max(obj.x - halfW, math.min(x, obj.x + halfW))
            local closestY = math.max(obj.y - halfH, math.min(y, obj.y + halfH))
            
            local dx = x - closestX
            local dy = y - closestY
            
            if (dx*dx + dy*dy) <= r2 then
                -- Apply damage
                obj:takeDamage(damage, "explosive")

                -- Apply auxiliary hit effects from the bullet to everyone in the blast
                if source.hitEffects then
                    for _, effect in ipairs(source.hitEffects) do
                        -- Only propagate non-independent effects (like Poison, Slow, etc.)
                        -- to avoid recursive explosions or splitting.
                        if not effect.isIndependent and obj.effectManager then
                            obj.effectManager:applyEffect(effect, source)
                        end
                    end
                end
            end
        end
    end

    -- Unlink to avoid potential reference leaks or stale data for shared templates
    self.effectManager.parent = nil
end

return Explosion
