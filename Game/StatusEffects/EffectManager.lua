local StatusEffectManager = {}
StatusEffectManager.__index = StatusEffectManager

local colors = {
    poison = {0.3, 1, 0.3, 1},
    -- add other effect colors here
}

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
    print("applied " .. effect.name)
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
                print("updating " .. effect.name)
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


-- Draws status effect icons (colored circles with stack numbers) above the owner's health bar
function StatusEffectManager:drawStatusEffects()
    local iconSize = 16 -- constant size for all objects
    local spacing = 4   -- space between icons
    -- Get health bar position and size from owner
    if not self.owner or not self.owner.getHealthBarRect then return end
    local x, y, width, height = self.owner:getHealthBarRect()
    if not (x and y and width and height) then return end

    local effectCount = 0
    for effectName, effectList in pairs(self.effects) do
        if #effectList > 0 then
            effectCount = effectCount + 1
        end
    end
    if effectCount == 0 then return end
    local totalWidth = effectCount * iconSize + (effectCount-1) * spacing
    local drawX = x + (width - totalWidth) / 2
    local drawY = y - iconSize - 2 -- just above health bar

    local i = 0
    for effectName, effectList in pairs(self.effects) do
        if #effectList > 0 then
            local color = colors[effectName] or {1,1,1,1}
            love.graphics.setColor(color)
            love.graphics.circle("fill", drawX + i*(iconSize+spacing) + iconSize/2, drawY + iconSize/2, iconSize/2)
            love.graphics.setColor(0,0,0,1)
            love.graphics.printf(tostring(#effectList), drawX + i*(iconSize+spacing), drawY + 2, iconSize, "center")
            i = i + 1
        end
    end
    love.graphics.setColor(1,1,1,1)
end

function StatusEffectManager:removeEffect(effect)

end

return StatusEffectManager