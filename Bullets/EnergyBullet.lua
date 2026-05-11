local Bullet = require("Bullets.Bullet")
local EnergyBullet = setmetatable({}, {__index = Bullet})
EnergyBullet.__index = EnergyBullet

function EnergyBullet:new(config)
    local b = Bullet:new(config)
    setmetatable(b, EnergyBullet)
    
    b.trail = {}
    b.maxTrail = config.maxTrail or 12
    return b
end

function EnergyBullet:update(dt)
    Bullet.update(self, dt)
end

function EnergyBullet:draw()
    local r, g, b, a = unpack(self.color or {0, 1, 1, 1})
    
    -- 1. Draw Fading Trail
    if #self.trail > 1 then
        for i = 1, #self.trail - 1 do
            local p1 = self.trail[i]
            local p2 = self.trail[i+1]
            
            -- Calculate alpha based on age (i=1 is newest)
            local alpha = (1 - (i / #self.trail)) * 0.6
            love.graphics.setColor(r, g, b, alpha)
            
            -- Thicker lines for newer segments
            local width = (1 - (i / #self.trail)) * 3
            love.graphics.setLineWidth(width)
            love.graphics.line(p1.x, p1.y, p2.x, p2.y)
        end
    end
    
    -- 2. Draw Glow Layers (Slightly smaller bloom)
    for i = 3, 1, -1 do
        love.graphics.setColor(r, g, b, 0.15 * (4-i))
        love.graphics.circle("fill", self.x, self.y, self.w * (0.2 + i * 0.3))
    end
    
    -- 3. Draw Bullet Head
    local angle = self.angle
    local length = self.w
    local hw = length / 2
    
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(angle)
    
    -- Outer Bloom (Sleeker body)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("fill", -hw, -1.5, length, 3, 1, 1)
    
    -- White Core (Finer center)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.rectangle("fill", -hw * 0.6, -0.5, length * 0.6, 1, 0.5, 0.5)
    
    love.graphics.pop()
end

return EnergyBullet
