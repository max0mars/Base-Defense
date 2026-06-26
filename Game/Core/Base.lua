local Base = {
}
local living_object = require("Classes.living_object") -- Import the living_object module
setmetatable(Base, { __index = living_object }) -- Inherit from the object class

local default = {
    x = 50,
    y = 300,
    w = 100,
    h = 400,
    shape = "rectangle",
    color = {love.math.colorFromBytes(69, 69, 69)},
    hitbox = {shape = "rectangle"},
    hp = 200,
    maxHp = 200,
    types = { base = true},
    big = true,
    buildGrid = {
        cellSize = 25,
        width = 4,
        height = 16,
        buildings = {}
    },
    selectedSlot = nil,
    outlineThickness = 4,
}

function Base:new(config)
    local config = config or {}
    -- Merge with defaults
    for key, value in pairs(default) do
        if config[key] == nil then
            config[key] = value
        end
    end
    if not config.buildGrid then
        error("buildGrid is required for Base")
    end
    local obj = living_object:new(config)
    setmetatable(obj, { __index = self })
    obj.buildGrid = {
        x = config.buildGrid.x or 0,
        y = config.buildGrid.y or 100,
        cellSize = config.buildGrid.cellSize or 25,
        width = config.buildGrid.width,
        height = config.buildGrid.height,
        buildings = {},
        unlocked = {}
    }
    obj.damageTracker = {}
    return obj
end

function Base:update(dt)
    if self.effectManager then
        self.effectManager:update(dt)
    end
end

function Base:takeDamage(amount, damageType, hitX, hitY, sourceEntity, damageTags)
    if self.game.testingMode and self.game.baseInvincible then
        return 0
    end
    
    if sourceEntity then
        local enemyName = sourceEntity.name or "Enemy"
        
        local level = 1
        local tracker = self.damageTracker
        if _G.PersistentState then
            if not _G.PersistentState.damageTracker then
                _G.PersistentState.damageTracker = {}
            end
            tracker = _G.PersistentState.damageTracker
            level = (_G.PersistentState.battlesCompleted or 0) + 1
        else
            if not self.damageTracker then
                self.damageTracker = {}
            end
        end
        
        if not tracker[level] then
            tracker[level] = {}
        end
        
        if not tracker[level][enemyName] then
            tracker[level][enemyName] = {
                damage = 0,
                color = sourceEntity.color,
                w = sourceEntity.w or 20,
                h = sourceEntity.h or 20,
                shape = sourceEntity.shape or "rectangle"
            }
        end
        tracker[level][enemyName].damage = tracker[level][enemyName].damage + amount
    end

    self.game.damageTakenThisBattle = (self.game.damageTakenThisBattle or 0) + amount

    return living_object.takeDamage(self, amount, damageType, hitX, hitY, damageTags)
end

function Base:getProcessedDamageHistory()
    local tracker = self.damageTracker
    if _G.PersistentState and _G.PersistentState.damageTracker then
        tracker = _G.PersistentState.damageTracker
    end
    
    local history = {}
    if tracker then
        for level, enemies in pairs(tracker) do
            for name, data in pairs(enemies) do
                table.insert(history, {
                    level = level,
                    name = name,
                    damage = data.damage,
                    color = data.color,
                    w = data.w,
                    h = data.h,
                    shape = data.shape
                })
            end
        end
    end
    
    table.sort(history, function(a, b)
        if a.level == b.level then
            return a.damage > b.damage
        end
        return a.level < b.level
    end)
    
    return history
end

