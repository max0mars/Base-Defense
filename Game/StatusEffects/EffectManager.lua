local StatusEffectManager = {}
StatusEffectManager.__index = StatusEffectManager

function StatusEffectManager:new(owner)
    if not owner then
        error("StatusEffectManager requires an owner.")
    end
    local instance = setmetatable({}, StatusEffectManager)
    instance.owner = owner
    instance.effects = {
        poison = {},
        -- add other effects
    }
    return instance
end

function StatusEffectManager:applyEffect(effect)
    if #self.effects[effect.name] >= effect.maxStacks then
        -- max stacks
    else
        table.insert(self.effects[effect.name], effect)
        effect:onApply(self.owner) -- Call the onApply function when the effect is applied
    end
end

function StatusEffectManager:update(dt)
    for effectName, effectList in pairs(self.effects) do
        for i = #effectList, 1, -1 do
            local effect = effectList[i]
            if effect.onUpdate then
                effect:onUpdate(dt, self.owner) -- Call the onUpdate function every update
            end
            effect.duration = effect.duration - dt
            if effect.duration <= 0 then
                if effect.onExpire then
                    effect:onExpire(self.owner) -- Call the onExpire function when the effect expires
                end
                table.remove(effectList, i) -- Remove expired effect
            end
        end
    end
end

function StatusEffectManager:removeEffect(effect)

end

return StatusEffectManager