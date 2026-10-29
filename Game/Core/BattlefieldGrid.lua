local Layout = require("Game.GUI.Layout")
local LockIcon = require("Graphics.LockIcon")

local BattlefieldGrid = {}
BattlefieldGrid.__index = BattlefieldGrid

-- The field is split into three independent lanes by two border rows. Enemies
-- stay in the lane they spawn in (only special abilities, like a Phantom's
-- blink, move them across). Rows are 1-based grid rows.
-- The middle lane is a row wider than the outer two, so it is centred on the
-- field (and on the base's main turret).
BattlefieldGrid.LANES = {
    { first = 1,  last = 5 },
    { first = 7,  last = 12 },
    { first = 14, last = 18 },
}
BattlefieldGrid.BORDER_ROWS = { 6, 13 }

-- Building slots along each border: pairs of side-by-side cells, nearest the
-- base first. Each slot of a pair costs `price` tokens to unlock.
BattlefieldGrid.BORDER_SLOT_PAIRS = {
    { cols = { 11, 12 }, price = 1 },
    { cols = { 18, 19 }, price = 2 },
    { cols = { 25, 26 }, price = 3 },
}

function BattlefieldGrid:new(game)
    local obj = setmetatable({}, self)
    obj.game = game
    -- Grid configuration. The field has a FIXED world size (independent of the
    -- canvas resolution) so widening the canvas to 16:9 never resizes the grid;
    -- it is centered on screen via the Layout viewport instead.
    obj.cellSize = 25
    obj.baseMarginCells = 5
    obj.x = Layout.WORLD_X      -- 0 (world space; centered at draw time)
    obj.y = Layout.WORLD_Y      -- 100
    obj.width = math.floor(Layout.FIELD_W / obj.cellSize)  -- 32
    obj.height = math.floor(Layout.FIELD_H / obj.cellSize) -- 18
    
    obj.buildings = {}
    obj.noBuildZones = {} -- map of slot -> reservation count
    obj.unlocked = {} -- For consistency with base grid
    
    -- Initialize grid and spawn protection zones
    for i = 1, obj.width * obj.height do
        local col = ((i - 1) % obj.width) + 1
        -- Reserve last 2 columns for spawning
        if col >= obj.width - 2 then
            obj.noBuildZones[i] = 1
        else
            obj.noBuildZones[i] = 0
        end
        obj.unlocked[i] = false -- Battlefield defaults to locked (unlock with tokens)
    end

    -- Border slots are the only battlefield cells that can be built on
    obj.slotPrices = {} -- slot -> unlock price
    for _, row in ipairs(BattlefieldGrid.BORDER_ROWS) do
        for _, pair in ipairs(BattlefieldGrid.BORDER_SLOT_PAIRS) do
            for _, col in ipairs(pair.cols) do
                obj.slotPrices[(row - 1) * obj.width + col] = pair.price
            end
        end
    end
    
    return obj
end

-- -----------------------------------------------------------------------------
-- Lanes
-- -----------------------------------------------------------------------------

--- Top and bottom world y of a lane (1-3).
function BattlefieldGrid:getLaneBounds(lane)
    local rows = BattlefieldGrid.LANES[lane]
    return self.y + (rows.first - 1) * self.cellSize, self.y + rows.last * self.cellSize
end

--- The lane at world y; a y on a border (or off the field) counts as the nearest lane.
function BattlefieldGrid:getLaneAt(y)
    local best, bestDist
    for lane = 1, #BattlefieldGrid.LANES do
        local top, bottom = self:getLaneBounds(lane)
        if y >= top and y < bottom then return lane end
        local dist = math.min(math.abs(y - top), math.abs(y - bottom))
        if not bestDist or dist < bestDist then best, bestDist = lane, dist end
    end
    return best
end

--- `y` kept inside `lane`, leaving room for a body `halfSize` tall either side.
function BattlefieldGrid:clampToLane(lane, y, halfSize)
    local top, bottom = self:getLaneBounds(lane)
    halfSize = math.min(halfSize or 0, (bottom - top) / 2)
    return math.max(top + halfSize, math.min(bottom - halfSize, y))
end

function BattlefieldGrid:isBorderRow(row)
    for _, r in ipairs(BattlefieldGrid.BORDER_ROWS) do
        if r == row then return true end
    end
    return false
end

--- Token price to unlock a border slot (nil for slots that can't be built on).
function BattlefieldGrid:getSlotPrice(slot)
    return self.slotPrices[slot]
end

function BattlefieldGrid:isBuildSlot(slot)
    return self.slotPrices[slot] ~= nil
end

--- True if a turret or passive placed on this grid covers the slot.
function BattlefieldGrid:isSlotTaken(slot)
    for _, obj in ipairs(self.game.objects) do
        if not obj.destroyed and (obj:isType("turret") or obj:isType("passive"))
           and obj.buildGrid == self and obj.occupiesSlot and obj:occupiesSlot(slot) then
            return true
        end
    end
    return false
end

function BattlefieldGrid:addBuilding(building, anchorSlot)
    local slotsToOccupy = building:getSlotsFromPattern(anchorSlot)
    -- Only non-turret structures go in the buildings lookup table
    -- Turrets coexist in self.game.objects but shouldn't overwrite the platform foundation
    if not (building:isType("turret") or building:isType("passive")) then
        for _, slot in ipairs(slotsToOccupy) do
            self.buildings[slot] = building
        end
        
        -- Update noBuildZones (radius logic)
        local radius = building.noBuildRadius or 1
        self:updateReservations(slotsToOccupy, radius, 1)
    end
    
    if building.onPlaced then
        building:onPlaced(anchorSlot)
    end
    
    self:recalculatePaths()
end

function BattlefieldGrid:removeBuilding(building)
    if not building.slot then return end
    
    local slotsToOccupy = building:getSlotsFromPattern(building.slot)
    
    if not (building:isType("turret") or building:isType("passive")) then
        for _, slot in ipairs(slotsToOccupy) do
            if self.buildings[slot] == building then
                self.buildings[slot] = nil
            end
        end
        
        local radius = building.noBuildRadius or 1
        self:updateReservations(slotsToOccupy, radius, -1)
    end
    
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
    -- Nothing to recalculate while enemies walk straight at the base
    if not require("Physics.Navigators").USE_PATHFINDING then return end
    for _, obj in ipairs(self.game.objects) do
        if obj:isType("enemy") and not obj.destroyed then
            if obj.recalculatePath then
                obj:recalculatePath()
            end
        end
    end
end

local BORDER_COLOR = { 0.0, 0.85, 1.0 }

--- Top-left world position of a slot.
function BattlefieldGrid:getSlotPosition(slot)
    local i = ((slot - 1) % self.width) + 1
    local j = math.ceil(slot / self.width)
    return self.x + (i - 1) * self.cellSize, self.y + (j - 1) * self.cellSize
end

--- The border rows walling the lanes off, from the base's edge to the spawn edge.
function BattlefieldGrid:drawBorders()
    local baseGrid = self.game.base and self.game.base.buildGrid
    local left = baseGrid and (baseGrid.x + baseGrid.width * baseGrid.cellSize) or self.x
    local right = self.x + self.width * self.cellSize
    local c = BORDER_COLOR
    for _, row in ipairs(BattlefieldGrid.BORDER_ROWS) do
        local top = self.y + (row - 1) * self.cellSize
        local bottom = top + self.cellSize
        love.graphics.setColor(0.02, 0.05, 0.08, 0.9)
        love.graphics.rectangle("fill", left, top, right - left, self.cellSize)
        -- Hatching so the band reads as a wall, not a walkable row
        love.graphics.setColor(c[1], c[2], c[3], 0.08)
        for x = left, right, 10 do
            love.graphics.line(x, bottom, x + self.cellSize, top)
        end
        love.graphics.setColor(c[1], c[2], c[3], 0.6)
        love.graphics.setLineWidth(2)
        love.graphics.line(left, top, right, top)
        love.graphics.line(left, bottom, right, bottom)
        love.graphics.setLineWidth(1)
    end
end

--- Border building slots: locked ones show a padlock (price in the hover tooltip),
--- unlocked ones an empty pad.
function BattlefieldGrid:drawBorderSlots()
    local cs = self.cellSize
    for slot, price in pairs(self.slotPrices) do
        local sx, sy = self:getSlotPosition(slot)
        if self.unlocked[slot] then
            love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
            love.graphics.rectangle("line", sx + 2, sy + 2, cs - 4, cs - 4)
        else
            love.graphics.setColor(0.1, 0.1, 0.1)
            love.graphics.rectangle("fill", sx + 1, sy + 1, cs - 2, cs - 2)
            if self.game.tokens and self.game.tokens >= price then
                love.graphics.setColor(0, 0.5, 0) -- faint green
            else
                love.graphics.setColor(0.5, 0, 0) -- faint red
            end
            love.graphics.rectangle("line", sx + 1, sy + 1, cs - 2, cs - 2)
            LockIcon.draw(sx + cs / 2, sy + cs / 2)
        end

        -- Hover highlight for the border slot under the cursor
        if self.hoveredSlot == slot then
            local affordable = self.unlocked[slot] or (self.game.tokens or 0) >= price
            if affordable then love.graphics.setColor(0.3, 1.0, 0.5, 0.95)
            else love.graphics.setColor(1.0, 0.4, 0.4, 0.95) end
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", sx + 1, sy + 1, cs - 2, cs - 2)
            love.graphics.setLineWidth(1)
        end
    end
end

function BattlefieldGrid:drawGrid()
    self:drawBorders()
    self:drawBorderSlots()

    if self.game.inputMode == "placing" then 
        local bp = self.game.blueprint
        if not bp then return end
        
        local isTurret = bp:isType("turret") or bp:isType("passive")

        if isTurret then
            -- Subtle background grid
            love.graphics.setColor(1, 1, 1, 0.05)
            for i = 1, self.width + 1 do
                local x = self.x + (i - 1) * self.cellSize
                love.graphics.line(x, self.y, x, self.y + self.height * self.cellSize)
            end
            for j = 1, self.height + 1 do
                local y = self.y + (j - 1) * self.cellSize
                love.graphics.line(self.x, y, self.x + self.width * self.cellSize, y)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function BattlefieldGrid:drawOverlays()
    if self.game.inputMode == "placing" then
        local bp = self.game.blueprint
        if not bp then return end
        
        local isTurret = bp:isType("turret") or bp:isType("passive")
        
        -- 3. Draw the vacant border slots it could go on - OVER buildings
        if isTurret then
            for slot in pairs(self.slotPrices) do
                if not self:isSlotTaken(slot) then
                    local sx, sy = self:getSlotPosition(slot)
                    local a = self.unlocked[slot] and 1 or 0.5
                    love.graphics.setColor(0, 1, 1, 0.2 * a)
                    love.graphics.rectangle("fill", sx + 2, sy + 2, self.cellSize - 4, self.cellSize - 4)
                    
                    love.graphics.setColor(0, 1, 1, 0.5 * a)
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
        
        -- Turret Placement Logic
        if isPlacingTurret then
            -- 1. Must be a border slot (a locked one is unlocked as part of the placement)
            if not self:isBuildSlot(slot) then return false end
            
            -- 2. Must NOT be on top of another turret or passive
            if self:isSlotTaken(slot) then return false end
            
            -- 3. In-Base Margin check still applies (unless onBase)
            local i = ((slot - 1) % self.width) + 1
            local j = math.ceil(slot / self.width)
            local px = self.x + (i - 1) * self.cellSize
            local py = self.y + (j - 1) * self.cellSize
            
            local margin = self.baseMarginCells * self.cellSize
            local left = baseGrid.x - margin
            local right = baseGrid.x + baseGrid.width * baseGrid.cellSize + margin
            local top = baseGrid.y - margin
            local bottom = baseGrid.y + baseGrid.height * baseGrid.cellSize + margin
            
            if px >= left and px < right and py >= top and py < bottom then
                return false
            end
        else
            -- Only turrets and passives can be built on the battlefield
            return false
        end
    end

    if not building:isFullyInsideGrid(slotsToCheck) then
        return false
    end

    return true
end

return BattlefieldGrid
