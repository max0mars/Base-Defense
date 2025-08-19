local Base = {
}
local living_object = require("Classes.living_object") -- Import the living_object module
setmetatable(Base, { __index = living_object }) -- Inherit from the object class

function Base:new(config)
    local obj = living_object:new(config)
    setmetatable(obj, { __index = self })
    obj.buildGrid = {
        width = config.buildGrid.width,
        height = config.buildGrid.height,
        buildings = {}
    }
    return obj
end

return Base