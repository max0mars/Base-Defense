local Blocker = require("Buildings.Blockers.Blocker")

local box = setmetatable({}, Blocker)
box.__index = box

local default = {
    shapePattern = {
        {0, 0}, {1, 0}, {0, 1}, {1, 1}
    },
}

function box:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    
    local obj = setmetatable(Blocker.new(self, config), { __index = self })
    return obj
end

return box

