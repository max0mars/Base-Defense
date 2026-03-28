local BattlefieldGrid = {}
BattlefieldGrid.__index = BattlefieldGrid

function BattlefieldGrid:new(game)
    local obj = setmetatable({}, self)
    obj.game = game
    -- Grid configuration
    obj.cellSize = 25
    obj.x = 0
    obj.y = 100
    obj.width = math.floor(love.graphics.getWidth() / obj.cellSize)
    obj.height = 16
    
    obj.buildings = {}
    obj.noBuildZones = {} -- map of slot -> reservation count
    obj.unlocked = {} -- For consistency with base grid
    
    -- Initialize grid
    for i = 1, obj.width * obj.height do
        obj.noBuildZones[i] = 0
        obj.unlocked[i] = true -- Battlefield is everywhere unlocked
    end
    
    return obj
end

function BattlefieldGrid:addBuilding(building, anchorSlot)
    local slotsToOccupy = building:getSlotsFromPattern(anchorSlot)
    for _, slot in ipairs(slotsToOccupy) do
        self.buildings[slot] = building
    end
    
    -- Update noBuildZones
    local radius = building.noBuildRadius or 1
    self:updateReservations(slotsToOccupy, radius, 1)
    
    self:recalculatePaths()
end

function BattlefieldGrid:removeBuilding(building)
    if not building.slot then return end
    
    local slotsToOccupy = building:getSlotsFromPattern(building.slot)
    for _, slot in ipairs(slotsToOccupy) do
        self.buildings[slot] = nil
    end
    
    local radius = building.noBuildRadius or 1
    self:updateReservations(slotsToOccupy, radius, -1)
    
    self:recalculatePaths()
end

function BattlefieldGrid:updateReservations(slotsToOccupy, radius, amount)
    local updatedSlots = {}
    for _, centerSlot in ipairs(slotsToOccupy) do
        local centerI = ((centerSlot - 1) % self.width) + 1
        local centerJ = math.ceil(centerSlot / self.width)
        
        for dx = -radius, radius do
            for dy = -radius, radius do
                local i = centerI + dx
                local j = centerJ + dy
                
                if i >= 1 and i <= self.width and j >= 1 and j <= self.height then
                    local targetSlot = (j - 1) * self.width + i
                    if not updatedSlots[targetSlot] then
                        self.noBuildZones[targetSlot] = (self.noBuildZones[targetSlot] or 0) + amount
                        updatedSlots[targetSlot] = true
                    end
                end
            end
        end
    end
end

function BattlefieldGrid:recalculatePaths()
    -- Placeholder for flow field updating
    print("recalculatePaths trigger: Flow fields updated.")
end

function BattlefieldGrid:draw()
    -- Draw no-build zones with subtle warning pattern
    if self.game.inputMode == "placing" and self.game.blueprint and self.game.blueprint:isType("battlefield") then
        love.graphics.setColor(1, 0, 0, 0.2)
        for slot, count in pairs(self.noBuildZones) do
            if count > 0 then
                local i = ((slot - 1) % self.width) + 1
                local j = math.ceil(slot / self.width)
                local sx = self.x + (i - 1) * self.cellSize
                local sy = self.y + (j - 1) * self.cellSize
                
                -- Draw cross-hatch or solid simple warning
                love.graphics.rectangle("fill", sx, sy, self.cellSize, self.cellSize)
                
                love.graphics.setColor(1, 0, 0, 0.5)
                love.graphics.line(sx, sy, sx + self.cellSize, sy + self.cellSize)
                love.graphics.line(sx + self.cellSize, sy, sx, sy + self.cellSize)
                love.graphics.setColor(1, 0, 0, 0.2)
            end
        end
        love.graphics.setColor(1, 1, 1, 1)

        -- Draw invalid slots (red)
        if self.invalidSlots then
            love.graphics.setColor(1, 0, 0, 1)
            love.graphics.setLineWidth(2)
            for _, slot in ipairs(self.invalidSlots) do
                if slot >= 1 and slot <= (self.width * self.height) then
                    local i = ((slot - 1) % self.width) + 1
                    local j = math.ceil(slot / self.width)
                    love.graphics.rectangle("line", self.x + (i - 1) * self.cellSize, self.y + (j - 1) * self.cellSize, self.cellSize, self.cellSize)
                end
            end
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1, 1, 1, 1)
        elseif self.selectedSlots then
            -- Draw valid selected slots (yellow)
            love.graphics.setColor(1, 1, 0, 1)
            love.graphics.setLineWidth(2)
            for _, slot in ipairs(self.selectedSlots) do
                local i = ((slot - 1) % self.width) + 1
                local j = math.ceil(slot / self.width)
                love.graphics.rectangle("line", self.x + (i - 1) * self.cellSize, self.y + (j - 1) * self.cellSize, self.cellSize, self.cellSize)
            end
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

function BattlefieldGrid:areSlotsAvailable(building, slotsToCheck, anchorSlot)
    local baseGrid = self.game.base.buildGrid
    for _, slot in ipairs(slotsToCheck) do
        if slot < 1 or slot > (self.width * self.height) or self.buildings[slot] then
            return false
        end
        if building:isType("battlefield") and self.noBuildZones[slot] and self.noBuildZones[slot] > 0 then
            return false
        end
        
        local i = ((slot - 1) % self.width) + 1
        local j = math.ceil(slot / self.width)
        local px = self.x + (i - 1) * self.cellSize
        local py = self.y + (j - 1) * self.cellSize
        
        local margin = 3 * self.cellSize
        local left = baseGrid.x - margin
        local right = baseGrid.x + baseGrid.width * baseGrid.cellSize + margin
        local top = baseGrid.y - margin
        local bottom = baseGrid.y + baseGrid.height * baseGrid.cellSize + margin
        
        if px >= left and px < right and py >= top and py < bottom then
            return false
        end
    end
    if not building:isFullyInsideGrid(slotsToCheck) then
        return false
    end
    return true
end

return BattlefieldGrid
