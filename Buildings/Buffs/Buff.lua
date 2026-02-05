local building = require("Buildings.Building")

Buff = setmetatable({}, building)
Buff.__index = Buff

default = {
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
    -- Apply this buff to all turrets in affected slots
    if not self.slot then return end -- Not placed yet
    
    local affectedSlots = self:getAffectedSlotsFromAnchor(self.slot)
    local base = self.game.base
    
    for _, slot in ipairs(affectedSlots) do
        local building = base.buildGrid.buildings[slot]
        if building and building.addBuff then -- Check if it's a turret with buff capability
            local buffData = {}
            
            -- Convert statChanges to buff format
            if self.statChanges.damage then
                buffData.damageMultiplier = self.statChanges.damage
            end
            if self.statChanges.fireRate then
                -- Invert fireRate buff since lower fireRate = better (faster firing)
                buffData.fireRateMultiplier = 1 / self.statChanges.fireRate
            end
            if self.statChanges.bulletSpeed then
                buffData.bulletSpeedMultiplier = self.statChanges.bulletSpeed
            end
            if self.statChanges.range then
                buffData.rangeMultiplier = self.statChanges.range
            end
            
            -- Set buff type and onHit effect if applicable
            buffData.type = self.buffType
            if self.buffType == "onHit" and self.onHitEffect then
                -- onHitEffect should be a table: {id=..., func=...}
                buffData.onHitEffect = self.onHitEffect
            end
            
            building:addBuff(self.id, buffData)
        end
    end
end

function Buff:removeBuffs()
    -- Remove this buff from all turrets
    if not self.slot then return end
    
    local affectedSlots = self:getAffectedSlotsFromAnchor(self.slot)
    local base = self.game.base
    
    for _, slot in ipairs(affectedSlots) do
        local building = base.buildGrid.buildings[slot]
        if building and building.removeBuff then
            building:removeBuff(self.id)
        end
    end
end

return Buff