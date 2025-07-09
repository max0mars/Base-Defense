-- Simple explosion effect
local explosions = {

}

function explosions:new(x, y, maxRadius, duration)
    local explosion = {
        x = x,
        y = y,
        radius = 0,
        maxRadius = maxRadius or 50,
        timer = 0,
        duration = 0.5, -- half second explosion
        active = true
    }
    
    return setmetatable(explosion, { __index = self })
end

function explosions:update(dt)
    
    self.timer = self.timer + dt
    
    -- Grow radius over time
    local progress = self.timer / self.duration
    self.radius = self.maxRadius * progress
    
end

function explosions:draw()
    local progress = self.timer / self.duration
    local alpha = 1 - progress
    
    for i = 1, 10 do
        local angle = math.rad(i * 36) -- Spread out the circles
        local offsetX = math.cos(angle) * self.radius * 0.1
        local offsetY = math.sin(angle) * self.radius * 0.1
        
        -- Draw smaller circles around the main explosion
        love.graphics.setColor(1, 0, 0, alpha * 0.5) -- Red with fade
        love.graphics.circle("line", self.x + offsetX, self.y + offsetY, self.radius * 0.2)
    end
    -- Draw expanding circle with fade
    love.graphics.setColor(1, 0.5, 0, alpha) -- Orange with fade
    love.graphics.circle("line", self.x, self.y, self.radius)
    
    -- Optional: Add inner circle
    if self.radius > 10 then
        love.graphics.setColor(1, 1, 0, alpha * 0.5) -- Yellow center
        love.graphics.circle("line", self.x, self.y, self.radius * 0.6)
    end
end

return explosions