function Base:draw()
    for i = 1, self.buildGrid.width do
        for j = 1, self.buildGrid.height do
            local slot = (j - 1) * self.buildGrid.width + i
            
            -- Fog of War: Only draw if visible
            if self:isSlotVisible(slot) then
                if not self.buildGrid.buildings[slot] then
                    if not self.buildGrid.unlocked[slot] then
                        love.graphics.setColor(0.1, 0.1, 0.1)
                        love.graphics.rectangle("fill", self.buildGrid.x + (i - 1) * self.buildGrid.cellSize, self.buildGrid.y + (j - 1) * self.buildGrid.cellSize, self.buildGrid.cellSize, self.buildGrid.cellSize)
                        
                        -- Color logic: Green if affordable, Red if locked and expensive
                        local price = self:getSlotPrice(slot)
                        if self.game.tokens >= price then
                            love.graphics.setColor(0, 0.5, 0) -- faint green
                        else
                            love.graphics.setColor(0.5, 0, 0) -- faint red
                        end
                        
                        -- Draw $ symbol in the center of locked but visible slots
                        local font = love.graphics.getFont()
                        local char = "T"
                        local charW = font:getWidth(char)
                        local charH = font:getHeight()
                        love.graphics.print(char,
                            self.buildGrid.x + (i - 1) * self.buildGrid.cellSize + (self.buildGrid.cellSize - charW)/2,
                            self.buildGrid.y + (j - 1) * self.buildGrid.cellSize + (self.buildGrid.cellSize - charH)/2 - 2)

                        -- Hover highlight for the locked (token) slot under the cursor.
                        if self.hoveredLockedSlot and self.hoveredLockedSlot.slot == slot then
                            local sx = self.buildGrid.x + (i - 1) * self.buildGrid.cellSize
                            local sy = self.buildGrid.y + (j - 1) * self.buildGrid.cellSize
                            local cs = self.buildGrid.cellSize
                            local affordable = self.game.tokens >= (self.hoveredLockedSlot.price or 0)
                            if affordable then love.graphics.setColor(0.2, 0.9, 0.4, 0.20)
                            else love.graphics.setColor(0.9, 0.3, 0.3, 0.20) end
                            love.graphics.rectangle("fill", sx, sy, cs, cs)
                            if affordable then love.graphics.setColor(0.3, 1.0, 0.5, 0.95)
                            else love.graphics.setColor(1.0, 0.4, 0.4, 0.95) end
                            love.graphics.setLineWidth(2)
                            love.graphics.rectangle("line", sx + 1, sy + 1, cs - 2, cs - 2)
                            love.graphics.setLineWidth(1)
                        end
                    else
                        love.graphics.setColor(0.5, 0.5, 0.5, 0.5) -- Gray color for empty slots

                        -- Hover highlight for an empty (unlocked) slot under the cursor.
                        if self.hoveredEmptySlot == slot then
                            local sx = self.buildGrid.x + (i - 1) * self.buildGrid.cellSize
                            local sy = self.buildGrid.y + (j - 1) * self.buildGrid.cellSize
                            local cs = self.buildGrid.cellSize
                            love.graphics.setColor(0.4, 0.7, 1.0, 0.16)
                            love.graphics.rectangle("fill", sx, sy, cs, cs)
                            love.graphics.setColor(0.5, 0.8, 1.0, 0.9)
                            love.graphics.setLineWidth(2)
                            love.graphics.rectangle("line", sx + 1, sy + 1, cs - 2, cs - 2)
                            love.graphics.setLineWidth(1)
                        end
                    end

                    -- Check if this slot should be highlighted
                    local shouldHighlight = false
                    if self.game.inputMode == "placing" and self.selectedSlots then
                        for _, selectedSlot in ipairs(self.selectedSlots) do
                            if selectedSlot == slot then
                                shouldHighlight = true
                                break
                            end
                        end
                    elseif self.selectedSlot == slot then
                        shouldHighlight = true
                    end
                    
                    if shouldHighlight then
                        self.drawlast = {slot, i, j}
                    end
                    
                    love.graphics.rectangle("line", self.buildGrid.x + (i - 1) * self.buildGrid.cellSize, self.buildGrid.y + (j - 1) * self.buildGrid.cellSize, self.buildGrid.cellSize, self.buildGrid.cellSize)
                    --love.graphics.print(slot, self.buildGrid.x + (i - 1) * self.buildGrid.cellSize, self.buildGrid.y + (j - 1) * self.buildGrid.cellSize)
                end
            end
        end
    end
    
    -- Draw yellow highlights for selected slots
    if self.game.inputMode == "placing" and self.selectedSlots then
        love.graphics.setColor(1, 1, 0, 1) -- Yellow color for selected slots
        for _, slot in ipairs(self.selectedSlots) do
            local i = ((slot - 1) % self.buildGrid.width) + 1
            local j = math.ceil(slot / self.buildGrid.width)
            love.graphics.rectangle("line", self.buildGrid.x + (i - 1) * self.buildGrid.cellSize, self.buildGrid.y + (j - 1) * self.buildGrid.cellSize, self.buildGrid.cellSize, self.buildGrid.cellSize)
        end
    elseif self.drawlast then
        local slot, i, j = self.drawlast[1], self.drawlast[2], self.drawlast[3]
        love.graphics.setColor(1, 1, 0, 1) -- Yellow color for selected slot
        love.graphics.rectangle("line", self.buildGrid.x + (i - 1) * self.buildGrid.cellSize, self.buildGrid.y + (j - 1) * self.buildGrid.cellSize, self.buildGrid.cellSize, self.buildGrid.cellSize)
        self.drawlast = nil
    end
    
    -- Draw red outlines for invalid slots
    if self.game.inputMode == "placing" and self.invalidSlots then
        love.graphics.setColor(1, 0, 0, 1) -- Red color for invalid slots
        love.graphics.setLineWidth(2)
        for _, slot in ipairs(self.invalidSlots) do
            -- Only draw if slot is within valid grid bounds for visualization
            if slot >= 1 and slot <= (self.buildGrid.width * self.buildGrid.height) then
                local i = ((slot - 1) % self.buildGrid.width) + 1
                local j = math.ceil(slot / self.buildGrid.width)
                love.graphics.rectangle("line", self.buildGrid.x + (i - 1) * self.buildGrid.cellSize, self.buildGrid.y + (j - 1) * self.buildGrid.cellSize, self.buildGrid.cellSize, self.buildGrid.cellSize)
            end
        end
        love.graphics.setLineWidth(1) -- Reset line width
    end
    
    -- Draw green outlines for buff-affected slots
    if self.game.inputMode == "placing" and self.affectedSlots then
        love.graphics.setColor(0, 1, 0, 1) -- Green color for affected slots
        love.graphics.setLineWidth(2)
        for _, slot in ipairs(self.affectedSlots) do
            local i = ((slot - 1) % self.buildGrid.width) + 1
            local j = math.ceil(slot / self.buildGrid.width)
            love.graphics.rectangle("line", self.buildGrid.x + (i - 1) * self.buildGrid.cellSize, self.buildGrid.y + (j - 1) * self.buildGrid.cellSize, self.buildGrid.cellSize, self.buildGrid.cellSize)
        end
        love.graphics.setLineWidth(1) -- Reset line width
    end
    -- Redundant blueprint drawing removed (handled by GameManager)
    -- if self.game.inputMode == "placing" then
    --     self.game.blueprint:draw(self.game.inputHandler.mouseX, self.game.inputHandler.mouseY)
    -- end
    -- Draw green outline for buff building hover/selection slots
    if self.buffHoverSlots then
        love.graphics.setColor(0, 1, 0, 1) -- Bright green outline
        love.graphics.setLineWidth(2)
        for _, slot in ipairs(self.buffHoverSlots) do
            local i = ((slot - 1) % self.buildGrid.width) + 1
            local j = math.ceil(slot / self.buildGrid.width)
            love.graphics.rectangle("line", self.buildGrid.x + (i - 1) * self.buildGrid.cellSize, self.buildGrid.y + (j - 1) * self.buildGrid.cellSize, self.buildGrid.cellSize, self.buildGrid.cellSize)
        end
        love.graphics.setLineWidth(1) -- Reset line width
    end

    -- Draw the glowing green wall on the right edge only (the side facing the
    -- incoming enemies); the other three sides are left open.
    local pulse = (math.sin(self.game.pulseTimer * self.game.oscillationSpeed) + 1) / 2 -- Range 0 to 1
    local r, g, b = 0.2, 1, 0.2 -- Green glow
    local wallX = self.x + self.w / 2
    local wallTop = self.y - self.h / 2
    local wallBottom = self.y + self.h / 2

    -- Draw multiple layers for glow effect
    for i = 4, 1, -1 do
        local alpha = (0.25 * (1 - i/5)) * (0.6 + pulse * 0.4)
        local width = self.outlineThickness + i * 3 + pulse * 6
        love.graphics.setLineWidth(width)
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.line(wallX, wallTop, wallX, wallBottom)
    end

    -- Main crisp wall line
    love.graphics.setLineWidth(self.outlineThickness)
    love.graphics.setColor(r, g, b, 0.9 + pulse * 0.1)
    love.graphics.line(wallX, wallTop, wallX, wallBottom)
    love.graphics.setLineWidth(1)

    for _, building in pairs(self.buildGrid.buildings) do
        building:draw()
    end

    -- The unlock-slot hover tooltip is rendered by TooltipManager in screen space
    -- (drawing it here too — in world space with screen coords — duplicated and
    -- misplaced it).
