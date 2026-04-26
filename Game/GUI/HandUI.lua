local HandUI = {}
HandUI.__index = HandUI

function HandUI:new(game)
    local obj = setmetatable({
        game = game,
        cardW = 75,
        cardH = 100,
        yOffset = 100, -- Height from bottom
        hoveredIndex = nil
    }, self)
    return obj
end

function HandUI:getCardArea()
    local inventory = self.game.inventory.items
    if #inventory == 0 then return nil end
    
    local inventorySize = #inventory
    local spacing = math.min(60, 600 / inventorySize)
    if inventorySize == 1 then spacing = self.cardW end
    local totalWidth = (inventorySize - 1) * spacing + self.cardW
    local startX = (VIRTUAL_WIDTH - totalWidth) / 2
    local startY = VIRTUAL_HEIGHT - self.cardH
    
    return startX, startY, totalWidth, self.cardH, spacing
end

function HandUI:update(dt)
    if self.game.inputMode == "placing" then 
        self.hoveredIndex = nil
        return 
    end
    
    local mx, my = love.mouse.getPosition()
    local startX, startY, totalWidth, totalHeight, spacing = self:getCardArea()
    
    self.hoveredIndex = nil
    local inventory = self.game.inventory.items
    if startX and my >= startY then
        for i = #inventory, 1, -1 do
            local cardX = startX + (i - 1) * spacing
            if mx >= cardX and mx <= cardX + self.cardW and my >= startY and my <= startY + self.cardH then
                self.hoveredIndex = i
                break
            end
        end
    end
end

function HandUI:draw()
    local inventory = self.game.inventory.items
    if #inventory == 0 then 
        if self.game.inputMode == "placing" then self:drawDropZone() end
        return 
    end

    local startX, startY, totalWidth, totalHeight, spacing = self:getCardArea()
    
    for i, blueprint in ipairs(inventory) do
        if i ~= self.hoveredIndex then
            local x = startX + (i - 1) * spacing
            self:drawCard(blueprint, x, startY, false)
        end
    end
    
    -- Draw hovered card last (on top)
    if self.hoveredIndex then
        local blueprint = inventory[self.hoveredIndex]
        local x = startX + (self.hoveredIndex - 1) * spacing
        self:drawCard(blueprint, x, startY - 20, true)
    end

    if self.game.inputMode == "placing" then
        self:drawDropZone()
    end
end

function HandUI:drawCard(blueprint, x, y, isHovered)
    if blueprint.rewardCard then
        blueprint.rewardCard:draw(x, y, self.cardW, self.cardH, isHovered)
    else
        love.graphics.setColor(isHovered and {0.3, 0.3, 0.3, 1} or {0.2, 0.2, 0.2, 1})
        love.graphics.rectangle("fill", x, y, self.cardW, self.cardH)
        love.graphics.setColor(isHovered and {1, 1, 0, 1} or {0.5, 0.5, 0.5, 1})
        love.graphics.rectangle("line", x, y, self.cardW, self.cardH)
        
        if blueprint.color then
            love.graphics.setColor(blueprint.color)
            love.graphics.rectangle("fill", x + self.cardW/2 - blueprint.w/2, y + self.cardH/2 - blueprint.h/2, blueprint.w, blueprint.h)
        end
    end
end

function HandUI:drawDropZone()
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, VIRTUAL_HEIGHT - 100, VIRTUAL_WIDTH, 100)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Click here to store building", 0, VIRTUAL_HEIGHT - 55, VIRTUAL_WIDTH, "center")
end

function HandUI:mousepressed(x, y, button)
    if button ~= 1 then return false end
    
    if y >= VIRTUAL_HEIGHT - 100 then
        if self.game.inputMode == "placing" then
            self.game.inventory:add(self.game.blueprint)
            self.game.blueprint = nil
            self.game.inputMode = "idle"
            if self.game.base.clearSelection then
                self.game.base:clearSelection()
            end
            return true
        elseif self.hoveredIndex then
            self.game.blueprint = table.remove(self.game.inventory.items, self.hoveredIndex)
            self.game.inputMode = "placing"
            return true
        end
    end
    return false
end

return HandUI
