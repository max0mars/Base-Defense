local Buff = require("Buildings.Passives.Buff")

local ColdTactics = setmetatable({}, Buff)
ColdTactics.__index = ColdTactics

-- Nearby turrets deal +10% damage per chill stack on the enemy they hit
-- (a frozen enemy counts as max stacks). Affects the 5 surrounding slots that
-- aren't on its left.
local default = {
    name = "Cold Tactics",
    types = { passive = true },
    affectedSlots = {{0, -1}, {1, -1}, {1, 0}, {1, 1}, {0, 1}},
    color = {0.55, 0.85, 1, 1}, -- Ice blue
    damagePerStack = 0.1,
}

function ColdTactics:new(config)
    config = config or {}
    for key, value in pairs(default) do
        if config[key] == nil then
            config[key] = value
        end
    end

    config.effect = {
        name = "Cold Tactics",
        duration = math.huge,
        targetTypes = { turret = true },
        damageVsChill = { perStack = config.damagePerStack },
    }

    local obj = Buff:new(config)
    setmetatable(obj, self)
    return obj
end

return ColdTactics
