local Enemy = require("Enemies.Enemy")
local speeder = setmetatable({}, {__index = Enemy})
speeder.__index = speeder

local default = {
    name = "Speeder",
    speed = 110, -- Reduced from 120 (carrier nerf)
    maxHp = 25,
    color = {0.8, 1, 0, 1}, -- Default color for basic enemies
    types = { speeder = true },
    size = 15,
    reward = 15,
    isFlying = false
}

function speeder:new(config)
    if not config.types then config.types = {} end
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    for key in pairs(default.types) do
        config.types[key] = true
    end
    local instance = Enemy:new(config)
    setmetatable(instance, speeder)
    return instance
end

function speeder:getTargetPos()
    -- Speeder's left tip is drawn at 7/15 of its size
    self.target = self.game.base.x + self.game.base.w / 2 + (self.w * 7 / 15)
end

function speeder:drawCustomShape(mode, cx, cy)
    local scale = self:getStat("size", 15) / 15
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(scale, scale)
    
    -- Dart shape pointing left
    love.graphics.polygon(mode, -7, 0, 7, -4, 4, 0, 7, 4)
    
    love.graphics.pop()
end

return speeder
