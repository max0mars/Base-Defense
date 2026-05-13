local HandUI = require("Game.GUI.HandUI")
local TooltipManager = require("Game.GUI.TooltipManager")
local ConfirmationUI = require("Game.GUI.ConfirmationUI")
local GameText = require("Game.GUI.GameText")
local MutationUI = require("Game.GUI.MutationUI")

local GUIManager = {}
GUIManager.__index = GUIManager

function GUIManager:new(game)
    local obj = setmetatable({
        game = game,
        hand = HandUI:new(game),
        tooltips = TooltipManager:new(game),
        confirmation = ConfirmationUI:new(game),
        buyButton = { x = 210, y = 50, w = 150, h = 30 },
        infoButton = { x = 365, y = 50, w = 30, h = 30 },
        luckButton = { x = 210, y = 10, w = 150, h = 30 },
        mutation = MutationUI:new(game)
    }, self)
    return obj
end

function GUIManager:isConsumingInput(x, y)
    local game = self.game
    
    -- Reward and Mutation systems take priority
    if game.rewardSystem and game.rewardSystem.isActive then return true end
    if self.mutation and self.mutation.isActive then return true end
    if game:isState("upgrade_mutation") then return true end
    
    -- Bottom card area (only if active or placing)
    if y >= VIRTUAL_HEIGHT - 100 then return true end
    
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

    -- Luck Button area
    if mx >= self.luckButton.x and mx <= self.luckButton.x + self.luckButton.w and
       my >= self.luckButton.y and my <= self.luckButton.y + self.luckButton.h then
        return true
    end

    -- Info Button area
    if mx >= self.infoButton.x and mx <= self.infoButton.x + self.infoButton.w and
       my >= self.infoButton.y and my <= self.infoButton.y + self.infoButton.h then
        return true
    end
    
    return false
end

function GUIManager:update(dt)
    self.hand:update(dt)
    self.tooltips:update(dt)
    self.confirmation:update(dt)
    self.mutation:update(dt)

    -- Handle Info Button Hover
    local mx, my = love.mouse.getPosition()
    local hoverInfo = mx >= self.infoButton.x and mx <= self.infoButton.x + self.infoButton.w and
                      my >= self.infoButton.y and my <= self.infoButton.y + self.infoButton.h
    
    if hoverInfo and not self.game.rewardSystem.isActive then
        if not self.tooltips.rarityProbs then
            self.tooltips.rarityProbs = self.game.rewardSystem.poolLogic:getLuckProbabilities(self.game.luck)
        end
    else
        self.tooltips.rarityProbs = nil
    end
end

function GUIManager:draw()
    -- Global HUD (Score, Tokens, Wave) and Masks
    self:drawHUD()
    
    -- UI elements on top of masks
    self.hand:draw()
    self.mutation:draw()     -- Draw mutation screen
    self.tooltips:draw()     -- Draw tips above everything
end

