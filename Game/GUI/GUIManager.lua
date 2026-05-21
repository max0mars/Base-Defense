local HandUI = require("Game.GUI.HandUI")
local TooltipManager = require("Game.GUI.TooltipManager")
local ConfirmationUI = require("Game.GUI.ConfirmationUI")
local GameText = require("Game.GUI.GameText")
local MutationUI = require("Game.GUI.MutationUI")
local IncomeFeedbackManager = require("Game.GUI.IncomeFeedbackManager")

-- =============================================================================
-- Local Helpers for Tron/Neon UI Aesthetics
-- =============================================================================

local function drawGlowRect(x, y, w, h, r, g, b, thickness, rx, ry, pulse)
    rx = rx or 4
    ry = ry or 4
    pulse = pulse or 0
    love.graphics.push("all")
    -- Outer glow lines
    for i = 3, 1, -1 do
        local alpha = (0.06 * (1 - i/4)) * (0.6 + pulse * 0.4)
        local glowWidth = thickness + i * 4 + pulse * 6
        love.graphics.setLineWidth(glowWidth)
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.rectangle("line", x, y, w, h, rx, ry)
    end
    -- Solid core line
    love.graphics.setColor(r, g, b, 0.85 + pulse * 0.15)
    love.graphics.setLineWidth(thickness)
    love.graphics.rectangle("line", x, y, w, h, rx, ry)
    love.graphics.pop()
end

local function drawToggle(btn, label, isEnabled, isHovered, pulse)
    pulse = pulse or 0
    love.graphics.push("all")
    
    -- Background: glassmorphism dark cyan/navy
    love.graphics.setColor(0.02, 0.05, 0.1, 0.7)
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 4)
    
    -- Outer neon border color
    local r, g, b = 0.3, 0.4, 0.5
    local borderThick = 1
    if isHovered then
        r, g, b = 0.0, 0.85, 1.0 -- Cyan on hover
        borderThick = 2
    end
    
    -- Draw glowing frame
    drawGlowRect(btn.x, btn.y, btn.w, btn.h, r, g, b, borderThick, 4, 4, pulse)
    
    -- LED status indicator (cyber circle/ring)
    local ledX = btn.x + 10
    local ledY = btn.y + btn.h/2
    local ledRadius = 4
    
    if isEnabled then
        -- Glowing green LED
        love.graphics.setColor(0, 1.0, 0.4, 0.3)
        love.graphics.circle("fill", ledX, ledY, ledRadius + 2)
        love.graphics.setColor(0, 1.0, 0.4, 1.0)
        love.graphics.circle("fill", ledX, ledY, ledRadius)
    else
        -- Dim red LED
        love.graphics.setColor(1.0, 0.2, 0.2, 0.3)
        love.graphics.circle("fill", ledX, ledY, ledRadius + 1)
        love.graphics.setColor(1.0, 0.2, 0.2, 0.9)
        love.graphics.circle("fill", ledX, ledY, ledRadius)
    end
    
    -- Print Text label
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(label, btn.x + 22, btn.y + btn.h/2 - 6)
    
    love.graphics.pop()
end

-- =============================================================================
-- GUIManager Definition
-- =============================================================================

local GUIManager = {}
GUIManager.__index = GUIManager

function GUIManager:new(game)
    local obj = setmetatable({
        game = game,
        hand = HandUI:new(game),
        tooltips = TooltipManager:new(game),
        confirmation = ConfirmationUI:new(game),
        buyButton = { x = 210, y = 52, w = 150, h = 32 },
        infoButton = { x = 365, y = 52, w = 32, h = 32 },
        luckButton = { x = 210, y = 12, w = 150, h = 32 },
        
        -- New Cybernetic Controls
        autoFireButton = { x = 410, y = 12, w = 130, h = 24 },
        dmgNumsButton = { x = 410, y = 41, w = 130, h = 24 },
        autoWaveButton = { x = 410, y = 70, w = 130, h = 24 },
        speedPanel = { x = 555, y = 12, w = 235, h = 82 },
        speedMinusButton = { x = 567, y = 48, w = 32, h = 32 },
        speedPlusButton = { x = 746, y = 48, w = 32, h = 32 },
        
        mutation = MutationUI:new(game),
        incomeFeedback = IncomeFeedbackManager:new(game)
    }, self)
    return obj
