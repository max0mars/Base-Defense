local HandUI = require("Game.GUI.HandUI")
local TooltipManager = require("Game.GUI.TooltipManager")
local ConfirmationUI = require("Game.GUI.ConfirmationUI")
local GameText = require("Game.GUI.GameText")

local GUIManager = {}
GUIManager.__index = GUIManager

function GUIManager:new(game)
    local obj = setmetatable({
        game = game,
        hand = HandUI:new(game),
        tooltips = TooltipManager:new(game),
        confirmation = ConfirmationUI:new(game),
        buyButton = { x = 10, y = 80, w = 150, h = 30 }
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
        return true
    end
    
    -- Buy Button area
    local mx, my = x, y
    if mx >= self.buyButton.x and mx <= self.buyButton.x + self.buyButton.w and
       my >= self.buyButton.y and my <= self.buyButton.y + self.buyButton.h then
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
    love.graphics.setColor(0, 0, 0, 1)
    
    -- Wave info
    love.graphics.printf("Wave: " .. game.wave, 0, 10, love.graphics.getWidth() - 20, "left")
    love.graphics.printf("Money: " .. game.money, 0, 30, love.graphics.getWidth() - 20, "left")
    love.graphics.printf("Score: " .. game.xp, 0, 50, love.graphics.getWidth() - 20, "left")

    if game:isState("startup") then
        love.graphics.setColor(1, 1, 1, 1)
        local y = 150
        for i, lineSet in ipairs(GameText.IntroText) do
            local text = lineSet[1]
            love.graphics.printf(text, 50, y, love.graphics.getWidth() - 100, "center")
            
            -- Estimate lines based on width (very rough approximation for height offset)
            local font = love.graphics.getFont()
            local _, lines = font:getWrap(text, love.graphics.getWidth() - 100)
            y = y + (#lines * 16) + 10 -- 16 line height + 10 padding
        end
        love.graphics.printf("Press Enter to Start", 0, y + 30, love.graphics.getWidth(), "center")
    end

    -- Reward and Auto-start
    -- Draw Buy Button
    local mx, my = love.mouse.getPosition()
    local isHovered = mx >= self.buyButton.x and mx <= self.buyButton.x + self.buyButton.w and
                      my >= self.buyButton.y and my <= self.buyButton.y + self.buyButton.h
    
    local canAfford = game.money >= game.rewardCost
    local isActive = game.rewardSystem.isActive
    local isIdle = game.inputMode == "idle"
    local enabled = not isActive and isIdle
    
    if isHovered and enabled then
        if canAfford then
            love.graphics.setColor(0.2, 0.7, 0.2, 1) -- Highlight Green
        else
            love.graphics.setColor(0.7, 0.2, 0.2, 1) -- Highlight Red
        end
    else
        love.graphics.setColor(0.3, 0.3, 0.3, 0.5) -- Default Grey
    end
    
    love.graphics.rectangle("fill", self.buyButton.x, self.buyButton.y, self.buyButton.w, self.buyButton.h, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", self.buyButton.x, self.buyButton.y, self.buyButton.w, self.buyButton.h, 4)
    
    local btnText = "Buy Upgrade ($" .. math.floor(game.rewardCost) .. ")"
    love.graphics.printf(btnText, self.buyButton.x, self.buyButton.y + 7, self.buyButton.w, "center")
    
    -- local autoText = game.autoStartWave and "ON" or "OFF"
    -- love.graphics.printf("Press 'A' for Auto-Start: " .. autoText, 0, 25, love.graphics.getWidth(), "center")
    
    
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
    
    -- Check Buy Button
    if button == 1 then
        if x >= self.buyButton.x and x <= self.buyButton.x + self.buyButton.w and
           y >= self.buyButton.y and y <= self.buyButton.y + self.buyButton.h then
            self.game:attemptPurchaseReward()
            return true
        end
    end
    
    return false
end




return GUIManager
