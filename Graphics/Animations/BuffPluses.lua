-- BuffPluses.lua
-- Floating green '+' symbols animation to indicate a buff on a turret.

local BuffPluses = {}
BuffPluses.__index = BuffPluses

function BuffPluses:new(x, y, lifetime)
    local obj = setmetatable({}, self)
    
    obj.x = x
    obj.y = y
    obj.maxLifetime = lifetime or 0.9
    obj.lifetime = obj.maxLifetime
    obj.destroyed = false
    
    obj.symbols = {}
    local numSymbols = 5
    for i = 1, numSymbols do
        table.insert(obj.symbols, {
            offX = love.math.random(-15, 15),
            offY = love.math.random(-5, 10), -- Start near/below center, float up
            speed = love.math.random(20, 45)
        })
    end
    
    return obj
end

function BuffPluses:update(dt)
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then
        self.destroyed = true
        return
    end
    
    for _, sym in ipairs(self.symbols) do
        sym.offY = sym.offY - sym.speed * dt -- Float upward
    end
end

function BuffPluses:draw()
    local alpha = self.lifetime / self.maxLifetime
    love.graphics.setColor(0.2, 1.0, 0.3, alpha)
    love.graphics.setLineWidth(1.5)
    
    for _, sym in ipairs(self.symbols) do
        local sx = self.x + sym.offX
        local sy = self.y + sym.offY
        
        -- Draw a '+' symbol
        love.graphics.line(sx - 3, sy, sx + 3, sy)  -- Horizontal
        love.graphics.line(sx, sy - 3, sx, sy + 3)  -- Vertical
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

return BuffPluses
