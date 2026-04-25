local push = require("Libraries.push")

local BattlefieldGrid = {}
BattlefieldGrid.__index = BattlefieldGrid

function BattlefieldGrid:new(game)
    local obj = setmetatable({}, self)
    obj.game = game
    -- Grid configuration
    obj.cellSize = 25
    obj.x = 0
    obj.y = 100
    obj.width = math.floor(push:getWidth() / obj.cellSize)
    obj.height = 16
    
    obj.buildings = {}
    obj.noBuildZones = {} -- map of slot -> reservation count
    obj.unlocked = {} -- For consistency with base grid
    
    -- Initialize grid and spawn protection zones
    for i = 1, obj.width * obj.height do
        local col = ((i - 1) % obj.width) + 1
        -- Reserve last 2 columns for spawning
        if col >= obj.width - 1 then
            obj.noBuildZones[i] = 1
        else
            obj.noBuildZones[i] = 0
        end
        obj.unlocked[i] = false -- Battlefield defaults to locked (use SlottedBlockers)
    end
    
    return obj
end

function BattlefieldGrid:addBuilding(building, anchorSlot)
    local slotsToOccupy = building:getSlotsFromPattern(anchorSlot)
    -- Only structures and blockers go in the buildings lookup table
    -- Turrets coexist in self.game.objects but shouldn't overwrite the platform foundation
    if not (building:isType("turret") or building:isType("passive")) then
        for _, slot in ipairs(slotsToOccupy) do
            self.buildings[slot] = building
        end
    end
    
    -- Update noBuildZones (radius logic)
    local radius = building.noBuildRadius or 1
    self:updateReservations(slotsToOccupy, radius, 1)
    
    if building.onPlaced then
        building:onPlaced(anchorSlot)
    end
    
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
    
    if building.onRemoved then
        building:onRemoved()
    end
    
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
    if not self.game then return end
    for _, obj in ipairs(self.game.objects) do
        if obj:isType("enemy") and not obj.destroyed then
            if obj.recalculatePath then
                obj:recalculatePath()
            end
        end
    end
end

function BattlefieldGrid:drawGrid()
    if self.game.inputMode == "placing" then 
        local bp = self.game.blueprint
        if not bp then return end
        
        local isBlocker = bp:isType("blocker")
        local isTurret = bp:isType("turret") or bp:isType("passive")
        
        if isBlocker or isTurret then
            -- 1. Draw subtle background grid
            love.graphics.setColor(1, 1, 1, 0.05)
            for i = 1, self.width + 1 do
                local x = self.x + (i - 1) * self.cellSize
                love.graphics.line(x, self.y, x, self.y + self.height * self.cellSize)
            end
            for j = 1, self.height + 1 do
                local y = self.y + (j - 1) * self.cellSize
                love.graphics.line(self.x, y, self.x + self.width * self.cellSize, y)
            end

            -- 2. Draw no-build zones and base restricted area (UNDER buildings)
            love.graphics.setColor(1, 0, 0, 0.15)
            local baseGrid = self.game.base.buildGrid
            local margin = 3 * self.cellSize
            local left = baseGrid.x - margin
            local right = baseGrid.x + baseGrid.width * baseGrid.cellSize + margin
            local top = baseGrid.y - margin
            local bottom = baseGrid.y + baseGrid.height * baseGrid.cellSize + margin

            for slot = 1, self.width * self.height do
                local i = ((slot - 1) % self.width) + 1
                local j = math.ceil(slot / self.width)
                local sx = self.x + (i - 1) * self.cellSize
                local sy = self.y + (j - 1) * self.cellSize
                
                local inBaseMargin = sx >= left and sx < right and sy >= top and sy < bottom
                local onBase = sx >= baseGrid.x and sx < (baseGrid.x + baseGrid.width * baseGrid.cellSize) and 
                               sy >= baseGrid.y and sy < (baseGrid.y + baseGrid.height * baseGrid.cellSize)
                
                local isNoBuild = (self.noBuildZones[slot] and self.noBuildZones[slot] > 0)
                
                if (isNoBuild or inBaseMargin) and not onBase then
                    love.graphics.rectangle("fill", sx, sy, self.cellSize, self.cellSize)
                    love.graphics.setColor(1, 0, 0, 0.3)
                    love.graphics.line(sx, sy, sx + self.cellSize, sy + self.cellSize)
                    love.graphics.line(sx + self.cellSize, sy, sx, sy + self.cellSize)
                    love.graphics.setColor(1, 0, 0, 0.15)
                end
            end
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

