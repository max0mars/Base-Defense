local IterativeEffect = {}
IterativeEffect.__index = IterativeEffect

--[[
Template for an iterative effect that scales every wave.
Example config:
{
    name = "Scaling Damage",
    displayName = "Scaling Damage",
    statModifiers = { damage = { mult = 1.0 } },
    iterativeChanges = {
        damage = { mult = -0.25 } -- Lose 25% damage multiplier each wave
    }
}
]]

function IterativeEffect:new(config)
    if not config then
        error("Developer Error: IterativeEffect called with nil config.")
    end

    local instance = setmetatable({}, IterativeEffect)
    -- Copy basic fields
    for k, v in pairs(config) do 
        if k ~= "statModifiers" and k ~= "iterativeChanges" then
            instance[k] = v
        end
    end
    
    instance.name = config.name or "Iterative Effect"
    
    -- Deep copy initial stat modifiers to avoid modifying a shared table
    instance.statModifiers = {}
    if config.statModifiers then
        for stat, mods in pairs(config.statModifiers) do
            instance.statModifiers[stat] = {
                add = mods.add or mods.additive or 0,
                mult = mods.mult or mods.multiplier or 0,
                max = mods.max or 0
            }
        end
    end

    -- iterativeChanges structure: { statName = { add = X, mult = Y, max = Z } }
    instance.iterativeChanges = config.iterativeChanges or {}
    
    -- iterativeLimits structure: { statName = { max_add = X, min_add = Y, max_mult = Z, min_mult = W } }
    instance.iterativeLimits = config.iterativeLimits or {}
    
    return instance
end

function IterativeEffect:onWaveComplete(target)
    for stat, changes in pairs(self.iterativeChanges) do
        if not self.statModifiers[stat] then
            self.statModifiers[stat] = {add = 0, mult = 0, max = 0}
        end
        local mods = self.statModifiers[stat]
        
        if changes.add then
            mods.add = mods.add + changes.add
            if self.iterativeLimits[stat] then
                if self.iterativeLimits[stat].max_add and mods.add > self.iterativeLimits[stat].max_add then mods.add = self.iterativeLimits[stat].max_add end
                if self.iterativeLimits[stat].min_add and mods.add < self.iterativeLimits[stat].min_add then mods.add = self.iterativeLimits[stat].min_add end
            end
        end
        if changes.mult then
            mods.mult = mods.mult + changes.mult
            if self.iterativeLimits[stat] then
                if self.iterativeLimits[stat].max_mult and mods.mult > self.iterativeLimits[stat].max_mult then mods.mult = self.iterativeLimits[stat].max_mult end
                if self.iterativeLimits[stat].min_mult and mods.mult < self.iterativeLimits[stat].min_mult then mods.mult = self.iterativeLimits[stat].min_mult end
            end
        end
        if changes.max then
            mods.max = mods.max + changes.max
        end
    end
end

return IterativeEffect
