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

function Card:getCardDraw()
    if not self.payload then self.payload = {} end
    if not self.payload.rewardCard then
        local CardDraw = require("Game.Cards.CardDraw")
        local isTargeted = self.executionType == require("Game.Cards.ExecutionType").Targeted or self.executionType == "Targeted"
        local isGlobal = self.executionType == require("Game.Cards.ExecutionType").Global or self.executionType == "Global"
        
        local dmgBars, rngBars, frBars = 0, 0, 0
        local affSlots = self.payload.affectedSlots or {}
        local iconCat = self.payload.iconCategory or "turret"
        
        local success, rewardIndex = pcall(require, "Game.Rewards.NormalRewardIndex")
        if success and rewardIndex then
            for _, category in pairs(rewardIndex) do
                if type(category) == "table" then
                    for _, reward in ipairs(category) do
                        if reward.id == self.id then
                            dmgBars = reward.damageBars or dmgBars
                            rngBars = reward.rangeBars or rngBars
                            frBars = reward.firerateBars or frBars
                            affSlots = reward.affectedSlots or affSlots
                            iconCat = reward.iconCategory or iconCat
                            break
                        end
                    end
                end
            end
        end

        local data = {
            name = self.name,
            description = self.description,
            cost = self:getCost(),
            rarity = self.payload.rarity or self.rarity or "common",
            type = self.payload.isMainUpgrade and "main_upgrade" or ((isGlobal or isTargeted) and "effect" or "building"),
            iconCategory = (isGlobal or isTargeted) and "upgrade" or iconCat,
            damageBars = dmgBars,
            rangeBars = rngBars,
            firerateBars = frBars,
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

    foundCost = searchIndex("Game.Rewards.NormalRewardIndex") or 
                searchIndex("Game.Rewards.BlockerRewardIndex") or 
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
