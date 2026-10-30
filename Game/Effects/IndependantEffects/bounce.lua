local Bullet = require("Bullets.Bullet")
local Utils = require("Classes.Utils")

local Bounce = {}
Bounce.__index = Bounce

Bounce.FALLOFF = 0.9 -- damage kept on each bounce
Bounce.SPEED_KEPT = 0.94 -- speed kept on each bounce: it slows as it goes (40% after 15)

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
        -- Aim where the next target will be when the bolt arrives (like a
        -- turret leads its target), so slow bolts don't fly behind it
        local speed = sourceBullet:getStat("bulletSpeed") * Bounce.SPEED_KEPT
        local aimX, aimY = closestEnemy.x, closestEnemy.y
        if speed > 0 and closestEnemy.getFuturePosition then
            for _ = 1, 2 do -- the second pass refines the flight time
                local fx, fy = aimX - target.x, aimY - target.y
                aimX, aimY = closestEnemy:getFuturePosition(math.sqrt(fx * fx + fy * fy) / speed)
            end
        end
        local angle = math.atan2(aimY - target.y, aimX - target.x)
        
        -- Calculate the initial damage if this is the first bounce in the chain
        local initialDamage = sourceBullet.initialDamage or sourceBullet:getStat("damage")
        -- Which bounce this is (1 = first), so falloff doesn't depend on the bounce count
        local bounceNumber = (sourceBullet.bounceNumber or 0) + 1

        -- Create the bounced bullet
        local bounceConfig = {
            name = (sourceBullet.name or "Tesla") .. " Arc",
            x = target.x,
            y = target.y,
            angle = angle,
            bulletSpeed = speed,
            initialDamage = initialDamage,
            -- Each bounce keeps 90% of the last one's damage (100% -> 90% -> 81%...):
            -- it never reaches zero, however many bounces there are
            damage = initialDamage * Bounce.FALLOFF ^ bounceNumber,
            bounceNumber = bounceNumber,
            bouncesLeft = bouncesLeft - 1,
            pierce = 1,
            lifespan = sourceBullet:getStat("lifespan"),
            displayLifespan = sourceBullet:getStat("displayLifespan") or 0.1,
            w = sourceBullet.w, h = sourceBullet.h,
            shape = sourceBullet.shape,
            -- Keeps the original's look through every bounce
            color = sourceBullet.color,
            drawStyle = sourceBullet.drawStyle,
            maxTrail = sourceBullet.maxTrail,
            hitbox = true,
            types = { bullet = true },
            game = game,
            source = sourceBullet.source,
            damageType = sourceBullet.damageType or "energy",
            hitCache = Utils.deepCopy(sourceBullet.hitCache),
            hitEffects = {},
            recursion = sourceBullet.recursion,
            recursionSpread = sourceBullet.recursionSpread,
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
