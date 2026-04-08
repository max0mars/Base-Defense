local Turret = require("Buildings.Turrets.Turret")
local PoisonEffect = require("Game.Effects.StatusEffects.Poison")

local PoisonTurret = setmetatable({}, { __index = Turret })
PoisonTurret.__index = PoisonTurret

local default = {
    fireRate = 0.5, -- Hz (was 2s delay)
    damage = 5,
    color = {0.5, 1, 0.5, 1}, -- Greenish color to indicate poison effect
    types = { poison = true },
    dps = 15,
    duration = 4
}

function PoisonTurret:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    for key in pairs(default.types) do
        config.types[key] = true
    end
    local t = Turret:new(config)
    setmetatable(t, { __index = self })
    t:addHitEffect(PoisonEffect:new{})
    return t
end

return PoisonTurret
