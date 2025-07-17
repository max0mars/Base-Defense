local Base = {
}
local living_object = require("Scripts.living_object") -- Import the living_object module
setmetatable(Base, { __index = living_object }) -- Inherit from the object class

function Base:new(config)
    local obj = living_object:new(config)
    setmetatable(obj, { __index = self })
    return obj
end

return Base