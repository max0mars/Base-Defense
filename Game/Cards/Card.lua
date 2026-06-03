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
        local affSlots = {}
        
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
            iconCategory = (isGlobal or isTargeted) and "upgrade" or "turret",
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
    local rarity = self.payload.rarity or self.rarity or "common"
    local costs = {
        common = 1,
        uncommon = 2,
        rare = 3,
        epic = 4,
        legendary = 5
    }
    return costs[rarity] or 1
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

return Card
