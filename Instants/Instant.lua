local Instant = {}
Instant.__index = Instant -- This tells Lua where to look for methods

-- Enum for clarity
Instant.ExecutionType = {
    Global = "Global",
    Targeted = "Targeted"
}

-- The Constructor
function Instant.new(config)
    -- Create a new empty table and attach the Instant methods to it
    local self = setmetatable({}, Instant)
    
    -- Standard Card Meta Data
    self.id = config.id
    self.name = config.name or "Unknown Spell"
    self.description = config.description or ""
    self.cost = config.cost or 1 
    self.rarity = config.rarity or "Common"
    
    self.executionType = config.executionType or Instant.ExecutionType.Targeted
    self.statModifiers = config.statModifiers or {}
    self.customExecute = config.customExecute or nil
    self.requiredType = config.requiredType or nil
    
    return self
end

function Instant:getCardDraw()
    if not self.rewardCard then
        local CardDraw = require("Game.Cards.CardDraw")
        local isTargeted = self.executionType == Instant.ExecutionType.Targeted or self.executionType == "Targeted"
        local isGlobal = self.executionType == Instant.ExecutionType.Global or self.executionType == "Global"
        
        local data = {
            name = self.name,
            description = self.description,
            cost = self.cost or 1,
            rarity = self.rarity or "Common",
            type = (isGlobal or isTargeted) and "effect" or "building",
            iconCategory = (isGlobal or isTargeted) and "upgrade" or "turret",
            damageBars = 0,
            rangeBars = 0,
            firerateBars = 0,
            affectedSlots = {},
            isTargeted = isTargeted,
            isGlobal = isGlobal
        }
        self.rewardCard = CardDraw.new(0, 0, data)
    end
    return self.rewardCard
end

function Instant:getCost()
    return self.cost or 1
end

-- 1. TARGET VALIDATION
-- Called when the player is holding the card and hovering over a tile
function Instant:isValidTarget(targetEntity)
    if self.executionType == Instant.ExecutionType.Global then
        return true -- Global cards don't need a specific map target
    end

    -- For targeted cards, fail if they clicked empty grass or a non-turret
    if not targetEntity or type(targetEntity.isType) ~= "function" or not targetEntity:isType("turret") then
        return false 
    end

    if self.requiredType and not targetEntity:isType(self.requiredType) then
        return false
    end

    -- (Optional) You can add logic here for specific cards, 
    -- e.g., ensuring a "Sniper Buff" only targets Snipers.
    return true
end

-- 2. EXECUTION
-- Called by the Game Manager when the player confirms the action
function Instant:execute(targetEntity)
    -- Double check validity before spending the card
    if self.executionType == Instant.ExecutionType.Targeted then
        if not self:isValidTarget(targetEntity) then return false end
        self:applyTargetedEffect(targetEntity)
        
    elseif self.executionType == Instant.ExecutionType.Global then
        self:applyGlobalEffect(targetEntity)
    end

    -- Run any custom logic if the card has unique behavior
    if self.customExecute then
        self.customExecute(targetEntity)
    end

    return true -- Return true to tell the GameManager to consume the tokens and card
end

function Instant:applyTargetedEffect(targetEntity)
    if targetEntity and targetEntity.effectManager then
        local buff = {
            name = self.id,
            displayName = self.name,
            statModifiers = self.statModifiers
        }
        targetEntity.effectManager:applyEffect(buff)
    else
        print("WARNING: Target has no effectManager for Instant!")
    end
end

function Instant:applyGlobalEffect(gameObj)
    if gameObj and gameObj.playerEffectManager then
        local buff = {
            name = self.id,
            displayName = self.name,
            statModifiers = self.statModifiers
        }
        gameObj.playerEffectManager:applyEffect(buff)
        if type(gameObj.registerActiveGlobalBuff) == "function" then
            gameObj:registerActiveGlobalBuff(buff)
        end
    else
        print("WARNING: GameManager or playerEffectManager not linked for Global Instant!")
    end
end

return Instant