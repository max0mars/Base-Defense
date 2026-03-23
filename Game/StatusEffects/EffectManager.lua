local EffectManager = {}
EffectManager.__index = EffectManager

local colors = {
    poison = {0.3, 1, 0.3, 1},
    -- add other effect colors here
}

function EffectManager:new(owner)
    if not owner then
        error("EffectManager requires an owner.")
    end
    local instance = setmetatable({}, EffectManager)
    instance.owner = owner
    instance.effects = {}
    return instance
end

function EffectManager:applyEffect(effectTemplate)
    print("applied " .. tostring(effectTemplate.name))
    
    local effect = {}
    for k, v in pairs(effectTemplate) do
        effect[k] = v
    end
    setmetatable(effect, getmetatable(effectTemplate) or effectTemplate)

    local name = effect.name
    if not self.effects[name] then
        self.effects[name] = {}
    end

    local maxStacks = effect.maxStacks or math.huge
    if #self.effects[name] >= maxStacks then
        -- max stacks reached
    else
        table.insert(self.effects[name], effect)
        if effect.onApply then
            effect:onApply(self.owner)
        end
    end
end


function EffectManager:update(dt)
    for effectName, effectList in pairs(self.effects) do
        for i = #effectList, 1, -1 do
            local effect = effectList[i]
            if effect.onUpdate then
                -- print("updating " .. effect.name)
                effect:onUpdate(dt, self.owner)
            end
            if effect.duration then
                effect.duration = effect.duration - dt
                if effect.duration <= 0 then
                    if effect.onExpire then
                        effect:onExpire(self.owner)
                    end
                    table.remove(effectList, i)
                end
            end
        end
    end
end


-- Draws status effect icons (colored circles with stack numbers) above the owner's health bar
function EffectManager:drawStatusEffects()
    local iconSize = 4 -- constant size for all objects (4x smaller)
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

function EffectManager:removeEffect(effect)

end

function EffectManager:triggerEvent(eventName, ...)
    for effectName, effectList in pairs(self.effects) do
        for i = 1, #effectList do
            local effect = effectList[i]
            if effect[eventName] and type(effect[eventName]) == "function" then
                effect[eventName](effect, ...)
            end
        end
    end
end

function EffectManager:calculateStat(statName, baseValue)
    local multiplierSum = 1.0
    local additiveSum = 0.0

    for effectName, effectList in pairs(self.effects) do
        for i = 1, #effectList do
            local effect = effectList[i]
            if effect.statModifiers and effect.statModifiers[statName] then
                local mod = effect.statModifiers[statName]
                multiplierSum = multiplierSum + (mod.mult or mod.multiplier or 0)
                additiveSum = additiveSum + (mod.add or mod.additive or 0)
            end
        end
    end

    return baseValue * multiplierSum + additiveSum
end

return EffectManager