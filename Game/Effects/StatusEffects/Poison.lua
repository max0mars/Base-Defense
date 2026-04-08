local Poison = {}
Poison.__index = Poison

function Poison:new(config)
    if not config then
        error("Developer Error: Poison effect called with nil config.")
    end

    local required = {"duration", "dps_poison", "maxStacks"}
    for _, key in ipairs(required) do
        if config[key] == nil then
            error("Developer Error: Poison is missing the '" .. key .. "' field in config.")
        end
    end

    local instance = setmetatable({}, Poison)
    -- for k, v in pairs(config) do 
    --     instance[k] = v
    -- end

    -- Ensure we have a name for the EffectManager stacking and icons
    instance.name = config.name or "poison"
    
    return instance
end

function Poison:onApply(target, source)
    -- This sets the final values once, purely at the time of application.
    if source and source.getStat then
        self.dps_poison = source:getStat("dps_poison")
        self.duration = source:getStat("duration")
    end
end

function Poison:onUpdate(dt, target)
    target:takeDamage(self.dps_poison * dt, "poison")
end

return Poison