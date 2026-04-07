local Turret = require("Buildings.Turrets.Turret")

local HeavyGun = setmetatable({}, { __index = Turret })
HeavyGun.__index = HeavyGun

local default = {
    fireRate = 0.7,   -- 5 shots per second
    damage = 50,     -- Low damage per shot
    bulletSpeed = 500, 
    types = { turret = true },
    color = {0.8, 0.8, 0.2, 1}, -- Gold
    firingArc = {
        direction = 0,    -- Firing arc facing direction in radians
        minRange = 0,     -- Minimum firing range
        angle = math.pi/4   -- Firing arc angle size in radians
    }
}

function HeavyGun:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    local t = Turret:new(config)
    setmetatable(t, { __index = self })
    return t
end

return HeavyGun
