local Bullet = require("Bullets.Bullet")

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
    local _damage = sourceBullet:getStat("splitDamage") 
    
    -- Inherited properties that should propagate to shards
    local _speed = sourceBullet:getStat("bulletSpeed")
    local _pierce = sourceBullet:getStat("pierce")
    local _lifespan = sourceBullet:getStat("lifespan")

    for i = 1, _splitamount do
        -- Calculate angles for shards
        local angle = sourceBullet.angle + (i * _spread) - (_spread * (_splitamount + 1) / 2)
        
        -- Use target position if available, otherwise use source bullet position (ground hit)
        local spawnX = target and target.x or sourceBullet.x
        local spawnY = target and target.y or sourceBullet.y

        local splitBulletConfig = {
            name = (sourceBullet.name or "Bullet") .. " Shard",
            x = spawnX,
            y = spawnY,
            angle = angle,
            bulletSpeed = _speed * 0.8, -- Shards are slightly slower
            damage = _damage,
            pierce = 1, -- Shards typically don't pierce
            lifespan = _lifespan * 0.5, -- Shards have shorter life
            w = 3, h = 3, shape = "rectangle", -- Smaller shards
            hitbox = true, -- REQUIRED for collision
            types = { bullet = true }, -- REQUIRED for collision system lookup
            game = sourceBullet.game,
            source = sourceBullet.source,
            damageType = sourceBullet.damageType,
            hitCache = {},
        }
        
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