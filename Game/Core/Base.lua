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
    return obj
end

function Base:update(dt)
    if self.effectManager then
        self.effectManager:update(dt)
    end
end

function Base:draw()
    for i = 1, self.buildGrid.width do
        for j = 1, self.buildGrid.height do
            local slot = (j - 1) * self.buildGrid.width + i
            
            -- Fog of War: Only draw if visible
            if self:isSlotVisible(slot) then
                if not self.buildGrid.buildings[slot] then
                    if not self.buildGrid.unlocked[slot] then
                        love.graphics.setColor(0.1, 0.1, 0.1, 0.6)
                        love.graphics.rectangle("fill", self.buildGrid.x + (i - 1) * self.buildGrid.cellSize, self.buildGrid.y + (j - 1) * self.buildGrid.cellSize, self.buildGrid.cellSize, self.buildGrid.cellSize)
                        
                        -- Color logic: Green if affordable, Red if locked and expensive
                        local price = self:getSlotPrice(slot)
                        if self.game.money >= price then
                            love.graphics.setColor(0.2, 0.5, 0.2, 0.6) -- faint green
                        else
                            love.graphics.setColor(0.5, 0.2, 0.2, 0.6) -- faint red
                        end
                    else
                        love.graphics.setColor(0.5, 0.5, 0.5, 0.5) -- Gray color for empty slots
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
    if self.game.inputMode == "placing" then
        self.game.blueprint:draw(self.game.inputHandler.mouseX, self.game.inputHandler.mouseY)
    end
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

    -- Draw glowing green outline
    local pulse = (math.sin(self.game.pulseTimer * self.game.oscillationSpeed) + 1) / 2 -- Range 0 to 1
    local r, g, b = 0.2, 1, 0.2 -- Green glow
    
    -- Draw multiple layers for glow effect
    for i = 4, 1, -1 do
        local alpha = (0.25 * (1 - i/5)) * (0.6 + pulse * 0.4)
        local width = self.outlineThickness + i * 3 + pulse * 6
        love.graphics.setLineWidth(width)
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.rectangle("line", self.x - self.w / 2, self.y - self.h / 2, self.w, self.h)
    end
    
    -- Main crisp outline
    love.graphics.setLineWidth(self.outlineThickness)
    love.graphics.setColor(r, g, b, 0.9 + pulse * 0.1)
    love.graphics.rectangle("line", self.x - self.w / 2, self.y - self.h / 2, self.w, self.h)
    love.graphics.setLineWidth(1)

    for _, building in pairs(self.buildGrid.buildings) do
        building:draw()
    end

    if self.hoverTooltip then
        love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
        local font = love.graphics.getFont()
        local tw = font:getWidth(self.hoverTooltip.text)
        local th = font:getHeight()
        love.graphics.rectangle("fill", self.hoverTooltip.x, self.hoverTooltip.y, tw + 10, th + 10)
        
        if self.game.money >= self.hoverTooltip.cost then
            love.graphics.setColor(0, 1, 0, 1)
        else
            love.graphics.setColor(1, 0, 0, 1)
        end
        love.graphics.print(self.hoverTooltip.text, self.hoverTooltip.x + 5, self.hoverTooltip.y + 5)
    end
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