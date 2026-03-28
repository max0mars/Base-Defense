local object = require("Classes.object")
local collision = require("Physics.collisionSystem_brute")

local HitscanBullet = setmetatable({}, object)
HitscanBullet.__index = HitscanBullet

function HitscanBullet:new(config)
    local obj = setmetatable(object:new(config), { __index = self })
    
    obj.x = config.x
    obj.y = config.y
    obj.angle = config.angle
    obj.range = config.range or 800
    obj.damage = config.damage or 10
    obj.hitEffects = config.hitEffects or {}
    obj.source = config.source
    obj.lifespan = 0.1
    obj.maxLifespan = 0.1
    obj.tags = config.tags or {"bullet"}
    
    -- Hitscan endpoint logic
    local x2 = obj.x + math.cos(obj.angle) * obj.range
    local y2 = obj.y + math.sin(obj.angle) * obj.range
    
    local ray = {
        x1 = obj.x, y1 = obj.y,
        x2 = x2, y2 = y2,
        getHitbox = function(s) return s end,
        isType = function() return false end -- Rays aren't themselves types usually
    }
    
    local closestT = 1
    local closestEnemy = nil
    
    for _, other in ipairs(obj.game.objects) do
        if other:isType("enemy") and not other.destroyed then
            local hit, t = collision:rayRect(ray, other)
            if hit and t < closestT then
                closestT = t
                closestEnemy = other
            end
        end
    end
    
    obj.endpoint = {
        x = obj.x + (x2 - obj.x) * closestT,
        y = obj.y + (y2 - obj.y) * closestT
    }
    
    if closestEnemy then
        obj:onHit(closestEnemy)
    end
    
    return obj
end

function HitscanBullet:onHit(target)
    target:takeDamage(self.damage)
    
    if target.effectManager then
        for _, effectTemplate in ipairs(self.hitEffects) do
            target.effectManager:applyEffect(effectTemplate)
        end
        target.effectManager:triggerEvent("onHit", self)
    end
end

function HitscanBullet:update(dt)
    self.lifespan = self.lifespan - dt
    if self.lifespan <= 0 then
        self.destroyed = true
    end
end

function HitscanBullet:draw()
    local alpha = self.lifespan / self.maxLifespan
    love.graphics.setColor(1, 0.9, 0.3, alpha)
    love.graphics.setLineWidth(2)
    love.graphics.line(self.x, self.y, self.endpoint.x, self.endpoint.y)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function HitscanBullet:isType(t)
    return t == "bullet" or t == "hitscan"
end

return HitscanBullet
