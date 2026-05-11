local Buff = require("Buildings.Buffs.Buff")

local RangeBuff = setmetatable({}, Buff)
RangeBuff.__index = RangeBuff

function RangeBuff:new(config)
    config = config or {}
    
    -- Define the specific configuration for the Range Buff
    config.color = {0.2, 0.6, 0.8, 1} -- Light blue
    config.affectedSlots = {{0, 1}, {1, 1}, {0, -1}, {1, -1}}
    config.shapePattern = {
        {0, 0}, {1, 0}
    }
    
    config.effect = {
        name = "Range Buff",
        duration = math.huge,
        statModifiers = {
            range = { mult = 0.2 }
        }
    }
    
    local rb = setmetatable(Buff:new(config), { __index = self })
    return rb
end

return RangeBuff
