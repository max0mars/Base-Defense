local HandUI = require("Game.GUI.HandUI")
local Layout = require("Game.GUI.Layout")
local TooltipManager = require("Game.GUI.TooltipManager")
local ConfirmationUI = require("Game.GUI.ConfirmationUI")
local GameText = require("Game.GUI.GameText")
local MutationUI = require("Game.GUI.MutationUI")
local IncomeFeedbackManager = require("Game.GUI.IncomeFeedbackManager")
local EnemySpawnUI = require("Game.GUI.EnemySpawnUI")
local WavePreviewUI = require("Game.GUI.WavePreviewUI")
local ItemPickerUI = require("Game.GUI.ItemPickerUI")
local InfoColumn = require("Game.GUI.InfoColumn")
local Codex = require("Game.GUI.Codex")
local Cursor = require("Game.GUI.Cursor")

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

-- Borderless toggle indicator: a status LED followed by a label. No box/frame.
local function drawToggle(btn, label, isEnabled, isHovered, pulse)
    pulse = pulse or 0
    love.graphics.push("all")

    -- LED status dot.
    local ledX = btn.x + 6
    local ledY = btn.y + btn.h / 2
    local ledRadius = 4
    if isEnabled then
        love.graphics.setColor(0, 1.0, 0.4, 0.30)
        love.graphics.circle("fill", ledX, ledY, ledRadius + 2)
        love.graphics.setColor(0, 1.0, 0.4, 1.0)
        love.graphics.circle("fill", ledX, ledY, ledRadius)
    else
        love.graphics.setColor(1.0, 0.3, 0.3, 0.85)
        love.graphics.circle("line", ledX, ledY, ledRadius)
    end

    -- Label, brighter on hover or when enabled.
    if isHovered then
        love.graphics.setColor(0.0, 0.9, 1.0, 1.0)
    elseif isEnabled then
        love.graphics.setColor(0.9, 0.95, 1.0, 1.0)
    else
        love.graphics.setColor(0.55, 0.62, 0.72, 0.9)
    end
    love.graphics.print(label, btn.x + 16, btn.y + btn.h / 2 - 6)

    love.graphics.pop()
end

