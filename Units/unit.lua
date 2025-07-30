local parent = require("Classes.living_object")

local unit = setmetatable({}, {__index = parent})
unit.__index = unit

local stats = {
    tag = "unit", -- Tag for collision detection
}

function unit:new(config)
    for key, value in pairs(stats) do
        config[key] = config[key] or value -- Use default values if not provided
    end
    local instance = parent:new(config)
    setmetatable(instance, {__index = self})
    return instance
end

