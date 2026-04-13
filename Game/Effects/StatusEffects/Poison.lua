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
    for k, v in pairs(config) do 
        instance[k] = v
    end

    -- Ensure we have a name for the EffectManager stacking and icons
    instance.name = config.name or ("poison")
    
    return instance
end

function Poison:onApply(target, source)
    -- This sets the final values once, purely at the time of application.
    -- We use pcall because some buildings (like MainTurret) might not have these stats natively,
    -- in which case we fall back to the defaults provided during the effect's creation (e.g., from a Totem).
    if source and source.getStat then
        local mult = 0
        pcall(function() mult = source:getStat("poison_from_damage") end)
        
        if mult > 0 then
            -- Scale dps_poison based on the bullet's damage
            self.dps_poison = source:getStat("damage") * mult
        else
            -- Fall back to flat dps_poison
            pcall(function()
                self.dps_poison = source:getStat("dps_poison")
            end)
        end
        
        pcall(function()
            self.duration = source:getStat("duration")
        end)
    end
end

function Poison:onUpdate(dt, target)
    target:takeDamage(self.dps_poison * dt, "poison")
end

return Poison