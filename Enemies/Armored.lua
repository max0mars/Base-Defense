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
        config[key] = config[key] or value
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
    love.graphics.setColor(r, g, b, 0.1)
    love.graphics.polygon("fill", points)

    -- 2. Scissor Box for Health Fill (Bottom-to-Top)
    local fillRatio = self.hp / self:getStat("maxHp")
    local footprintW = size
    local footprintH = size
    local fx = self.x - footprintW/2
    local fy = self.y - footprintH/2
    
    local scissorY = fy + footprintH * (1 - fillRatio)
    local scissorH = footprintH * fillRatio

    -- 3. Health Fill (Bright fill restricted by scissor)
    love.graphics.setScissor(math.floor(fx), math.floor(scissorY), math.ceil(footprintW), math.ceil(scissorH))
    love.graphics.setColor(r, g, b, 0.7)
    love.graphics.polygon("fill", points)
    love.graphics.setScissor()

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
