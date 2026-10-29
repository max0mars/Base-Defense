local Layout = require("Game.GUI.Layout")

local InputHandler = {}
InputHandler.__index = InputHandler

function InputHandler:new(game)
    local obj = setmetatable({}, self)
    obj.game = game
    obj.mouseX = 0
    obj.mouseY = 0
    obj.buildMode = false
    obj.selectedBuilding = nil
    obj.selectedEnemy = nil
    obj.hoveredBuilding = nil
obj.confirmRect = nil
    obj.fireDelay = 0
    obj.isMouseDown = false
    -- Edit mode (between waves only): drag-select turrets, then aim them together.
    obj.editMode = false
    obj.editSelection = {}       -- turrets currently being aimed as a group
    obj.editSavedDirections = {} -- turret -> arc direction before aiming (for cancel)
    obj.dragStart = nil          -- field-space {x, y} of an in-progress drag
    return obj
end

-- Drags shorter than this (world px) on both axes count as a plain click.
local DRAG_THRESHOLD = 4

--- Edit mode only lives between waves, with no card or placement in progress.
function InputHandler:isEditPhase()
    local game = self.game
    return (game:isState("startup") or game:isState("preparing")) and game.inputMode == "idle"
end

--- Whether edit mode can be switched on right now (also blocked behind overlays).
function InputHandler:canEdit()
    return self:isEditPhase() and not (self.game.gui and self.game.gui:overlayActive())
end

function InputHandler:toggleEditMode()
    if self.editMode then
        self:exitEditMode()
    elseif self:canEdit() then
        self:clearSelection()
        self.editMode = true
    end
end

--- Leaves edit mode, keeping whatever aim the group currently has.
function InputHandler:exitEditMode()
    self:commitEditAim()
    self.dragStart = nil
    self.editMode = false
end

--- Turrets the group aim can steer. The main turret is aimed by the player directly.
function InputHandler:isEditAimable(obj)
    return obj:isType("turret") and not obj:isType("mainturret") and obj.firingArc
        and obj.slot and not obj.destroyed
end

function InputHandler:isEditSelected(obj)
    for _, b in ipairs(self.editSelection) do
        if b == obj then return true end
    end
    return false
end

--- Normalized field-space rectangle of the current drag, or nil when not dragging.
function InputHandler:getDragRect()
    if not self.dragStart then return nil end
    local x1, y1 = self.dragStart.x, self.dragStart.y
    local x2, y2 = self.mouseX, self.mouseY
    return math.min(x1, x2), math.min(y1, y2), math.abs(x2 - x1), math.abs(y2 - y1)
end

local function isBuildingInRect(obj, rx, ry, rw, rh)
    local cx, cy = obj:getCenterPosition()
    return cx >= rx and cx <= rx + rw and cy >= ry and cy <= ry + rh
end

--- Selected turrets plus any turret inside the live drag box (for arc previews).
function InputHandler:isEditHighlighted(obj)
    if not self.editMode then return false end
    if self:isEditSelected(obj) then return true end
    local rx, ry, rw, rh = self:getDragRect()
    if rx and (rw > DRAG_THRESHOLD or rh > DRAG_THRESHOLD) and self:isEditAimable(obj) then
        return isBuildingInRect(obj, rx, ry, rw, rh)
    end
    return false
end

function InputHandler:setEditSelection(buildings)
    self.editSelection = buildings
    self.editSavedDirections = {}
    for _, b in ipairs(buildings) do
        self.editSavedDirections[b] = b.firingArc.direction
    end
end

--- Locks in the group's current aim and clears the selection.
function InputHandler:commitEditAim()
    self.editSelection = {}
    self.editSavedDirections = {}
end

--- Restores the group's pre-aim directions and clears the selection.
function InputHandler:cancelEditAim()
    for b, dir in pairs(self.editSavedDirections) do
        b.firingArc.direction = dir
        b.rotation = dir
        b.targetRotation = dir
    end
    self:commitEditAim()
end

--- Each selected turret faces the cursor, so the whole group converges on one point.
function InputHandler:updateEditAim()
    for i = #self.editSelection, 1, -1 do
        local b = self.editSelection[i]
        if b.destroyed then
            table.remove(self.editSelection, i)
            self.editSavedDirections[b] = nil
        else
            local cx, cy = b:getCenterPosition()
            local angle = math.atan2(self.mouseY - cy, self.mouseX - cx)
            if angle < 0 then angle = angle + 2 * math.pi end
            b.firingArc.direction = angle
            b.rotation = angle
            b.targetRotation = angle
        end
    end
end