end

function Base:drawHealthBar()
    -- Base health bar is handled by GUIManager HUD
end

function Base:initMainLazer(turretClass)
    local gridWidth  = self.buildGrid.width
    local gridHeight = self.buildGrid.height
    local centerRow  = math.ceil(gridHeight / 2)
    local centerCol  = math.ceil(gridWidth / 2)
    local centerSlot = (centerRow - 1) * gridWidth + centerCol
    
    self.mainLazer = turretClass:new({game = self.game})
    
    for dr = -1, 2 do
        for dc = -1, 2 do
            -- Skip the 4 corners of the 4x4 area
            if not ((dr == -1 and dc == -1) or (dr == -1 and dc == 2) or
                    (dr == 2 and dc == -1) or (dr == 2 and dc == 2)) then
                
                local r = centerRow + dr
                local c = centerCol + dc
                if r >= 1 and r <= gridHeight and c >= 1 and c <= gridWidth then
                    local s = (r - 1) * gridWidth + c
                    self.buildGrid.unlocked[s] = true
                end
            end
        end
    end
    
    self.game:newBuilding(self.mainLazer, centerSlot)
    
    -- Unlock additional adjacent slots if player chose the starting slots upgrade
    local extraUnlocks = _G.PersistentState and _G.PersistentState.startBattleExtraSlotsUnlocked or 0
    local slotsToUnlockCount = extraUnlocks * 4
    
    for i = 1, slotsToUnlockCount do
        local candidates = {}
        for s = 1, gridWidth * gridHeight do
            if not self.buildGrid.unlocked[s] then
                local neighbors = self:getNeighbors(s)
                for _, n in ipairs(neighbors) do
                    if self.buildGrid.unlocked[n] then
                        table.insert(candidates, s)
                        break
                    end
                end
            end
        end
        
        if #candidates > 0 then
            -- Sort candidates by distance to the center row/column
            table.sort(candidates, function(a, b)
                local ax = ((a - 1) % gridWidth) + 1
                local ay = math.ceil(a / gridWidth)
                local bx = ((b - 1) % gridWidth) + 1
                local by = math.ceil(b / gridWidth)
                local distA = (ax - centerCol)^2 + (ay - centerRow)^2
                local distB = (bx - centerCol)^2 + (by - centerRow)^2
                if distA == distB then
                    return a < b
                end
                return distA < distB
            end)
            
            self.buildGrid.unlocked[candidates[1]] = true
        else
            break
        end
    end
    
    return self.mainLazer
