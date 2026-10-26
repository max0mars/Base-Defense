local Buff = require("Buildings.Passives.Buff")

local ColdTactics = setmetatable({}, Buff)
ColdTactics.__index = ColdTactics

-- Nearby turrets deal more damage the closer the enemy they hit is to freezing:
-- up to +50% just before freezing (+10% per stack on normal enemies), +50% while
-- frozen. Affects the 5 surrounding slots that aren't on its left.
local default = {
    name = "Cold Tactics",
    types = { passive = true },
    affectedSlots = {{0, -1}, {1, -1}, {1, 0}, {1, 1}, {0, 1}},
    color = {0.55, 0.85, 1, 1}, -- Ice blue
    maxBonus = 0.5,
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
        damageVsChill = { chilledMax = config.maxBonus, frozen = config.maxBonus },
    }

    local obj = Buff:new(config)
    setmetatable(obj, self)
    return obj
end

return ColdTactics
