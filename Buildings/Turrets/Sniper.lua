local Turret = require("Buildings.Turrets.Turret")

local Sniper = setmetatable({}, { __index = Turret })
Sniper.__index = Sniper

local default = {
    fireRate = 0.5, -- 1 shot every 2 seconds
    damage = 150,    -- High damage
    bulletSpeed = 1200, -- Very fast bullet
    range = 1000,   -- Huge range coverage
    types = { turret = true },
    color = {0.8, 0.2, 0.2, 1}, -- Dark Red
    firingArc = {
        direction = 0,    -- Firing arc facing direction in radians
        minRange = 0,     -- Minimum firing range
        angle = math.pi/32   -- Firing arc angle size in radians
    }
}

function Sniper:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    local t = Turret:new(config)
    setmetatable(t, { __index = self })
    return t
end

return Sniper
