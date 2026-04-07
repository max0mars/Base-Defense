local Blocker = require("Buildings.Blockers.Blocker")

local fence = setmetatable({}, Blocker)
fence.__index = fence

local default = {
    shapePattern = {
        {-1, 0}, {0, 0}, {1, 0}
    },
}

function fence:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    
    local obj = setmetatable(Blocker.new(self, config), { __index = self })
    return obj
end

return fence
