local Enemy = require("Enemies.Enemy")
local speeder = setmetatable({}, {__index = Enemy})
speeder.__index = speeder

local default = {
    speed = 120, -- Set speed for speeder
    hp = 25, -- Set health for speeder
    maxHp = 25,
    color = {0, 1, 0, 1}, -- Default color for basic enemies
    types = { speeder = true },
    size = 15,
    reward = 15
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

return speeder