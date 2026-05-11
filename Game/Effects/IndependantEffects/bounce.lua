local Bullet = require("Bullets.Bullet")
local Utils = require("Classes.Utils")

local Bounce = {}
Bounce.__index = Bounce

function Bounce:new(config)
    local instance = setmetatable({}, Bounce)
    for k, v in pairs(config or {}) do
        instance[k] = v
    end
    instance.name = instance.name or "bounce"
    instance.isIndependent = true
    return instance
end

function Bounce:trigger(target, sourceBullet)
    -- sourceBullet is the bullet instance that hit the target
    -- target is the enemy hit
    
    local bouncesLeft = sourceBullet:getStat("bouncesLeft", 0)
    if bouncesLeft <= 0 then return end
    
    local game = sourceBullet.game
    local closestEnemy = nil
    local closestDist = math.huge
    
    -- Find the closest nearby enemy (excluding the one we just hit and anyone in the hitCache)
    for _, obj in ipairs(game.objects) do
        if obj:isType("enemy") and not obj.destroyed and obj ~= target and not sourceBullet.hitCache[obj:getID()] then
            local dx = obj.x - target.x
            local dy = obj.y - target.y
            local dist = dx*dx + dy*dy -- Squared distance for performance
            
            if dist < closestDist then
                closestDist = dist
                closestEnemy = obj
            end
        end
    end
    
    if closestEnemy then
        -- Calculate angle to the next target
        local dx = closestEnemy.x - target.x
        local dy = closestEnemy.y - target.y
        local angle = math.atan2(dy, dx)
        
        -- Calculate the initial damage if this is the first bounce in the chain
        local initialDamage = sourceBullet.initialDamage or sourceBullet:getStat("damage")
        
        -- Create the bounced bullet
        local bounceConfig = {
            name = (sourceBullet.name or "Tesla") .. " Arc",
            x = target.x,
            y = target.y,
            angle = angle,
            bulletSpeed = sourceBullet:getStat("bulletSpeed"),
            initialDamage = initialDamage,
            damage = initialDamage * ((bouncesLeft - 1) / 10), -- Linear 10% decrease (100% -> 90% -> 80%...)
            bouncesLeft = bouncesLeft - 1,
            pierce = 1,
            lifespan = sourceBullet:getStat("lifespan"),
            displayLifespan = sourceBullet:getStat("displayLifespan") or 0.1,
            w = sourceBullet.w, h = sourceBullet.h,
            shape = sourceBullet.shape,
            hitbox = true,
            types = { bullet = true },
            game = game,
            source = sourceBullet.source,
            damageType = sourceBullet.damageType or "energy",
            hitCache = Utils.deepCopy(sourceBullet.hitCache),
            hitEffects = {},
            canDirectHit = true
        }
        
        -- Propagate all hit effects including this bounce effect
        if sourceBullet.hitEffects then
            for _, effect in ipairs(sourceBullet.hitEffects) do
                table.insert(bounceConfig.hitEffects, effect)
            end
        end
        
        -- Mark the target we just hit in the new bullet's cache
        bounceConfig.hitCache[target:getID()] = true
        
        game:addObject(Bullet:new(bounceConfig))
    end
end

return Bounce
