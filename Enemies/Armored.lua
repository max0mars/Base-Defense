local Enemy = require("Enemies.Enemy")
local Armored = setmetatable({}, {__index = Enemy})
Armored.__index = Armored

local default = {
    speed = 20,
    damage = 15,
    maxHp = 300,
    color = {0.5, 0.4, 1, 1}, -- Neon Steel/Purple
    types = { armored = true, tank = true },
    size = 32,
    reward = 50,
    affinities = {
        normal = 0.5, -- 50% resistance to normal damage
    }
}

function Armored:new(config)
    config = config or {}
    if not config.types then config.types = {} end
    for key, value in pairs(default) do
        if key == "affinities" then
            if not config.affinities then
                config.affinities = {}
                for k, v in pairs(default.affinities) do
                    config.affinities[k] = v
                end
            end
        else
            config[key] = config[key] or value
        end
    end
    for key in pairs(default.types) do
        config.types[key] = true
    end
    
    local instance = Enemy:new(config)
    setmetatable(instance, Armored)
    
    return instance
end

function Armored:draw()
    local drawX, drawY = self.x, self.y
    local size = self.size or 32
    local r, g, b, a = unpack(self.color or {1, 1, 1, 1})

    -- Helper to get Octagon points
    local function getOctagonPoints(x, y, s)
        local pts = {}
        for i = 0, 7 do
            local angle = i * (math.pi * 2 / 8) + math.pi / 8
            table.insert(pts, x + math.cos(angle) * s)
            table.insert(pts, y + math.sin(angle) * s)
        end
        return pts
    end

    local points = getOctagonPoints(drawX, drawY, size * 0.6)

    -- 1. Empty State (Dim fill)
    love.graphics.setColor(r, g, b, 0.2)
    love.graphics.polygon("fill", points)
    
    -- 2. Scissor Box for Health Fill (Bottom-to-Top)
    local maxHp = self:getStat("maxHp")
    local fillRatio = self.hp / maxHp
    
    -- Calculate actual vertical bounds of the octagon to avoid "dead space"
    local minY, maxY = points[2], points[2]
    for i = 4, #points, 2 do
        local y = points[i]
        if y < minY then minY = y end
        if y > maxY then maxY = y end
    end
    local actualH = maxY - minY
    
    local scissorY = minY + actualH * (1 - fillRatio)
    
    -- Guarantee at least a 1px visual drop/presence
    if self.hp < maxHp and self.hp > 0 then
        scissorY = math.max(minY + 1, math.min(maxY - 1, scissorY))
    end
    
    local scissorH = maxY - scissorY
    
    -- 3. Health Fill (Bright fill restricted by scissor)
    love.graphics.setScissor(math.floor(self.x - size), math.floor(scissorY), math.ceil(size * 2), math.ceil(scissorH))
    love.graphics.setColor(r, g, b, 0.7)
    love.graphics.polygon("fill", points)
    
    -- Add a bright horizontal line at the health level "cap"
    -- We do this by setting a very thin scissor and redrawing the shape fill
    if fillRatio > 0 and fillRatio < 1 then
        love.graphics.setScissor(math.floor(self.x - size), math.floor(scissorY), math.ceil(size * 2), 2)
        love.graphics.setColor(r, g, b, 1)
        love.graphics.polygon("fill", points)
        love.graphics.setScissor()
    end
    
    love.graphics.setScissor()

    -- Layer 3: Shield Fill (Scissor bottom-up)
    if self.maxShield > 0 and self.shield > 0 then
        local shieldRatio = self.shield / self.maxShield
        local sScissorY = minY + actualH * (1 - shieldRatio)
        local sScissorH = maxY - sScissorY
        
        love.graphics.setScissor(math.floor(self.x - size), math.floor(sScissorY), math.ceil(size * 2), math.ceil(sScissorH))
        love.graphics.setColor(0.6, 0.6, 0.6, 1) -- Flat Grey
        love.graphics.polygon("fill", points)
        love.graphics.setScissor()
    end

    -- 4. Glow Layers (Double thick borders)
    for i = 4, 1, -1 do
        local alpha = 0.05 * (1 - i/5)
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.setLineWidth(i * 4)
        love.graphics.polygon("line", points)
    end

    -- 5. Main Neon Border
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(3)
    love.graphics.polygon("line", points)
    
    -- Inner border for "Armored" look
    local innerPoints = getOctagonPoints(drawX, drawY, size * 0.4)
    love.graphics.setColor(r, g, b, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line", innerPoints)
end

return Armored
