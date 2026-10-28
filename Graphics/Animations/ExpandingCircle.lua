local ExpandingCircle = {}
ExpandingCircle.__index = ExpandingCircle

-- delay: seconds before the ring appears (for staggered rings)
function ExpandingCircle:new(x, y, startRadius, endRadius, color, duration, delay)
    local obj = setmetatable({}, self)
    
    obj.x = x
    obj.y = y
    obj.startRadius = startRadius or 0
    obj.endRadius = endRadius or 150
    obj.color = color or {0.6, 0.6, 0.6} -- Default grey
    obj.maxLifetime = duration or 0.6
    obj.lifetime = obj.maxLifetime
    obj.delay = delay or 0
    obj.destroyed = false
    
    return obj
end

function ExpandingCircle:update(dt)
    if self.delay > 0 then
        self.delay = self.delay - dt
        return
    end
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then
        self.destroyed = true
    end
end

function ExpandingCircle:draw()
    if self.delay > 0 then return end
    local progress = 1 - (self.lifetime / self.maxLifetime)
    local alpha = self.lifetime / self.maxLifetime
    local r, g, b = unpack(self.color)
    
    local currentRadius = self.startRadius + (self.endRadius - self.startRadius) * progress
    
    -- Draw expanding ring
    love.graphics.setLineWidth(3 * alpha + 1)
    love.graphics.setColor(r, g, b, alpha * 0.5)
    love.graphics.circle("line", self.x, self.y, currentRadius)
    
    -- Optional inner glow
    love.graphics.setColor(r, g, b, alpha * 0.1)
    love.graphics.circle("fill", self.x, self.y, currentRadius)
    
    -- Reset graphics state
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return ExpandingCircle
