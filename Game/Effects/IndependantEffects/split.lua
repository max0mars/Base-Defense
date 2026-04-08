local IndependantEffect = require("Game.Effects.IndependantEffects.IndependantEffect")
local Bullet = require("Bullets.Bullet")
local Split = setmetatable({}, { __index = IndependantEffect })
Split.__index = Split

local default = {
    name = "split",
}

function Split:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    local effect = IndependantEffect:new(config)
    return setmetatable(effect, Split)
end

function Split:onApply(target, bullet)
    -- bullet (source) is the bullet instance that hit the target
    local _splitamount = 5
    local _spread = 0.1
    local _damage = 100
    
    if bullet.source and bullet.source.getStat then
        _splitamount = bullet.source:getStat("splitamount") or _splitamount
        _spread = bullet.source:getStat("spread") or _spread
        _damage = bullet.source:getStat("damage") or _damage
    end

    for i = 1, _splitamount do
        local angle = bullet.angle + (i * _spread) - (_spread * (_splitamount + 1) / 2)
        local splitBulletConfig = {
            x = bullet.x,
            y = bullet.y,
            angle = angle,
            hitCache = {},
            damage = _damage / 10,
            game = bullet.game,
            source = bullet.source, -- Keep the original turret as source
        }
        -- Copy hit cache to avoid hitting the same enemy again
        if bullet.hitCache then
            for k, v in pairs(bullet.hitCache) do
                splitBulletConfig.hitCache[k] = v
            end
        end
        -- Also add the current target to the cache so shards don't immediately hit it
        splitBulletConfig.hitCache[target:getID()] = true
        
        bullet.game:addObject(Bullet:new(splitBulletConfig))

    end
    
    -- Immediately remove the effect so it doesn't show an icon
    if target.effectManager then
        target.effectManager:removeEffect(self)
    end
end

return Split