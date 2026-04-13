local bullet = require("Bullets.Bullet")
local collision = require("Physics.collisionSystem_brute")

local HitscanBullet = setmetatable({}, bullet)
HitscanBullet.__index = HitscanBullet

function HitscanBullet:new(config)
    if not config then
        error("Developer Error: HitscanBullet:new called with nil config.")
    end

    local required = {"name", "damage", "displayLifespan", "color"} -- removed "range"
    for _, key in ipairs(required) do
        if config[key] == nil then
            error("Developer Error: HitscanBullet [" .. (config.name or "Unknown") .. "] is missing the '" .. key .. "' field in config.")
        end
    end

    -- Hitscan-specific defaults to satisfy Bullet:new requirements
    config.bulletSpeed = config.bulletSpeed or 0
    config.pierce = config.pierce or 1
    config.w = config.w or 1
    config.h = config.h or 1
    config.shape = config.shape or "line"
    config.displayLifespan = config.displayLifespan or 0.1
    config.lifespan = config.displayLifespan -- technical lifespan for base class
    
    local obj = bullet:new(config)
    setmetatable(obj, self)
    
    obj.displayLifespan = config.displayLifespan
    obj.maxDisplayLifespan = config.displayLifespan
    obj.endpoint = { x = obj.x, y = obj.y }
    
    -- Hitscan endpoint logic
    local x2 = config.targetX or obj.x
    local y2 = config.targetY or obj.y
    
    local ray = {
        x1 = obj.x, y1 = obj.y,
        x2 = x2, y2 = y2,
        getHitbox = function(s) return s end,
        isType = function() return false end
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
    
    -- Process the hit immediately
    if closestEnemy then
        obj:onHit(closestEnemy)
    else 
        obj:onHit(nil)
    end
    
    return obj
end

function HitscanBullet:onHit(target)
    -- Temporarily move to endpoint for the particle explosion at the point of impact
    local oldX, oldY = self.x, self.y
    self.x, self.y = self.endpoint.x, self.endpoint.y
    
    -- Call base Bullet onHit for damage and effect propagation
    bullet.onHit(self, target)
    
    -- Restore position for line drawing
    self.x, self.y = oldX, oldY
    
    -- Hitscan bullets should persist for their trail duration despite hitting something
    if self.displayLifespan > 0 then
        self.destroyed = false
    end
end

function HitscanBullet:update(dt)
    self.displayLifespan = self.displayLifespan - dt
    if self.displayLifespan <= 0 then
        self.destroyed = true
    end
end

function HitscanBullet:draw()
    local alpha = self.displayLifespan / self.maxDisplayLifespan
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], alpha)
    love.graphics.setLineWidth(2)
    love.graphics.line(self.x, self.y, self.endpoint.x, self.endpoint.y)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return HitscanBullet
