local Buff = require("Buildings.Passives.Buff")

local ShardBullets = setmetatable({}, Buff)
ShardBullets.__index = ShardBullets

local default = {
    name = "Shard Bullets",
    types = { passive = true },
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
            recursion = {add = 1},
            recursionSpread = {max = math.rad(10), hidden=true}
        }
    }
    
    local obj = Buff:new(config)
    setmetatable(obj, self)
    return obj
end

-- Sprite: a round that forks, then forks again
function ShardBullets:drawShape(cx, cy, s)
    local forkX, tipX = cx + s * 0.2, cx + s * 0.95
    love.graphics.line(cx - s, cy, cx - s * 0.45, cy)
    love.graphics.line(cx - s * 0.45, cy, forkX, cy - s * 0.5, tipX, cy - s * 0.85)
    love.graphics.line(forkX, cy - s * 0.5, tipX, cy - s * 0.2)
    love.graphics.line(cx - s * 0.45, cy, forkX, cy + s * 0.5, tipX, cy + s * 0.85)
    love.graphics.line(forkX, cy + s * 0.5, tipX, cy + s * 0.2)
end

function ShardBullets:drawDetail(cx, cy, s, pulse)
    love.graphics.circle("fill", cx - s * 0.45, cy, 2)
    love.graphics.setColor(1, 1, 1, 0.6 + pulse * 0.4)
    for _, y in ipairs({ -0.85, -0.2, 0.2, 0.85 }) do
        love.graphics.circle("fill", cx + s * 0.95, cy + y * s, 1.1)
    end
end

return ShardBullets
