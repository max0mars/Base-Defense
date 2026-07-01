local Turret = require("Buildings.Turrets.Turret")
local Utils = require("Classes.Utils")

local ChainLaser = setmetatable({}, { __index = Turret })
ChainLaser.__index = ChainLaser

function ChainLaser:draw(drawx, drawy)
    local cx, cy = drawx or self.x, drawy or self.y
    if not drawx and not drawy then
        cx, cy = self:getCenterPosition()
    end
    local r, g, b = unpack(self.color or {0.4, 0.7, 1, 1})
    local time = love.timer.getTime()
    
    -- Draw Aiming Arc (Standard Turret feature)
    if self.showArc then
        self:drawFiringArc(cx, cy, 0.4)
    end
    
    -- 1. Draw Hexagonal Power Base
    local function drawHex(radius)
        local pts = {}
        for i = 0, 5 do
            local angle = i * (math.pi * 2 / 6)
            table.insert(pts, cx + math.cos(angle) * radius)
            table.insert(pts, cy + math.sin(angle) * radius)
        end
        love.graphics.polygon("line", pts)
    end
    
    -- Base Glow
    love.graphics.setColor(r, g, b, 0.2)
    love.graphics.setLineWidth(4)
    drawHex(10)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(2)
    drawHex(8)
    
    -- Corner Power Cells
    for i = 0, 2 do
        local angle = i * (math.pi * 2 / 3) + time * 0.5
        local px = cx + math.cos(angle) * 10
        local py = cy + math.sin(angle) * 10
        local pulse = (math.sin(time * 5 + i) + 1) / 2
        love.graphics.setColor(r, g, b, 0.3 + 0.7 * pulse)
        love.graphics.circle("fill", px, py, 2)
    end
    
    -- 2. Draw Aiming Head (Floating Rails)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(self.rotation)
    
    -- Reload Progress for visuals
    local currentFireRate = self:getStat("fireRate")
    local reloadProgress = 1 - math.max(0, self.cooldown / (1 / currentFireRate))
    
    -- Floating Rails
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", 2, -5, 10, 2, 1) -- Top rail
    love.graphics.rectangle("fill", 2, 3, 10, 2, 1)  -- Bottom rail
    
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("line", 2, -5, 10, 2, 1)
    love.graphics.rectangle("line", 2, 3, 10, 2, 1)
    
    -- Energy Core (Pulsing)
    local corePulse = (math.sin(time * 15) + 1) / 2
    love.graphics.setColor(r, g, b, 0.4 + 0.6 * corePulse * reloadProgress)
    love.graphics.circle("fill", 5, 0, 3 + corePulse)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 5, 0, 1.5)
    
    -- Electrical Arcs between rails (if charging)
    if reloadProgress > 0.3 then
        love.graphics.setColor(r, g, b, 0.7 * reloadProgress)
        love.graphics.setLineWidth(1)
        for i = 1, 2 do
            local x = 4 + math.random() * 8
            local y1 = -3
            local y2 = 3
            love.graphics.line(x, y1, x + (math.random()-0.5)*4, (y1+y2)/2, x, y2)
        end
    end
    
    love.graphics.pop()
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return ChainLaser
