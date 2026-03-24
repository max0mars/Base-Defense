local Turret = require("Buildings.Turrets.Turret")

local AutoCannon = setmetatable({}, { __index = Turret })
AutoCannon.__index = AutoCannon

local default = {
    fireRate = 5,   -- 5 shots per second
    damage = 5,     -- Low damage per shot
    bulletSpeed = 500, 
    range = 350,    -- Shorter range than standard
    types = { turret = true },
    color = {0.8, 0.8, 0.2, 1}, -- Gold
    firingArc = {
        direction = 0,    -- Firing arc facing direction in radians
        minRange = 0,     -- Minimum firing range
        angle = math.pi/4   -- Firing arc angle size in radians
    }
}

function AutoCannon:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    local t = Turret:new(config)
    setmetatable(t, { __index = self })
    return t
end

return AutoCannon
