local Enemy = require("Enemies.Enemy")
local tank = setmetatable({}, {__index = Enemy})
tank.__index = tank

local default = {
    speed = 15, -- Set speed for tank
    maxHp = 1300,
    damage = 30,
    color = {1, 1, 0, 1}, -- Default color for basic enemies
    types = { tank = true },
    size = 45,
    reward = 100
}

function tank:new(config)
    if not config.types then config.types = {} end
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    for key in pairs(default.types) do
        config.types[key] = true
    end
    local instance = Enemy:new(config)
    setmetatable(instance, tank)
    
    return instance
end

return tank