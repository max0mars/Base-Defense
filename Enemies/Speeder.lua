local Enemy = require("Enemies.Enemy")
local speeder = setmetatable({}, {__index = Enemy})
speeder.__index = speeder

local default = {
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

function speeder:drawCustomShape(mode, cx, cy)
    -- Dart shape pointing left
    love.graphics.polygon(mode, cx - 7, cy, cx + 7, cy - 4, cx + 4, cy, cx + 7, cy + 4)
end

return speeder
