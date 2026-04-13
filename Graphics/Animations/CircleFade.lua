local CircleFade = {}
CircleFade.__index = CircleFade

--- @param x number X coordinate of the center
--- @param y number Y coordinate of the center
--- @param radius number Final radius of the circle
--- @param color table {r, g, b} color table
--- @param duration number How long the animation lasts
function CircleFade:new(x, y, radius, color, duration)
    local obj = setmetatable({}, self)
    
    obj.x = x
    obj.y = y
    obj.radius = radius or 50
    obj.color = color or {1, 0.5, 0} -- Default neon orange
    obj.maxLifetime = duration or 0.5
    obj.lifetime = obj.maxLifetime
    obj.destroyed = false
    
    return obj
end

function CircleFade:update(dt)
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then
        self.destroyed = true
    end
end

function CircleFade:draw()
    local alpha = self.lifetime / self.maxLifetime
    local r, g, b = unpack(self.color)
    
    -- Neon Glow Effect
    -- Outer soft glow Layer
    love.graphics.setLineWidth(4)
    love.graphics.setColor(r, g, b, alpha * 0.3)
    love.graphics.circle("line", self.x, self.y, self.radius)
    
    -- Core Neon Circle
    love.graphics.setLineWidth(2)
    love.graphics.setColor(r, g, b, alpha)
    love.graphics.circle("line", self.x, self.y, self.radius)
    
    -- Reset graphics state
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return CircleFade
