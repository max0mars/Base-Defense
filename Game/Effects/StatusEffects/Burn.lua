local Burn = {
    timePerTick = 1
}
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
    instance.duration = config.duration_burn

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
        elseif source:getStat("dps_burn") > 0 then
            -- Fall back to flat dps_burn from source if provided
            self.dps_burn = source:getStat("dps_burn")
        end
        
        local sourceDuration = source:getStat("duration_burn")
        if sourceDuration > 0 then
            self.duration_burn = sourceDuration
        end
        self.duration = self.duration_burn
    end
end

function Burn:onUpdate(dt, target)
    self.time = self.time + dt
    if self.time >= self.timePerTick then
        target:takeDamage(self.dps_burn * self.timePerTick, "fire")
        self.time = self.time - self.timePerTick
    end
end

return Burn