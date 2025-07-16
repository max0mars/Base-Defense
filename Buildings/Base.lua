local Base = {
}
setmetatable(Base, { __index = require("Scripts.object") }) -- Inherit from the object class

local living_object = require("Scripts.living_object") -- Import the living_object module

function Base:new(config)
    local obj = living_object:new(config)
    setmetatable(obj, { __index = self })
    -- obj.w = config.w or 100
    -- obj.h = config.h or 400
    -- obj.hp = config.hp or 1000
    -- obj.maxHp = config.maxHp or 1000 -- Store the maximum health
    -- obj.color = {love.math.colorFromBytes(69, 69, 69)}
    return obj
end

return Base