end

function GUIManager:isConsumingInput(x, y)
    local game = self.game
    
    -- Reward and Mutation systems take priority
    if game.rewardSystem and game.rewardSystem.isActive then return true end
    if self.mutation and self.mutation.isActive then return true end
    if game:isState("upgrade_mutation") then return true end
    
    -- Top HUD area blocks click/hover completely
    if y <= 100 then return true end
    
    -- Bottom card area (only if active or placing)
    if y >= VIRTUAL_HEIGHT - 100 then return true end
    
    -- Confirmation prompt
    if self.confirmation.active then
        return true
    end
    
    return false
end

function GUIManager:update(dt)
    self.hand:update(dt)
    self.tooltips:update(dt)
    self.confirmation:update(dt)
    self.mutation:update(dt)
    self.incomeFeedback:update(dt)

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
    local pulse = (math.sin(game.pulseTimer * 3.5) + 1) / 2 -- Pulsing rate for neon glow

    -- 0. Draw Deep Dark Glass HUD masks
    love.graphics.setColor(0.01, 0.02, 0.04, 0.95)
    love.graphics.rectangle("fill", 0, 0, 800, 100)   -- Top frame
    love.graphics.rectangle("fill", 0, 500, 800, 100) -- Bottom frame
    
    -- Subtle grid lines inside the HUD areas
    love.graphics.push("all")
    love.graphics.setColor(0, 0.8, 1, 0.04)
    for gx = 20, 780, 20 do
        love.graphics.line(gx, 0, gx, 100)
        love.graphics.line(gx, 500, gx, 600)
    end
    for gy = 10, 90, 20 do
        love.graphics.line(0, gy, 800, gy)
    end
    for gy = 510, 590, 20 do
        love.graphics.line(0, gy, 800, gy)
    end
    love.graphics.pop()

    -- 1. Draw glowing borders (moved from GameManager)
    self:drawBorders()

    -- ==========================================
    -- LEFT PANEL: Stats & Health Box
    -- ==========================================
    -- Draw stats container panel
    local statPanel = { x = 10, y = 10, w = 185, h = 82 }
    drawGlowRect(statPanel.x, statPanel.y, statPanel.w, statPanel.h, 0.0, 0.7, 0.9, 1, 6, 6, pulse * 0.3)
    
    -- Print digital styled readouts
    love.graphics.push("all")
    
    -- WAVE
    love.graphics.setColor(0, 0.85, 1.0, 0.8)
    love.graphics.print("WAVE", 20, 14)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(tostring(game.wave), 90, 14)
    
    -- TOKENS
    love.graphics.setColor(1.0, 0.7, 0.1, 0.8)
    love.graphics.print("TOKENS", 20, 31)
    love.graphics.setColor(1.0, 0.9, 0.2, 1)
    love.graphics.print(tostring(game.tokens), 90, 31)
    
    -- SCORE
    love.graphics.setColor(1.0, 0.2, 0.6, 0.8)
    love.graphics.print("SCORE", 20, 48)
    love.graphics.setColor(1.0, 0.4, 0.8, 1)
    love.graphics.print(tostring(game.xp), 90, 48)
    
    -- HEALTH BAR
    if game.base then
        local hpX, hpY, hpW, hpH = 20, 78, 165, 8
        local healthPercent = game.base.hp / game.base:getStat("maxHp")
        
        love.graphics.setColor(1, 1, 1, 0.8)
        local hpText = string.format("BASE HP: %d/%d", game.base.hp, game.base:getStat("maxHp"))
        love.graphics.print(hpText, 20, 64)
        
        -- Health bar background track
        love.graphics.setColor(0.05, 0.05, 0.08, 0.8)
        love.graphics.rectangle("fill", hpX, hpY, hpW, hpH, 2)
        love.graphics.setColor(0, 0.85, 1.0, 0.3)
        love.graphics.rectangle("line", hpX, hpY, hpW, hpH, 2)
        
        -- Segmented Health/Shield segments
        local numSegments = 10
        local gap = 1
        local segW = (hpW - (numSegments - 1) * gap) / numSegments
        
        -- Pulse indicator for low health
        local hpR, hpG, hpB = 0.0, 1.0, 0.4 -- Green
        if healthPercent <= 0.3 then
            local flash = (math.sin(game.pulseTimer * 12) + 1) / 2
            hpR, hpG, hpB = 1.0, 0.2 * flash, 0.2 * flash -- Flashing red
        elseif healthPercent <= 0.6 then
            hpR, hpG, hpB = 1.0, 0.65, 0.0 -- Orange
        end
        
        for s = 1, numSegments do
            local segX = hpX + (s - 1) * (segW + gap)
            local fillRatio = healthPercent * numSegments
            if s <= fillRatio then
                love.graphics.setColor(hpR, hpG, hpB, 0.95)
                love.graphics.rectangle("fill", segX, hpY, segW, hpH, 1)
                -- LED inner glow
                love.graphics.setColor(hpR, hpG, hpB, 0.4)
                love.graphics.rectangle("fill", segX - 1, hpY - 1, segW + 2, hpH + 2, 2)
            else
                love.graphics.setColor(0.1, 0.15, 0.2, 0.2)
                love.graphics.rectangle("fill", segX, hpY, segW, hpH, 1)
            end
        end
    end
    love.graphics.pop()

    -- ==========================================
    -- CENTER PANEL: Action Buttons (Luck, Buy, Info)
    -- ==========================================
    local mx, my = love.mouse.getPosition()
    
    -- 1. Luck Button
    local currentCost = game:getLuckCost()
    local canAffordLuck = currentCost and game.tokens >= currentCost
    local luckMaxed = game.luck >= 10
    local luckEnabled = not luckMaxed and game.inputMode == "idle"
    local isLuckHovered = mx >= self.luckButton.x and mx <= self.luckButton.x + self.luckButton.w and
                         my >= self.luckButton.y and my <= self.luckButton.y + self.luckButton.h
                         
    local luckColor = { 1.0, 0.65, 0.0 } -- Gold/Amber
    if luckMaxed then
        luckColor = { 0.4, 0.4, 0.4 }
    elseif not luckEnabled then
        luckColor = { 0.5, 0.2, 0.2 }
    elseif isLuckHovered then
        if canAffordLuck then
            luckColor = { 0.1, 0.9, 0.3 } -- Bright Green if affordable
        else
            luckColor = { 0.9, 0.1, 0.1 } -- Bright Red if unaffordable
        end
    end
    
    -- Draw Luck Button
    love.graphics.setColor(0.02, 0.05, 0.1, 0.7)
    love.graphics.rectangle("fill", self.luckButton.x, self.luckButton.y, self.luckButton.w, self.luckButton.h, 4)
    drawGlowRect(self.luckButton.x, self.luckButton.y, self.luckButton.w, self.luckButton.h, luckColor[1], luckColor[2], luckColor[3], isLuckHovered and 2 or 1, 4, 4, pulse * 0.3)
    
    local luckText = luckMaxed and "MAX LUCK" or "LUCK OFFERING (" .. currentCost .. " T)"
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, luckEnabled and 1.0 or 0.5)
    love.graphics.printf(luckText, self.luckButton.x, self.luckButton.y + 8, self.luckButton.w, "center")
    love.graphics.pop()
    
    -- 2. Buy Upgrade Button
    local canAffordBuy = game.tokens >= game.rewardCost
    local buyActive = game.rewardSystem.isActive
    local buyIdle = game.inputMode == "idle"
    local buyEnabled = not buyActive and buyIdle
    local isBuyHovered = mx >= self.buyButton.x and mx <= self.buyButton.x + self.buyButton.w and
                        my >= self.buyButton.y and my <= self.buyButton.y + self.buyButton.h
                        
    local buyColor = { 0.0, 0.85, 1.0 } -- Cyber-cyan
    if not buyEnabled then
        buyColor = { 0.4, 0.4, 0.4 }
    elseif isBuyHovered then
        if canAffordBuy then
            buyColor = { 0.1, 0.9, 0.3 } -- Green
        else
            buyColor = { 0.9, 0.1, 0.1 } -- Red
        end
    end
    
    -- Draw Buy Button
    love.graphics.setColor(0.02, 0.05, 0.1, 0.7)
    love.graphics.rectangle("fill", self.buyButton.x, self.buyButton.y, self.buyButton.w, self.buyButton.h, 4)
    drawGlowRect(self.buyButton.x, self.buyButton.y, self.buyButton.w, self.buyButton.h, buyColor[1], buyColor[2], buyColor[3], isBuyHovered and 2 or 1, 4, 4, pulse * 0.3)
    
    local buyCostText = string.format("BUY UPGRADE (%d T)", math.floor(game.rewardCost))
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, buyEnabled and 1.0 or 0.5)
    love.graphics.printf(buyCostText, self.buyButton.x, self.buyButton.y + 8, self.buyButton.w, "center")
    love.graphics.pop()
    
    -- 3. Info "?" Button
    local isInfoHovered = mx >= self.infoButton.x and mx <= self.infoButton.x + self.infoButton.w and
                         my >= self.infoButton.y and my <= self.infoButton.y + self.infoButton.h
    local infoColor = isInfoHovered and { 0.0, 0.85, 1.0 } or { 0.3, 0.5, 0.7 }
    
    love.graphics.setColor(0.02, 0.05, 0.1, 0.7)
    love.graphics.rectangle("fill", self.infoButton.x, self.infoButton.y, self.infoButton.w, self.infoButton.h, 4)
    drawGlowRect(self.infoButton.x, self.infoButton.y, self.infoButton.w, self.infoButton.h, infoColor[1], infoColor[2], infoColor[3], isInfoHovered and 2 or 1, 4, 4, pulse * 0.2)
    
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf("?", self.infoButton.x, self.infoButton.y + 8, self.infoButton.w, "center")
    love.graphics.pop()

    -- ==========================================
    -- RIGHT PANEL: Toggles (AutoFire, Dmg Nums, AutoWave)
    -- ==========================================
    local hoverAutoFire = mx >= self.autoFireButton.x and mx <= self.autoFireButton.x + self.autoFireButton.w and
                          my >= self.autoFireButton.y and my <= self.autoFireButton.y + self.autoFireButton.h
    local hoverDmgNums = mx >= self.dmgNumsButton.x and mx <= self.dmgNumsButton.x + self.dmgNumsButton.w and
                         my >= self.dmgNumsButton.y and my <= self.dmgNumsButton.y + self.dmgNumsButton.h
    local hoverAutoWave = mx >= self.autoWaveButton.x and mx <= self.autoWaveButton.x + self.autoWaveButton.w and
                          my >= self.autoWaveButton.y and my <= self.autoWaveButton.y + self.autoWaveButton.h

    local autofireEnabled = game.mainLazer and game.mainLazer.autofire or false
    drawToggle(self.autoFireButton, "AUTO-FIRE", autofireEnabled, hoverAutoFire, pulse * 0.4)
    drawToggle(self.dmgNumsButton, "DMG NUMS", game.showDamageNumbers, hoverDmgNums, pulse * 0.4)
    drawToggle(self.autoWaveButton, "AUTO-WAVE", game.autoStartWave, hoverAutoWave, pulse * 0.4)

    -- ==========================================
    -- FAR RIGHT PANEL: Speed Control Console
    -- ==========================================
    -- Speed Panel Frame
    love.graphics.setColor(0.02, 0.05, 0.1, 0.6)
    love.graphics.rectangle("fill", self.speedPanel.x, self.speedPanel.y, self.speedPanel.w, self.speedPanel.h, 6)
    drawGlowRect(self.speedPanel.x, self.speedPanel.y, self.speedPanel.w, self.speedPanel.h, 0.0, 0.85, 1.0, 1, 6, 6, pulse * 0.25)
    
    -- Speed Panel Title
    love.graphics.push("all")
    love.graphics.setColor(0.0, 0.85, 1.0, 0.75)
    love.graphics.printf("SPEED CONSOLE", self.speedPanel.x, self.speedPanel.y + 6, self.speedPanel.w, "center")
    love.graphics.pop()
    
    -- Minus Button
    local hoverSpeedMinus = mx >= self.speedMinusButton.x and mx <= self.speedMinusButton.x + self.speedMinusButton.w and
                            my >= self.speedMinusButton.y and my <= self.speedMinusButton.y + self.speedMinusButton.h
    love.graphics.setColor(0.02, 0.05, 0.1, 0.8)
    love.graphics.rectangle("fill", self.speedMinusButton.x, self.speedMinusButton.y, self.speedMinusButton.w, self.speedMinusButton.h, 4)
    drawGlowRect(self.speedMinusButton.x, self.speedMinusButton.y, self.speedMinusButton.w, self.speedMinusButton.h, 0.0, 0.85, 1.0, hoverSpeedMinus and 2 or 1, 4, 4, pulse * 0.3)
    
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf("-", self.speedMinusButton.x, self.speedMinusButton.y + 8, self.speedMinusButton.w, "center")
    love.graphics.pop()
    
    -- Plus Button
    local hoverSpeedPlus = mx >= self.speedPlusButton.x and mx <= self.speedPlusButton.x + self.speedPlusButton.w and
                           my >= self.speedPlusButton.y and my <= self.speedPlusButton.y + self.speedPlusButton.h
    love.graphics.setColor(0.02, 0.05, 0.1, 0.8)
    love.graphics.rectangle("fill", self.speedPlusButton.x, self.speedPlusButton.y, self.speedPlusButton.w, self.speedPlusButton.h, 4)
    drawGlowRect(self.speedPlusButton.x, self.speedPlusButton.y, self.speedPlusButton.w, self.speedPlusButton.h, 0.0, 0.85, 1.0, hoverSpeedPlus and 2 or 1, 4, 4, pulse * 0.3)
    
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf("+", self.speedPlusButton.x, self.speedPlusButton.y + 8, self.speedPlusButton.w, "center")
    love.graphics.pop()
    
    -- Speed Readout (pulsing and color changes)
    local speedStr = string.format("%.1fX", game.time_mul)
    local readoutCol = { 0.0, 1.0, 0.4 } -- green
    if game.time_mul == 0 then
        speedStr = "PAUSED"
        readoutCol = { 1.0, 0.2, 0.2 } -- red
    elseif game.time_mul > 2 then
        readoutCol = { 1.0, 0.5, 0.0 } -- orange for fast forward
    end
    
    love.graphics.push("all")
    love.graphics.setColor(readoutCol[1], readoutCol[2], readoutCol[3], 0.9 + pulse * 0.1)
    
    -- Scaling text slightly for punchiness
    love.graphics.push()
    love.graphics.scale(1.2, 1.2)
    local scaledX = (self.speedPanel.x + 35) / 1.2
    local scaledY = (self.speedPanel.y + 36) / 1.2
    local scaledW = (self.speedPanel.w - 70) / 1.2
    love.graphics.printf(speedStr, scaledX, scaledY, scaledW, "center")
    love.graphics.pop()
    love.graphics.pop()

    -- Startup Text (Intro text)
    if game:isState("startup") then
        love.graphics.push("all")
        love.graphics.setColor(1, 1, 1, 1)
        local y = 150
        for i, lineSet in ipairs(GameText.IntroText) do
            local text = lineSet[1]
            love.graphics.printf(text, 90, y, VIRTUAL_WIDTH - 100, "center")
            
            -- Estimate lines based on width
            local font = love.graphics.getFont()
            local _, lines = font:getWrap(text, VIRTUAL_WIDTH - 100)
            y = y + (#lines * 16) + 10
        end
        -- Glowing start text
        love.graphics.setColor(0, 0.85, 1.0, 0.7 + pulse * 0.3)
        love.graphics.printf("PRESS ENTER TO START", 0, y + 30, VIRTUAL_WIDTH, "center")
        love.graphics.pop()
    end
end

function GUIManager:drawBorders()
    local game = self.game
    local pulse = (math.sin(game.pulseTimer * (game.oscillationSpeed or 1)) + 1) / 2
    local r, g, b = 0.0, 0.85, 1.0 -- Cyber-cyan glow instead of Red
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
    
    if button == 1 then
        -- Check Luck Button
        if x >= self.luckButton.x and x <= self.luckButton.x + self.luckButton.w and
           y >= self.luckButton.y and y <= self.luckButton.y + self.luckButton.h then
            self.game:buyLuck()
            return true
        end
        
        -- Check Buy Button
        if x >= self.buyButton.x and x <= self.buyButton.x + self.buyButton.w and
           y >= self.buyButton.y and y <= self.buyButton.y + self.buyButton.h then
            self.game:attemptPurchaseReward()
            return true
        end

        -- Check Info Button
        if x >= self.infoButton.x and x <= self.infoButton.x + self.infoButton.w and
           y >= self.infoButton.y and y <= self.infoButton.y + self.infoButton.h then
            -- We don't have an action here other than hover tooltip, but intercept click
            return true
        end

        -- Check AutoFire Button
        if x >= self.autoFireButton.x and x <= self.autoFireButton.x + self.autoFireButton.w and
           y >= self.autoFireButton.y and y <= self.autoFireButton.y + self.autoFireButton.h then
            if self.game.mainLazer then
                self.game.mainLazer.autofire = not self.game.mainLazer.autofire
            end
            return true
        end

        -- Check Damage Numbers Button
        if x >= self.dmgNumsButton.x and x <= self.dmgNumsButton.x + self.dmgNumsButton.w and
           y >= self.dmgNumsButton.y and y <= self.dmgNumsButton.y + self.dmgNumsButton.h then
            self.game:toggleDamageNumbers()
            return true
        end

        -- Check AutoWave Button
        if x >= self.autoWaveButton.x and x <= self.autoWaveButton.x + self.autoWaveButton.w and
           y >= self.autoWaveButton.y and y <= self.autoWaveButton.y + self.autoWaveButton.h then
            self.game.autoStartWave = not self.game.autoStartWave
            return true
        end

        -- Check Speed Minus Button
        if x >= self.speedMinusButton.x and x <= self.speedMinusButton.x + self.speedMinusButton.w and
           y >= self.speedMinusButton.y and y <= self.speedMinusButton.y + self.speedMinusButton.h then
            self.game.time_mul = math.max(self.game.time_mul - 0.5, 0.5)
            return true
        end

        -- Check Speed Plus Button
        if x >= self.speedPlusButton.x and x <= self.speedPlusButton.x + self.speedPlusButton.w and
           y >= self.speedPlusButton.y and y <= self.speedPlusButton.y + self.speedPlusButton.h then
            self.game.time_mul = math.min(self.game.time_mul + 0.5, 2.0)
            return true
        end
    end
    
    return false
end

return GUIManager
