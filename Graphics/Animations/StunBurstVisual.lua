local StunBurstVisual = {}
StunBurstVisual.__index = StunBurstVisual

function StunBurstVisual:new(x, y, radius, duration)
    local obj = setmetatable({}, self)
    obj.x = x
    obj.y = y
    obj.radius = radius or 70
    obj.maxLifetime = duration or 1.5
    obj.lifetime = obj.maxLifetime
    obj.destroyed = false
    obj.pulseTimer = 0
    return obj
end

function StunBurstVisual:update(dt)
    self.lifetime = self.lifetime - dt
    self.pulseTimer = self.pulseTimer + dt
    if self.lifetime <= 0 then
        self.destroyed = true
    end
end

function StunBurstVisual:draw()
    local alpha = math.min(1, self.lifetime / 0.3) -- fade out at the end, fade in at start
    if self.lifetime < 0.3 then
        alpha = self.lifetime / 0.3
    end
    
    local pulse = math.sin(self.pulseTimer * 4) * 0.04 + 1.0
    local r, g, b = 0.9, 0.9, 0.1 -- Yellow/electricity stun color
    
    -- Draw main soft stun cloud
    love.graphics.setColor(r, g, b, alpha * 0.18)
    love.graphics.circle("fill", self.x, self.y, self.radius * pulse)
    
    -- Draw outer faint boundary
    love.graphics.setColor(r, g, b, alpha * 0.45)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", self.x, self.y, self.radius * pulse)
    
    -- Draw swirling inner elements
    love.graphics.setColor(r, g, b, alpha * 0.12)
    for i = 1, 4 do
        local angle = (i * 90) + (self.pulseTimer * 30)
        local dist = (self.radius * 0.35) * (1 + math.sin(self.pulseTimer + i) * 0.1)
        local px = self.x + math.cos(math.rad(angle)) * dist
        local py = self.y + math.sin(math.rad(angle)) * dist
        love.graphics.circle("fill", px, py, self.radius * 0.3)
    end
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return StunBurstVisual
