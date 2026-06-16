local AcidCloudVisual = {}
AcidCloudVisual.__index = AcidCloudVisual

function AcidCloudVisual:new(x, y, radius, duration)
    local obj = setmetatable({}, self)
    obj.x = x
    obj.y = y
    obj.radius = radius or 80
    obj.maxLifetime = duration or 5.0
    obj.lifetime = obj.maxLifetime
    obj.destroyed = false
    obj.pulseTimer = 0
    return obj
end

function AcidCloudVisual:update(dt)
    self.lifetime = self.lifetime - dt
    self.pulseTimer = self.pulseTimer + dt
    if self.lifetime <= 0 then
        self.destroyed = true
    end
end

function AcidCloudVisual:draw()
    local alpha = math.min(1, self.lifetime / 0.5) -- fade out at the end, fade in at start
    if self.lifetime < 0.5 then
        alpha = self.lifetime / 0.5
    end
    
    local pulse = math.sin(self.pulseTimer * 3) * 0.05 + 1.0
    local r, g, b = 0.1, 0.7, 0.2 -- Green toxic/acid color
    
    -- Draw main soft toxic cloud
    love.graphics.setColor(r, g, b, alpha * 0.15)
    love.graphics.circle("fill", self.x, self.y, self.radius * pulse)
    
    -- Draw outer faint warning boundary
    love.graphics.setColor(r, g, b, alpha * 0.4)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", self.x, self.y, self.radius * pulse)
    
    -- Draw swirling inner particles/smaller clouds
    love.graphics.setColor(r, g, b, alpha * 0.1)
    for i = 1, 5 do
        local angle = (i * 72) + (self.pulseTimer * 20)
        local dist = (self.radius * 0.4) * (1 + math.sin(self.pulseTimer + i) * 0.1)
        local px = self.x + math.cos(math.rad(angle)) * dist
        local py = self.y + math.sin(math.rad(angle)) * dist
        love.graphics.circle("fill", px, py, self.radius * 0.35)
    end
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return AcidCloudVisual
