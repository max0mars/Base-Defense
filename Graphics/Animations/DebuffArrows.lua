-- DebuffArrows.lua
-- Down-facing red arrows animation to indicate a debuff on a turret.

local DebuffArrows = {}
DebuffArrows.__index = DebuffArrows

function DebuffArrows:new(x, y, lifetime)
    local obj = setmetatable({}, self)
    
    obj.x = x
    obj.y = y
    obj.maxLifetime = lifetime or 0.8
    obj.lifetime = obj.maxLifetime
    obj.destroyed = false
    
    obj.arrows = {}
    local numArrows = 5
    for i = 1, numArrows do
        table.insert(obj.arrows, {
            offX = love.math.random(-15, 15),
            offY = love.math.random(-30, -5), -- Start a bit above, randomized
            speed = love.math.random(20, 45)
        })
    end
    
    return obj
end

function DebuffArrows:update(dt)
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then
        self.destroyed = true
        return
    end
    
    for _, arrow in ipairs(self.arrows) do
        arrow.offY = arrow.offY + arrow.speed * dt
    end
end

function DebuffArrows:draw()
    local alpha = self.lifetime / self.maxLifetime
    love.graphics.setColor(1, 0.2, 0.2, alpha)
    love.graphics.setLineWidth(1.5)
    
    for _, arrow in ipairs(self.arrows) do
        local ax = self.x + arrow.offX
        local ay = self.y + arrow.offY
        
        -- Draw a down-facing arrow (v shape + stem) - made smaller
        love.graphics.line(ax, ay - 4, ax, ay + 3)
        love.graphics.line(ax - 2.5, ay + 1, ax, ay + 3)
        love.graphics.line(ax + 2.5, ay + 1, ax, ay + 3)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

return DebuffArrows
