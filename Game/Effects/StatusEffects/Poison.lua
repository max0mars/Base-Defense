local StatusEffect = require("Game.Effects.StatusEffects.StatusEffect")
local Poison = setmetatable({}, StatusEffect)
Poison.__index = Poison

function Poison:new(config)
    if not config then
        error("Developer Error: Poison effect called with nil config.")
    end

    local required = {"name", "duration", "dps", "maxStacks"}
    for _, key in ipairs(required) do
        if config[key] == nil then
            error("Developer Error: Poison [" .. (config.name or "Unknown") .. "] is missing the '" .. key .. "' field in config.")
        end
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