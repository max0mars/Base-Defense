local EffectManager = {}
EffectManager.__index = EffectManager

EffectManager.colors = {
    poison = {0.3, 1, 0.3, 1},
    burn = {1, 0.5, 0, 1},
    -- add other effect colors here
}

function EffectManager:new(owner, game)
    local instance = setmetatable({}, EffectManager)
    instance.owner = owner
    instance.game = game
    instance.activeEffects = {}
    instance.effectCounts = {}
    instance.parent = nil
    instance.currentModifiers = {}
    instance.taggedModifiers = {} -- For damage tags
    instance.tickerEffects = {}
    return instance
end

function EffectManager:recalculateStats()
    self.currentModifiers = {}
    self.taggedModifiers = {}
    self.tickerEffects = {}
    
    local function processManager(em, isParent)
        for _, effect in ipairs(em.activeEffects) do
            -- Only collect tickers from local manager to avoid double-updates
            if not isParent and (effect.onUpdate or effect.duration) then
                table.insert(self.tickerEffects, effect)
            end
            
            if effect.statModifiers then
                for statName, mod in pairs(effect.statModifiers) do
                    if effect.targetTags and #effect.targetTags > 0 then
                        if not self.taggedModifiers[statName] then self.taggedModifiers[statName] = {} end
                        table.insert(self.taggedModifiers[statName], {
                            tags = effect.targetTags,
                            add = mod.add or mod.additive or 0,
                            mult = mod.mult or mod.multiplier or 0,
                            max = mod.max or 0
                        })
                    else
                        if not self.currentModifiers[statName] then
                            self.currentModifiers[statName] = {add = 0, mult = 0, max = 0}
                        end
                        local m = self.currentModifiers[statName]
                        m.add = m.add + (mod.add or mod.additive or 0)
                        m.mult = m.mult + (mod.mult or mod.multiplier or 0)
                        if mod.max then
                            m.max = math.max(m.max, mod.max)
                        end
                    end
                end
            end
        end
    end

    processManager(self, false)
    if self.parent then
        processManager(self.parent, true)
    end
end

function EffectManager:propagateRecalculation()
    if self.game and self.game.objects then
        for _, obj in ipairs(self.game.objects) do
            if obj.effectManager then
                obj.effectManager:recalculateStats()
            end
        end
    end
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

    if currentStacks < maxStacks then
        table.insert(self.activeEffects, effect)
        self.effectCounts[name] = currentStacks + 1
        self:recalculateStats()
        if not self.owner then
            self:propagateRecalculation()
        end
        if effect.onApply then
            effect:onApply(self.owner, source)
        end
    end
end

function EffectManager:update(dt)
    local changed = false
    for i = #self.tickerEffects, 1, -1 do
        local effect = self.tickerEffects[i]
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
                -- Find and remove from activeEffects
                for j = 1, #self.activeEffects do
                    if self.activeEffects[j] == effect then
                        table.remove(self.activeEffects, j)
                        break
                    end
                end
                changed = true
            end
        end
    end
    if changed then
        self:recalculateStats()
        if not self.owner then
            self:propagateRecalculation()
        end
    end
end

-- Removed drawStatusEffects (moved to UI/LivingObject)

function EffectManager:getEffect(name)
    for _, effect in ipairs(self.activeEffects) do
        if effect.name == name then
            return effect
        end
    end
    return nil
end

function EffectManager:removeEffect(effect)
    for i = #self.activeEffects, 1, -1 do
        if self.activeEffects[i] == effect then
            self.effectCounts[effect.name] = (self.effectCounts[effect.name] or 1) - 1
            table.remove(self.activeEffects, i)
            self:recalculateStats()
            if not self.owner then
                self:propagateRecalculation()
            end
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
    local mod = self.currentModifiers[statName]
    if not mod then return baseValue end
    return (baseValue + mod.add + mod.max) * (1 + mod.mult)
end

function EffectManager:getDamage(baseValue, damageTags)
    local mult = 0
    local add = 0
    local max = 0

    -- Global modifiers
    local mod = self.currentModifiers["damage"]
    if mod then
        mult = mod.mult
        add = mod.add
        max = mod.max
    end

    -- Tagged modifiers
    local tagged = self.taggedModifiers["damage"]
    if tagged and damageTags then
        for _, tMod in ipairs(tagged) do
            local applies = false
            for _, tag in ipairs(damageTags) do
                for _, targetTag in ipairs(tMod.tags) do
                    if tag == targetTag then applies = true; break end
                end
                if applies then break end
            end
            if applies then
                mult = mult + tMod.mult
                add = add + tMod.add
                max = math.max(max, tMod.max)
            end
        end
    end

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
            -- Add generic named effects if not already shown via modifiers/abilities
            if effect.name and not effect.hidden and not seenAbilities[effect.name] then
                local nameFoundInStats = false
                if effect.statModifiers then
                    for k, _ in pairs(effect.statModifiers) do
                        if nameMap[k] then nameFoundInStats = true; break end
                    end
                end
                if not nameFoundInStats then
                    table.insert(strings, effect.name)
                    seenAbilities[effect.name] = true
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

-- Removed drawTooltip (moved to TooltipManager)

return EffectManager