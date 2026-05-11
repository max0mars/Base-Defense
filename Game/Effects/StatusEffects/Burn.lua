local Burn = {}
Burn.__index = Burn

function Burn:new(config)
    if not config then
        error("Developer Error: Burn effect called with nil config.")
    end

    local required = {"duration_burn", "dps_burn", "maxStacks"}
    for _, key in ipairs(required) do
        if config[key] == nil then
            error("Developer Error: Burn is missing the '" .. key .. "' field in config.")
        end
    end

    local instance = setmetatable({}, Burn)
    for k, v in pairs(config) do 
        instance[k] = v
    end
    instance.time = 0

    -- Ensure we have a name for the EffectManager stacking and icons
    instance.name = config.name or ("burn")
    
    return instance
end

function Burn:onApply(target, source)
    if source and source.getStat then
        local mult = source:getStat("burn_from_damage")
        
        if mult > 0 then
            -- Scale dps_burn based on the bullet's damage
            self.dps_burn = source:getStat("damage") * mult
            print("applied burn with " .. self.dps_burn .. " dps")
        else
            -- Fall back to flat dps_burn
            self.dps_burn = source:getStat("dps_burn")
        end
        
        self.duration_burn = source:getStat("duration_burn")
        -- The EffectManager handles the actual 'duration' countdown if we set it here
        self.duration = self.duration_burn
    end
end

function Burn:onUpdate(dt, target)
    self.time = self.time + dt
    if self.time >= 1 then
        target:takeDamage(self.dps_burn, "fire")
        self.time = 0
    end
end

return Burn