--- Selects every aimable turret (the A key). Any group already being aimed goes
--- back to how it was first, so this always starts a fresh aim.
function InputHandler:selectAllEditTurrets()
    if not self.editMode then return end
    self:cancelEditAim()
    self.dragStart = nil
    local picked = {}
    for _, obj in ipairs(self.game.objects) do
        if self:isEditAimable(obj) then table.insert(picked, obj) end
    end
    self:setEditSelection(picked)
end

--- Turns every aimable turret back to face forward (the Backspace key). Any
--- group being aimed is dropped first.
function InputHandler:resetEditAim()
    if not self.editMode then return end
    self:commitEditAim()
    self.dragStart = nil
    for _, obj in ipairs(self.game.objects) do
        if self:isEditAimable(obj) then
            obj.firingArc.direction = 0
            obj.rotation = 0
            obj.targetRotation = 0
        end
    end
end

function InputHandler:finishEditDrag()
    local rx, ry, rw, rh = self:getDragRect()
    self.dragStart = nil
    if not rx then return end

    local picked = {}
    if rw <= DRAG_THRESHOLD and rh <= DRAG_THRESHOLD then
        -- Plain click: pick the single turret under the cursor, if any.
        for _, obj in ipairs(self.game.objects) do
            if self:isEditAimable(obj) and self:isMouseOverBuilding(obj) then
                picked[1] = obj
                break
            end
        end
    else
        for _, obj in ipairs(self.game.objects) do
            if self:isEditAimable(obj) and isBuildingInRect(obj, rx, ry, rw, rh) then
                table.insert(picked, obj)
            end
        end
    end
    self:setEditSelection(picked)
end

--- World-space overlay: the drag box and an outline on each highlighted turret.
-- @param drawOutline function(building, color) that outlines a building's cells
function InputHandler:drawEditOverlay(drawOutline)
    if not self.editMode then return end
    love.graphics.push("all")
    local rx, ry, rw, rh = self:getDragRect()
    if rx and (rw > DRAG_THRESHOLD or rh > DRAG_THRESHOLD) then
        love.graphics.setColor(1.0, 0.75, 0.2, 0.12)
        love.graphics.rectangle("fill", rx, ry, rw, rh)
        love.graphics.setColor(1.0, 0.75, 0.2, 0.8)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", rx, ry, rw, rh)
    end
    for _, obj in ipairs(self.game.objects) do
        if self:isEditHighlighted(obj) then
            drawOutline(obj, {1.0, 0.75, 0.2, 0.9})
        end
    end
    love.graphics.pop()
end

function InputHandler:update(dt)
    local game = self.game
    
    if self.game.base then
        self.game.base.hoverTooltip = nil
        self.game.base.hoveredLockedSlot = nil
        self.game.base.hoveredEmptySlot = nil
    end

    -- Raw (full-canvas) cursor, used for screen-space tooltips and HUD checks.
    self.screenMouseX, self.screenMouseY = love.mouse.getPosition()
    -- Field-local cursor, used for all world/grid interactions.
    self.mouseX, self.mouseY = Layout.mouseToField(self.screenMouseX, self.screenMouseY)

    -- Edit mode ends as soon as a wave starts or a card is played.
    if self.editMode and not self:isEditPhase() then
        self:exitEditMode()
    end
    if self.editMode then
        self:updateEditAim()
    end

    
    -- Handle space key hold for showing all firing arcs
    local showAllArcs = love.keyboard.isDown("space")
    for _, obj in ipairs(game.objects) do
        if (obj:isType("turret") or (obj:isType("passive") and obj.range)) and not obj.destroyed then
            if showAllArcs then
                obj.showArc = true
            else
                -- Only keep selected building's arc visible when space not held
                obj.showArc = (obj == self.selectedBuilding) or self:isEditHighlighted(obj)
            end
        end
    end
    
    -- A modal overlay (card draft, mutation pick, ...) covers the board: nothing
    -- underneath it reacts to the mouse
    local overlayActive = game.gui and game.gui:overlayActive()
    if overlayActive then
        if self.hoveredBuilding then self.hoveredBuilding.showEffects = false end
        self.hoveredBuilding = nil
    else
        self:handleBuildingHover()
    end
    
    -- The selected turret's firing arc follows the mouse: a just-placed turret
    -- until the click that sets it, and between waves any turret clicked on
    -- (until the next click). During a wave, turrets keep their aim, and one
    -- clicked during a wave isn't re-aimed once it ends. Edit mode aims groups
    -- of turrets instead; the main turret aims at the cursor itself.
    local selected = self.selectedBuilding
    local reAiming = self.reAimSelected and self:isEditPhase() and not self.editMode
    if (game.inputMode == "aiming" or reAiming) and selected and selected.firingArc
       and not selected:isType("mainturret") then
        local cx, cy = self.selectedBuilding:getCenterPosition()
        local dx = self.mouseX - cx
        local dy = self.mouseY - cy
        local angleToMouse = math.atan2(dy, dx)
        
        -- Normalize angle to [0, 2π]
        if angleToMouse < 0 then
            angleToMouse = angleToMouse + 2 * math.pi
        end
        
        self.selectedBuilding.firingArc.direction = angleToMouse
    end
    
    if game.inventory.hoveredCardIndex then
        local base = game.base
        base.selectedSlots = nil
        base.invalidSlots = nil
        base.affectedSlots = nil
        base.selectedSlot = nil
    elseif not overlayActive then
        -- Only handle building slot hover when placing
        if game.inputMode == "placing" then
            self:handleBuildingSlotHover()
        elseif game.inputMode == "idle" and not self.editMode then
            self:handleLockedSlotHover()
        end
    end

    self:handleButtonHold()
    
    if self.fireDelay > 0 then
        self.fireDelay = self.fireDelay - dt
    end
