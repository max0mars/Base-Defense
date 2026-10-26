local ExecutionType = require("Game.Cards.ExecutionType")
local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")

local Card = {}
Card.__index = Card

function Card:new(config)
    local obj = setmetatable({}, self)
    obj.id = config.id or "unknown"
    obj.name = config.name or "Unknown Card"
    obj.description = config.description or ""
    obj.executionType = config.executionType or ExecutionType.Placement
    obj.quantity = config.quantity or 1
    
    obj.isConsume = config.isConsume or false
    obj.isExile = config.isExile or false
    obj.cost = config.cost
    
    -- payload contains the building class and configuration or the effect definition
    obj.payload = config.payload or {}
    
    -- Tier progression (Tier 1 = I, up to Tier 5 = V)
    obj.tier = config.tier or 1
    obj.upgradeCosts = config.upgradeCosts or (obj.payload and obj.payload.upgradeCosts)
    
    -- Upgradable flag (defaults to whether card is a turret, can be overridden)
    if config.upgradable ~= nil then
        obj.upgradable = config.upgradable
    elseif obj.payload and obj.payload.upgradable ~= nil then
        obj.upgradable = obj.payload.upgradable
    elseif obj.payload and obj.payload.config and obj.payload.config.upgradable ~= nil then
        obj.upgradable = obj.payload.config.upgradable
    else
        obj.upgradable = obj:isTurret()
    end
    
    return obj
end

