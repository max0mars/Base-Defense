local StatusEffect = require("Game.Effects.StatusEffects.StatusEffect")
local Poison = setmetatable({}, StatusEffect)
Poison.__index = Poison

local default = {
    name = "poison",
    duration = 5, -- Duration in seconds
    dps = 10, -- Damage dealt per second
    --maxStacks = 3, -- Maximum number of stacks for this effect
}

function Poison:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    local effect = StatusEffect:new(config)
    return setmetatable(effect, Poison)
end

function Poison:onApply(target, source)
    -- This sets the final values once, purely at the time of application.
    if source and source.getStat then
        self.dps = source:getStat("dps") or self.dps
        self.duration = source:getStat("duration") or self.duration
    end
end

function Poison:onUpdate(dt, target)
    target:takeDamage(self.dps * dt, "poison")
end

return Poison