end

function InputHandler:handleBuildingHover()
    local gameObjects = self.game.objects
    local showAllArcs = love.keyboard.isDown("space")
    local base = self.game.base
    
    base.buffHoverSlots = nil
    
    -- Find the hovered turret or passive
    local bestHover = nil
    for _, obj in ipairs(gameObjects) do
        if (obj:isType("turret") or obj:isType("passive")) and not obj.destroyed then
            if self:isMouseOverBuilding(obj) then
                bestHover = obj
                -- If we found a turret or passive, it takes absolute priority
                if obj:isType("turret") or obj:isType("passive") then
                    break
                end
            end
        end
    end

    -- Update hovered building state
    if self.hoveredBuilding and self.hoveredBuilding ~= bestHover then
        self.hoveredBuilding.showEffects = false
    end
    self.hoveredBuilding = bestHover
    
    if bestHover then
        bestHover.showEffects = true
        -- Handle turret-specific hover (firing arcs)
        if bestHover:isType("turret") or (bestHover:isType("passive") and bestHover.range) then
            bestHover.showArc = true
        end
        
        -- Handle buff building hover (affected slots)
        if bestHover:isType("passive") and bestHover.getAffectedSlotsFromAnchor then
            base.buffHoverSlots = bestHover:getAffectedSlotsFromAnchor(bestHover.slot)
        end
    end

    -- Cleanup arcs for all non-hovered/non-selected buildings
    for _, obj in ipairs(gameObjects) do
        if (obj:isType("turret") or obj:isType("passive")) and not obj.destroyed then
            if obj ~= self.hoveredBuilding and obj ~= self.selectedBuilding and not showAllArcs
               and not self:isEditHighlighted(obj) then
                if obj:isType("turret") or (obj:isType("passive") and obj.range) then
                    obj.showArc = false
                    obj.showEffects = false
                end
            end
        end
    end
end

function InputHandler:handleButtonHold()
    local game = self.game
    local mainLazer = game.mainLazer
    
    -- Prevent firing while interacting with UI or placing buildings
    if game.inputMode ~= "idle" then return end
    if game.rewardSystem and game.rewardSystem.isActive then return end
    if self.fireDelay > 0 then return end
    if self.holdFireUntilRelease then return end

    -- Only fire when the cursor is over the battlefield (not the surrounding HUD).
    if not Layout.inFieldScreen(self.screenMouseX, self.screenMouseY) then return end

    if self.isMouseDown then
        -- Handle left mouse button hold actions here
        mainLazer:PlayerClick(self.mouseX, self.mouseY)
    end
end

function InputHandler:isMouseOverBuilding(building)
    if not building.slot then return false end -- Building not placed yet
    
    -- Get all slots occupied by the building
    local occupiedSlots = building:getSlotsFromPattern(building.slot)
    local buildGrid = building.buildGrid
    
    -- Check if mouse is over any occupied slot
    for _, slot in ipairs(occupiedSlots) do
        local i = ((slot - 1) % buildGrid.width) + 1
        local j = math.ceil(slot / buildGrid.width)
        local slotX = buildGrid.x + (i - 1) * buildGrid.cellSize
        local slotY = buildGrid.y + (j - 1) * buildGrid.cellSize
        
        -- Check if mouse is within this slot
        if self.mouseX >= slotX and self.mouseX <= slotX + buildGrid.cellSize and
           self.mouseY >= slotY and self.mouseY <= slotY + buildGrid.cellSize then
            return true
        end
    end
    
    return false
end

