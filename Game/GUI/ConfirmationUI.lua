local ConfirmationUI = {}
ConfirmationUI.__index = ConfirmationUI

function ConfirmationUI:new(game)
    local obj = setmetatable({
        game = game,
        active = false,
        target = nil,
        confirmRect = nil,
        boxW = 220,
        boxH = 80
    }, self)
    return obj
end

function ConfirmationUI:update(dt)
    self.target = self.game.inputHandler.destructionTarget
    self.active = self.target ~= nil
end

function ConfirmationUI:draw()
    if not self.active then return end
    
    local target = self.target
    local tipX, tipY = target.x, target.y
    if target.getCenterPosition then tipX, tipY = target:getCenterPosition() end
    
    local cx = math.floor(tipX - self.boxW / 2)
    local cy = math.floor(tipY - self.boxH - 40)
    
    -- Bound to screen
    if cx < 5 then cx = 5 
    elseif cx + self.boxW > love.graphics.getWidth() - 5 then
        cx = love.graphics.getWidth() - 5 - self.boxW
    end
    
    -- Draw box
    love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
    love.graphics.rectangle("fill", cx, cy, self.boxW, self.boxH)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Do you want to destroy this building?", cx + 10, cy + 10, self.boxW - 20, "center")
    
    -- Draw confirm button
    local btnW, btnH = 80, 25
    local btnX = math.floor(cx + self.boxW / 2 - btnW / 2)
    local btnY = math.floor(cy + 45)
    self.confirmRect = {x = btnX, y = btnY, w = btnW, h = btnH}
    
    love.graphics.setColor(0.8, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("CONFIRM", btnX, btnY + 5, btnW, "center")
end

function ConfirmationUI:mousepressed(x, y, button)
    if not self.active or button ~= 1 then return false end
    
    if self.confirmRect then
        if x >= self.confirmRect.x and x <= self.confirmRect.x + self.confirmRect.w and
           y >= self.confirmRect.y and y <= self.confirmRect.y + self.confirmRect.h then
            
            if self.target:isType("battlefield") and self.game.battlefieldGrid then
                self.game.battlefieldGrid:removeBuilding(self.target)
            end
            
            self.target:remove()
            self.game.inputHandler.destructionTarget = nil
            self.game:recalculateAllBuffs()
            return true
        end
    end
    
    -- Clicking anywhere else cancels destruction
    self.game.inputHandler.destructionTarget = nil
    return true
end

return ConfirmationUI
