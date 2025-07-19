local parent = require("Scripts.living_object")

local unit = setmetatable({}, {__index = parent})
unit.__index = unit

local stats = {
    speed = 50,
    damage = 5,
    range = 100,
    size = 10, -- Default size for units
    shape = "rectangle", -- Default shape for units
    color = {0, 1, 0, 1}, -- Default color for units
    hitbox = {
        shape = "rectangle",
    },
    hp = 50, -- Default health for units
    maxHp = 50, -- Maximum health for units
    tag = "unit", -- Tag for collision detection
}

function unit:new(config)
    for key, value in pairs(Stats) do
        config[key] = config[key] or value -- Use default values if not provided
    end
    local instance = parent:new(config)
    setmetatable(instance, {__index = self})
    return instance
end

