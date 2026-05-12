local Enemy = require("Enemies.Enemy")
local Flyer = setmetatable({}, {__index = Enemy})
Flyer.__index = Flyer

local default = {
    speed = 25, -- Faster than standard 25
    maxHp = 200,
    damage = 15,
    color = {1, 0.5, 0, 1}, -- Neon Orange
    types = { flyer = true },
    size = 25,
    reward = 35,
    isFlying = true -- Custom flag for pathfinding/collision bypass
}

function Flyer:new(config)
    config = config or {}
    if not config.types then config.types = {} end
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    for key in pairs(default.types) do
        config.types[key] = true
    end
    
    -- Hitbox is a standard square
    config.w = config.size
    config.h = config.size
    
    local instance = Enemy:new(config)
    setmetatable(instance, Flyer)
    return instance
end

function Flyer:draw()
    local r, g, b, a = unpack(self.color or {1, 0.5, 0, 1})
    local drawX = self.x
    local drawY = self.y
    local size = self.size
    
    -- Calculate rotation (pointing towards target)
    local angle = 0
    if self.navigator and self.tx then
        angle = math.atan2(self.ty - self.y, self.tx - self.x)
    else
        angle = math.pi -- Default facing left
    end

    -- Arrow Polygon Points (Arrow pointing along the angle)
    -- tip, back-right, indented-back, back-left
    local function getArrowPoints(cx, cy, s, ang)
        local points = {
            {cx + math.cos(ang) * s, cy + math.sin(ang) * s}, -- Tip
            {cx + math.cos(ang + 2.5) * s, cy + math.sin(ang + 2.5) * s}, -- Back-right
            {cx + math.cos(ang + math.pi) * (s * 0.4), cy + math.sin(ang + math.pi) * (s * 0.4)}, -- Indented back
            {cx + math.cos(ang - 2.5) * s, cy + math.sin(ang - 2.5) * s} -- Back-left
        }
        local flat = {}
        for _, p in ipairs(points) do
            table.insert(flat, p[1])
            table.insert(flat, p[2])
        end
        return flat
    end

    local arrowPoints = getArrowPoints(drawX, drawY, size * 0.8, angle)

    -- 1. Draw "Empty" Base State (Dim fill)
    love.graphics.setColor(r, g, b, 0.15)
    love.graphics.polygon("fill", arrowPoints)
    
    -- 2. Calculate Scissor Box for Health Fill (Draining effect)
    local fillRatio = self.hp / self:getStat("maxHp")
    -- We use a footprint that fully covers the arrow points radius (size * 0.8 * 2)
    local footprintW = size * 1.6
    local footprintH = size * 1.6
    local fx = self.x - footprintW/2
    local fy = self.y - footprintH/2
    
    local scissorY = fy + footprintH * (1 - fillRatio)
    local scissorH = footprintH * fillRatio
    
    -- 3. Draw "Health" Fill (Bright fill restricted by scissor)
    love.graphics.setScissor(math.floor(fx), math.floor(scissorY), math.ceil(footprintW), math.ceil(scissorH))
    love.graphics.setColor(r, g, b, 0.7)
    love.graphics.polygon("fill", arrowPoints)
    love.graphics.setScissor()
    
    -- Layer 3: Shield Fill (Scissor bottom-up)
    if self.maxShield > 0 and self.shield > 0 then
        local shieldRatio = self.shield / self.maxShield
        local sScissorY = fy + footprintH * (1 - shieldRatio)
        local sScissorH = footprintH * shieldRatio
        
        love.graphics.setScissor(math.floor(fx), math.floor(sScissorY), math.ceil(footprintW), math.ceil(sScissorH))
        love.graphics.setColor(0.6, 0.6, 0.6, 1) -- Flat Grey
        love.graphics.polygon("fill", arrowPoints)
        love.graphics.setScissor()
    end
    
    -- 4. Glow Layers (Outside scissor)
    for i = 4, 1, -1 do
        local alpha = 0.05 * (1 - i/5)
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.setLineWidth(i * 3)
        love.graphics.polygon("line", arrowPoints)
    end
    
    -- 5. Main Neon Border
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", arrowPoints)
end

return Flyer