-- A filled "card" action button: function-colored fill + left accent bar, a
-- left-aligned label and a right-aligned cost (green/red by affordability).
local function drawActionButton(btn, label, costText, baseCol, hovered, enabled, affordable)
    local r, g, b = baseCol[1], baseCol[2], baseCol[3]
    love.graphics.push("all")

    -- Body fill.
    local fillA = enabled and (hovered and 0.24 or 0.13) or 0.06
    love.graphics.setColor(r, g, b, fillA)
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 5, 5)

    -- Left accent bar.
    love.graphics.setColor(r, g, b, enabled and 1.0 or 0.4)
    love.graphics.rectangle("fill", btn.x, btn.y + 3, 3, btn.h - 6, 2, 2)

    -- Hover glow.
    if hovered and enabled then
        for i = 1, 2 do
            love.graphics.setColor(r, g, b, 0.07 * (1 - i / 3))
            love.graphics.setLineWidth(2 + i * 3)
            love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 5, 5)
        end
    end
    -- Border.
    love.graphics.setColor(r, g, b, enabled and (hovered and 0.95 or 0.5) or 0.25)
    love.graphics.setLineWidth(hovered and 2 or 1)
    love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 5, 5)

    -- Label (left) + cost (right).
    local ty = btn.y + btn.h / 2 - 6
    love.graphics.setColor(1, 1, 1, enabled and 1.0 or 0.45)
    love.graphics.print(label, btn.x + 14, ty)
    if costText then
        local font = love.graphics.getFont()
        if not enabled then love.graphics.setColor(0.6, 0.6, 0.65, 0.6)
        elseif affordable then love.graphics.setColor(0.4, 1.0, 0.5, 1)
        else love.graphics.setColor(1.0, 0.4, 0.4, 1) end
        love.graphics.print(costText, btn.x + btn.w - 12 - font:getWidth(costText), ty)
    end

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
        -- Top-bar controls are right-aligned across the wide 16:9 bar; the stats
        -- panel sits far left and the central gap is reserved for wave status.
        -- Roll / purchase buttons sit in the RIGHT slice of the stored-towers
        -- tray (stored cards lay out to their left).
        buyBlockerButton = { x = Layout.W - 188, y = Layout.tray.y + 16, w = 180, h = 34 },

        -- Borderless indicators in the top strip (centered in the field's top
        -- margin): toggle LEDs on the left, speed control on the right.
        autoFireButton = { x = Layout.field.x + 24,  y = math.floor((Layout.field.y - 24) / 2), w = 116, h = 24 },
        dmgNumsButton  = { x = Layout.field.x + 148, y = math.floor((Layout.field.y - 24) / 2), w = 116, h = 24 },
        autoWaveButton = { x = Layout.field.x + 272, y = math.floor((Layout.field.y - 24) / 2), w = 116, h = 24 },

        -- Speed control: [-] chevrons [+], no borders.
        speedMinusButton = { x = Layout.W - 130, y = math.floor((Layout.field.y - 24) / 2), w = 24, h = 24 },
        speedPanel       = { x = Layout.W - 102, y = math.floor((Layout.field.y - 24) / 2), w = 62, h = 24 },
        speedPlusButton  = { x = Layout.W - 36,  y = math.floor((Layout.field.y - 24) / 2), w = 24, h = 24 },
        
        mutation = MutationUI:new(game),
        incomeFeedback = IncomeFeedbackManager:new(game),
        enemySpawner = EnemySpawnUI:new(game),
        wavePreview = WavePreviewUI:new(game),
        itemPicker = ItemPickerUI:new(game),
        infoColumn = InfoColumn:new(game),
        codex = Codex:new(game),
        -- The codex is opened from the "BASE JOURNAL" button at the bottom of the
        -- info column (see InfoColumn).
    }, self)
    return obj
end

function GUIManager:isConsumingInput(x, y)
    local game = self.game
    
    -- Reward and Mutation systems take priority
    if game.rewardSystem and game.rewardSystem.isActive then return true end
    if self.mutation and self.mutation.isActive then return true end
    if game:isState("upgrade_mutation") then return true end
    if self.enemySpawner and self.enemySpawner.isActive then return true end
    if self.itemPicker and self.itemPicker.isActive then return true end

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
    if self.enemySpawner then self.enemySpawner:update(dt) end
    if self.wavePreview then self.wavePreview:update(dt) end
    if self.itemPicker then self.itemPicker:update(dt) end
    if self.infoColumn then self.infoColumn:update(dt) end

    local mx, my = love.mouse.getPosition()
    self.tooltips.rarityProbs = nil
end

function GUIManager:draw()
    -- Global HUD (chrome, stats, controls, borders).
    self:drawHUD()

    -- Left-column Horde + Inspect (replaces the old floating wave preview and
    -- bottom-right hover card).
    if self.infoColumn then self.infoColumn:draw() end

    -- UI elements on top of masks
    self.hand:draw()
    self.mutation:draw()     -- Draw mutation screen
    if self.enemySpawner then self.enemySpawner:draw() end
    if self.itemPicker then self.itemPicker:draw() end
    self.tooltips:draw()     -- Draw tips above everything
    if self.codex then self.codex:draw() end -- Codex overlays everything
end

-- True when a modal/overlay is open over the HUD (so background HUD buttons
-- should not respond to hover).
function GUIManager:overlayActive()
    return (self.game.rewardSystem and self.game.rewardSystem.isActive)
        or (self.mutation and self.mutation.isActive)
        or (self.game.specialUpgradeManager and self.game.specialUpgradeManager.isActive)
        or (self.codex and self.codex.isActive)
        or (self.enemySpawner and self.enemySpawner.isActive)
        or (self.itemPicker and self.itemPicker.isActive)
        or (self.confirmation and self.confirmation.active)
        or (paused == 1)
