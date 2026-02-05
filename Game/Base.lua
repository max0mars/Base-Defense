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
    tag = "base",
    big = true,
    buildGrid = {
        cellSize = 25,
        width = 4,
        height = 16,
        buildings = {}
    },
    selectedSlot = nil,
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
        buildings = {}
    }
    return obj
end

function Base:draw()
    love.graphics.setColor(self.color or {1, 1, 1, 1})
    love.graphics.rectangle("fill", self.x - self.w / 2, self.y - self.h / 2, self.w, self.h)

    for i = 1, self.buildGrid.width do
        for j = 1, self.buildGrid.height do
            local slot = (j - 1) * self.buildGrid.width + i
            if not self.buildGrid.buildings[slot] then
                love.graphics.setColor(0.5, 0.5, 0.5, 0.5) -- Gray color for empty slots
                
                -- Check if this slot should be highlighted
                local shouldHighlight = false
                if self.game:isState("placing") and self.selectedSlots then
                    -- Highlight multiple slots during placement
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
                love.graphics.print(slot, self.buildGrid.x + (i - 1) * self.buildGrid.cellSize, self.buildGrid.y + (j - 1) * self.buildGrid.cellSize)
            end
        end
    end
    -- Draw yellow highlights for selected slots
    if self.game:isState("placing") and self.selectedSlots then
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

    for _, building in pairs(self.buildGrid.buildings) do
        building:draw()
    end
end

function Base:addBuilding(building, anchorSlot)
    if not building or not anchorSlot then
        error("Invalid building or anchor slot is missing")
    end
    
    -- Generate slots that the building will occupy
    local slotsToOccupy = building:getSlotsFromPattern(anchorSlot)
    
    -- Check if all required slots are available
    if not self:areSlotsAvailable(slotsToOccupy, anchorSlot) then
        error("One or more required slots are already occupied")
    end
    
    -- Set building's anchor slot and calculate final occupied slots
    building.slot = anchorSlot
    local finalSlots = building:getSlotsFromPattern(anchorSlot)
    building.slotsOccupied = finalSlots -- For legacy compatibility
    
    -- Occupy all slots
    for _, slot in ipairs(finalSlots) do
        self.buildGrid.buildings[slot] = building
    end
    
    building.x, building.y = building:getX() + building.buildGrid.cellSize/2, building:getY() + building.buildGrid.cellSize/2
end

function Base:areSlotsAvailable(slotsToCheck, anchorSlot)
    for _, slot in ipairs(slotsToCheck) do
        if slot < 1 or slot > (self.buildGrid.width * self.buildGrid.height) or self.buildGrid.buildings[slot] then
            return false
        end
    end
    return true
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

return Base