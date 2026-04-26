local Inventory = {}
Inventory.__index = Inventory

function Inventory:new(game)
    local obj = setmetatable({}, self)
    obj.game = game
    obj.items = {}
    obj.hoveredCardIndex = nil
    return obj
end

function Inventory:update(dt)
    local game = self.game
    local mouseX = game.inputHandler.mouseX
    local mouseY = game.inputHandler.mouseY
    
    self.hoveredCardIndex = nil
    
    if game.inputMode == "placing" then return end
    if #self.items > 0 then
        local cardW, cardH = 75, 100
        local spacing = math.min(60, 600 / #self.items)
        if #self.items == 1 then spacing = cardW end
        local totalWidth = (#self.items - 1) * spacing + cardW
        local startX = (VIRTUAL_WIDTH - totalWidth) / 2
        local startY = VIRTUAL_HEIGHT - cardH
        
        for i = #self.items, 1, -1 do
            local cardX = startX + (i - 1) * spacing
            local cardY = startY
            if mouseX >= cardX and mouseX <= cardX + cardW and mouseY >= cardY and mouseY <= cardY + cardH then
                self.hoveredCardIndex = i
                break
            end
        end
    end
end

function Inventory:draw()
    local game = self.game
    
    -- Draw Cards
    local cardW, cardH = 75, 100
    local inventorySize = #self.items
    if inventorySize > 0 then
        local spacing = math.min(60, 600 / inventorySize)
        if inventorySize == 1 then spacing = cardW end
        local totalWidth = (inventorySize - 1) * spacing + cardW
        local startX = (VIRTUAL_WIDTH - totalWidth) / 2
        local startY = VIRTUAL_HEIGHT - cardH
        
        for i, blueprint in ipairs(self.items) do
            if i ~= self.hoveredCardIndex then
                local x = startX + (i - 1) * spacing
                if blueprint.rewardCard then
                    blueprint.rewardCard:draw(x, startY, cardW, cardH, false)
                else
                    love.graphics.setColor(0.2, 0.2, 0.2, 1)
                    love.graphics.rectangle("fill", x, startY, cardW, cardH)
                    love.graphics.setColor(0.5, 0.5, 0.5, 1)
                    love.graphics.rectangle("line", x, startY, cardW, cardH)
                    
                    if blueprint.color then
                        love.graphics.setColor(blueprint.color)
                    end
                    love.graphics.rectangle("fill", x + cardW/2 - blueprint.w/2, startY + cardH/2 - blueprint.h/2, blueprint.w, blueprint.h)
                end
            end
        end
        
        -- Draw hovered card on top if it exists
        if self.hoveredCardIndex then
            local i = self.hoveredCardIndex
            local blueprint = self.items[i]
            if blueprint then
                local x = startX + (i - 1) * spacing
                local y = startY - 20
                if blueprint.rewardCard then
                    blueprint.rewardCard:draw(x, y, cardW, cardH, true)
                else
                    love.graphics.setColor(0.3, 0.3, 0.3, 1)
                    love.graphics.rectangle("fill", x, y, cardW, cardH)
                    love.graphics.setColor(1, 1, 0, 1)
                    love.graphics.rectangle("line", x, y, cardW, cardH)
                    
                    if blueprint.color then
                        love.graphics.setColor(blueprint.color)
                    end
                    love.graphics.rectangle("fill", x + cardW/2 - blueprint.w/2, y + cardH/2 - blueprint.h/2, blueprint.w, blueprint.h)
                end
            end
        end
    end
    
    -- Storage Zone Hint and Grey Effect (drawn ON TOP of cards)
    if game.inputMode == "placing" then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", 0, VIRTUAL_HEIGHT - 100, VIRTUAL_WIDTH, 100)
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Click here to store building", 0, VIRTUAL_HEIGHT - 55, VIRTUAL_WIDTH, "center")
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Inventory:mousepressed(x, y, button)
    local game = self.game

    if y >= love.graphics.getHeight() - 100 and button == 1 then
        if game.inputMode == "placing" then
            self:add(game.blueprint)
            game.blueprint = nil
            game.inputMode = "idle"
            
            local base = game.base
            base.selectedSlots = nil
            base.invalidSlots = nil
            base.affectedSlots = nil
            base.selectedSlot = nil
            return true
        elseif self.hoveredCardIndex then
            game.blueprint = table.remove(self.items, self.hoveredCardIndex)
            game.inputMode = "placing"
            return true
        end
    end
    
    return false
end

function Inventory:add(blueprint)
    table.insert(self.items, blueprint)
    table.sort(self.items, function(a, b)
        local nameA = a.rewardCard and a.rewardCard.name or "z_fallback"
        local nameB = b.rewardCard and b.rewardCard.name or "z_fallback"
        return nameA < nameB
    end)
end

return Inventory