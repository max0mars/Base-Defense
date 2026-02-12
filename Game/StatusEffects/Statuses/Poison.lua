local StatusEffect = require("Game.StatusEffects.StatusEffect")
local Poison = setmetatable({}, StatusEffect)
Poison.__index = Poison

local default = {
    name = "poison",
    duration = 5, -- Duration in seconds
    damagePerSecond = 10, -- Damage dealt per second
    maxStacks = 3, -- Maximum number of stacks for this effect
}

function Poison:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    local effect = StatusEffect:new(config)
    return setmetatable(effect, Poison)
end

function Poison:onUpdate(dt, target)
    local damage = self.damagePerSecond * dt
    target:takeDamage(damage, "poison")
end

return Poison