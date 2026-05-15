local Buff = require("Buildings.Buffs.Buff")

local ShardBullets = setmetatable({}, Buff)
ShardBullets.__index = ShardBullets

local default = {
    name = "Shard Bullets",
    types = { passive = true, totem = true, shard = true },
    affectedSlots = {{-1, 0}, {1, 0}}, -- Only affects building directly in front
    shapePattern = {
        {0, 0}
    },
    color = {0.3, 0.3, 0.8, 1}, -- Steel blue for sharding
}

function ShardBullets:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    
    -- Create the effect that the Totem applies to the turret
    -- This effect now adds stats that tell the split effect to scale with damage
    config.effect = {
        name = "Sharding Bullets",
        duration = math.huge,
        statModifiers = {
            recursion = {add = 1}
        }
    }
    
    local obj = Buff:new(config)
    setmetatable(obj, self)
    return obj
end

return ShardBullets