function GUIManager:drawHUD()
    local game = self.game

    -- 0. Draw Black Masks to hide gameplay behind HUD
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, 800, 100)   -- Top frame
    love.graphics.rectangle("fill", 0, 500, 800, 100) -- Bottom frame
    
    -- 1. Draw glowing borders (moved from GameManager)
    self:drawBorders()

    -- 2. Draw Luck Offering Button
    local currentCost = game:getLuckCost()
    local canAffordLuck = currentCost and game.tokens >= currentCost
    local luckMaxed = game.luck >= 10
    local luckEnabled = not luckMaxed and game.inputMode == "idle"
    
    local mx, my = love.mouse.getPosition()
    local isLuckHovered = mx >= self.luckButton.x and mx <= self.luckButton.x + self.luckButton.w and
                         my >= self.luckButton.y and my <= self.luckButton.y + self.luckButton.h
    
    if luckEnabled and isLuckHovered then
        if canAffordLuck then
            love.graphics.setColor(0.2, 0.7, 0.2, 1) -- Highlight Green
        else
            love.graphics.setColor(0.7, 0.2, 0.2, 1) -- Highlight Red
        end
    elseif luckMaxed then
        love.graphics.setColor(0.1, 0.1, 0.1, 0.5) -- Dark
    else
        love.graphics.setColor(0.3, 0.3, 0.3, 0.5) -- Default Grey
    end
    
    love.graphics.rectangle("fill", self.luckButton.x, self.luckButton.y, self.luckButton.w, self.luckButton.h, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", self.luckButton.x, self.luckButton.y, self.luckButton.w, self.luckButton.h, 4)
    
    local luckText = luckMaxed and "Max Luck" or "Luck Offering (" .. currentCost .. " T)"
    love.graphics.printf(luckText, self.luckButton.x, self.luckButton.y + 7, self.luckButton.w, "center")

    love.graphics.setColor(0, 255, 0, 1)
    
    -- Wave info
    love.graphics.printf("Wave: " .. game.wave, 10, 10, VIRTUAL_WIDTH - 20, "left")
    love.graphics.printf("Tokens: " .. game.tokens, 10, 30, VIRTUAL_WIDTH - 20, "left")
    love.graphics.printf("Score: " .. game.xp, 10, 50, VIRTUAL_WIDTH - 20, "left")

    -- Base Health Bar
    if game.base then
        local barX, barY, barW, barH = 10, 85, 150, 10
        local healthPercent = game.base.hp / game.base:getStat("maxHp")
        
        -- Draw background
        love.graphics.setColor(0.1, 0.1, 0.1, 1)
        love.graphics.rectangle("fill", barX, barY, barW, barH, 2)
        
        -- Draw health
        love.graphics.setColor(0.8, 0.2, 0.2, 1) -- Red for base health
        love.graphics.rectangle("fill", barX, barY, barW * healthPercent, barH, 2)
        
        -- Draw border
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", barX, barY, barW, barH, 2)
        
        -- Add text
        local font = love.graphics.getFont()
        local text = string.format("Base HP: %d/%d", game.base.hp, game.base:getStat("maxHp"))
        local tw = font:getWidth(text)
        love.graphics.print(text, math.floor(barX + (barW - tw)/2), barY - 14)
    end

    love.graphics.printf("Damage Numbers: " .. (game.showDamageNumbers and "On" or "Off"), 600, 20, VIRTUAL_WIDTH - 20, "left")
    love.graphics.printf("AutoFire: " .. (game.mainTurret and game.mainTurret.autofire and "On" or "Off"), 600, 40, VIRTUAL_WIDTH - 20, "left")
    love.graphics.printf(string.format("Game Speed: %.1fx", game.time_mul), 600, 60, VIRTUAL_WIDTH - 20, "left")
    
    if game:isState("startup") then
        love.graphics.setColor(1, 1, 1, 1)
        local y = 150
        for i, lineSet in ipairs(GameText.IntroText) do
            local text = lineSet[1]
            love.graphics.printf(text, 90, y, VIRTUAL_WIDTH - 100, "center")
            
            -- Estimate lines based on width (very rough approximation for height offset)
            local font = love.graphics.getFont()
            local _, lines = font:getWrap(text, VIRTUAL_WIDTH - 100)
            y = y + (#lines * 16) + 10 -- 16 line height + 10 padding
        end
        love.graphics.printf("Press Enter to Start", 0, y + 30, VIRTUAL_WIDTH, "center")
    end

    -- Reward and Auto-start
    -- Draw Buy Button
    local mx, my = love.mouse.getPosition()
    local isHovered = mx >= self.buyButton.x and mx <= self.buyButton.x + self.buyButton.w and
                      my >= self.buyButton.y and my <= self.buyButton.y + self.buyButton.h
    
    local canAfford = game.tokens >= game.rewardCost
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
    
    local btnText = "Buy Upgrade (" .. math.floor(game.rewardCost) .. " T)"
    love.graphics.printf(btnText, self.buyButton.x, self.buyButton.y + 7, self.buyButton.w, "center")
    
    -- Draw Info Button
    local mx, my = love.mouse.getPosition()
    local hoverInfo = mx >= self.infoButton.x and mx <= self.infoButton.x + self.infoButton.w and
                      my >= self.infoButton.y and my <= self.infoButton.y + self.infoButton.h
    
    if hoverInfo then
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.rectangle("fill", self.infoButton.x, self.infoButton.y, self.infoButton.w, self.infoButton.h, 4)
    end
    
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.rectangle("line", self.infoButton.x, self.infoButton.y, self.infoButton.w, self.infoButton.h, 4)
    love.graphics.printf("?", self.infoButton.x, self.infoButton.y + 7, self.infoButton.w, "center")
    
    
    -- Tokens and Score (optional addition if needed)
end

function GUIManager:drawBorders()
    local game = self.game
    local pulse = (math.sin(game.pulseTimer * (game.oscillationSpeed or 1)) + 1) / 2
    local r, g, b = 1, 0, 0 -- Red glow
    local thickness = 4
    local width, height = VIRTUAL_WIDTH, VIRTUAL_HEIGHT
    
    -- Top Border Line (at y=100)
    for i = 3, 1, -1 do
        local alpha = (0.15 * (1 - i/4)) * (0.5 + pulse * 0.5)
        local glowWidth = thickness + i * 4 + pulse * 8
        love.graphics.setLineWidth(glowWidth)
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.line(0, 100, width, 100)
    end
    love.graphics.setColor(r, g, b, 0.8 + pulse * 0.2)
    love.graphics.setLineWidth(thickness)
    love.graphics.line(0, 100, width, 100)
    
    -- Bottom Border Line (at y=500)
    for i = 3, 1, -1 do
        local alpha = (0.15 * (1 - i/4)) * (0.5 + pulse * 0.5)
        local glowWidth = thickness + i * 4 + pulse * 8
        love.graphics.setLineWidth(glowWidth)
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.line(0, 500, width, 500)
    end
    love.graphics.setColor(r, g, b, 0.8 + pulse * 0.2)
    love.graphics.setLineWidth(thickness)
    love.graphics.line(0, 500, width, 500)
    
    love.graphics.setLineWidth(1)
end

function GUIManager:mousepressed(x, y, button)
    -- Handle input in reverse draw order (top to bottom)
    
    if self.confirmation:mousepressed(x, y, button) then
        return true
    end

    if self.mutation:mousepressed(x, y, button) then
        return true
    end
    
    if self.hand:mousepressed(x, y, button) then
        return true
    end
    
    -- Check Luck Button
    if button == 1 then
        if x >= self.luckButton.x and x <= self.luckButton.x + self.luckButton.w and
           y >= self.luckButton.y and y <= self.luckButton.y + self.luckButton.h then
            self.game:buyLuck()
            return true
        end
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
