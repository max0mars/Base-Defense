local Spell = {}
Spell.__index = Spell

function Spell.new(config)
    local self = setmetatable({}, Spell)
    
    self.id = config.id
    self.name = config.name or "Unknown Spell"
    self.description = config.description or ""
    self.cost = config.cost or 1 
    self.rarity = config.rarity or "Common"
    self.radius = config.radius or 50
    self.isGlobalSpell = config.isGlobalSpell or false
    
    local ExecutionType = require("Game.Cards.ExecutionType")
    self.executionType = config.executionType or ExecutionType.Spell
    self.customExecute = config.customExecute or nil
    
    return self
end

function Spell:getCardDraw()
    if not self.rewardCard then
        local CardDraw = require("Game.Cards.CardDraw")
        
        local data = {
            name = self.name,
            description = self.description,
            cost = self.cost or 1,
            rarity = self.rarity or "Common",
            type = "spell", -- Maps self.instantType to "Spell" in CardDraw
            iconCategory = "upgrade",
            damageBars = 0,
            rangeBars = 0,
            firerateBars = 0,
            affectedSlots = {},
            isTargeted = false,
            isGlobal = self.isGlobalSpell
        }
        self.rewardCard = CardDraw.new(0, 0, data)
    end
    return self.rewardCard
end

function Spell:getCost()
    return self.cost or 1
end

function Spell:isValidTarget(x, y)
    if not x or not y then return false end
    
    -- If it's a global spell, any point on screen is valid targeting
    if self.isGlobalSpell then
        return true
    end

    -- Check if target is inside the battlefield screen boundaries
    local Layout = require("Game.GUI.Layout")
    local sx, sy = Layout.worldToScreen(x, y)
    return Layout.inFieldScreen(sx, sy)
end

function Spell:execute(x, y, game)
    if not self:isValidTarget(x, y) then return false end
    
    if self.customExecute then
        self.customExecute(x, y, game)
    end
    
    return true
end

return Spell
