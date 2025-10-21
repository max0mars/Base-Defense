local Enemy = require("Enemies.Enemy")
local speeder = setmetatable({}, {__index = Enemy})
speeder.__index = speeder

local default = {
    speed = 70, -- Set speed for speeder
    hp = 20, -- Set health for speeder
    maxHp = 20,
    color = {0, 1, 0, 1}, -- Default color for basic enemies
    size = 15
}

function speeder:new(config)
    for key, value in pairs(default) do
        config[key] = value
    end
    local instance = Enemy:new(config)
    setmetatable(instance, speeder)
    return instance
end

return speeder