function BattlefieldGrid:drawOverlays()
    if self.game.inputMode == "placing" then
        local bp = self.game.blueprint
        if not bp then return end
        
        local isTurret = bp:isType("turret") or bp:isType("passive")
        
        -- 3. Draw unlocked turret slots (highlight buildable areas on blockers) - OVER buildings
        if isTurret then
            for slot = 1, self.width * self.height do
                local existing = self.buildings[slot]
                local isVacantOnPlatform = not existing or existing:isType("slotted")
                
                if self.unlocked[slot] and isVacantOnPlatform then
                    love.graphics.setColor(0, 1, 1, 0.2)
                    local i = ((slot - 1) % self.width) + 1
                    local j = math.ceil(slot / self.width)
                    local sx = self.x + (i - 1) * self.cellSize
                    local sy = self.y + (j - 1) * self.cellSize
                    love.graphics.rectangle("fill", sx + 2, sy + 2, self.cellSize - 4, self.cellSize - 4)
                    
                    love.graphics.setColor(0, 1, 1, 0.5)
                    love.graphics.rectangle("line", sx + 2, sy + 2, self.cellSize - 4, self.cellSize - 4)
                end
            end
        end

        -- 4. Draw invalid/selected slots border - OVER buildings
        if self.invalidSlots then
            love.graphics.setColor(1, 0, 0, 0.8)
            love.graphics.setLineWidth(2)
            for _, slot in ipairs(self.invalidSlots) do
                if slot >= 1 and slot <= (self.width * self.height) then
                    local i = ((slot - 1) % self.width) + 1
                    local j = math.ceil(slot / self.width)
                    love.graphics.rectangle("line", self.x + (i - 1) * self.cellSize + 1, self.y + (j - 1) * self.cellSize + 1, self.cellSize - 2, self.cellSize - 2)
                end
            end
        elseif self.selectedSlots then
            love.graphics.setColor(0, 1, 0, 0.8)
            love.graphics.setLineWidth(2)
            for _, slot in ipairs(self.selectedSlots) do
                local i = ((slot - 1) % self.width) + 1
                local j = math.ceil(slot / self.width)
                love.graphics.rectangle("line", self.x + (i - 1) * self.cellSize + 1, self.y + (j - 1) * self.cellSize + 1, self.cellSize - 2, self.cellSize - 2)
            end
        end
        
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function BattlefieldGrid:areSlotsAvailable(building, slotsToCheck, anchorSlot)
    local isPlacingTurret = building:isType("turret") or building:isType("passive")
    local baseGrid = self.game.base.buildGrid
    
    for _, slot in ipairs(slotsToCheck) do
        if slot < 1 or slot > (self.width * self.height) then return false end
        
        local existing = self.buildings[slot]
        
        -- Turret Placement Logic
        if isPlacingTurret then
            -- 1. Must be on an unlocked slot
            if not self.unlocked[slot] then return false end
            
            -- 2. Must NOT be on top of another turret
            for _, obj in ipairs(self.game.objects) do
                if not obj.destroyed and obj:isType("turret") and obj.occupiesSlot and obj:occupiesSlot(slot) then
                    return false
                end
            end
            
            -- 3. In-Base Margin check still applies (unless onBase)
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
            
        else
            -- Blocker / Other building Placement Logic
            if existing then return false end
            if self.noBuildZones[slot] and self.noBuildZones[slot] > 0 then return false end
            
            -- In-Base Margin check
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
    end
    
    if not building:isFullyInsideGrid(slotsToCheck) then
        return false
    end
    
    return true
end

return BattlefieldGrid
