local HandUI = require("Game.GUI.HandUI")
local TooltipManager = require("Game.GUI.TooltipManager")
local ConfirmationUI = require("Game.GUI.ConfirmationUI")

local GUIManager = {}
GUIManager.__index = GUIManager

function GUIManager:new(game)
    local obj = setmetatable({
        game = game,
        hand = HandUI:new(game),
        tooltips = TooltipManager:new(game),
        confirmation = ConfirmationUI:new(game)
    }, self)
    return obj
end

function GUIManager:isConsumingInput(x, y)
    local game = self.game
    
    -- Reward system takes absolute priority
    if game.rewardSystem and game.rewardSystem.isActive then return true end
    
    -- Bottom card area (only if active or placing)
    if y >= love.graphics.getHeight() - 100 then return true end
    
    -- Confirmation prompt
    if self.confirmation.active then
        -- We consume input if there's a target, even if not clicking the specific button
        -- (this handles the "click away to cancel" logic)
        return true
    end
    
    return false
end

function GUIManager:update(dt)
    self.hand:update(dt)
    self.tooltips:update(dt)
    self.confirmation:update(dt)
end

function GUIManager:draw()
    self.hand:draw()
    self.confirmation:draw() -- Draw prompts above hand
    self.tooltips:draw()     -- Draw tips above everything
    
    -- Global HUD (Score, Money, Wave)
    self:drawHUD()
end

function GUIManager:drawHUD()
    local game = self.game
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Wave info
    love.graphics.printf("Wave: " .. game.wave, 0, 10, love.graphics.getWidth() - 20, "right")
    
    -- Reward and Auto-start
    love.graphics.printf("Press 'R' to Buy Reward ($" .. (game.rewardCost or 0) .. ")", 0, 10, love.graphics.getWidth(), "center")
    local autoText = game.autoStartWave and "ON" or "OFF"
    love.graphics.printf("Press 'A' for Auto-Start: " .. autoText, 0, 25, love.graphics.getWidth(), "center")
    
    -- Money and Score (optional addition if needed)
end

function GUIManager:mousepressed(x, y, button)
    -- Handle input in reverse draw order (top to bottom)
    
    if self.confirmation:mousepressed(x, y, button) then
        return true
    end
    
    if self.hand:mousepressed(x, y, button) then
        return true
    end
    
    return false
end

return GUIManager