-- A strict deep copy utility function for Lua tables
local function deepcopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
            end
            setmetatable(copy, deepcopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function Card:getClonedPayload()
    return deepcopy(self.payload)
end

local function resolveTurretStats(payload, cardId, CardDraw)
    local affSlots = payload.affectedSlots or {}
    local iconCat = payload.iconCategory or "turret"
    local source = nil

    -- 1. Try directly from payload.config / template
    local cfg = payload.config
    if cfg then
        source = (cfg.building and type(cfg.building) == "table" and cfg.building.template) or cfg.template or cfg
        affSlots = cfg.affectedSlots or affSlots
        iconCat = cfg.iconCategory or iconCat
    end

    -- 2. Fall back to RewardIndex by ID if source lacks raw stats
    if not (source and (source.damage or source.range or source.fireRate or source.damageBars)) and cardId then
        local success, rewardIndex = pcall(require, "Game.Rewards.RewardIndex")
        if success and rewardIndex then
            for _, category in pairs(rewardIndex) do
                if type(category) == "table" then
                    for _, reward in ipairs(category) do
                        if reward.id == cardId then
                            source = (reward.building and type(reward.building) == "table" and reward.building.template) or reward
                            affSlots = reward.affectedSlots or affSlots
                            iconCat = reward.iconCategory or iconCat
                            break
                        end
                    end
                end
                if source and (source.damage or source.range or source.fireRate or source.damageBars) then break end
            end
        end
    end

    -- 3. Calculate stat bars from source
    local dmgBars, rngBars, frBars = 0, 0, 0
    if source then
        if source.damage or source.range or source.fireRate then
            local dmg = source.damage or 0
            if source.pelletCount and source.pelletCount > 1 then
                dmg = dmg * source.pelletCount
            elseif source.splitamount and source.splitamount > 0 then
                dmg = dmg * (source.splitamount + 1)
            end
            local rng = source.range or 0
            local fr = source.fireRate or 1

            if CardDraw and CardDraw.calcBars then
                dmgBars = CardDraw.calcBars("damage", dmg)
                rngBars = CardDraw.calcBars("range", rng)
                frBars = CardDraw.calcBars("fireRate", fr)
            else
                error("CardDraw.calcBars not found")
            end
        else
            dmgBars = source.damageBars or 0
            rngBars = source.rangeBars or 0
            frBars = source.firerateBars or 0
        end
    end

    return dmgBars, rngBars, frBars, affSlots, iconCat
end

function Card:getCardDraw()
    if not self.payload then self.payload = {} end
    if self.payload.rewardCard and self.payload.rewardCard.cardType == "Building" and self.payload.rewardCard.buildingType == "Turret" then
        local rc = self.payload.rewardCard
        if rc.damageBars == 0 and rc.rangeBars == 0 and rc.firerateBars == 0 then
            self.payload.rewardCard = nil
        end
    end
    if not self.payload.rewardCard then
        local CardDraw = require("Game.Cards.CardDraw")
        local isTargeted = self.executionType == require("Game.Cards.ExecutionType").Targeted or self.executionType == "Targeted"
        local isGlobal = self.executionType == require("Game.Cards.ExecutionType").Global or self.executionType == "Global"
        local isSpell = self.executionType == require("Game.Cards.ExecutionType").Spell or self.executionType == "Spell"
        
        local dmgBars, rngBars, frBars, affSlots, iconCat = resolveTurretStats(self.payload, self.id, CardDraw)

        local tier = self.tier or 1
        local isUpgradable = self:isUpgradable()
        local displayTier = isUpgradable and tier or 1
        local tierDmgBonus = dmgBars * (CardUpgradeConfig.getTierMultiplier("damage", displayTier) - 1)
        local tierRngBonus = rngBars * (CardUpgradeConfig.getTierMultiplier("range", displayTier) - 1)
        local tierFrBonus = frBars * (CardUpgradeConfig.getTierMultiplier("fireRate", displayTier) - 1)

        local data = {
            name = self.name,
            tier = isUpgradable and tier or 1,
            upgradable = isUpgradable,
            description = self.description,
            cost = self:getCost(),
            rarity = self.payload.rarity or self.rarity or "common",
            type = self.payload.isMainUpgrade and "main_upgrade" or (isSpell and "spell" or ((isGlobal or isTargeted) and "effect" or "building")),
            iconCategory = (isGlobal or isTargeted) and "upgrade" or iconCat,
            damageBars = dmgBars,
            rangeBars = rngBars,
            firerateBars = frBars,
            damageBarsBonus = (self.payload.damageBarsBonus or 0) + tierDmgBonus,
            rangeBarsBonus = (self.payload.rangeBarsBonus or 0) + tierRngBonus,
            firerateBarsBonus = (self.payload.firerateBarsBonus or 0) + tierFrBonus,
            affectedSlots = affSlots,
            isTargeted = isTargeted,
            isGlobal = isGlobal
        }
        self.payload.rewardCard = CardDraw.new(0, 0, data)
    end
    return self.payload.rewardCard
end

function Card:isUpgradable()
    if self.upgradable ~= nil then
        return self.upgradable
    end
    if self.payload then
        if self.payload.upgradable ~= nil then return self.payload.upgradable end
        if self.payload.config and self.payload.config.upgradable ~= nil then return self.payload.config.upgradable end
    end
    return self:isTurret()
end

function Card:isTurret()
    if self.executionType ~= ExecutionType.Placement and self.executionType ~= "Placement" then
        return false
    end

    local payload = self.payload or {}
    local cfg = payload.config or {}

    -- Helper to check if a collection of types contains a given type name
    local function checkType(collection, typeName)
        if not collection then return false end
        if type(collection) == "table" then
            for _, t in ipairs(collection) do
                if t == typeName then return true end
            end
            if collection[typeName] == true then return true end
        elseif collection == typeName then
            return true
        end
        return false
    end

    -- 1. Check iconCategory from all sources: if explicitly buff/blocker/spell/instant, not a turret
    local iconCategory = payload.iconCategory or cfg.iconCategory or self.iconCategory
    if iconCategory == "buff" or iconCategory == "blocker" or iconCategory == "spell" or iconCategory == "instant" then
        return false
    end

    -- 2. Check types from payload, config, self, or buildingClass: if passive/buff/blocker, not a turret
    local bClass = payload.buildingClass
    if checkType(payload.types, "passive") or checkType(payload.types, "buff") or checkType(payload.types, "blocker") or
       checkType(cfg.types, "passive") or checkType(cfg.types, "buff") or checkType(cfg.types, "blocker") or
       checkType(self.types, "passive") or checkType(self.types, "buff") or checkType(self.types, "blocker") or
       (bClass and (checkType(bClass.types, "passive") or checkType(bClass.types, "buff") or checkType(bClass.types, "blocker"))) then
        return false
    end

    -- 3. Check affectedSlots: passives have affectedSlots (and are not attack turrets)
    local affSlots = payload.affectedSlots or cfg.affectedSlots
    if affSlots and #affSlots > 0 and iconCategory ~= "turret" then
        return false
    end

    -- 4. Check explicit turret markings
    if iconCategory == "turret" then
        return true
    end
    if checkType(payload.types, "turret") or checkType(cfg.types, "turret") or checkType(self.types, "turret") or
       (bClass and checkType(bClass.types, "turret")) then
        return true
    end

    -- 5. Check if it has offensive combat turret stats
    local hasCombatStats = (cfg.damage or cfg.fireRate or cfg.range or cfg.bulletSpeed or cfg.firingArc or
                            cfg.damageBars or cfg.firerateBars or cfg.rangeBars or
                            payload.damage or payload.fireRate or payload.range or
                            payload.damageBars or payload.firerateBars or payload.rangeBars)
    if hasCombatStats then
        return true
    end

    -- 6. Fall back to RewardIndex lookup by ID
    if self.id then
        local success, rewardIndex = pcall(require, "Game.Rewards.RewardIndex")
        if success and rewardIndex then
            for _, category in pairs(rewardIndex) do
                if type(category) == "table" then
                    for _, reward in ipairs(category) do
                        if reward.id == self.id then
                            if reward.iconCategory == "buff" or reward.iconCategory == "blocker" or
                               checkType(reward.types, "passive") or checkType(reward.types, "buff") or checkType(reward.types, "blocker") or
                               (reward.affectedSlots and #reward.affectedSlots > 0 and reward.iconCategory ~= "turret") then
                                return false
                            end
                            if reward.iconCategory == "turret" or checkType(reward.types, "turret") or reward.damage or reward.fireRate then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end

    return false
end

function Card:getTier()
    return self.tier or 1
end

--- Upgrade material id for this card's turret (see MaterialRegistry).
function Card:getUpgradeMaterial()
    local MaterialRegistry = require("Game.Cards.MaterialRegistry")
    local payload = self.payload or {}
    local source = payload.config
    if not (source and (source.types or source.damageType or source.upgradeMaterial)) and self.id then
        -- Payload lacks type info: fall back to the reward index entry for this card
        local success, rewardIndex = pcall(require, "Game.Rewards.RewardIndex")
        if success and rewardIndex then
            for _, category in pairs(rewardIndex) do
                if type(category) == "table" then
                    for _, reward in ipairs(category) do
                        if reward.id == self.id then source = reward break end
                    end
                end
            end
        end
    end
    return MaterialRegistry.resolve(source)
end

function Card:getNextUpgradeCost()
    if not self:isUpgradable() then return nil end
    local currentTier = self.tier or 1
    if currentTier >= CardUpgradeConfig.MAX_TIER then return nil end
    local nextTier = currentTier + 1
    local cost = (self.upgradeCosts and self.upgradeCosts[nextTier]) or CardUpgradeConfig.DEFAULT_COSTS[nextTier]
    return CardUpgradeConfig.resolveCost(cost, self:getUpgradeMaterial())
end

function Card:canUpgrade()
    if not self:isUpgradable() then return false, "not_upgradable" end
    if (self.tier or 1) >= CardUpgradeConfig.MAX_TIER then return false, "max_tier" end
    local cost = self:getNextUpgradeCost()
    if not cost then return false, "no_cost" end
    if not CardUpgradeConfig.Economy.canAfford(cost) then
        return false, "insufficient_resources", cost
    end
    return true, nil, cost
end

function Card:upgrade(deck)
    deck = deck or (_G.PersistentState and _G.PersistentState.deck)
    local can, reason, cost = self:canUpgrade()
    if not can then return false, reason end
    
    CardUpgradeConfig.Economy.deduct(cost)
    local currentTier = self.tier or 1
    local nextTier = currentTier + 1
    
    -- Invalidate cached visual CardDraw
    if self.payload then
        self.payload.rewardCard = nil
    end

    if (self.quantity or 1) > 1 then
        -- Only upgrade a single card: decrement current duplicate stack by 1
        self.quantity = self.quantity - 1

        -- Check if a stack with the same ID and nextTier already exists in the deck
        local merged = false
        if deck and deck.cards then
            for _, other in ipairs(deck.cards) do
                if other.id == self.id and (other.tier or 1) == nextTier then
                    other.quantity = (other.quantity or 1) + 1
                    if other.payload then other.payload.rewardCard = nil end
                    merged = true
                    break
                end
            end
        end

        if not merged then
            local newPayload = deepcopy(self.payload)
            if newPayload then newPayload.rewardCard = nil end
            local newCard = Card:new({
                id = self.id,
                name = self.name,
                description = self.description,
                executionType = self.executionType,
                cost = self.cost,
                quantity = 1,
                tier = nextTier,
                upgradable = self.upgradable,
                payload = newPayload,
                upgradeCosts = self.upgradeCosts and deepcopy(self.upgradeCosts) or nil
            })
            if deck and deck.cards then
                table.insert(deck.cards, newCard)
            end
            return true, nextTier, newCard
        end
        return true, nextTier
    else
        -- Only 1 card in this stack: check if it can merge into an existing stack at nextTier
        local merged = false
        if deck and deck.cards then
            for _, other in ipairs(deck.cards) do
                if other ~= self and other.id == self.id and (other.tier or 1) == nextTier then
                    other.quantity = (other.quantity or 1) + 1
                    if other.payload then other.payload.rewardCard = nil end
                    -- Remove self from deck since this card merged into the higher-tier stack
                    for j = #deck.cards, 1, -1 do
                        if deck.cards[j] == self then
                            table.remove(deck.cards, j)
                            break
                        end
                    end
                    merged = true
                    break
                end
            end
        end

        if not merged then
            self.tier = nextTier
            if self.payload then
                self.payload.rewardCard = nil
            end
        end
        return true, nextTier
    end
end

function Card:getCost()
    if self._computedCost then return self._computedCost end
    if self.cost then 
        self._computedCost = self.cost
        return self._computedCost 
    end
    if self.payload and self.payload.cost then
        self._computedCost = self.payload.cost
        return self._computedCost
    end
    
    local idToLookFor = self.id
    local foundCost = nil
    
    -- Dynamically look up cost from Reward Indices
    local function searchIndex(modName)
        local success, index = pcall(require, modName)
        if success and index then
            for _, category in pairs(index) do
                if type(category) == "table" then
                    for _, reward in ipairs(category) do
                        if reward.id == idToLookFor and reward.cost then
                            return reward.cost
                        end
                    end
                end
            end
        end
        return nil
    end

    foundCost = searchIndex("Game.Rewards.RewardIndex") or 
                searchIndex("Game.Rewards.SpecialRewardIndex")
                
    if foundCost then
        self._computedCost = foundCost
        return self._computedCost
    end
    return -1
end

function Card:execute(game)
    local payload = self:getClonedPayload()
    
    if self.executionType == ExecutionType.Placement then
        if payload.buildingClass then
            local config = payload.config or {}
            config.game = game
            
            -- Fallback: if stats were directly on payload instead of payload.config
            if config.damage == nil and payload.damage ~= nil then config.damage = payload.damage end
            if config.range == nil and payload.range ~= nil then config.range = payload.range end
            if config.fireRate == nil and payload.fireRate ~= nil then config.fireRate = payload.fireRate end

            -- Safety fallback: if turret is still missing critical stats (e.g. fireRate), look up in RewardIndex by ID
            if (config.fireRate == nil or config.damage == nil or config.range == nil) and self.id then
                local success, rewardIndex = pcall(require, "Game.Rewards.RewardIndex")
                if success and rewardIndex then
                    for _, category in pairs(rewardIndex) do
                        if type(category) == "table" then
                            for _, item in ipairs(category) do
                                if item.id == self.id then
                                    for k, v in pairs(item) do
                                        if config[k] == nil then
                                            config[k] = v
                                        end
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end

            -- Apply tier scaling (flat per-stat bonus per tier above Tier I, see TIER_BONUS)
            -- This sets the turret's BASE values so in-battle buffs (e.g. +50% damage)
            -- multiply the upgraded base value (e.g. Tier 2: 120% * 1.5).
            if self:isUpgradable() and self.tier and self.tier > 1 then
                local dmgMult = CardUpgradeConfig.getTierMultiplier("damage", self.tier)
                local rangeMult = CardUpgradeConfig.getTierMultiplier("range", self.tier)
                local rateMult = CardUpgradeConfig.getTierMultiplier("fireRate", self.tier)
                if config.damage then config.damage = config.damage * dmgMult end
                if config.range then
                    config.range = config.range * rangeMult
                    -- Hidden: stretch bullet lifespan with range so shots still reach max range
                    config.lifespan = (config.lifespan or 1) * rangeMult
                end
                if config.fireRate then config.fireRate = config.fireRate * rateMult end
                if config.splitDamage then config.splitDamage = config.splitDamage * dmgMult end
                if config.explosionDamage then config.explosionDamage = config.explosionDamage * dmgMult end
            end
            config.tier = self.tier or 1
            
            return payload.buildingClass:new(config)
        end
    elseif self.executionType == ExecutionType.Global then
        if payload.effect then
            -- Execute the global effect, attach to player manager, and register it to be cleared
            game.playerEffectManager:applyEffect(payload.effect)
            game:registerActiveGlobalBuff(payload.effect)
            return true
        end
    end
    
    return nil
end

function Card:Consume(game)
    table.insert(game.consumedPile, self)
end

function Card:Exile(game)
    if _G.PersistentState and _G.PersistentState.deck then
        _G.PersistentState.deck:removeCard(self.id, 1)
    end
    if not game.exiledPile then
        game.exiledPile = {}
    end
    table.insert(game.exiledPile, self)
end

return Card
