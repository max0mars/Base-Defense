local Buff = require("Buildings.Passives.Buff")
local ToxicEffect = require("Game.Effects.StatusEffects.Toxic")

local ToxicTotem = setmetatable({}, Buff)
ToxicTotem.__index = ToxicTotem

local default = {
    name = "Toxic Totem",
    types = { passive = true, toxic = true },
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

-- Sprite: a bubbling flask
function ToxicTotem:drawShape(cx, cy, s)
    love.graphics.polygon("line",
        cx - s * 0.25, cy - s * 0.85, cx - s * 0.25, cy - s * 0.3, cx - s * 0.9, cy + s,
        cx + s * 0.9, cy + s, cx + s * 0.25, cy - s * 0.3, cx + s * 0.25, cy - s * 0.85)
    love.graphics.line(cx - s * 0.45, cy - s * 0.85, cx + s * 0.45, cy - s * 0.85)
end

function ToxicTotem:drawDetail(cx, cy, s, pulse)
    local r, g, b = unpack(self.color)
    -- Liquid
    love.graphics.setColor(r, g, b, 0.35 + 0.2 * pulse)
    love.graphics.polygon("fill",
        cx - s * 0.62, cy + s * 0.45, cx + s * 0.62, cy + s * 0.45,
        cx + s * 0.85, cy + s * 0.93, cx - s * 0.85, cy + s * 0.93)
    -- Bubbles rising up the neck
    local t = love.timer.getTime()
    love.graphics.setColor(r, g, b, 1)
    for i = 0, 2 do
        local phase = (t * 0.7 + i / 3) % 1
        local by = cy + s * 0.6 - phase * s * 1.7
        local bx = cx + math.sin(phase * 9 + i * 2) * s * 0.12
        love.graphics.circle("line", bx, by, 0.8 + (1 - phase) * 0.9)
    end
end

return ToxicTotem
