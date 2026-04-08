local IndependantEffect = require("Game.Effects.IndependantEffects.IndependantEffect")
local Bullet = require("Bullets.Bullet")
local Split = setmetatable({}, { __index = IndependantEffect })
Split.__index = Split

local default = {
    name = "split",
    isIndependent = true,
}

function Split:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    local effect = IndependantEffect:new(config)
    return setmetatable(effect, Split)
end

function Split:trigger(target, sourceBullet)
    -- sourceBullet is the bullet instance that hit the target
    -- target is the enemy hit
    
    local _splitamount = 3
    local _spread = 0.8
    local _damage = 5
    
    -- Try to get stats from the bullet or source turret
    if sourceBullet.getStat then
        _splitamount = sourceBullet:getStat("splitamount") or _splitamount
        _spread = sourceBullet:getStat("spread") or _spread
        _damage = sourceBullet:getStat("splitDamage") or _damage
    end

    for i = 1, _splitamount do
        -- Calculate angles for shards
        local angle = sourceBullet.angle + (i * _spread) - (_spread * (_splitamount + 1) / 2)
        
        local splitBulletConfig = {
            x = target.x, -- Spawn at enemy position
            y = target.y,
            angle = angle,
            hitCache = {},
            damage = _damage * 0.3, -- Shards deal 30% damage
            game = sourceBullet.game,
            source = sourceBullet.source,
            damageType = sourceBullet.damageType,
        }
        
        -- Copy hit cache from the original bullet
        if sourceBullet.hitCache then
            for k, v in pairs(sourceBullet.hitCache) do
                splitBulletConfig.hitCache[k] = v
            end
        end
        -- Ensure shards don't hit the target that just generated them
        splitBulletConfig.hitCache[target:getID()] = true
        
        -- Add to game
        sourceBullet.game:addObject(Bullet:new(splitBulletConfig))
    end
end

return Split