--- The square an Area card would hit: `size` x `size` cells of the base grid
--- (or the battlefield grid, when only that is under the mouse), centred as
--- near the mouse as fits inside the grid. Returns
--- { grid, x, y, w, h, turrets } in world space, or nil off the grids.
function InputHandler:getAreaTarget(size)
    local game = self.game
    local grid
    if self:isMouseOverGrid(game.base.buildGrid) then
        grid = game.base.buildGrid
    elseif self:isMouseOverGrid(game.battlefieldGrid) then
        grid = game.battlefieldGrid
    else
        return nil
    end
    local cs = grid.cellSize
    local cols, rows = math.min(size, grid.width), math.min(size, grid.height)
    -- Top-left cell (0-based) of the square whose middle is nearest the mouse
    local col = math.floor((self.mouseX - grid.x) / cs - cols / 2 + 0.5)
    local row = math.floor((self.mouseY - grid.y) / cs - rows / 2 + 0.5)
    col = math.max(0, math.min(grid.width - cols, col))
    row = math.max(0, math.min(grid.height - rows, row))

    local area = { grid = grid, x = grid.x + col * cs, y = grid.y + row * cs, w = cols * cs, h = rows * cs, turrets = {} }
    for _, obj in ipairs(game.objects) do
        if obj:isType("turret") and not obj:isType("mainturret") and not obj.destroyed and obj.slot then
            local cx, cy = obj.x, obj.y
            if obj.getCenterPosition then cx, cy = obj:getCenterPosition() end
            if cx >= area.x and cx < area.x + area.w and cy >= area.y and cy < area.y + area.h then
                table.insert(area.turrets, obj)
            end
        end
    end
    return area
end

function InputHandler:isMouseOverGrid(grid)
    if not grid then return false end
    return self.mouseX >= grid.x and self.mouseX < grid.x + grid.width * grid.cellSize and
           self.mouseY >= grid.y and self.mouseY < grid.y + grid.height * grid.cellSize
end

function InputHandler:handleBuildingSlotHover()
    local game = self.game
    local base = game.base
    
    if not game.blueprint then return end
    
    local hoverBattlefield = self:isMouseOverGrid(game.battlefieldGrid)

    -- Pick the grid: Turrets use battlefield ONLY if hovering over it.
    local buildGrid = base.buildGrid -- Default
    local isBattlefield = false

    if (game.blueprint:isType("turret") or game.blueprint:isType("passive")) and hoverBattlefield then
        -- Only use battlefield if NOT hovering over the base grid (prioritize base)
        if not self:isMouseOverGrid(base.buildGrid) then
            buildGrid = game.battlefieldGrid
            isBattlefield = true
        end
    end
    
    game.blueprint.buildGrid = buildGrid
    
    local gridX = math.floor((self.mouseX - buildGrid.x) / buildGrid.cellSize) + 1
    local gridY = math.floor((self.mouseY - buildGrid.y) / buildGrid.cellSize) + 1
    
    base.selectedSlot = nil
    base.selectedSlots = nil
    base.invalidSlots = nil
    base.affectedSlots = nil
    if game.battlefieldGrid then
        game.battlefieldGrid.selectedSlot = nil
        game.battlefieldGrid.selectedSlots = nil
        game.battlefieldGrid.invalidSlots = nil
    end

    local activeStateBox = isBattlefield and game.battlefieldGrid or base

    if gridX >= 1 and gridX <= buildGrid.width and
       gridY >= 1 and gridY <= buildGrid.height then
        local anchorSlot = (gridY - 1) * buildGrid.width + gridX
        
        if game.inputMode == "placing" then
            local invalidSlots = {} -- Defined early to avoid nil errors later
            local slotsToOccupy = game.blueprint:getSlotsFromPattern(anchorSlot)
            
            -- Validation: Use the grid's own logic to check for obstacles/locking
            if not activeStateBox:areSlotsAvailable(game.blueprint, slotsToOccupy, anchorSlot) then
                invalidSlots = slotsToOccupy
            end
            
            -- A click here would be refused if unlock + card cost exceed tokens, so preview it as invalid too
            local totalCost = 0
            if #invalidSlots == 0 then
                totalCost = self:getUnlockCost(slotsToOccupy, buildGrid, isBattlefield)
                if totalCost > 0 then
                    local affordable = game:canAffordPlacement(totalCost)
                    local unit = (totalCost == 1) and " Token)" or " Tokens)"
                    local text = affordable and ("Unlock slot(s) and place building? (" .. totalCost .. unit)
                        or ("Not enough tokens to unlock and place (" .. (totalCost + game:getActiveCardTokenCost()) .. " needed)")
                    base.hoverTooltip = {x = self.screenMouseX + 15, y = self.screenMouseY + 15, text = text, cost = totalCost, affordable = affordable}
                    if not affordable then
                        invalidSlots = slotsToOccupy
                    end
                end
            end

            if #invalidSlots > 0 then
                activeStateBox.selectedSlots = nil
                activeStateBox.invalidSlots = slotsToOccupy
            else
                activeStateBox.selectedSlots = slotsToOccupy
                activeStateBox.invalidSlots = nil
            end
            
            if not isBattlefield and game.blueprint.getAffectedSlotsFromAnchor and #invalidSlots == 0 then
                base.affectedSlots = game.blueprint:getAffectedSlotsFromAnchor(anchorSlot)
            else
                base.affectedSlots = nil
            end

            -- GRID SNAPPING: Calculate center of the anchor slot for the preview
            self.snappedX = buildGrid.x + (gridX - 1) * buildGrid.cellSize + buildGrid.cellSize / 2
            self.snappedY = buildGrid.y + (gridY - 1) * buildGrid.cellSize + buildGrid.cellSize / 2
        else
            activeStateBox.selectedSlot = anchorSlot
            self.snappedX = nil
            self.snappedY = nil
        end
    else
        self.snappedX = nil
        self.snappedY = nil
    end
