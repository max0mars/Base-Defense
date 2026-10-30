local building = require("Buildings.Building")

local Buff = setmetatable({}, building)
Buff.__index = Buff

local default = {
    types = { passive = true },
    effect = {
        name = "Damage Buff",
        statModifiers = {damage = {mult = 0.3}},
        --description = "Increases damage by 20%",
        duration = math.huge,
    },
    affectedSlots = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}}, -- Array of slots that this buff affects
    -- shapePattern = {
    --     {0, 0}
    -- },
    -- vibrant neon green color
    color = {0.2, 0.9, 0.3, 1},
    isGlobal = false,
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
    b.isGlobal = config.isGlobal
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
    -- s is the sprite's half-size; sprites are drawn centred on (cx, cy)
    local padding = cellSize * 0.12
    local s = (math.min(totalW, totalH) - padding * 2) / 2

    local r, g, b = unpack(self.color or {1, 1, 1})
    local pulse = 0
    if not self.disableGlow and not self.noGlow then
        pulse = (math.sin(love.timer.getTime() * 4) + 1) / 2 -- 0 to 1 pulsing
    end

    love.graphics.push("all")
    love.graphics.setLineJoin("bevel")

    -- 3. Neon Glow: the sprite outline redrawn in wide, faint strokes (skipped for noGlow sprites)
    if not self.noGlow then
        for i = 3, 1, -1 do
            love.graphics.setColor(r, g, b, (0.08 + (3 - i) * 0.08) * (0.6 + pulse * 0.4))
            love.graphics.setLineWidth(i * 2 + pulse * 1.5)
            self:drawShape(cx, cy, s, pulse)
        end
    end

    -- 4. Bright Core Line
    love.graphics.setLineWidth(1.5)
    love.graphics.setColor(math.min(r * 1.5, 1), math.min(g * 1.5, 1), math.min(b * 1.5, 1), 1)
    self:drawShape(cx, cy, s, pulse)

    -- 5. Unglowed details (fills, small animated parts)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(r, g, b, 1)
    self:drawDetail(cx, cy, s, pulse)

    love.graphics.pop()
end

-- Sprites: drawShape draws the outline (lines only; it's redrawn for the glow) and
-- drawDetail draws everything else once, in the building's colour. Both are
-- centred on (cx, cy) within a box of half-size s. Override them per passive.

-- Default sprite (Ammo Cache): an ammo crate with three rounds standing in it
function Buff:drawShape(cx, cy, s)
    love.graphics.rectangle("line", cx - s, cy - s * 0.05, s * 2, s * 1.05, 1, 1)
    local hw = s * 0.2
    for _, x in ipairs({ cx - s * 0.55, cx, cx + s * 0.55 }) do
        love.graphics.polygon("line",
            x - hw, cy - s * 0.05,
            x - hw, cy - s * 0.65,
            x, cy - s,
            x + hw, cy - s * 0.65,
            x + hw, cy - s * 0.05)
    end
end

function Buff:drawDetail(cx, cy, s, pulse)
    -- Crate slats
    love.graphics.line(cx - s, cy + s * 0.5, cx + s, cy + s * 0.5)
    love.graphics.setColor(1, 1, 1, 0.5 + pulse * 0.5)
    love.graphics.circle("fill", cx, cy + s * 0.5, 1.2)
end

function Buff:applyBuffs()
    -- Apply this buff to all turrets in affected slots using the EffectManager
    if not self.slot or self.destroyed then return end
    
    local targets = {}
    
    if self.isGlobal then
        if self.game and self.game.playerEffectManager then
            table.insert(targets, { effectManager = self.game.playerEffectManager })
        end
    else
        local affectedSlots = self:getAffectedSlotsFromAnchor(self.slot)
        for _, slot in ipairs(affectedSlots) do
            local target = self.buildGrid.buildings[slot]
            if target then
                -- If the effect specifies targetTypes, only include matching targets
                if self.effect and self.effect.targetTypes then
                    local matches = false
                    for tType, val in pairs(self.effect.targetTypes) do
                        if val and target.isType and target:isType(tType) then
                            matches = true
                            break
                        end
                    end
                    if matches then
                        table.insert(targets, target)
                    end
                else
                    table.insert(targets, target)
                end
            end
        end
    end
    
    for _, target in ipairs(targets) do
        if target and target.effectManager then
            local effectToApply = {}
            -- Shallow copy the effect provided in configuration
            if self.effect then
                for k, v in pairs(self.effect) do
                    effectToApply[k] = v
                end
                
                -- Append building ID to ensure multiple buildings of same type stack
                effectToApply.displayName = self.effect.name or "buff"
                effectToApply.name = effectToApply.displayName .. "_" .. self.id
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
