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
    -- vibrant neon green color
    color = {0.2, 0.9, 0.3, 1},
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
    local cx, cy
    local totalW, totalH
    local cellSize = self.buildGrid.cellSize
    
    -- 1. Calculate Bounding Box and Center
    if not drawx or not drawy then
        if not self.slot then return end
        cx, cy = self:getCenterPosition()
        
        -- Calculate total span from shapePattern for multi-cell buildings
        local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
        for _, coord in ipairs(self.shapePattern) do
            minX = math.min(minX, coord[1])
            maxX = math.max(maxX, coord[1])
            minY = math.min(minY, coord[2])
            maxY = math.max(maxY, coord[2])
        end
        totalW = (maxX - minX + 1) * cellSize
        totalH = (maxY - minY + 1) * cellSize
    else
        -- Preview mode: snapped center is passed as drawx, drawy
        cx, cy = drawx, drawy
        
        local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
        for _, coord in ipairs(self.shapePattern) do
            minX = math.min(minX, coord[1])
            maxX = math.max(maxX, coord[1])
            minY = math.min(minY, coord[2])
            maxY = math.max(maxY, coord[2])
        end
        totalW = (maxX - minX + 1) * cellSize
        totalH = (maxY - minY + 1) * cellSize
        
        -- Adjust center point if building is multi-cell
        local offsetX = (minX + maxX) * cellSize / 2
        local offsetY = (minY + maxY) * cellSize / 2
        cx = cx + offsetX
        cy = cy + offsetY
    end

    -- 2. Styling Parameters
    local padding = cellSize * 0.15
    local w = totalW - padding * 2
    local h = totalH - padding * 2
    
    local r, g, b = unpack(self.color or {1, 1, 1})
    local time = love.timer.getTime()
    local pulse = (math.sin(time * 4) + 1) / 2 -- 0 to 1 pulsing
    
    -- 3. Neon Glow Effect
    -- Draw multiple layers of the geometric shape with decreasing thickness and increasing opacity
    for i = 4, 1, -1 do
        local alpha = (0.05 + (1 - i/5) * 0.3) * (0.6 + pulse * 0.4)
        local glowWidth = i * 2 + pulse * 3
        love.graphics.setLineWidth(glowWidth)
        love.graphics.setColor(r, g, b, alpha)
        
        -- Geometric Shape: Diamond wireframe
        love.graphics.polygon("line", 
            cx, cy - h/2, -- Top
            cx + w/2, cy, -- Right
            cx, cy + h/2, -- Bottom
            cx - w/2, cy  -- Left
        )
    end
    
    -- 4. Bright Core Line
    love.graphics.setLineWidth(2)
    love.graphics.setColor(math.min(r * 1.5, 1), math.min(g * 1.5, 1), math.min(b * 1.5, 1), 1)
    love.graphics.polygon("line", 
        cx, cy - h/2,
        cx + w/2, cy,
        cx, cy + h/2,
        cx - w/2, cy
    )
    
    -- 5. Inner Detail: Pulse-synced Core Node
    love.graphics.setColor(r, g, b, 0.8 + pulse * 0.2)
    love.graphics.circle("fill", cx, cy, 3 + pulse * 2)
    
    -- Inner diamond detail
    local sw, sh = w * 0.4, h * 0.4
    love.graphics.polygon("line", 
        cx, cy - sh/2,
        cx + sw/2, cy,
        cx, cy + sh/2,
        cx - sw/2, cy
    )
    
    -- Reset drawing state
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function Buff:applyBuffs()
    -- Apply this buff to all turrets in affected slots using the EffectManager
    if not self.slot or self.destroyed then return end
    
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