end

--- Token cost of unlocking the locked base slots a placement would occupy (battlefield slots are free).
function InputHandler:getUnlockCost(slotsToOccupy, buildGrid, isBattlefield)
    if isBattlefield then return 0 end
    local totalCost = 0
    for _, s in ipairs(slotsToOccupy) do
        if not buildGrid.unlocked[s] then
            totalCost = totalCost + self.game.base:getSlotPrice(s)
        end
    end
    return totalCost
end

function InputHandler:handleLockedSlotHover()
    local base = self.game.base
    local buildGrid = base.buildGrid
    
    local gridX = math.floor(self.mouseX / buildGrid.cellSize) + 1
    local gridY = math.floor((self.mouseY - buildGrid.y) / buildGrid.cellSize) + 1
    
    if gridX >= 1 and gridX <= buildGrid.width and
       gridY >= 1 and gridY <= buildGrid.height then
        local anchorSlot = (gridY - 1) * buildGrid.width + gridX
        -- Expansion Logic: Only allow interaction if visible
        if not buildGrid.buildings[anchorSlot] and base:isSlotVisible(anchorSlot) then
            if not buildGrid.unlocked[anchorSlot] then
                local cost = base:getSlotPrice(anchorSlot)
                local unit = (cost == 1) and " Token)" or " Tokens)"
                base.hoverTooltip = {x = self.screenMouseX + 15, y = self.screenMouseY + 15, text = "Unlock slot? (" .. cost .. unit, cost = cost}
                base.hoveredLockedSlot = {slot = anchorSlot, price = cost}
            else
                base.hoveredEmptySlot = anchorSlot
            end
        end
    end
end