end

function Base:addBuilding(building, anchorSlot)
    if not building or not anchorSlot then
        error("Invalid building or anchor slot is missing")
    end
    
    -- Generate slots that the building will occupy
    local slotsToOccupy = building:getSlotsFromPattern(anchorSlot)
    
    -- Check if all required slots are available (unoccupied and visible)
    if not self:areSlotsAvailable(building, slotsToOccupy, anchorSlot) then
        error("One or more required slots are already occupied or currently hidden!")
    end
    
    -- Set building's anchor slot and calculate final occupied slots
    building.slot = anchorSlot
    local finalSlots = building:getSlotsFromPattern(anchorSlot)
    building.slotsOccupied = finalSlots -- For legacy compatibility
    
    -- Occupy all slots
    for _, slot in ipairs(finalSlots) do
        self.buildGrid.buildings[slot] = building
        self.buildGrid.unlocked[slot] = true
    end
    
    building.x, building.y = building:getX() + building.buildGrid.cellSize/2, building:getY() + building.buildGrid.cellSize/2
end

function Base:areSlotsAvailable(building, slotsToCheck, anchorSlot)
    -- Check for occupancy and bounds
    for _, slot in ipairs(slotsToCheck) do
        if slot < 1 or slot > (self.buildGrid.width * self.buildGrid.height) or self.buildGrid.buildings[slot] then
            return false
        end
    end
    
    if not building:isFullyInsideGrid(slotsToCheck) then
        return false
    end

    -- Expansion Logic: At least one slot must be visible (unlocked or adjacent to unlocked)
    local isConnected = false
    for _, s in ipairs(slotsToCheck) do
        if self:isSlotVisible(s) then
            isConnected = true
            break
        end
    end
    
    return isConnected
