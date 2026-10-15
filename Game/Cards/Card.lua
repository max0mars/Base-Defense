local ExecutionType = require("Game.Cards.ExecutionType")

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
    obj.payload = config.payload
    
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

        local data = {
            name = self.name,
            description = self.description,
            cost = self:getCost(),
            rarity = self.payload.rarity or self.rarity or "common",
            type = self.payload.isMainUpgrade and "main_upgrade" or (isSpell and "spell" or ((isGlobal or isTargeted) and "effect" or "building")),
            iconCategory = (isGlobal or isTargeted) and "upgrade" or iconCat,
            damageBars = dmgBars,
            rangeBars = rngBars,
            firerateBars = frBars,
            damageBarsBonus = self.payload.damageBarsBonus or 0,
            rangeBarsBonus = self.payload.rangeBarsBonus or 0,
            firerateBarsBonus = self.payload.firerateBarsBonus or 0,
            affectedSlots = affSlots,
            isTargeted = isTargeted,
            isGlobal = isGlobal
        }
        self.payload.rewardCard = CardDraw.new(0, 0, data)
    end
    return self.payload.rewardCard
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
