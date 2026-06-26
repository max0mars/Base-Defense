local object = require("Classes.object")
local Instant = setmetatable({}, { __index = object })
Instant.__index = Instant -- This tells Lua where to look for methods

-- Enum for clarity
Instant.ExecutionType = {
    Global = "Global",
    Group = "Group",
    Targeted = "Targeted"
}

-- The Constructor
function Instant.new(config)
    config = config or {}
    config.types = config.types or {}
    config.types.instant = true
    config.effectManager = true

    -- Create a new empty table and attach the Instant methods to it
    local self = setmetatable(object:new(config), { __index = Instant })
    
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
    self.targetTypes = config.targetTypes or nil
    
    self.isConsume = config.isConsume or false
    self.isExile = config.isExile or false
    
    return self
end

function Instant:getCardDraw()
    if not self.rewardCard then
        local CardDraw = require("Game.Cards.CardDraw")
        local isTargeted = self.executionType == Instant.ExecutionType.Targeted or self.executionType == "Targeted"
        local isGlobal = self.executionType == Instant.ExecutionType.Global or self.executionType == "Global"
                         or self.executionType == Instant.ExecutionType.Group or self.executionType == "Group"
        
        local data = {
            name = self.name,
            description = self.description,
            cost = self:getCost(),
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
    return self:getStat("cost", self.cost or 1)
end

-- 1. TARGET VALIDATION
-- Called when the player is holding the card and hovering over a tile
function Instant:isValidTarget(targetEntity)
    if self.executionType == Instant.ExecutionType.Global or self.executionType == Instant.ExecutionType.Group then
        return true -- Global/Group cards don't need a specific map target
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
        
    elseif self.executionType == Instant.ExecutionType.Group then
        self:applyGroupEffect(targetEntity)

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
            statModifiers = self.statModifiers,
            targetTypes = self.targetTypes
        }
        targetEntity.effectManager:applyEffect(buff)
        -- Spawn buff animation on the affected target
        if targetEntity.game and targetEntity.game.spawnBuffPluses then
            local tx, ty = targetEntity.x, targetEntity.y
            if targetEntity.getCenterPosition then
                tx, ty = targetEntity:getCenterPosition()
            end
            targetEntity.game:spawnBuffPluses(tx, ty)
        end
    else
        print("WARNING: Target has no effectManager for Instant!")
    end
end

function Instant:applyGroupEffect(gameObj)
    if not self.statModifiers or next(self.statModifiers) == nil then
        return
    end

    if not gameObj then
        print("WARNING: gameObj is nil for Group Instant!")
        return
    end

    if gameObj.objects then
        local buff = {
            name = self.id,
            displayName = self.name,
            statModifiers = self.statModifiers,
            targetTypes = self.targetTypes
        }
        for _, obj in ipairs(gameObj.objects) do
            if obj and not obj.destroyed and obj:isType("turret") and obj.effectManager then
                local matches = true
                if self.targetTypes then
                    matches = false
                    for tType, val in pairs(self.targetTypes) do
                        if val and obj:isType(tType) then
                            matches = true
                            break
                        end
                    end
                end
                
                if matches then
                    obj.effectManager:applyEffect(buff)
                    obj.effectManager:recalculateStats()
                    -- Spawn buff animation on each affected turret
                    if gameObj.spawnBuffPluses then
                        local tx, ty = obj.x, obj.y
                        if obj.getCenterPosition then
                            tx, ty = obj:getCenterPosition()
                        end
                        gameObj:spawnBuffPluses(tx, ty)
                    end
                end
            end
        end
    else
        print("WARNING: GameManager or objects list not found for Group Instant!")
    end
end

function Instant:applyGlobalEffect(gameObj)
    if not self.statModifiers or next(self.statModifiers) == nil then
        return
    end

    if not gameObj then
        print("WARNING: gameObj is nil for Global Instant!")
        return
    end

    if gameObj.playerEffectManager then
        local buff = {
            name = self.id,
            displayName = self.name,
            statModifiers = self.statModifiers,
            targetTypes = self.targetTypes
        }
        gameObj.playerEffectManager:applyEffect(buff)
        if type(gameObj.registerActiveGlobalBuff) == "function" then
            gameObj:registerActiveGlobalBuff(buff)
        end
        
        -- Spawn buff animation on each affected turret for global buff
        if gameObj.objects and gameObj.spawnBuffPluses then
            for _, obj in ipairs(gameObj.objects) do
                if obj and not obj.destroyed and obj:isType("turret") then
                    local matches = true
                    if self.targetTypes then
                        matches = false
                        for tType, val in pairs(self.targetTypes) do
                            if val and obj:isType(tType) then
                                matches = true
                                break
                            end
                        end
                    end
                    if matches then
                        local tx, ty = obj.x, obj.y
                        if obj.getCenterPosition then
                            tx, ty = obj:getCenterPosition()
                        end
                        gameObj:spawnBuffPluses(tx, ty)
                    end
                end
            end
        end
    else
        print("WARNING: GameManager or playerEffectManager not linked for Global Instant!")
    end
end

function Instant:Consume(game)
    table.insert(game.consumedPile, self)
end

function Instant:Exile(game)
    if _G.PersistentState and _G.PersistentState.deck then
        _G.PersistentState.deck:removeCard(self.id, 1)
    end
    if not game.exiledPile then
        game.exiledPile = {}
    end
    table.insert(game.exiledPile, self)
end

return Instant
