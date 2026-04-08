local building = require("Buildings.Building")

local Buff = setmetatable({}, building)
Buff.__index = Buff

local default = {
    types = { passive = true },
    effect = {
        name = "Damage Buff",
        statModifiers = {damage = {mult = 0.2}},
        --description = "Increases damage by 20%",
        duration = math.huge,
    },
    affectedSlots = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}}, -- Array of slots that this buff affects
    -- shapePattern = {
    --     {0, 0}
    -- },
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
    b.effect = config.effect
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

function Buff:draw(drawx, drawy)
    if not drawx or not drawy then
        if not self.slot then
            error("Can't draw building if it's not placed on grid")
        end -- Can't draw without placement
    
        love.graphics.setColor(self.color or {1, 1, 1, 1})
        
        -- Draw filled rectangles for each occupied slot
        local occupiedSlots = self:getSlotsFromPattern(self.slot)
        for _, slot in ipairs(occupiedSlots) do
            local i = ((slot - 1) % self.buildGrid.width) + 1
            local j = math.ceil(slot / self.buildGrid.width)
            local x = self.buildGrid.x + (i - 1) * self.buildGrid.cellSize
            local y = self.buildGrid.y + (j - 1) * self.buildGrid.cellSize
            
            love.graphics.rectangle("fill", x, y, self.buildGrid.cellSize, self.buildGrid.cellSize)
        end
        
        -- Reset color
        love.graphics.setColor(1, 1, 1, 1)
    else
        love.graphics.setColor(self.color or {1, 1, 1, 1})
        
        -- Draw the building's shape based on shapePattern
        for _, coord in ipairs(self.shapePattern) do
            local cellX = drawx + (coord[1] * self.buildGrid.cellSize)
            local cellY = drawy + (coord[2] * self.buildGrid.cellSize)
            
            love.graphics.rectangle("fill", cellX, cellY, self.buildGrid.cellSize, self.buildGrid.cellSize)
        end
        
        -- Reset color
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function Buff:applyBuffs()
    -- Apply this buff to all turrets in affected slots using the EffectManager
    if not self.slot then return end
    
    local affectedSlots = self:getAffectedSlotsFromAnchor(self.slot)
    local base = self.game.base
    
    for _, slot in ipairs(affectedSlots) do
        local target = base.buildGrid.buildings[slot]
        if target and target.effectManager then
            local effectToApply = {}
            -- Shallow copy the effect provided in configuration
            if self.effect then
                for k, v in pairs(self.effect) do
                    effectToApply[k] = v
                end
                
                -- Append building ID to ensure multiple buildings of same type stack
                effectToApply.name = (self.effect.name or "buff") .. "_" .. self.id
                effectToApply.isBuffTotem = true
                
                target.effectManager:applyEffect(effectToApply)
            end
        end
    end
end

function Buff:removeBuffs()
    -- Effect removal is currently handled by the EffectManager's internal logic 
    -- if we were to implement a named removal, but for now recalculateAllBuffs 
    -- in GameManager handles clearing most states if needed.
end

return Buff