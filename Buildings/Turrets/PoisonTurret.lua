local Turret = require("Buildings.Turrets.Turret")
local PoisonEffect = require("Game.StatusEffects.Statuses.Poison")

local PoisonTurret = setmetatable({}, { __index = Turret })
PoisonTurret.__index = PoisonTurret

local default = {
    fireRate = 2, -- Slower fire rate than regular turret
    damage = 5,
    color = {0.5, 1, 0.5, 1} -- Greenish color to indicate poison effect
}

function PoisonTurret:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    local t = Turret:new(config)
    setmetatable(t, { __index = self })
    t:addHitEffect(PoisonEffect:new{})
    return t
end

return PoisonTurret
