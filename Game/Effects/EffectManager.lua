local EffectManager = {}
EffectManager.__index = EffectManager

EffectManager.colors = {
    poison = {0.3, 1, 0.3, 1},
    burn = {1, 0.5, 0, 1},
    toxic = {0.7, 0.2, 0.9, 1},
    Toxic = {0.7, 0.2, 0.9, 1},
    slow = {0.5, 0.8, 1.0, 1},
    slow_aura = {0.5, 0.8, 1.0, 1},
    GuardianAura = {0.6, 0.6, 0.6, 1},
    stun = {1, 1, 0, 1}, -- Yellow for stun
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

function EffectManager:getStackingKey(effect)
    if effect.globalStacks then
        return effect.displayName or effect.name
    end
    return effect.name
end

function EffectManager:recalculateStats()
    self.currentModifiers = {}
    self.taggedModifiers = {}
    self.tickerEffects = {}
    
    local function processManager(em, isParent)
        for _, effect in ipairs(em.activeEffects) do
            local matches = true
            if effect.targetTypes and self.owner then
                matches = false
                if type(self.owner.isType) == "function" then
                    for t, req in pairs(effect.targetTypes) do
                        if req and self.owner:isType(t) then
                            matches = true
                            break
                        end
                    end
                end
            end
            
            if matches then
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
                                self.currentModifiers[statName] = {add = 0, mult = 0, max = 0, compoundMult = 1}
                            end
                            local m = self.currentModifiers[statName]
                            m.add = m.add + (mod.add or mod.additive or 0)
                            m.mult = m.mult + (mod.mult or mod.multiplier or 0)
                            if mod.compoundMult then
                                m.compoundMult = m.compoundMult * mod.compoundMult
                            end
                            if mod.max then
                                m.max = math.max(m.max, mod.max)
                            end
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
    if effectTemplate.chance and math.random() > effectTemplate.chance then
        return
    end

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

    local stackingKey = self:getStackingKey(effect)
    local currentStacks = self.effectCounts[stackingKey] or 0
    
    local sourceMaxStacks = source and source.getStat and source:getStat("maxStacks")
    if sourceMaxStacks == nil or sourceMaxStacks <= 0 then
        sourceMaxStacks = effect.maxStacks
    end
    local maxStacks = sourceMaxStacks or math.huge
    if effect.globalStacks then
        maxStacks = effect.globalStacks
    end

    local inheritedTime = nil
    if currentStacks >= maxStacks then
        -- Find and remove the oldest stack of the same name to make room for the new one
        for i = 1, #self.activeEffects do
            if self:getStackingKey(self.activeEffects[i]) == stackingKey then
                inheritedTime = self.activeEffects[i].time
                table.remove(self.activeEffects, i)
                currentStacks = currentStacks - 1
                break
            end
        end
    end

    if currentStacks < maxStacks then
        if inheritedTime then
            effect.time = inheritedTime
        end
        table.insert(self.activeEffects, effect)
        self.effectCounts[stackingKey] = currentStacks + 1
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
                local key = self:getStackingKey(effect)
                self.effectCounts[key] = (self.effectCounts[key] or 1) - 1
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
            local key = self:getStackingKey(effect)
            self.effectCounts[key] = (self.effectCounts[key] or 1) - 1
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

function EffectManager:getStat(statName, baseValue, damageType, damageTags)
    local mod = self.currentModifiers[statName]
    
    local effAdd = mod and mod.add or 0
    local effMult = mod and mod.mult or 0
    local effMax = mod and mod.max or 0
    local effCompoundMult = mod and mod.compoundMult or 1

    local hasMod = mod ~= nil

    -- 1. Damage Type Modifiers
    if statName == "damage" then
        local dt = damageType
        if dt == nil and self.owner then
            dt = self.owner.damageType
        end
        
        local combinedTags = {}
        if damageTags then
            for _, tag in ipairs(damageTags) do
                table.insert(combinedTags, tag)
            end
        end
        if dt then
            table.insert(combinedTags, dt)
        end
        
        for _, tag in ipairs(combinedTags) do
            local dtModName = tag .. "_damage"
            local dtMod = self.currentModifiers[dtModName]
            if dtMod then
                effAdd = effAdd + (dtMod.add or 0)
                effMult = effMult + (dtMod.mult or 0)
                effMax = math.max(effMax, dtMod.max or 0)
                if dtMod.compoundMult then
                    effCompoundMult = effCompoundMult * dtMod.compoundMult
                end
                hasMod = true
            end
        end
    end

    if not hasMod then return baseValue end
    
    local finalMult = math.max(0, 1 + effMult)
    if effCompoundMult ~= 1 then
        finalMult = finalMult * effCompoundMult
    end
    
    if baseValue < effMax then 
        return (effAdd + effMax) * finalMult
    else 
        return (baseValue + effAdd) * finalMult
    end
end

function EffectManager:getStatMult(statName)
    local mod = self.currentModifiers[statName]
    if not mod then return 1 end
    local finalMult = math.max(0, 1 + mod.mult)
    if mod.compoundMult then
        finalMult = finalMult * mod.compoundMult
    end
    return finalMult
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
            local matches = true
            if effect.targetTypes and self.owner then
                matches = false
                if type(self.owner.isType) == "function" then
                    for t, req in pairs(effect.targetTypes) do
                        if req and self.owner:isType(t) then
                            matches = true
                            break
                        end
                    end
                end
            end

            if matches then
                local displayName = effect.displayName or effect.name
                if displayName then
                    -- Strip trailing _ID if present and no explicit displayName
                    if not effect.displayName then
                        displayName = displayName:gsub("_%d+$", "")
                    end
                end

                local isRepresented = false

                if effect.statModifiers then
                    for statName, mod in pairs(effect.statModifiers) do
                        if not mod.hidden then
                            nameMap[statName] = true
                            flatMap[statName] = (flatMap[statName] or 0) + (mod.add or mod.additive or 0)
                            multMap[statName] = (multMap[statName] or 0) + (mod.mult or mod.multiplier or 0)
                            maxMap[statName] = math.max(maxMap[statName] or 0, mod.max or 0)
                            isRepresented = true
                        end
                    end
                end

                if effect.grantedHitEffect then
                    local rawName = effect.grantedHitEffect.name or "Ability"
                    local abilityName = rawName:gsub("^%l", string.upper)
                    local abilityString = string.format("%s on Hit", abilityName)
                    
                    if not seenAbilities[abilityString] then
                        table.insert(strings, abilityString)
                        seenAbilities[abilityString] = true
                    end
                    isRepresented = true
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