end

function Base:adjustSlotsToAnchor(slotsPattern, anchorSlot)
    -- Adjust slot pattern based on where the anchor slot is placed
    local minSlot = math.min(unpack(slotsPattern))
    local offset = anchorSlot - minSlot
    local adjustedSlots = {}
    
    for _, slot in ipairs(slotsPattern) do
        table.insert(adjustedSlots, slot + offset)
    end
    
    return adjustedSlots
end

function Base:getBuildingAtSlot(slot)
    return self.buildGrid.buildings[slot]
end

function Base:getSlotPrice(slot)
    return 1
    -- local width = self.buildGrid.width
    -- local height = self.buildGrid.height
    
    -- -- Center 2x2 area coordinates (assuming 1-based indexing)
    -- local cx1, cx2 = width / 2, width / 2 + 1
    -- local cy1, cy2 = height / 2, height / 2 + 1
    
    -- local gridX = ((slot - 1) % width) + 1
    -- local gridY = math.ceil(slot / width)
    
    -- -- Distance to the nearest part of the 2x2 center
    -- local dx = 0
    -- if gridX < cx1 then 
    --     dx = cx1 - gridX 
    -- elseif gridX > cx2 then 
    --     dx = gridX - cx2 
    -- end
    
    -- local dy = 0
    -- if gridY < cy1 then     
    --     dy = cy1 - gridY 
    -- elseif gridY > cy2 then 
    --     dy = gridY - cy2 
    -- end
    
    -- local distance = dx + dy
    -- return math.floor(10 + (distance * distance) * 15)
end

function Base:getNeighbors(slot)
    local width = self.buildGrid.width
    local height = self.buildGrid.height
    local neighbors = {}
    
    local gx = ((slot - 1) % width) + 1
    local gy = math.ceil(slot / width)
    
    if gy > 1 then table.insert(neighbors, slot - width) end -- Up
    if gy < height then table.insert(neighbors, slot + width) end -- Down
    if gx > 1 then table.insert(neighbors, slot - 1) end -- Left
    if gx < width then table.insert(neighbors, slot + 1) end -- Right
    
    return neighbors
end

function Base:clearSelection()
    self.selectedSlots = nil
    self.invalidSlots = nil
    self.affectedSlots = nil
    self.hoveredSlots = nil
    self.buffHoverSlots = nil
    self.selectionColor = nil
end

function Base:isSlotVisible(slot)
    -- A slot is visible if it is unlocked OR adjacent to an unlocked slot
    if self.buildGrid.unlocked[slot] then return true end
    
    local neighbors = self:getNeighbors(slot)
    for _, n in ipairs(neighbors) do
        if self.buildGrid.unlocked[n] then
            return true
        end
    end
    
    return false
end

return Base
