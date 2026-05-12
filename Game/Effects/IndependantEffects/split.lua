local Bullet = require("Bullets.Bullet")
local Utils = require("Classes.Utils")

local Split = {}
Split.__index = Split

function Split:new(config)
    local instance = setmetatable({}, Split)
    for k, v in pairs(config or {}) do
        instance[k] = v
    end
    -- Essential identification
    instance.name = instance.name or "split"
    instance.isIndependent = true
    return instance
end

function Split:trigger(target, sourceBullet)
    -- sourceBullet is the bullet instance that hit the target
    -- target is the enemy hit
    
    local _splitamount = sourceBullet:getStat("splitamount") 
    local _spread = sourceBullet:getStat("spread") 
    
    -- local _damage = 0
    -- local mult = sourceBullet:getStat("splitDamage_from_damage")
    -- if mult > 0 then
    --     _damage = sourceBullet:getStat("damage") * mult
    -- else
    --     _damage = sourceBullet:getStat("splitDamage")
    -- end
    
    -- -- Inherited properties that should propagate to shards
    -- local _speed = sourceBullet:getStat("bulletSpeed")
    -- local _pierce = sourceBullet:getStat("pierce")
    -- local _lifespan = sourceBullet:getStat("lifespan")

    for i = 1, _splitamount do
        -- Calculate angles for shards
        local angle = sourceBullet.angle + (i * _spread) - (_spread * (_splitamount + 1) / 2)
        
        -- Use target position if available, otherwise use source bullet position (ground hit)
        local spawnX = target and target.x or sourceBullet.x
        local spawnY = target and target.y or sourceBullet.y

        local _damage = 0
        local mult = sourceBullet:getStat("splitDamage_from_damage")
        if mult > 0 then
            _damage = sourceBullet:getStat("damage") * mult
        else
            _damage = sourceBullet:getStat("splitDamage")
        end
        if _damage <= 0 then
            _damage = sourceBullet:getStat("damage") * 0.4
        end

        local splitBulletConfig = {
            name = (sourceBullet.name or "Bullet") .. " Shard",
            x = spawnX,
            y = spawnY,
            angle = angle,
            bulletSpeed = sourceBullet:getStat("bulletSpeed") * 0.7, 
            damage = _damage,
            pierce = 1,
            lifespan = sourceBullet:getStat("lifespan") * 0.5,
            displayLifespan = sourceBullet:getStat("displayLifespan") or 0.1,
            w = 3, h = 3, shape = "rectangle",
            hitbox = true,
            types = { bullet = true },
            game = sourceBullet.game,
            source = sourceBullet.source,
            damageType = sourceBullet.damageType,
            hitCache = {},
            hitEffects = {}, -- We will populate this next
            
            -- Pass along all relevant scaling stats
            poison_from_damage = sourceBullet:getStat("poison_from_damage"),
            dps_poison = sourceBullet:getStat("dps_poison"),
            splitamount = sourceBullet:getStat("splitamount"),
            spread = sourceBullet:getStat("spread"),
            splitDamage = sourceBullet:getStat("splitDamage"),
            splitDamage_from_damage = sourceBullet:getStat("splitDamage_from_damage"),
            canDirectHit = true
        }

        -- Propagate hit effects (but skip ourselves to avoid infinite recursion)
        if sourceBullet.hitEffects then
            for _, effect in ipairs(sourceBullet.hitEffects) do
                if effect ~= self then
                    table.insert(splitBulletConfig.hitEffects, effect)
                end
            end
        end
        
        -- Individual hit cache management
        if sourceBullet.hitCache then
            for k, v in pairs(sourceBullet.hitCache) do
                splitBulletConfig.hitCache[k] = v
            end
        end
        
        -- Prevent shards from immediate re-collision with the same target
        if target then
            splitBulletConfig.hitCache[target:getID()] = true
        end
        
        sourceBullet.game:addObject(Bullet:new(splitBulletConfig))
    end
end

return Split