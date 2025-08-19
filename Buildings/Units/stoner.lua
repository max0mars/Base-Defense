local parent = require("Buildings.Units.unit")

local stoner = setmetatable({}, {__index = parent})
stoner.__index = stoner

local stats = {
    tag = "unit", -- Tag for collision detection
    health = 100, -- Default health value
    damage = 10, -- Default damage value
    range = 100, -- Default range value
    speed = 50, -- Default speed value
    size = 6, -- Default size for stoner units
    shape = "circle", -- Default shape for stoner units
    color = {0.5, 0.5, 1, 1}, -- Default color for stoner units
    
}

function stoner:new(config)
    local instance = parent:new(config)
    setmetatable(instance, {__index = self})
    return instance
end

return stoner
