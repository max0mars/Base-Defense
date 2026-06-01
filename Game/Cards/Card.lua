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
