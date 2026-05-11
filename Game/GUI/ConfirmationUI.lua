local ConfirmationUI = {}
ConfirmationUI.__index = ConfirmationUI

function ConfirmationUI:new(game)
    local obj = setmetatable({
        game = game,
        active = false,
        message = "Are you sure?",
        confirmRect = nil,
        cancelRect = nil,
        boxW = 240,
        boxH = 100,
        onConfirm = nil,
        onCancel = nil,
        target = nil
    }, self)
    return obj
end

function ConfirmationUI:activate(message, onConfirm, onCancel, target)
    self.active = true
    self.message = message
    self.onConfirm = onConfirm
    self.onCancel = onCancel
    self.target = target
end

function ConfirmationUI:update(dt)
    -- Handle the legacy destruction target auto-activation
    if not self.active and self.game.inputHandler and self.game.inputHandler.destructionTarget then
        self:activate(
            "Do you want to destroy this building?",
            function()
                local target = self.game.inputHandler.destructionTarget
                if target:isType("blocker") and self.game.battlefieldGrid then
                    self.game.battlefieldGrid:removeBuilding(target)
                end
                target:remove()
                self.game.inputHandler.destructionTarget = nil
                self.game:recalculateAllBuffs()
            end,
            function()
                self.game.inputHandler.destructionTarget = nil
            end,
            self.game.inputHandler.destructionTarget
        )
    end
end

function ConfirmationUI:draw()
    if not self.active then return end
    
    -- Full screen dim
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    
    local cx, cy
    if self.target then
        local tipX, tipY = self.target.x, self.target.y
        if self.target.getCenterPosition then tipX, tipY = self.target:getCenterPosition() end
        cx = math.floor(tipX - self.boxW / 2)
        cy = math.floor(tipY - self.boxH - 40)
    else
        -- Center on screen if no target
        cx = math.floor((VIRTUAL_WIDTH - self.boxW) / 2)
        cy = math.floor((VIRTUAL_HEIGHT - self.boxH) / 2)
    end
    
    -- Bound to screen
    if cx < 5 then cx = 5 
    elseif cx + self.boxW > VIRTUAL_WIDTH - 5 then
        cx = VIRTUAL_WIDTH - 5 - self.boxW
    end
    if cy < 5 then cy = 5
    elseif cy + self.boxH > VIRTUAL_HEIGHT - 5 then
        cy = VIRTUAL_HEIGHT - 5 - self.boxH
    end
    
    -- Draw box
    love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
    love.graphics.rectangle("fill", cx, cy, self.boxW, self.boxH, 8)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", cx, cy, self.boxW, self.boxH, 8)
    
    love.graphics.printf(self.message, cx + 10, cy + 15, self.boxW - 20, "center")
    
    -- Draw buttons
    local btnW, btnH = 80, 30
    local spacing = 20
    
    -- Confirm Button (Left)
    local confirmX = math.floor(cx + self.boxW / 2 - btnW - spacing / 2)
    local btnY = math.floor(cy + self.boxH - btnH - 15)
    self.confirmRect = {x = confirmX, y = btnY, w = btnW, h = btnH}
    
    love.graphics.setColor(0.2, 0.6, 0.2, 1)
    love.graphics.rectangle("fill", confirmX, btnY, btnW, btnH, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", confirmX, btnY, btnW, btnH, 4)
    love.graphics.printf("YES", confirmX, btnY + 8, btnW, "center")
    
    -- Cancel Button (Right)
    local cancelX = math.floor(cx + self.boxW / 2 + spacing / 2)
    self.cancelRect = {x = cancelX, y = btnY, w = btnW, h = btnH}
    
    love.graphics.setColor(0.6, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", cancelX, btnY, btnW, btnH, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", cancelX, btnY, btnW, btnH, 4)
    love.graphics.printf("NO", cancelX, btnY + 8, btnW, "center")
    
    love.graphics.setLineWidth(1)
end

function ConfirmationUI:mousepressed(x, y, button)
    if not self.active or button ~= 1 then return false end
    
    -- Check Confirm
    if self.confirmRect and x >= self.confirmRect.x and x <= self.confirmRect.x + self.confirmRect.w and
       y >= self.confirmRect.y and y <= self.confirmRect.y + self.confirmRect.h then
        local callback = self.onConfirm
        self.active = false
        if callback then callback() end
        return true
    end
    
    -- Check Cancel
    if self.cancelRect and x >= self.cancelRect.x and x <= self.cancelRect.x + self.cancelRect.w and
       y >= self.cancelRect.y and y <= self.cancelRect.y + self.cancelRect.h then
        local callback = self.onCancel
        self.active = false
        if callback then callback() end
        return true
    end
    
    return true -- Consume click if active
end

return ConfirmationUI