function InputHandler:mousepressed(x, y, button)
    local game = self.game
    if button == 1 then self.isMouseDown = true end
    
    if game:isState("mulligan") then
        game:handleMulliganClick(x, y, button)
        return
    end

    -- Check GUI consumption first
    if game.gui:mousepressed(x, y, button) then
        return
    end
    
    -- Reward system check (if not consumed by GUIManager)
    if game.rewardSystem and game.rewardSystem.isActive then
        game.rewardSystem:mousepressed(x, y, button)
        return
    end

    -- Everything below operates in WORLD space (grids, turrets). Convert the
    -- click to field-local coords; clicks outside the field fail grid bounds.
    x, y = Layout.mouseToField(x, y)

    local base = game.base
    local mainLazer = game.mainLazer

    -- Edit mode owns the battlefield: left drags select / clicks commit the aim,
    -- right-click cancels an aim in progress.
    if self.editMode then
        if button == 1 then
            if #self.editSelection > 0 then
                self:commitEditAim()
            elseif Layout.inFieldScreen(self.screenMouseX, self.screenMouseY) then
                self.dragStart = { x = x, y = y }
            end
            return
        elseif button == 2 and (#self.editSelection > 0 or self.dragStart) then
            self.dragStart = nil
            self:cancelEditAim()
            return
        end
    end

    if button == 2 then
        if game.inputMode == "placing" or game.inputMode == "targeting_card" or game.inputMode == "targeting_global"
           or game.inputMode == "targeting_spell" or game.inputMode == "targeting_area" then
            if game.activeCard then
                game:refundCard(game.activeCard)
            end
            if game.blueprint then
                game.blueprint = nil
            end
            game.inputMode = "idle"
            return
        end
        -- Placed buildings are permanent: right-click does nothing else
        return
    end

    -- Handle aiming after placement
    if game.inputMode == "aiming" and button == 1 then
        game.inputMode = "idle"
        self.fireDelay = 0.15 -- Small delay to prevent accidental firing
        self:clearSelection()
        return
    end
    
    -- Handle global targeting execution
    if game.inputMode == "targeting_global" and button == 1 then
        local hoverBattlefield = self:isMouseOverGrid(game.battlefieldGrid)
        local hoverBase = self:isMouseOverGrid(game.base.buildGrid)
        
        if hoverBattlefield or hoverBase then
            local card = game.activeCard
            if card then
                if type(card.execute) == "function" then
                    local success = card:execute(game)
                    if success ~= false then
                        game:consumeCard(card)
                    else
                        game:refundCard(card)
                    end
                else
                    game:refundCard(card)
                end
            end
        else
            if game.activeCard then
                game:refundCard(game.activeCard)
            end
        end
        game.inputMode = "idle"
        return
    end

    -- Handle area targeting execution (a square of grid cells)
    if game.inputMode == "targeting_area" and button == 1 then
        local card = game.activeCard
        local area = card and self:getAreaTarget(card.areaSize or 2)
        if card and area then
            if card:execute(area) then
                game:consumeCard(card)
            else
                game:spawnFloatingText("No turrets there!", x, y, {0.8, 0.2, 0.2, 1})
                game:refundCard(card)
            end
        elseif card then
            game:refundCard(card)
        end
        game.inputMode = "idle"
        -- The click that plays the card must not turn into main-turret fire while held
        self.holdFireUntilRelease = true
        return
    end

    -- Handle spell targeting execution
    if game.inputMode == "targeting_spell" and button == 1 then
        local mx, my = love.mouse.getPosition()
        if Layout.inFieldScreen(mx, my) then
            local card = game.activeCard
            if card then
                local success = card:execute(x, y, game)
                if success then
                    game:consumeCard(card)
                else
                    game:spawnScreenText("Invalid target!", mx, my, {0.8, 0.2, 0.2, 1})
                    game:refundCard(card)
                end
            end
        else
            if game.activeCard then
                game:refundCard(game.activeCard)
            end
        end
        game.inputMode = "idle"
        -- The casting click must not turn into main-turret fire while still held.
        self.holdFireUntilRelease = true
        return
    end

    -- Handle targeting execution
    if game.inputMode == "targeting_card" and button == 1 then
        local clickedTarget = nil
        for _, obj in ipairs(game.objects) do
            if (obj:isType("turret") or obj:isType("passive")) and not obj.destroyed then
                if self:isMouseOverBuilding(obj) then
                    clickedTarget = obj
                    if obj:isType("turret") or obj:isType("passive") then
                        break
                    end
                end
            end
        end
        
        if clickedTarget then
            local card = game.activeCard
            if card then
                if card.payload then
                    if card.payload.isMainUpgrade then
                        if clickedTarget:isType("mainturret") then
                            clickedTarget:applyUpgrade({ id = card.id, name = card.name })
                            game:consumeCard(card)
                        else
                            game:spawnFloatingText("Must be used on Main Turret!", x, y, {0.8, 0.2, 0.2, 1})
                            game:refundCard(card)
                        end
                    elseif card.payload.effect then
                        if card.payload.requiredType and not clickedTarget:isType(card.payload.requiredType) then
                            game:spawnFloatingText("Must be used on " .. card.payload.requiredType, x, y, {0.8, 0.2, 0.2, 1})
                            game:refundCard(card)
                        elseif clickedTarget.effectManager then
                            clickedTarget.effectManager:applyEffect(card.payload.effect)
                            game:consumeCard(card)
                        else
                            game:spawnFloatingText("Invalid target!", x, y, {0.8, 0.2, 0.2, 1})
                            game:refundCard(card)
                        end
                    else
                        game:refundCard(card)
                    end
                elseif type(card.execute) == "function" then
                    -- This is likely an Instant card
                    local success = card:execute(clickedTarget)
                    if success then
                        game:consumeCard(card)
                    else
                        game:spawnFloatingText("Invalid target!", x, y, {0.8, 0.2, 0.2, 1})
                        game:refundCard(card)
                    end
                else
                    game:refundCard(card)
                end
            end
        else
            if game.activeCard then
                game:refundCard(game.activeCard)
            end
        end
        return
    end
    
    -- Handle building placement
    if game.inputMode == "placing" and button == 1 then
        local hoverBattlefield = self:isMouseOverGrid(game.battlefieldGrid)

        local buildGrid = base.buildGrid
        local isBattlefield = false
        if (game.blueprint:isType("turret") or game.blueprint:isType("passive")) and hoverBattlefield then
            if not self:isMouseOverGrid(base.buildGrid) then
                buildGrid = game.battlefieldGrid
                isBattlefield = true
            end
        end
        local activeStateBox = isBattlefield and game.battlefieldGrid or base

        local gridX = math.floor((x - buildGrid.x) / buildGrid.cellSize) + 1
        local gridY = math.floor((y - buildGrid.y) / buildGrid.cellSize) + 1
        if gridX >= 1 and gridX <= buildGrid.width and
           gridY >= 1 and gridY <= buildGrid.height then
            local anchorSlot = (gridY - 1) * buildGrid.width + gridX
            
            -- Check if all required slots are available
            local slotsToOccupy = game.blueprint:getSlotsFromPattern(anchorSlot)
            if activeStateBox:areSlotsAvailable(game.blueprint, slotsToOccupy, anchorSlot) then
            
                local totalCost = self:getUnlockCost(slotsToOccupy, buildGrid, isBattlefield)
                
                if totalCost > 0 then
                    if game:canAffordPlacement(totalCost) then
                        game.tokens = game.tokens - totalCost
                        for _, s in ipairs(slotsToOccupy) do
                            buildGrid.unlocked[s] = true
                        end
                    else
                        print("Cannot place building: Not enough tokens to unlock slots and pay for the card!")
                        return
                    end
                end
            
                local placedBuilding = game.blueprint
                placedBuilding.buildGrid = buildGrid
                if isBattlefield then
                    placedBuilding.slot = anchorSlot
                    placedBuilding.slotsOccupied = placedBuilding:getSlotsFromPattern(anchorSlot)
                    placedBuilding.x, placedBuilding.y = placedBuilding:getX() + buildGrid.cellSize/2, placedBuilding:getY() + buildGrid.cellSize/2
                    game.battlefieldGrid:addBuilding(placedBuilding, anchorSlot)
                    game:addObject(placedBuilding)
                else
                    game:newBuilding(placedBuilding, anchorSlot)
                end
                
                if placedBuilding:isType("turret") then
                    game.inputMode = "aiming"
                    self:selectBuilding(placedBuilding)
                else
                    game.inputMode = "idle"
                end
                
                game.blueprint = nil
                game:recalculateAllBuffs()
                if game.activeCard then
                    game:consumeCard(game.activeCard)
                end
            else
                print("Cannot place building: required slots are occupied or out of bounds!")
                if game.activeCard then
                    game:refundCard(game.activeCard)
                    game.blueprint = nil
                end
            end
        end
        return -- Don't process turret selection during building placement
    end
    
    -- Handle single slot unlocking
    if (game.inputMode == "idle" or game:isState("preparing")) and button == 1 then
        local buildGrid = base.buildGrid
        local gridX = math.floor(x / buildGrid.cellSize) + 1
        local gridY = math.floor((y - buildGrid.y) / buildGrid.cellSize) + 1
        if gridX >= 1 and gridX <= buildGrid.width and gridY >= 1 and gridY <= buildGrid.height then
            local anchorSlot = (gridY - 1) * buildGrid.width + gridX
            -- Expansion Logic: Only allow click-to-unlock if visible
            if not buildGrid.buildings[anchorSlot] and not buildGrid.unlocked[anchorSlot] and base:isSlotVisible(anchorSlot) then
                local cost = base:getSlotPrice(anchorSlot)
                if game.tokens >= cost then
                    game.tokens = game.tokens - cost
        if game.tokens < 0 then game.tokens = 0 end
                    buildGrid.unlocked[anchorSlot] = true
                else
                    print("Not enough tokens to unlock slot!")
                end
                return -- Stop propagation so we don't select a building or shoot
            end
        end
    end
    
    -- Handle building selection and other mouse interactions
    if button == 1 then -- Left click
        local clickedOnBuilding = false
        
        -- Click a placed building to focus it (shows in the INSPECT pane and stays
        -- focused); clicking empty field clears the focus. Works in any state.
        local selected = nil
        for _, obj in ipairs(game.objects) do
            if (obj:isType("turret") or obj:isType("passive")) and not obj.destroyed then
                if self:isMouseOverBuilding(obj) then
                    selected = obj
                    if obj:isType("turret") or obj:isType("passive") then
                        break
                    end
                end
            end
        end

        if selected then
            self:selectBuilding(selected)
            -- Between waves, clicking a turret picks it up to re-aim (see update)
            self.reAimSelected = self:isEditPhase()
            clickedOnBuilding = true
        else
            -- No building under the cursor: focus a hovered enemy instead, so it
            -- stays highlighted and pinned in the INSPECT pane.
            local he = game.gui and game.gui.tooltips and game.gui.tooltips.hoveredEnemy
            if he and not he.destroyed then
                self:clearSelection()
                self.selectedEnemy = he
                clickedOnBuilding = true
            end
        end
        
        -- Handle MainLazer clicking (firing only, not selectable)
        for _, obj in ipairs(game.objects) do
            if obj:isType("mainturret") and not obj.destroyed then
                if self:isMouseOverBuilding(obj) then
                    -- Handle MainLazer firing (only in wave state)
                    obj:PlayerClick(x, y)
                    clickedOnBuilding = true
                    break
                end
            end
        end
        
        -- If not clicking on building, clear selection
        if not clickedOnBuilding then
            self:clearSelection()
        end
    end
end

function InputHandler:mousereleased(x, y, button)
    if button == 1 then
        self.isMouseDown = false
        self.holdFireUntilRelease = false
        if self.editMode and self.dragStart then
            self:finishEditDrag()
        end
    end
end

function InputHandler:selectBuilding(building)
    -- Clear previous selection
    self:clearSelection()
    
    -- Set new selection
    self.selectedBuilding = building
    building.selected = true
    
    -- Handle building-specific selection behavior
    if building:isType("turret") or (building:isType("passive") and building.range) then
        building.showArc = true
    elseif building:isType("passive") and building.getAffectedSlotsFromAnchor then
        -- Show affected slots for buff buildings
        self.game.base.buffHoverSlots = building:getAffectedSlotsFromAnchor(building.slot)
    end
end

function InputHandler:clearSelection()
    if self.selectedBuilding then
        self.selectedBuilding.selected = false
        
        -- Handle building-specific clearing
        if self.selectedBuilding:isType("turret") or (self.selectedBuilding:isType("passive") and self.selectedBuilding.range) then
            self.selectedBuilding.showArc = false
        end
        
        self.selectedBuilding = nil
    end

    self.selectedEnemy = nil
    self.reAimSelected = false

    -- Clear buff hover visualization
    self.game.base.buffHoverSlots = nil
end

function InputHandler:keypressed(key)
    local game = self.game

    if game:isState("mulligan") then
        if key == "return" or key == "enter" then
            game:setState("startup")
        end
        return
    end

    if key == "`" then
        game.debugMode = not game.debugMode
    end

    -- Number keys pick a card from the hand (1 = leftmost); during a wave only
    -- spells count. Targeting only starts here; the cast needs a fresh left
    -- click, so a button already held for turret fire never casts it.
    local slot = tonumber(key)
    if slot and slot >= 1 and game.gui and game.gui.hand and not game.gui:overlayActive() then
        game.gui.hand:selectHotkeyCard(slot)
        return
    end

    if key == "0" then
        game:toggleDamageNumbers()
    end

    -- elseif key == "a" then
    --     game.autoStartWave = not game.autoStartWave

    if game.testingMode then
        if key == "u" then
            game.baseInvincible = not game.baseInvincible
            return
        end
        if key == "e" then
            if game.gui.enemySpawner then
                game.gui.enemySpawner.isActive = not game.gui.enemySpawner.isActive
            end
            return
        end
        if key == "g" then
            if game.gui.itemPicker then
                game.gui.itemPicker.isActive = not game.gui.itemPicker.isActive
            end
            return
        end
        if game.gui.enemySpawner and game.gui.enemySpawner.isActive and (key == "return" or key == "enter") then
            local total = 0
            local customWaveList = {}
            for eName, count in pairs(game.gui.enemySpawner.spawnCounts) do
                total = total + count
                if count > 0 then
                    local eClass = require("Enemies." .. eName)
                    for i = 1, count do
                        table.insert(customWaveList, eClass)
                    end
                end
            end
            
            if total > 0 then
                game:startWave(customWaveList)
            end
            game.gui.enemySpawner.isActive = false
            return
        end
    end
    
    -- Handle turret target reset
    if key == "space" then
        -- Space key now handled in update() for showing all firing arcs
    elseif key == "return" or key == "enter" then
        -- Start the wave directly from either the initial startup screen or the
        -- between-wave preparing screen (both show the same single prompt).
        if game:isState("startup") or game:isState("preparing") then
            if self.editMode then self:exitEditMode() end
            game:startWave()
        end
    elseif key == "tab" then
        -- Toggle autofire
        if game.mainLazer then
            game.mainLazer.autofire = not game.mainLazer.autofire
        end
    elseif key == "lshift" or key == "rshift" then
        self:toggleEditMode()
    elseif key == "a" and self.editMode then
        self:selectAllEditTurrets()
    elseif key == "backspace" and self.editMode then
        self:resetEditAim()
    elseif key == "h" then
        if game.gui and game.gui.hand then
            game.gui.hand.isHidden = not game.gui.hand.isHidden
        end
    end
    
    -- Handle selection clearing
    if key == "escape" then
        self:clearSelection()
    end
end

return InputHandler
