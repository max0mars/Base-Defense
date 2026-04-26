local EffectManager = {}
EffectManager.__index = EffectManager

local colors = {
    poison = {0.3, 1, 0.3, 1},
    -- add other effect colors here
}

function EffectManager:new(owner)
    if(owner == nil) then
        print("Warning: EffectManager created without an owner")
    end
    local instance = setmetatable({}, EffectManager)
    instance.owner = owner
    instance.activeEffects = {}
    instance.effectCounts = {}
    instance.isDirty = true
    instance.version = 0
    instance.parent = nil
    instance.lastParentVersion = 0
    instance.cache = {}
    return instance
end

function EffectManager:incrementVersion()
    self.version = self.version + 1
    self.isDirty = true
end

function EffectManager:applyEffect(effectTemplate, source)
    local effect = {}
    for k, v in pairs(effectTemplate) do
        effect[k] = v
    end
    setmetatable(effect, getmetatable(effectTemplate) or effectTemplate)

    if effect.isIndependent then
        if effect.onApply then
            effect:onApply(self.owner, source)
        end
        return
    end

    local name = effect.name
    local currentStacks = self.effectCounts[name] or 0
    local maxStacks = effect.maxStacks or math.huge

    if currentStacks >= maxStacks then
        -- max stacks reached
    else
        table.insert(self.activeEffects, effect)
        self.effectCounts[name] = currentStacks + 1
        self:incrementVersion()
        if effect.onApply then
            effect:onApply(self.owner, source)
        end
    end
end

function EffectManager:update(dt)
    local changed = false
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
                changed = true
            end
        end
    end
    if changed then
        self:incrementVersion()
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
            self:incrementVersion()
            break
        end
    end
end

function EffectManager:triggerEvent(eventName, ...)
    -- Trigger local effects
    for i = 1, #self.activeEffects do
        local effect = self.activeEffects[i]
        if effect[eventName] and type(effect[eventName]) == "function" then
            effect[eventName](effect, ...)
        end
    end
    -- Trigger parent effects
    if self.parent then
        self.parent:triggerEvent(eventName, ...)
    end
end

function EffectManager:getStat(statName, baseValue)
    if baseValue == nil then
        error("EffectManager:getStat called with nil baseValue for stat " .. statName)
    end
    
    local parentVersionChanged = (self.parent and self.parent.version > self.lastParentVersion)
    if self.isDirty or parentVersionChanged then
        self.cache = {}
        self.isDirty = false
        if self.parent then
            self.lastParentVersion = self.parent.version
        end
    end
    
    if self.cache[statName] then
        return self.cache[statName]
    end
    
    local multiplierSum, additiveSum, maxValue = self:_getModifierSums(statName)
    
    local finalValue = (baseValue + additiveSum + maxValue) * (1 + multiplierSum)
    self.cache[statName] = finalValue
    return finalValue
end

-- Helper for recursive summation without full finalValue calculation
function EffectManager:_getModifierSums(statName, damageTags)
    local multiplierSum = 0.0
    local additiveSum = 0.0
    local maxValue = 0.0

    for i = 1, #self.activeEffects do
        local effect = self.activeEffects[i]
        local mod = effect.statModifiers and effect.statModifiers[statName]
        if mod then
            local applies = true
            if statName == "damage" then
                if effect.targetTags and #effect.targetTags > 0 then
                    applies = false
                    if damageTags then
                        for _, tag in ipairs(damageTags) do
                            for _, targetTag in ipairs(effect.targetTags) do
                                if tag == targetTag then applies = true; break end
                            end
                            if applies then break end
                        end
                    end
                end
            end

            if applies then
                multiplierSum = multiplierSum + (mod.mult or mod.multiplier or 0)
                additiveSum = additiveSum + (mod.add or mod.additive or 0)
                if mod.max then
                    maxValue = math.max(maxValue, mod.max)
                end
            end
        end
    end

    if self.parent then
        local pMult, pAdd, pMax = self.parent:_getModifierSums(statName, damageTags)
        multiplierSum = multiplierSum + pMult
        additiveSum = additiveSum + pAdd
        maxValue = math.max(maxValue, pMax)
    end

    return multiplierSum, additiveSum, maxValue
end

function EffectManager:getDamage(baseValue, damageTags)
    local mult, add, max = self:_getModifierSums("damage", damageTags)
    return (baseValue + add + max) * (1 + mult)
end

function EffectManager:getTooltipStrings()
    local strings = {}
    local nameMap = {}
    local flatMap = {}
    local multMap = {}
    local maxMap = {}
    local seenAbilities = {}
    
    local function processEffects(em)
        for _, effect in ipairs(em.activeEffects) do
            if effect.statModifiers then
                for statName, mod in pairs(effect.statModifiers) do
                    if not mod.hidden then
                        nameMap[statName] = true
                        flatMap[statName] = (flatMap[statName] or 0) + (mod.add or mod.additive or 0)
                        multMap[statName] = (multMap[statName] or 0) + (mod.mult or mod.multiplier or 0)
                        maxMap[statName] = math.max(maxMap[statName] or 0, mod.max or 0)
                    end
                end
            end
            if effect.grantedHitEffect then
                local rawName = effect.grantedHitEffect.name or "Ability"
                if not seenAbilities[rawName] then
                    local abilityName = rawName:gsub("^%l", string.upper)
                    table.insert(strings, string.format("%s on Hit", abilityName))
                    seenAbilities[rawName] = true
                end
            end
        end
        if em.parent then processEffects(em.parent) end
    end
    
    processEffects(self)
    
    for statName, _ in pairs(nameMap) do
        local flat = (flatMap[statName] or 0) + (maxMap[statName] or 0)
        local mult = multMap[statName] or 0
        
        local displayStat = statName:gsub("^%l", string.upper)
        if flat ~= 0 then
            local sign = flat > 0 and "+" or ""
            table.insert(strings, string.format("%s = %s%g", displayStat, sign, flat))
        end
        if mult ~= 0 then
            local sign = mult > 0 and "+" or ""
            table.insert(strings, string.format("%s = %s%g%%", displayStat, sign, mult * 100))
        end
    end
    return strings
end

function EffectManager:drawTooltip(drawx, drawy)
    local strings = self:getTooltipStrings()
    if #strings == 0 then return end
    
    local font = love.graphics.getFont()
    local lineHeight = font:getHeight()
    local padding = 5
    local boxHeight = padding * 2 + #strings * lineHeight
    
    local maxWidth = 0
    for _, str in ipairs(strings) do
        local w = font:getWidth(str)
        if w > maxWidth then maxWidth = w end
    end
    local boxWidth = maxWidth + padding * 2
    
    local tipX = drawx - boxWidth / 2
    local tipY = drawy - 30 - boxHeight -- 30 pixels above gives room for health bar
    
    -- Ensure it doesn't go off the left side (or right side)
    if tipX < 5 then
        tipX = 5
    elseif tipX + boxWidth > VIRTUAL_WIDTH - 5 then
        tipX = VIRTUAL_WIDTH - 5 - boxWidth
    end
    
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", tipX, tipY, boxWidth, boxHeight)
    
    love.graphics.setColor(1, 1, 1, 1)
    for i, str in ipairs(strings) do
        love.graphics.print(str, tipX + padding, tipY + padding + (i - 1) * lineHeight)
    end
    love.graphics.setColor(r, g, b, a)
end

return EffectManager