local Poison = {}
Poison.__index = Poison

function Poison:new(config)
    if not config then
        error("Developer Error: Poison effect called with nil config.")
    end

    local required = {"duration_poison", "dps_poison", "maxStacks"}
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
    if source and source.getStat then
        local mult = source:getStat("poison_from_damage")
        
        if mult > 0 then
            -- Scale dps_poison based on the bullet's damage
            self.dps_poison = source:getStat("damage") * mult
            print("applied poison with " .. self.dps_poison .. " dps")
        else
            -- Fall back to flat dps_poison
            self.dps_poison = source:getStat("dps_poison")
        end
        
        self.duration_poison = source:getStat("duration_poison")
    end
end

function Poison:onUpdate(dt, target)
    target:takeDamage(self.dps_poison * dt, "poison")
end

return Poison