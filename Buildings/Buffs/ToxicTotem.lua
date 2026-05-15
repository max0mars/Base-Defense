local Buff = require("Buildings.Buffs.Buff")
local ToxicEffect = require("Game.Effects.StatusEffects.Toxic")

local ToxicTotem = setmetatable({}, Buff)
ToxicTotem.__index = ToxicTotem

local default = {
    name = "Toxic Totem",
    types = { passive = true, totem = true, toxic = true },
    color = {0.7, 0.2, 0.9, 1}, -- Vibrant neon purple
    affectedSlots = { 
        {-1, -1}, {-1, 1},
        {1, -1},  {1, 1} 
    },
}

function ToxicTotem:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    
    -- Define the effect that will be applied to neighbors via the Buff system
    config.effect = {
        name = "Toxic Rounds",
        duration = math.huge,
        grantedHitEffect = ToxicEffect:new()
    }
    
    -- Ensure shapePattern is set for proper drawing in Buff:draw
    config.shapePattern = config.shapePattern or {{0, 0}}
    
    local obj = Buff:new(config)
    setmetatable(obj, self)
    
    return obj
end

function ToxicTotem:draw()
    local cx, cy = self:getCenterPosition()
    local r, g, b = unpack(self.color)
    
    -- Layered Geometric Design (Neon Purple Support Structure)
    local size = self.buildGrid.cellSize * 0.4
    
    -- 1. Base Glow
    love.graphics.setColor(r, g, b, 0.2)
    love.graphics.rectangle("fill", cx - size, cy - size, size * 2, size * 2, 4, 4)
    
    -- 2. Inner Pulsing Core
    local pulse = (math.sin(love.timer.getTime() * 5) + 1) / 2
    love.graphics.setColor(r, g, b, 0.4 + 0.4 * pulse)
    love.graphics.circle("fill", cx, cy, size * 0.6)
    
    -- 3. Outer Frame (Diamond)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", 
        cx, cy - size,
        cx + size, cy,
        cx, cy + size,
        cx - size, cy
    )
    
    -- 4. Connecting "Wires" to corners
    love.graphics.setColor(r, g, b, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.line(cx - size, cy - size, cx + size, cy + size)
    love.graphics.line(cx + size, cy - size, cx - size, cy + size)
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return ToxicTotem