end

function GUIManager:drawHUD()
    local game = self.game
    local pulse = (math.sin(game.pulseTimer * 3.5) + 1) / 2 -- Pulsing rate for neon glow

    -- 0. Draw Deep Dark Glass HUD chrome: the full-height left command column
    --    and the bottom tray. The battlefield fills the rest.
    local L = Layout
    love.graphics.setColor(0.01, 0.02, 0.04, 0.95)
    love.graphics.rectangle("fill", L.leftColumn.x, L.leftColumn.y, L.leftColumn.w, L.leftColumn.h)
    love.graphics.rectangle("fill", L.tray.x, L.tray.y, L.tray.w, L.tray.h)

    -- Subtle grid lines inside the left column and the tray.
    love.graphics.push("all")
    love.graphics.setColor(0, 0.8, 1, 0.04)
    for gx = 20, L.leftColumn.w - 10, 20 do
        love.graphics.line(gx, 0, gx, L.H)
    end
    for gx = L.tray.x + 20, L.W - 20, 20 do
        love.graphics.line(gx, L.tray.y, gx, L.H)
    end
    for gy = L.tray.y + 10, L.H - 10, 20 do
        love.graphics.line(L.tray.x, gy, L.W, gy)
    end
    love.graphics.pop()

    -- Tray label.
    love.graphics.push("all")
    love.graphics.setColor(0.25, 0.55, 0.7, 0.7)
    love.graphics.print("STORED TOWERS", L.tray.x + 12, L.tray.y + 6)
    love.graphics.pop()

    -- 1. Draw glowing borders (moved from GameManager)
    self:drawBorders()

    -- ==========================================
    -- LEFT PANEL: Stats & Health Box
    -- ==========================================
    -- Draw stats container panel
    local statPanel = { x = L.leftColumn.x + 12, y = L.leftColumn.y + 12, w = L.leftColumn.w - 24, h = 84 }
    drawGlowRect(statPanel.x, statPanel.y, statPanel.w, statPanel.h, 0.0, 0.7, 0.9, 1, 6, 6, pulse * 0.3)

    -- Print digital styled readouts
    love.graphics.push("all")
    local sx, sy = statPanel.x + 12, statPanel.y + 10

    -- WAVE
    love.graphics.setColor(0, 0.85, 1.0, 0.8)
    love.graphics.print("WAVE", sx, sy)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(tostring(game.wave), sx + 85, sy)

    -- TOKENS
    love.graphics.setColor(1.0, 0.7, 0.1, 0.8)
    love.graphics.print("TOKENS", sx, sy + 22)
    love.graphics.setColor(1.0, 0.9, 0.2, 1)
    love.graphics.print(tostring(game.tokens), sx + 85, sy + 22)

    -- HEALTH BAR
    if game.base then
        local hpX, hpY, hpW, hpH = sx, sy + 56, statPanel.w - 24, 8
        local healthPercent = game.base.hp / game.base:getStat("maxHp")

        love.graphics.setColor(1, 1, 1, 0.8)
        local hpText = string.format("BASE HP: %d/%d", game.base.hp, game.base:getStat("maxHp"))
        love.graphics.print(hpText, sx, sy + 42)
        
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
    -- ROLL / PURCHASE BUTTONS (bottom of the left column)
    -- ==========================================
    local mx, my = love.mouse.getPosition()
    -- Suppress HUD hover while a modal/overlay is open (no hovering background buttons).
    if self:overlayActive() then mx, my = -1000, -1000 end
    local buyEnabled = not game.rewardSystem.isActive and game.inputMode == "idle"

    -- Luck Offering.


    -- Buy Blocker.
    drawActionButton(self.buyBlockerButton, "BUY BLOCKER",
        string.format("%d T", math.floor(game.blockerCost)),
        { 0.95, 0.55, 0.15 },
        Layout.inRegion(self.buyBlockerButton, mx, my), buyEnabled,
        game.tokens >= game.blockerCost)

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
    -- TOP STRIP: Speed control  ( -  >>  + ), borderless
    -- ==========================================
    local hoverSpeedMinus = mx >= self.speedMinusButton.x and mx <= self.speedMinusButton.x + self.speedMinusButton.w and
                            my >= self.speedMinusButton.y and my <= self.speedMinusButton.y + self.speedMinusButton.h
    local hoverSpeedPlus = mx >= self.speedPlusButton.x and mx <= self.speedPlusButton.x + self.speedPlusButton.w and
                           my >= self.speedPlusButton.y and my <= self.speedPlusButton.y + self.speedPlusButton.h

    love.graphics.push("all")

    -- Minus / Plus glyphs (brighten on hover).
    if hoverSpeedMinus then love.graphics.setColor(0.0, 0.9, 1.0, 1) else love.graphics.setColor(0.7, 0.78, 0.88, 0.9) end
    love.graphics.printf("-", self.speedMinusButton.x, self.speedMinusButton.y + 5, self.speedMinusButton.w, "center")
    if hoverSpeedPlus then love.graphics.setColor(0.0, 0.9, 1.0, 1) else love.graphics.setColor(0.7, 0.78, 0.88, 0.9) end
    love.graphics.printf("+", self.speedPlusButton.x, self.speedPlusButton.y + 5, self.speedPlusButton.w, "center")

    -- Speed chevrons: 1x ">", 1.5x ">>", 2x ">>>"; 0.5x is a single orange ">".
    local m = game.time_mul
    local glyph, gr, gg, gb
    if m == 0 then          glyph, gr, gg, gb = "II",  1.0, 0.2, 0.2   -- paused
    elseif m <= 0.5 then    glyph, gr, gg, gb = ">",   1.0, 0.6, 0.1   -- slow (orange)
    elseif m < 1.25 then    glyph, gr, gg, gb = ">",   0.0, 0.9, 1.0   -- 1x
    elseif m < 1.75 then    glyph, gr, gg, gb = ">>",  0.0, 0.9, 1.0   -- 1.5x
    else                    glyph, gr, gg, gb = ">>>", 0.2, 1.0, 0.4   -- 2x
    end
    love.graphics.setColor(gr, gg, gb, 0.9 + pulse * 0.1)
    love.graphics.printf(glyph, self.speedPanel.x, self.speedPanel.y + 5, self.speedPanel.w, "center")

    love.graphics.pop()

    -- Hand cursor over any HUD button (mx is neutralized while an overlay is open).
    for _, btn in ipairs({ self.luckButton, self.buyButton, self.buyBlockerButton,
        self.autoFireButton, self.dmgNumsButton, self.autoWaveButton,
        self.speedMinusButton, self.speedPlusButton }) do
        if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
            Cursor.wantHand = true
            break
        end
    end

    -- Single "press enter" call-to-action, shown before wave 1 (startup) and
    -- between waves (preparing), in a bordered panel centered on the battlefield.
    if game:isState("startup") or game:isState("preparing") then
        local f = Layout.field
        local boxW, boxH = 320, 60
        local bx = f.x + (f.w - boxW) / 2
        local by = f.y + (f.h - boxH) / 2
        love.graphics.push("all")
        -- Panel.
        love.graphics.setColor(0.04, 0.06, 0.09, 0.85)
        love.graphics.rectangle("fill", bx, by, boxW, boxH, 8, 8)
        -- Pulsing neon border.
        love.graphics.setColor(0, 0.85, 1.0, 0.5 + pulse * 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", bx, by, boxW, boxH, 8, 8)
        love.graphics.setLineWidth(1)
        -- Label.
        local font = love.graphics.getFont()
        love.graphics.setColor(0, 0.85, 1.0, 0.7 + pulse * 0.3)
        love.graphics.printf("PRESS ENTER TO START WAVE", bx, by + boxH / 2 - font:getHeight() / 2, boxW, "center")
        love.graphics.pop()
    end
end

function GUIManager:drawBorders()
    local game = self.game
    local pulse = (math.sin(game.pulseTimer * (game.oscillationSpeed or 1)) + 1) / 2
    local r, g, b = 0.0, 0.85, 1.0 -- Cyber-cyan glow instead of Red
    local thickness = 4
    local width, height = VIRTUAL_WIDTH, VIRTUAL_HEIGHT

    -- Bottom Border Line (top edge of the tray) — only under the battlefield,
    -- since the left column now extends full-height past it.
    local trayTop = Layout.tray.y
    local fx1 = Layout.field.x
    for i = 3, 1, -1 do
        local alpha = (0.15 * (1 - i/4)) * (0.5 + pulse * 0.5)
        love.graphics.setLineWidth(thickness + i * 4 + pulse * 8)
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.line(fx1, trayTop, width, trayTop)
    end
    love.graphics.setColor(r, g, b, 0.8 + pulse * 0.2)
    love.graphics.setLineWidth(thickness)
    love.graphics.line(fx1, trayTop, width, trayTop)

    -- Vertical frame line: just the left-column separator (full height). The
    -- battlefield runs flush to the right screen edge, so no right border line.
    local vlines = {
        { x = fx1, y1 = Layout.topBar.h, y2 = Layout.H },     -- column / field separator
    }
    for _, ln in ipairs(vlines) do
        for i = 3, 1, -1 do
            local alpha = (0.15 * (1 - i/4)) * (0.5 + pulse * 0.5)
            love.graphics.setLineWidth(thickness + i * 4 + pulse * 8)
            love.graphics.setColor(r, g, b, alpha)
            love.graphics.line(ln.x, ln.y1, ln.x, ln.y2)
        end
        love.graphics.setColor(r, g, b, 0.8 + pulse * 0.2)
        love.graphics.setLineWidth(thickness)
        love.graphics.line(ln.x, ln.y1, ln.x, ln.y2)
    end

    -- Dark-grey frame around the entire game canvas (all four edges visible).
    love.graphics.setColor(0.14, 0.14, 0.17, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 1, 1, width - 2, height - 2)

    love.graphics.setLineWidth(1)
end

function GUIManager:mousepressed(x, y, button)
    -- Handle input in reverse draw order (top to bottom)

    -- Codex overlays everything and captures all input while open.
    if self.codex and self.codex.isActive then
        self.codex:mousepressed(x, y, button)
        return true
    end

    if self.confirmation:mousepressed(x, y, button) then
        return true
    end

    if self.mutation:mousepressed(x, y, button) then
        return true
    end

    if self.enemySpawner and self.enemySpawner:mousepressed(x, y, button) then
        return true
    end

    if self.itemPicker and self.itemPicker.isActive and self.itemPicker:mousepressed(x, y, button) then
        return true
    end

    if self.hand:mousepressed(x, y, button) then
        return true
    end

    -- Clicking a Horde / Inspect card (or the BASE JOURNAL button) opens the codex.
    if self.infoColumn and self.infoColumn.mousepressed then
        local action = self.infoColumn:mousepressed(x, y, button)
        if action then
            self.codex:open(action.tab, action.id)
            return true
        end
    end
    
    if button == 1 then
        -- Check Buy Blocker Button
        if x >= self.buyBlockerButton.x and x <= self.buyBlockerButton.x + self.buyBlockerButton.w and
           y >= self.buyBlockerButton.y and y <= self.buyBlockerButton.y + self.buyBlockerButton.h then
            self.game:attemptPurchaseBlocker()
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
