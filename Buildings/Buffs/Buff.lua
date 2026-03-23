local building = require("Buildings.Building")

local Buff = setmetatable({}, building)
Buff.__index = Buff

local default = {
    type = "passive",
    tag = "passive",
    buffType = "stat", -- "stat" or "onHit"
    statChanges = {damage = 1.2, fireRate = 1.2}, -- Table of stat changes, e.g. {damage = 1.2, fireRate = 0.8}
    onHitEffect = nil, -- Function to call on hit if buffType is "onHit"
    affectedSlots = {{1, 1}}, -- Array of slots that this buff affects
    shapePattern = {
        {0, 0}, {1, 0},
        {0, 1}, 
        {0, 2}, {1, 2}
    },
    --dark green color (normalized to 0-1 range for Love2D)
    color = {21/255, 71/255, 52/255},
}

-- buff provides either a stat boost or an on hit ability to nearby towers
-- buff has an array of slots to define which towers are affected

function Buff:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    
    local b = setmetatable(building:new(config), { __index = self })
    b.buffType = config.buffType
    b.statChanges = config.statChanges
    b.onHitEffect = config.onHitEffect
    b.affectedSlots = config.affectedSlots
    b.color = config.color
    return b
end

function Buff:getAffectedSlotsFromAnchor(anchorSlot)
    -- Convert affectedSlots coordinates to actual slot numbers relative to anchorSlot
    local slots = {}
    local gridWidth = self.buildGrid.width
    
    -- Calculate anchor position in grid coordinates
    local anchorX = ((anchorSlot - 1) % gridWidth)
    local anchorY = math.floor((anchorSlot - 1) / gridWidth)
    
    for _, coord in ipairs(self.affectedSlots) do
        local offsetX, offsetY = coord[1], coord[2]
        local actualX = anchorX + offsetX
        local actualY = anchorY + offsetY
        
        -- Check bounds
        if actualX >= 0 and actualX < gridWidth and actualY >= 0 and actualY < self.buildGrid.height then
            local slot = actualY * gridWidth + actualX + 1
            table.insert(slots, slot)
        end
    end
    
    return slots
end

function Buff:applyBuffs()
    -- Apply this buff to all turrets in affected slots using the EffectManager
    if not self.slot then return end
    
    local affectedSlots = self:getAffectedSlotsFromAnchor(self.slot)
    local base = self.game.base
    
    for _, slot in ipairs(affectedSlots) do
        local target = base.buildGrid.buildings[slot]
        if target and target.effectManager then
            local effect = {
                name = "buff_" .. self.id,
                statModifiers = {}
            }
            
            -- Map statChanges to standard EffectManager keys
            for statName, value in pairs(self.statChanges) do
                -- statChanges uses multipliers like 1.2, EffectManager uses mult additives like 0.2
                effect.statModifiers[statName] = { mult = value - 1 }
            end
            
            if self.buffType == "onHit" and self.onHitEffect then
                effect.onHit = self.onHitEffect
            end
            
            target.effectManager:applyEffect(effect)
        end
    end
end

function Buff:removeBuffs()
    -- Effect removal is currently handled by the EffectManager's internal logic 
    -- if we were to implement a named removal, but for now recalculateAllBuffs 
    -- in GameManager handles clearing most states if needed.
end

return Buff