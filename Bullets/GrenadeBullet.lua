local LobberBullet = require("Bullets.LobberBullet")

local GrenadeBullet = setmetatable({}, LobberBullet)
GrenadeBullet.__index = GrenadeBullet

function GrenadeBullet:new(config)
    local b = LobberBullet.new(self, config)
    
    b.landed = false
    b.currentFuse = (config.source and config.source.getStat and config.source:getStat("fuseTime")) or 0
    
    return b
end

function GrenadeBullet:update(dt)
    if self.destroyed then return end
    
    if not self.landed then
        LobberBullet.update(self, dt)
    else
        self.currentFuse = self.currentFuse - dt
        if self.currentFuse <= 0 then
            self:onHit(nil)
            self:died()
        end
    end
end

function GrenadeBullet:onGroundImpact()
    self.landed = true
    self.bulletSpeed = 0
    if self.effectManager then
        self.effectManager:recalculateStats()
    end
end

function GrenadeBullet:onCollision(obj)
    -- Do absolutely nothing. Grenades ignore direct impacts and only explode via fuse.
end

function GrenadeBullet:draw()
    -- Visual Indicator: Shadow at base coordinates
    local shadowWidth = 12
    local shadowHeight = 6
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", self.x, self.y, shadowWidth/2, shadowHeight/2)
    
    -- Render Bullet at (x, y - z)
    local c = self.color or {1, 1, 1, 1}
    if self.landed and math.sin(self.currentFuse * 15) > 0 then
        c = {1, 0, 0, 1} -- Blink red to indicate imminent explosion
    end
    
    love.graphics.setColor(c)
    local drawX = self.x
    local drawY = self.y - self.z
    
    if self.shape == "rectangle" then
        love.graphics.rectangle("fill", drawX - self.w / 2, drawY - self.h / 2, self.w, self.h)
    elseif self.shape == "circle" then
        love.graphics.circle("fill", drawX, drawY, self.size or (self.w/2))
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

return GrenadeBullet
