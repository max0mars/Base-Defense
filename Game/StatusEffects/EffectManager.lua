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
    instance.activeEffects = {}
    instance.effectCounts = {}
    instance.isDirty = true
    instance.cache = {}
    return instance
end

function EffectManager:applyEffect(effectTemplate)
    local effect = {}
    for k, v in pairs(effectTemplate) do
        effect[k] = v
    end
    setmetatable(effect, getmetatable(effectTemplate) or effectTemplate)

    local name = effect.name
    local currentStacks = self.effectCounts[name] or 0
    local maxStacks = effect.maxStacks or math.huge

    if currentStacks >= maxStacks then
        -- max stacks reached
    else
        table.insert(self.activeEffects, effect)
        self.effectCounts[name] = currentStacks + 1
        self.isDirty = true
        if effect.onApply then
            effect:onApply(self.owner)
        end
    end
end

function EffectManager:update(dt)
    for i = #self.activeEffects, 1, -1 do
        local effect = self.activeEffects[i]
        if effect.onUpdate then
            effect:onUpdate(dt, self.owner)
        end
        if effect.duration then
            effect.duration = effect.duration - dt
            if effect.duration <= 0 then
                if effect.onExpire then
                    effect:onExpire(self.owner)
                end
                self.effectCounts[effect.name] = (self.effectCounts[effect.name] or 1) - 1
                table.remove(self.activeEffects, i)
                self.isDirty = true
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
    for name, count in pairs(self.effectCounts) do
        if count > 0 then
            effectCount = effectCount + 1
        end
    end
    if effectCount == 0 then return end
    local totalWidth = effectCount * iconSize + (effectCount-1) * spacing
    local drawX = x + (width - totalWidth) / 2
    local drawY = y - iconSize - 2 -- just above health bar

    local i = 0
    for name, count in pairs(self.effectCounts) do
        if count > 0 then
            local color = colors[name] or {1,1,1,1}
            love.graphics.setColor(color)
            love.graphics.circle("fill", drawX + i*(iconSize+spacing) + iconSize/2, drawY + iconSize/2, iconSize/2)
            love.graphics.setColor(0,0,0,1)
            love.graphics.printf(tostring(count), drawX + i*(iconSize+spacing), drawY + 2, iconSize, "center")
            i = i + 1
        end
    end
    love.graphics.setColor(1,1,1,1)
end

function EffectManager:removeEffect(effect)
    for i = #self.activeEffects, 1, -1 do
        if self.activeEffects[i] == effect then
            self.effectCounts[effect.name] = (self.effectCounts[effect.name] or 1) - 1
            table.remove(self.activeEffects, i)
            self.isDirty = true
            break
        end
    end
end

function EffectManager:triggerEvent(eventName, ...)
    for i = 1, #self.activeEffects do
        local effect = self.activeEffects[i]
        if effect[eventName] and type(effect[eventName]) == "function" then
            effect[eventName](effect, ...)
        end
    end
end

function EffectManager:getStat(statName, baseValue)
    if self.isDirty then
        self.cache = {}
        self.isDirty = false
    end
    
    if self.cache[statName] then
        return self.cache[statName]
    end

    local multiplierSum = 0.0
    local additiveSum = 0.0

    for i = 1, #self.activeEffects do
        local effect = self.activeEffects[i]
        if effect.statModifiers and effect.statModifiers[statName] then
            local mod = effect.statModifiers[statName]
            multiplierSum = multiplierSum + (mod.mult or mod.multiplier or 0)
            additiveSum = additiveSum + (mod.add or mod.additive or 0)
        end
    end
    
    local finalValue = (baseValue + additiveSum) * (1 + multiplierSum)
    self.cache[statName] = finalValue
    return finalValue
end

function EffectManager:getDamage(baseValue, damageTags)
    local multiplierSum = 0.0
    local additiveSum = 0.0

    for i = 1, #self.activeEffects do
        local effect = self.activeEffects[i]
        if effect.statModifiers and effect.statModifiers["damage"] then
            local applies = false
            if not effect.targetTags or #effect.targetTags == 0 then
                applies = true
            elseif damageTags then
                for _, tag in ipairs(damageTags) do
                    for _, targetTag in ipairs(effect.targetTags) do
                        if tag == targetTag then
                            applies = true
                            break
                        end
                    end
                    if applies then break end
                end
            end
            if applies then
                local mod = effect.statModifiers["damage"]
                multiplierSum = multiplierSum + (mod.mult or mod.multiplier or 0)
                additiveSum = additiveSum + (mod.add or mod.additive or 0)
            end
        end
    end

    return (baseValue + additiveSum) * (1 + multiplierSum)
end

return EffectManager