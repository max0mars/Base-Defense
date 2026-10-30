local preparation_scene = {}
preparation_scene.__index = preparation_scene
local scene = require("Scenes.scene")
setmetatable(preparation_scene, { __index = scene })

local Cursor = require("Game.GUI.Cursor")
local Neon = require("Game.GUI.Neon")
local BattleDirector = require("Game.Spawning.BattleDirector")
local LevelManager = require("Game.Core.LevelManager")
local BattleManager = require("Game.Core.BattleManager")
local Card = require("Game.Cards.Card")
local MaterialRegistry = require("Game.Cards.MaterialRegistry")
local ExecutionType = require("Game.Cards.ExecutionType")
local PlayerDeck = require("Game.Cards.PlayerDeck")
local SettingsPanel = require("Game.GUI.SettingsPanel")
local CardDraw = require("Game.Cards.CardDraw")
local CardIcons = require("Game.Cards.CardIcons")
local ArtifactManager = require("Game.Artifacts.ArtifactManager")
local ArtifactViewerUI = require("Game.GUI.ArtifactViewerUI")
local DevMode = require("Game.Dev.DevMode")
local PrepLoop = require("Game.Prep.PrepLoop")
local Scouting = require("Game.Prep.Scouting")
local Merchant = require("Game.Prep.Merchant")
local SaveGame = require("Game.Core.SaveGame")

-- The middle of the screen changes with the battle just finished (see PrepLoop)
local SCREENS = {
    quote = require("Game.Prep.Quotes"),
    merchant = Merchant,
    alchemist = require("Game.Prep.Alchemist"),
    upgrades = require("Game.Prep.MajorUpgrades"),
}
-- How the status bar names the preparation phase after the next battle
local EVENT_NAMES = {
    quote = "A MOMENT OF CALM",
    merchant = "THE TRAVELING MERCHANT",
    alchemist = "THE ALCHEMIST",
    upgrades = "MAJOR UPGRADES",
}

-- Layout: status along the top, the shared menu bar along the bottom, and the
-- artifact strip (with its label above it) just over the menu bar
local TOP_H = 110
local BAR_H = 70
local STRIP_LABEL_H = 18
local function stripY() return VIRTUAL_HEIGHT - BAR_H - 40 end

function preparation_scene:drawTrashIcon(cx, cy, size, col)
    local w = size or 22
    local h = size or 22
    local x = cx - w / 2
    local y = cy - h / 2
    
    love.graphics.setColor(col or {0.9, 0.35, 0.35, 1})
    
    -- Lid handle (small rounded rectangle at top)
    local handleW = math.max(4, math.floor(w * 0.35))
    local handleH = math.max(2, math.floor(h * 0.12))
    love.graphics.rectangle("fill", cx - handleW / 2, y, handleW, handleH, 1)
    
    -- Lid bar (horizontal bar extending past body)
    local lidW = math.floor(w * 0.85)
    local lidH = math.max(2, math.floor(h * 0.12))
    local lidY = y + handleH + 1
    love.graphics.rectangle("fill", cx - lidW / 2, lidY, lidW, lidH, 1)
    
    -- Can body (slightly tapered/rounded rectangle)
    local bodyW = math.floor(w * 0.65)
    local bodyH = h - (lidY + lidH - y) - 2
    local bodyX = cx - bodyW / 2
    local bodyY = lidY + lidH + 1
    love.graphics.rectangle("fill", bodyX, bodyY, bodyW, bodyH, 2)
    
    -- Slits / vertical lines on can body for clear garbage can silhouette
    love.graphics.setColor(0.08, 0.08, 0.12, 0.75)
    local slitW = math.max(1, math.floor(w * 0.08))
    local slitH = math.max(2, math.floor(bodyH * 0.6))
    local slitY = bodyY + math.floor((bodyH - slitH) / 2)
    local spacing = math.floor(bodyW * 0.25)
    love.graphics.rectangle("fill", cx - spacing - slitW / 2, slitY, slitW, slitH, 1)
    love.graphics.rectangle("fill", cx - slitW / 2, slitY, slitW, slitH, 1)
    love.graphics.rectangle("fill", cx + spacing - slitW / 2, slitY, slitW, slitH, 1)
end

function preparation_scene:load(isPostBattle)
    
    _G.PersistentState = _G.PersistentState or {}
    _G.PersistentState.materials = _G.PersistentState.materials or { ["Card Removal"] = 2 }
    if _G.PersistentState.cardRemovals == nil then
        _G.PersistentState.cardRemovals = (_G.PersistentState.materials and _G.PersistentState.materials["Card Removal"]) or 2
    end
    _G.PersistentState.materials["Card Removal"] = _G.PersistentState.cardRemovals
    
    if isPostBattle then
        _G.PersistentState.battlesCompleted = (_G.PersistentState.battlesCompleted or 0) + 1
        _G.PersistentState.globalDifficulty = (_G.PersistentState.globalDifficulty or 1) + 1
        
        if _G.PersistentState.battlesCompleted % 3 == 0 then
            local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
            EnemyRegistry:triggerRandomMutation()
        end
    end

    self.settings = SettingsPanel:new({
        title = "PAUSED",
        bottomButtons = {
            { label = "RESUME", action = "resume",
              color = {0.1, 0.45, 0.25, 1}, hoverColor = {0.18, 0.7, 0.4, 1}, borderColor = {0.3, 0.9, 0.5, 1} },
            { label = "EXIT", action = "exit",
              color = {0.4, 0.18, 0.2, 1}, hoverColor = {0.6, 0.28, 0.3, 1}, borderColor = {0.95, 0.45, 0.45, 1} },
        },
    })
    
    -- Shared menu bar
    local barY = VIRTUAL_HEIGHT - BAR_H + 12
    self.deckButton = {
        x = 20, y = barY, w = 140, h = 45, label = "VIEW DECK",
        color = {0.3, 0.3, 0.4, 1}, hoverColor = {0.4, 0.4, 0.5, 1}, borderColor = {0.6, 0.6, 0.8, 1}
    }

    self.upgradeCardsButton = {
        x = 175, y = barY, w = 170, h = 45, label = "UPGRADE CARDS",
        color = {0.15, 0.4, 0.3, 1}, hoverColor = {0.2, 0.55, 0.4, 1}, borderColor = {0.3, 0.85, 0.6, 1}
    }

    self.artifactsButton = {
        x = 360, y = barY, w = 150, h = 45, label = "ARTIFACTS",
        color = {0.3, 0.2, 0.45, 1}, hoverColor = {0.42, 0.28, 0.62, 1}, borderColor = {0.75, 0.55, 1, 1}
    }
    self.artifactViewer = ArtifactViewerUI:new()

    self.previewBattlesButton = {
        x = 525, y = barY, w = 180, h = 45, label = "SCOUTING REPORT",
        color = {0.15, 0.35, 0.55, 1}, hoverColor = {0.2, 0.48, 0.75, 1}, borderColor = {0.4, 0.75, 1, 1}
    }

    self.startButton = {
        x = VIRTUAL_WIDTH - 260, y = barY, w = 240, h = 45, label = "START NEXT BATTLE",
        color = {0.1, 0.45, 0.25, 1}, hoverColor = {0.18, 0.7, 0.4, 1}, borderColor = {0.3, 0.9, 0.5, 1}
    }

    self.viewingDeck = false
    self.viewingUpgrades = false
    self.viewingLevelSelect = false
    self.upgradePage = 1
    self.deckPage = 1
    self.deckTrashMode = false
    self.destroyConfirmCard = nil

    self.levelManager = LevelManager:new()
    self.battleManager = BattleManager:new()
    self:precalculateWaves()
    self.visit = PrepLoop.getVisit()
    SaveGame.save("preparation")
end

--- Saves (so quitting mid-battle restarts it) and starts the selected battle.
function preparation_scene:launchBattle()
    SaveGame.save("game")
    self.scene_manager.switch("game")
end

--- Where the current screen (merchant, alchemist...) draws: between the status
--- bar and the artifact strip's label above the menu bar.
function preparation_scene:contentArea()
    local top = TOP_H + 10
    return { x = 20, y = top, w = VIRTUAL_WIDTH - 40, h = stripY() - STRIP_LABEL_H - 8 - top }
end

function preparation_scene:precalculateWaves()
    _G.PersistentState = _G.PersistentState or {}
    local currentLevel = (_G.PersistentState.battlesCompleted or 0) + 1

    -- Calculate upcoming major battle level (every 5 waves: 5, 10, 15, 20...)
    local nextMajorLevel = math.ceil(currentLevel / 5) * 5
    if nextMajorLevel == 0 then nextMajorLevel = 5 end
    self.nextMajorLevel = nextMajorLevel

    -- Check if we already generated and cached the upcoming major battle for this milestone
    local cached = _G.PersistentState.upcomingMajorBattle
    if cached and cached.level == nextMajorLevel and cached.choices then
        self.majorBattleChoices = cached.choices
    else
        self.majorBattleChoices = self.levelManager:generateChoices(nextMajorLevel)
        _G.PersistentState.upcomingMajorBattle = {
            level = nextMajorLevel,
            choices = self.majorBattleChoices
        }
    end

    -- If current level IS the milestone battle, the battle encounter is the cached major battle!
    if currentLevel == nextMajorLevel then
        self.levelChoices = self.majorBattleChoices
    else
        -- Use LevelManager to generate choices for the regular current level, once
        -- per visit so reloading a save doesn't reroll them
        local visit = PrepLoop.getVisit()
        visit.levelChoices = visit.levelChoices or self.levelManager:generateChoices(currentLevel)
        self.levelChoices = visit.levelChoices
    end

    -- Default to choice 1 (or safe choice) until player confirms/picks
    self:applyLevelChoice(self.levelChoices[1])
end

function preparation_scene:applyLevelChoice(choice)
    if not choice then return end
    self.selectedChoice = choice
    _G.PersistentState.selectedBattle = choice

    -- Create dummy game for BattleDirector
    local dummyGame = {}
    local bd = BattleDirector:new(dummyGame)
    
    local template = choice.template
    local upcomingWaves, upcomingSummaries, forecastTotals = bd:generateBattle(choice.difficultyMultiplier or 1, { template = template, roster = choice.roster, level = choice.playerLevel })
    _G.PersistentState.upcomingWaves = upcomingWaves
    _G.PersistentState.upcomingSummaries = upcomingSummaries
    
    self.forecast = {
        low = 0,
        medium = 0,
        high = 0,
        totals = forecastTotals,
        multiplier = choice.difficultyMultiplier,
        rewards = choice.rewards
    }
end

function preparation_scene:update(dt)
    if paused == 1 and self.settings then
        self.settings:update(dt)
        return
    end
end

function preparation_scene:drawButton(btn, mx, my)
    local isHovered = mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h
    if isHovered then Cursor.wantHand = true end
    Neon.button(btn, { hovered = isHovered })
end


-- Deck view grid, shared by drawing and click hit-testing. Cards keep their
-- 250x350 shape; Prev/Next sit in the side margins so two rows fit.
local DECK_COLS, DECK_PER_PAGE = 4, 8
local DECK_CARD_W, DECK_CARD_H = 190, 266
local DECK_SPACING_X, DECK_SPACING_Y = 36, 16
local DECK_START_Y = 96

--- Screen rect of the card at displayIndex (0-based) on the current deck page.
local function deckCardRect(displayIndex)
    local startX = (VIRTUAL_WIDTH - (DECK_COLS * DECK_CARD_W + (DECK_COLS - 1) * DECK_SPACING_X)) / 2
    local col = displayIndex % DECK_COLS
    local row = math.floor(displayIndex / DECK_COLS)
    return startX + col * (DECK_CARD_W + DECK_SPACING_X), DECK_START_Y + row * (DECK_CARD_H + DECK_SPACING_Y),
        DECK_CARD_W, DECK_CARD_H
end

function preparation_scene:drawDeck()
    local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")
    local removals = CardUpgradeConfig.Economy.getCardRemovals()
    local mx, my = love.mouse.getPosition()

    Neon.panel(100, 45, VIRTUAL_WIDTH - 200, VIRTUAL_HEIGHT - 90, Neon.CYAN)

    -- Header: Total cards count
    if _G.PersistentState.deck then
        local rawCards = _G.PersistentState.deck:getCards()
        local totalCount = 0
        for _, c in ipairs(rawCards) do
            totalCount = totalCount + (c.quantity or 1)
        end
        love.graphics.setColor(0.85, 0.85, 0.9, 1)
        love.graphics.printf("Cards in Deck: " .. totalCount, 120, 58, 200, "left")
    end

    -- Header: Garbage / Removal Button
    self.deckTrashBtn = {
        x = VIRTUAL_WIDTH - 290,
        y = 52,
        w = 170,
        h = 36
    }
    local isTrashBtnHover = false
    if not self.destroyConfirmCard then
        isTrashBtnHover = mx >= self.deckTrashBtn.x and mx <= self.deckTrashBtn.x + self.deckTrashBtn.w and my >= self.deckTrashBtn.y and my <= self.deckTrashBtn.y + self.deckTrashBtn.h
        if isTrashBtnHover then Cursor.wantHand = true end
    end

    if self.deckTrashMode then
        -- Pulsing warning banner in center
        local pulse = 0.75 + 0.25 * math.sin(love.timer.getTime() * 6)
        love.graphics.setColor(1, 0.35, 0.35, pulse)
        love.graphics.printf("REMOVAL MODE: Click a card to destroy it", 100, 60, VIRTUAL_WIDTH - 200, "center")

        -- Active Cancel button
        Neon.rect(self.deckTrashBtn.x, self.deckTrashBtn.y, self.deckTrashBtn.w, self.deckTrashBtn.h, Neon.RED,
            { bg = 0.9, tint = isTrashBtnHover and 0.35 or 0.22, width = 2.5 })
self:drawTrashIcon(self.deckTrashBtn.x + 22, self.deckTrashBtn.y + 18, 20, {1, 1, 1, 1})
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("CANCEL", self.deckTrashBtn.x + 36, self.deckTrashBtn.y + 10, self.deckTrashBtn.w - 40, "center")
    else
        local canTrash = removals > 0
        Neon.rect(self.deckTrashBtn.x, self.deckTrashBtn.y, self.deckTrashBtn.w, self.deckTrashBtn.h,
            canTrash and Neon.RED or Neon.DIM,
            { bg = 0.9, tint = (canTrash and isTrashBtnHover) and 0.22 or 0.08, width = isTrashBtnHover and 2.5 or 1.5,
              alpha = canTrash and 1 or 0.7 })

        local iconColor = canTrash and (isTrashBtnHover and {1, 0.4, 0.4, 1} or {0.9, 0.35, 0.35, 1})
                                   or {0.5, 0.5, 0.5, 1}
        self:drawTrashIcon(self.deckTrashBtn.x + 22, self.deckTrashBtn.y + 18, 20, iconColor)

        love.graphics.setColor(canTrash and {1, 1, 1, 1} or {0.55, 0.55, 0.6, 1})
        local label = canTrash and ("Destroy (" .. removals .. ")") or "Destroy (0)"
        love.graphics.printf(label, self.deckTrashBtn.x + 36, self.deckTrashBtn.y + 10, self.deckTrashBtn.w - 40, "center")
    end

    if _G.PersistentState.deck then
        local cards = _G.PersistentState.deck:getCards()

        local totalPages = math.max(1, math.ceil(#cards / DECK_PER_PAGE))
        self.deckPage = self.deckPage or 1
        if self.deckPage > totalPages then self.deckPage = totalPages end
        if self.deckPage < 1 then self.deckPage = 1 end

        local startIndex = (self.deckPage - 1) * DECK_PER_PAGE + 1
        local endIndex = math.min(self.deckPage * DECK_PER_PAGE, #cards)

        local hoveredIcon, iconX, iconY
        for i = startIndex, endIndex do
            local card = cards[i]
            local cx, cy, cardW, cardH = deckCardRect(i - startIndex)

            local isTargetedForDestruction = (self.destroyConfirmCard ~= nil and self.destroyConfirmCard == card)
            local isHovered = false
            if not self.destroyConfirmCard then
                isHovered = mx >= cx and mx <= cx + cardW and my >= cy and my <= cy + cardH
                if isHovered and self.deckTrashMode then
                    Cursor.wantHand = true
                    Cursor.setIcon("removeCard")
                end
            end

            if card.getCardDraw and card:getCardDraw() then
                card:getCardDraw():draw(cx, cy, cardW, cardH, isHovered and not self.deckTrashMode)
                if isHovered and not self.deckTrashMode then
                    hoveredIcon, iconX, iconY = card:getCardDraw():iconAt(mx, my, cx, cy, cardW, cardH)
                end

                -- Draw quantity badge
                if card.quantity and card.quantity > 1 then
                    love.graphics.setColor(0.9, 0.2, 0.2, 1)
                    love.graphics.circle("fill", cx + cardW, cy, 12)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.printf(tostring(card.quantity), cx + cardW - 12, cy - 7, 24, "center")
                end
            else
                -- Fallback if no visual card
                love.graphics.setColor(0.3, 0.3, 0.3, 1)
                love.graphics.rectangle("fill", cx, cy, cardW, cardH, 5)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.printf(card.name, cx, cy + 50, cardW, "center")
            end

            -- Highlight card: either locked to targeted card when confirm popup appears,
            -- or on hover when selecting a card in removal mode
            local shouldHighlight = isTargetedForDestruction or (self.destroyConfirmCard == nil and self.deckTrashMode and isHovered)
            if shouldHighlight then
                love.graphics.setColor(0.9, 0.15, 0.15, 0.22)
                love.graphics.rectangle("fill", cx, cy, cardW, cardH, 8)
                love.graphics.setColor(1, 0.25, 0.25, 1)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", cx, cy, cardW, cardH, 8)
                love.graphics.setLineWidth(1)
                self:drawTrashIcon(cx + cardW / 2, cy + cardH / 2, 42, {1, 0.3, 0.3, 0.9})
            end
        end
        
        -- Hovering a synergy icon explains it (drawn last so it sits over neighbouring cards)
        if hoveredIcon then
            CardIcons.drawTooltip(hoveredIcon, iconX, iconY)
        end

        local pageBtnY = DECK_START_Y + DECK_CARD_H + DECK_SPACING_Y / 2 - 20
        self.prevPageBtn = { x = 112, y = pageBtnY, w = 84, h = 40, label = "Prev Page" }
        self.nextPageBtn = { x = VIRTUAL_WIDTH - 196, y = pageBtnY, w = 84, h = 40, label = "Next Page" }
        
        if self.deckPage > 1 then
            local isHovered = not self.destroyConfirmCard and (mx >= self.prevPageBtn.x and mx <= self.prevPageBtn.x + self.prevPageBtn.w and my >= self.prevPageBtn.y and my <= self.prevPageBtn.y + self.prevPageBtn.h)
            if isHovered then Cursor.wantHand = true end
            love.graphics.setColor(isHovered and {0.4, 0.6, 0.9, 1} or {0.3, 0.5, 0.8, 1})
            love.graphics.rectangle("fill", self.prevPageBtn.x, self.prevPageBtn.y, self.prevPageBtn.w, self.prevPageBtn.h, 5)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(self.prevPageBtn.label, self.prevPageBtn.x, self.prevPageBtn.y + 12, self.prevPageBtn.w, "center")
        end
        
        if self.deckPage < totalPages then
            local isHovered = not self.destroyConfirmCard and (mx >= self.nextPageBtn.x and mx <= self.nextPageBtn.x + self.nextPageBtn.w and my >= self.nextPageBtn.y and my <= self.nextPageBtn.y + self.nextPageBtn.h)
            if isHovered then Cursor.wantHand = true end
            love.graphics.setColor(isHovered and {0.4, 0.6, 0.9, 1} or {0.3, 0.5, 0.8, 1})
            love.graphics.rectangle("fill", self.nextPageBtn.x, self.nextPageBtn.y, self.nextPageBtn.w, self.nextPageBtn.h, 5)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(self.nextPageBtn.label, self.nextPageBtn.x, self.nextPageBtn.y + 12, self.nextPageBtn.w, "center")
        end
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Page " .. self.deckPage .. " / " .. totalPages, 0, VIRTUAL_HEIGHT - 68, VIRTUAL_WIDTH, "center")
    end

    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.printf("Click anywhere else to close", 100, VIRTUAL_HEIGHT - 45, VIRTUAL_WIDTH - 200, "center")
end

function preparation_scene:drawDestroyConfirmation(mx, my)
    if not self.destroyConfirmCard then return end
    
    local card = self.destroyConfirmCard
    local dw = 480
    local dh = 270
    local dx = (VIRTUAL_WIDTH - dw) / 2
    local dy = (VIRTUAL_HEIGHT - dh) / 2
    
    -- Dim backdrop
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    
    -- Modal panel
    Neon.panel(dx, dy, dw, dh, Neon.RED)

    -- Trash icon next to title
    self:drawTrashIcon(dx + 35, dy + 32, 26, {0.95, 0.3, 0.3, 1})
    
    -- Title
    love.graphics.setColor(1, 0.35, 0.35, 1)
    love.graphics.printf("DESTROY CARD", dx + 55, dy + 22, dw - 75, "left")
    
    -- Card Name
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(card.name or "Unknown Card", dx + 20, dy + 68, dw - 40, "center")
    
    -- Explanation / Details
    local qty = card.quantity or 1
    if qty > 1 then
        love.graphics.setColor(1, 0.85, 0.3, 1)
        love.graphics.printf("You have " .. qty .. " copies of this card in your deck.\nOnly a single copy will be destroyed (" .. (qty - 1) .. " remaining).", dx + 20, dy + 105, dw - 40, "center")
    else
        love.graphics.setColor(0.85, 0.85, 0.85, 1)
        love.graphics.printf("This is your only copy of this card.\nIt will be permanently removed from your deck.", dx + 20, dy + 105, dw - 40, "center")
    end
    
    love.graphics.setColor(0.65, 0.65, 0.7, 1)
    love.graphics.printf("Cost: 1 Card Removal", dx + 20, dy + 155, dw - 40, "center")
    
    -- Buttons
    self.confirmDestroyBtn = { x = dx + 35, y = dy + dh - 58, w = 190, h = 42, label = "DESTROY" }
    self.cancelDestroyBtn = { x = dx + dw - 225, y = dy + dh - 58, w = 190, h = 42, label = "CANCEL" }
    
    -- Draw Confirm Button
    local isConfirmHover = mx >= self.confirmDestroyBtn.x and mx <= self.confirmDestroyBtn.x + self.confirmDestroyBtn.w and my >= self.confirmDestroyBtn.y and my <= self.confirmDestroyBtn.y + self.confirmDestroyBtn.h
    if isConfirmHover then
        Cursor.wantHand = true
        Cursor.setIcon("removeCard")
    end
    self.confirmDestroyBtn.borderColor = Neon.RED
    Neon.button(self.confirmDestroyBtn, { hovered = isConfirmHover })

    -- Draw Cancel Button
    local isCancelHover = mx >= self.cancelDestroyBtn.x and mx <= self.cancelDestroyBtn.x + self.cancelDestroyBtn.w and my >= self.cancelDestroyBtn.y and my <= self.cancelDestroyBtn.y + self.cancelDestroyBtn.h
    if isCancelHover then Cursor.wantHand = true end
    self.cancelDestroyBtn.borderColor = { 0.55, 0.6, 0.85 }
    Neon.button(self.cancelDestroyBtn, { hovered = isCancelHover })
end

function preparation_scene:executeCardRemoval(card)
    if not card then return false end
    local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")
    if CardUpgradeConfig.Economy.getCardRemovals() < 1 then
        return false
    end
    
    local deck = _G.PersistentState and _G.PersistentState.deck
    if not deck then return false end
    
    -- Deduct 1 card removal
    CardUpgradeConfig.Economy.useCardRemoval()
    
    -- Remove single card
    if type(deck.removeCardInstance) == "function" then
        deck:removeCardInstance(card)
    else
        local qty = card.quantity or 1
        if qty > 1 then
            card.quantity = qty - 1
            if card.payload then card.payload.rewardCard = nil end
            card.rewardCard = nil
        else
            if deck.cards then
                for idx = #deck.cards, 1, -1 do
                    if deck.cards[idx] == card then
                        table.remove(deck.cards, idx)
                        break
                    end
                end
            elseif type(deck.removeCard) == "function" then
                deck:removeCard(card.id, 1, card.tier)
            end
        end
    end
    
    -- Adjust pagination if needed
    local cards = deck:getCards()
    local totalPages = math.max(1, math.ceil(#cards / 8))
    if self.deckPage > totalPages then
        self.deckPage = totalPages
    end
    
    return true
end

local function isUpgradableCard(c)
    if not c then return false end
    if type(c.isUpgradable) == "function" then
        return c:isUpgradable()
    end
    if c.upgradable ~= nil then
        return c.upgradable
    end
    if type(c.isTurret) == "function" then
        return c:isTurret()
    end
    if c.payload then
        local payload = c.payload
        local cfg = payload.config or {}
        if payload.upgradable ~= nil then return payload.upgradable end
        if cfg.upgradable ~= nil then return cfg.upgradable end
        
        local iconCat = payload.iconCategory or cfg.iconCategory or c.iconCategory
        if iconCat == "buff" or iconCat == "spell" or iconCat == "instant" then return false end

        local function checkType(col, name)
            if not col then return false end
            if type(col) == "table" then
                for _, t in ipairs(col) do if t == name then return true end end
                if col[name] == true then return true end
            elseif col == name then return true end
            return false
        end

        local bClass = payload.buildingClass
        if checkType(payload.types, "passive") or checkType(payload.types, "buff") or
           checkType(cfg.types, "passive") or checkType(cfg.types, "buff") or
           checkType(c.types, "passive") or checkType(c.types, "buff") or
           (bClass and (checkType(bClass.types, "passive") or checkType(bClass.types, "buff"))) then
            return false
        end

        local affSlots = payload.affectedSlots or cfg.affectedSlots
        if affSlots and #affSlots > 0 and iconCat ~= "turret" then return false end

        if iconCat == "turret" then return true end
        if checkType(payload.types, "turret") or checkType(cfg.types, "turret") or checkType(c.types, "turret") or (bClass and checkType(bClass.types, "turret")) then
            return true
        end
        if cfg.damage or cfg.fireRate or cfg.range or cfg.damageBars or cfg.firerateBars or cfg.rangeBars or
           payload.damage or payload.fireRate or payload.range then
            return true
        end
    end
    if type(c.getCardDraw) == "function" then
        local cd = c:getCardDraw()
        if cd and cd.upgradable ~= nil then
            return cd.upgradable
        end
    end
    return false
end

local function getCardTier(c)
    if not c then return 1 end
    if type(c.getTier) == "function" then
        return c:getTier()
    end
    return c.tier or 1
end

local function getCardNextUpgradeCost(c)
    if not c then return nil end
    local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")
    if type(c.getNextUpgradeCost) == "function" then
        return c:getNextUpgradeCost()
    end
    local currentTier = getCardTier(c)
    if currentTier >= CardUpgradeConfig.MAX_TIER then return nil end
    local nextTier = currentTier + 1
    local cost = (c.upgradeCosts and c.upgradeCosts[nextTier]) or CardUpgradeConfig.DEFAULT_COSTS[nextTier]
    return CardUpgradeConfig.resolveCost(cost, nil)
end

local function canUpgradeCard(c)
    if not c then return false, "nil_card" end
    local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")
    if type(c.canUpgrade) == "function" then
        return c:canUpgrade()
    end
    local currentTier = getCardTier(c)
    if currentTier >= CardUpgradeConfig.MAX_TIER then return false, "max_tier" end
    local cost = getCardNextUpgradeCost(c)
    if not cost then return false, "no_cost" end
    if not CardUpgradeConfig.Economy.canAfford(cost) then
        return false, "insufficient_resources", cost
    end
    return true, nil, cost
end

local function upgradeCard(c)
    if not c then return false end
    local deck = _G.PersistentState and _G.PersistentState.deck
    if type(c.upgrade) == "function" then
        return c:upgrade(deck)
    end
    local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")
    local can, reason, cost = canUpgradeCard(c)
    if not can then return false, reason end
    CardUpgradeConfig.Economy.deduct(cost)
    local currentTier = getCardTier(c)
    local nextTier = currentTier + 1

    if (c.quantity or 1) > 1 then
        c.quantity = c.quantity - 1
        if c.payload then c.payload.rewardCard = nil end
        if c.rewardCard then c.rewardCard = nil end

        local merged = false
        if deck and deck.cards then
            for _, other in ipairs(deck.cards) do
                if other.id == c.id and getCardTier(other) == nextTier then
                    other.quantity = (other.quantity or 1) + 1
                    if other.payload then other.payload.rewardCard = nil end
                    if other.rewardCard then other.rewardCard = nil end
                    merged = true
                    break
                end
            end
        end

        if not merged then
            local Utils = require("Classes.Utils")
            local newCard = Utils.deepCopy(c)
            newCard.quantity = 1
            newCard.tier = nextTier
            if newCard.payload then newCard.payload.rewardCard = nil end
            newCard.rewardCard = nil
            if deck and deck.cards then
                table.insert(deck.cards, newCard)
            end
        end
    else
        local merged = false
        if deck and deck.cards then
            for i, other in ipairs(deck.cards) do
                if other ~= c and other.id == c.id and getCardTier(other) == nextTier then
                    other.quantity = (other.quantity or 1) + 1
                    if other.payload then other.payload.rewardCard = nil end
                    if other.rewardCard then other.rewardCard = nil end
                    for j = #deck.cards, 1, -1 do
                        if deck.cards[j] == c then
                            table.remove(deck.cards, j)
                            break
                        end
                    end
                    merged = true
                    break
                end
            end
        end
        if not merged then
            c.tier = nextTier
            if c.payload then c.payload.rewardCard = nil end
            if c.rewardCard then c.rewardCard = nil end
        end
    end
    return true, nextTier
end

function preparation_scene:drawUpgradeWindow()
    local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")
    local mx, my = love.mouse.getPosition()

    -- 1. Modal backdrop & border matching View Deck window
    Neon.panel(100, 45, VIRTUAL_WIDTH - 200, VIRTUAL_HEIGHT - 90, Neon.GREEN)

    -- 2. Header: Title and Resource Balances
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("UPGRADE CARDS", 100, 55, VIRTUAL_WIDTH - 200, "center")
    
    local cash = CardUpgradeConfig.Economy.getResource("cash") or CardUpgradeConfig.Economy.getResource("gold")
    love.graphics.setColor(1, 0.85, 0.2, 1)
    love.graphics.printf("Cash: $" .. cash, 120, 55, 200, "left")
    -- Material balances, right-aligned in one row (every material in the registry)
    local matX = VIRTUAL_WIDTH - 120
    for i = #MaterialRegistry.list, 1, -1 do
        local mat = MaterialRegistry.list[i]
        local text = MaterialRegistry.getShortName(mat.id) .. ": " .. CardUpgradeConfig.Economy.getResource(mat.id)
        local w = love.graphics.getFont():getWidth(text)
        matX = matX - w
        love.graphics.setColor(mat.color)
        love.graphics.print(text, matX, 55)
        matX = matX - 16
    end

    self.upgradeButtons = {}

    if _G.PersistentState.deck then
        local rawCards = _G.PersistentState.deck:getCards()
        local cards = {}
        for _, card in ipairs(rawCards) do
            if isUpgradableCard(card) then
                table.insert(cards, card)
            end
        end
        
        if #cards == 0 then
            love.graphics.setColor(0.7, 0.7, 0.7, 1)
            love.graphics.printf("No upgradable turret cards in deck", 100, VIRTUAL_HEIGHT / 2 - 10, VIRTUAL_WIDTH - 200, "center")
            love.graphics.setColor(0.6, 0.6, 0.6, 1)
            love.graphics.printf("Click anywhere else to close", 100, VIRTUAL_HEIGHT - 45, VIRTUAL_WIDTH - 200, "center")
            return
        end
        
        local cols = 4
        local cardW = 200
        local cardH = 240
        local spacingX = 40
        local spacingY = 48
        local startX = (VIRTUAL_WIDTH - (cols * cardW + (cols - 1) * spacingX)) / 2
        local startY = 82
        
        local maxPerPage = 8
        local totalPages = math.max(1, math.ceil(#cards / maxPerPage))
        self.upgradePage = self.upgradePage or 1
        if self.upgradePage > totalPages then self.upgradePage = totalPages end
        if self.upgradePage < 1 then self.upgradePage = 1 end
        
        local startIndex = (self.upgradePage - 1) * maxPerPage + 1
        local endIndex = math.min(self.upgradePage * maxPerPage, #cards)
        
        for i = startIndex, endIndex do
            local displayIndex = i - startIndex
            local card = cards[i]
            local col = (displayIndex % cols)
            local row = math.floor(displayIndex / cols)
            
            local cx = startX + col * (cardW + spacingX)
            local cy = startY + row * (cardH + spacingY)
            
            if card.getCardDraw and card:getCardDraw() then
                local isHovered = mx >= cx and mx <= cx + cardW and my >= cy and my <= cy + cardH
                card:getCardDraw():draw(cx, cy, cardW, cardH, isHovered)
                
                -- Draw quantity badge
                if card.quantity and card.quantity > 1 then
                    love.graphics.setColor(0.9, 0.2, 0.2, 1)
                    love.graphics.circle("fill", cx + cardW, cy, 12)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.printf(tostring(card.quantity), cx + cardW - 12, cy - 7, 24, "center")
                end
            else
                love.graphics.setColor(0.3, 0.3, 0.3, 1)
                love.graphics.rectangle("fill", cx, cy, cardW, cardH, 5)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.printf(card.name, cx, cy + 50, cardW, "center")
            end
            
            -- Upgrade control directly below card
            local currentTier = getCardTier(card)
            local btnY = cy + cardH + 5
            local btnH = 34
            
            if currentTier >= CardUpgradeConfig.MAX_TIER then
                love.graphics.setColor(0.2, 0.25, 0.25, 0.8)
                love.graphics.rectangle("fill", cx, btnY, cardW, btnH, 4)
                love.graphics.setColor(0.4, 0.8, 0.5, 1)
                love.graphics.rectangle("line", cx, btnY, cardW, btnH, 4)
                love.graphics.setColor(1, 0.85, 0.2, 1)
                love.graphics.printf("MAX TIER (Tier V)", cx, btnY + 9, cardW, "center")
            else
                local cost = getCardNextUpgradeCost(card)
                local canAfford = cost and CardUpgradeConfig.Economy.canAfford(cost)
                local nextTier = currentTier + 1
                local nextTierRoman = CardUpgradeConfig.TIER_NAMES[nextTier] or tostring(nextTier)
                
                -- Display exact modular costs (Gold and the card's material or specific items)
                local costParts = {}
                if cost then
                    if cost.gold or cost.cash then
                        table.insert(costParts, "$" .. (cost.gold or cost.cash))
                    end
                    for resName, amount in pairs(cost) do
                        if resName ~= "gold" and resName ~= "cash" then
                            table.insert(costParts, amount .. " " .. MaterialRegistry.getName(resName))
                        end
                    end
                end
                local costStr = #costParts > 0 and table.concat(costParts, ", ") or "Free"
                -- Note when Universal Essence will cover a material shortfall
                local plan = canAfford and CardUpgradeConfig.Economy.planSpend(cost)
                local universalUsed = plan and plan[MaterialRegistry.UNIVERSAL]
                if universalUsed and not (cost and cost[MaterialRegistry.UNIVERSAL]) then
                    costStr = costStr .. " (" .. universalUsed .. " Universal)"
                end
                
                local isBtnHover = mx >= cx and mx <= cx + cardW and my >= btnY and my <= btnY + btnH
                if isBtnHover then
                    Cursor.wantHand = true
                    Cursor.setIcon("upgradeCard")
                end
                
                local fillCol = canAfford and (isBtnHover and {0.2, 0.65, 0.35, 1} or {0.15, 0.45, 0.25, 1})
                                          or {0.28, 0.16, 0.18, 0.85}
                local borderCol = canAfford and (isBtnHover and {0.4, 0.95, 0.6, 1} or {0.3, 0.8, 0.5, 1})
                                            or {0.55, 0.28, 0.28, 1}
                
                love.graphics.setColor(fillCol)
                love.graphics.rectangle("fill", cx, btnY, cardW, btnH, 4)
                love.graphics.setColor(borderCol)
                love.graphics.rectangle("line", cx, btnY, cardW, btnH, 4)
                
                love.graphics.setColor(canAfford and {1, 1, 1, 1} or {0.85, 0.6, 0.6, 1})
                love.graphics.printf("Tier " .. nextTierRoman .. ": " .. costStr, cx, btnY + 9, cardW, "center")
                
                table.insert(self.upgradeButtons, {
                    x = cx, y = btnY, w = cardW, h = btnH,
                    card = card, canAfford = canAfford
                })
            end
        end
        
        self.prevUpgradePageBtn = { x = 120, y = VIRTUAL_HEIGHT - 85, w = 120, h = 35, label = "Prev Page" }
        self.nextUpgradePageBtn = { x = VIRTUAL_WIDTH - 240, y = VIRTUAL_HEIGHT - 85, w = 120, h = 35, label = "Next Page" }
        
        if self.upgradePage > 1 then
            local isHovered = mx >= self.prevUpgradePageBtn.x and mx <= self.prevUpgradePageBtn.x + self.prevUpgradePageBtn.w and my >= self.prevUpgradePageBtn.y and my <= self.prevUpgradePageBtn.y + self.prevUpgradePageBtn.h
            if isHovered then Cursor.wantHand = true end
            love.graphics.setColor(isHovered and {0.2, 0.65, 0.35, 1} or {0.15, 0.45, 0.25, 1})
            love.graphics.rectangle("fill", self.prevUpgradePageBtn.x, self.prevUpgradePageBtn.y, self.prevUpgradePageBtn.w, self.prevUpgradePageBtn.h, 5)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(self.prevUpgradePageBtn.label, self.prevUpgradePageBtn.x, self.prevUpgradePageBtn.y + 10, self.prevUpgradePageBtn.w, "center")
        end
        
        if self.upgradePage < totalPages then
            local isHovered = mx >= self.nextUpgradePageBtn.x and mx <= self.nextUpgradePageBtn.x + self.nextUpgradePageBtn.w and my >= self.nextUpgradePageBtn.y and my <= self.nextUpgradePageBtn.y + self.nextUpgradePageBtn.h
            if isHovered then Cursor.wantHand = true end
            love.graphics.setColor(isHovered and {0.2, 0.65, 0.35, 1} or {0.15, 0.45, 0.25, 1})
            love.graphics.rectangle("fill", self.nextUpgradePageBtn.x, self.nextUpgradePageBtn.y, self.nextUpgradePageBtn.w, self.nextUpgradePageBtn.h, 5)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(self.nextUpgradePageBtn.label, self.nextUpgradePageBtn.x, self.nextUpgradePageBtn.y + 10, self.nextUpgradePageBtn.w, "center")
        end
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Page " .. self.upgradePage .. " / " .. totalPages, 0, VIRTUAL_HEIGHT - 75, VIRTUAL_WIDTH, "center")
    end
    
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.printf("Click anywhere else to close", 100, VIRTUAL_HEIGHT - 45, VIRTUAL_WIDTH - 200, "center")
end

function preparation_scene:draw()
    if paused == 1 and self.settings then
        self.settings:draw()
        return
    end
    
    Cursor.reset()
    local mx, my = love.mouse.getPosition()
    
    love.graphics.setColor(0.1, 0.1, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    
    local ps = _G.PersistentState or {}
    local hp = ps.baseHP or 200
    local cash = ps.cash or 0

    -- Status bar
    love.graphics.setColor(0.06, 0.06, 0.08, 1)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, TOP_H)
    love.graphics.setColor(0.25, 0.25, 0.3, 1)
    love.graphics.line(0, TOP_H, VIRTUAL_WIDTH, TOP_H)

    -- What's coming: the next battle, then the preparation phase after it
    -- (this visit's own screen shows its title in the content area)
    local battlesCompleted = ps.battlesCompleted or 0
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("LEVEL " .. (battlesCompleted + 1), 0, 20, VIRTUAL_WIDTH, "center")
    love.graphics.setColor(0.7, 0.75, 0.85, 1)
    love.graphics.printf("NEXT: " .. (EVENT_NAMES[PrepLoop.screenAfter(battlesCompleted + 1)] or ""),
        0, 44, VIRTUAL_WIDTH, "center")
    love.graphics.setColor(0.55, 0.6, 0.7, 1)
    love.graphics.printf("Scouting Lv " .. Scouting.getLevel() .. "   |   Merchant Lv " .. Merchant.getLevel(),
        0, 74, VIRTUAL_WIDTH, "center")

    love.graphics.setColor(0.8, 0.2, 0.2, 1)
    love.graphics.printf("Base HP: " .. hp .. " / 200", 20, 20, 200, "left")

    love.graphics.setColor(0.2, 0.8, 0.2, 1)
    love.graphics.printf("Cash: $" .. cash, 20, 45, 200, "left")

    local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")
    local removals = CardUpgradeConfig.Economy.getCardRemovals()
    self:drawTrashIcon(25, 77, 18, {0.9, 0.35, 0.35, 1})
    love.graphics.setColor(0.9, 0.45, 0.45, 1)
    love.graphics.printf("Removals: " .. removals, 40, 70, 150, "left")

    -- Upgrade materials (every material in the registry)
    local matY = 8
    for _, mat in ipairs(MaterialRegistry.list) do
        love.graphics.setColor(mat.color)
        love.graphics.printf(mat.name .. ": " .. CardUpgradeConfig.Economy.getResource(mat.id),
            VIRTUAL_WIDTH - 200, matY, 180, "left")
        matY = matY + 20
    end

    -- This visit's screen
    local screen = SCREENS[self.visit.screen]
    if screen then screen.draw(self, self.visit, self:contentArea(), mx, my) end

    -- Shared menu bar
    love.graphics.setColor(0.06, 0.06, 0.08, 1)
    love.graphics.rectangle("fill", 0, VIRTUAL_HEIGHT - BAR_H, VIRTUAL_WIDTH, BAR_H)
    love.graphics.setColor(0.25, 0.25, 0.3, 1)
    love.graphics.line(0, VIRTUAL_HEIGHT - BAR_H, VIRTUAL_WIDTH, VIRTUAL_HEIGHT - BAR_H)

    self:drawButton(self.startButton, mx, my)
    self:drawButton(self.deckButton, mx, my)
    self:drawButton(self.upgradeCardsButton, mx, my)
    self.artifactsButton.label = "ARTIFACTS (" .. #ArtifactManager.getOwnedIds() .. ")"
    self:drawButton(self.artifactsButton, mx, my)
    self:drawButton(self.previewBattlesButton, mx, my)

    -- Owned artifacts at a glance (hover for details, click to open the full list)
    self.artifactStripRect = self.artifactViewer:getStripRect(20, stripY())
    local hoveredArtifact = self.artifactViewer:drawStrip(self.artifactStripRect.x, self.artifactStripRect.y, mx, my)
    
    if self.viewingDeck then
        self:drawDeck()
        if self.destroyConfirmCard then
            self:drawDestroyConfirmation(mx, my)
        end
        Cursor.wantHand = true
    end
    
    if self.viewingUpgrades then
        self:drawUpgradeWindow()
        Cursor.wantHand = true
    end
    
    if self.viewingLevelSelect then
        self:drawLevelSelectWindow()
        Cursor.wantHand = true
    end

    if self.artifactViewer.isActive then
        self.artifactViewer:draw(mx, my)
        Cursor.wantHand = true
    end

    local modalOpen = self.viewingDeck or self.viewingUpgrades or self.viewingLevelSelect
        or self.artifactViewer.isActive
    if hoveredArtifact and not modalOpen then
        ArtifactViewerUI.drawTooltip(hoveredArtifact, mx, my)
    end

    DevMode.draw(false)
end

function preparation_scene:drawLevelSelectWindow()
    local mx, my = love.mouse.getPosition()
    
    -- Semi-transparent backdrop
    love.graphics.setColor(0, 0, 0, 0.88)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    
    local isLaunchMode = (self.levelSelectMode == "launch")
    local currentLevel = (_G.PersistentState and _G.PersistentState.battlesCompleted and (_G.PersistentState.battlesCompleted + 1))
        or (self.levelChoices and self.levelChoices[1] and self.levelChoices[1].playerLevel)
        or 1

    local nextMajorLevel = self.nextMajorLevel or (math.ceil(currentLevel / 5) * 5)
    if nextMajorLevel == 0 then nextMajorLevel = 5 end

    -- Active choices to display:
    -- In launch mode: immediate battle choices for currentLevel
    -- In preview mode (Scouting Report): preview of the upcoming Major Battle (milestone)
    local displayedChoices = isLaunchMode and self.levelChoices or (self.majorBattleChoices or self.levelChoices)

    -- Header Title
    love.graphics.setColor(1, 1, 1, 1)
    if isLaunchMode then
        if not self.titleFont then
            self.titleFont = love.graphics.newFont(32)
        end
        local oldFont = love.graphics.getFont()
        love.graphics.setFont(self.titleFont)
        love.graphics.printf(string.format("Level %d", currentLevel), 0, 48, VIRTUAL_WIDTH, "center")
        love.graphics.setFont(oldFont)
    else
        love.graphics.printf("SCOUTING REPORT: UPCOMING MAJOR BATTLE", 0, 48, VIRTUAL_WIDTH, "center")
        love.graphics.setColor(0.8, 0.85, 0.95, 1)
        love.graphics.printf(string.format("Intel on Level %d Major Hostile Encounter. Prepare your defenses accordingly.", nextMajorLevel), 0, 78, VIRTUAL_WIDTH, "center")
    end
    
    local cardW = 340
    local spacing = 40
    local isSingleCard = (#(displayedChoices or {}) == 1)
    local totalW = isSingleCard and cardW or ((#(displayedChoices or {}) * cardW) + ((#(displayedChoices or {}) - 1) * spacing))
    local startX = (VIRTUAL_WIDTH - totalW) / 2
    local startY = 125

    -- Cards grow to fit their longest enemy and reward lists (all cards the same
    -- size, with the rewards lined up); rows tighten if that won't fit on screen
    local maxEnemies, maxRewards = 0, 0
    for _, choice in ipairs(displayedChoices or {}) do
        maxEnemies = math.max(maxEnemies, #(choice.enemies or {}))
        maxRewards = math.max(maxRewards, #(choice.rewards or {}))
    end
    local ENEMIES_TOP, REWARDS_HEADER_H, BUTTON_H = 115, 42, 65
    local fixedH = ENEMIES_TOP + REWARDS_HEADER_H + BUTTON_H
    local maxCardH = VIRTUAL_HEIGHT - 75 - startY
    local rows = math.max(1, maxEnemies + maxRewards)
    local row = math.min(22, (maxCardH - fixedH) / rows)
    local cardH = math.max(380, math.min(maxCardH, fixedH + rows * row))
    local rewardsTop = ENEMIES_TOP + maxEnemies * row + 12

    self.levelChoiceButtons = {}
    
    for i, choice in ipairs(displayedChoices or {}) do
        local cx = startX + (i - 1) * (cardW + spacing)
        local cy = startY
        local isSelected = (self.selectedChoice and self.selectedChoice.slotIndex == choice.slotIndex)
        local isHovered = mx >= cx and mx <= cx + cardW and my >= cy and my <= cy + cardH
        if isHovered then Cursor.wantHand = true end
        
        -- Multiplier color
        local mult = choice.difficultyMultiplier or 1.0
        local isSafe = choice.isSafe
        local ELITE_PURPLE = {0.75, 0.35, 1, 1}
        local accentColor = choice.isMilestone and {1, 0.2, 0.2, 1}
            or (choice.isElite and ELITE_PURPLE)
            or (isSafe and {0.2, 0.9, 0.4, 1} or ((mult < 1.6) and {1, 0.8, 0.2, 1} or {1, 0.35, 0.35, 1}))
        
        -- Card background
        love.graphics.setColor(0.08, 0.08, 0.12, 0.95)
        love.graphics.rectangle("fill", cx, cy, cardW, cardH, 12)
        
        -- Card border: Always highlighted in danger color
        love.graphics.setColor(accentColor)
        love.graphics.setLineWidth(isHovered and 3 or 2)
        love.graphics.rectangle("line", cx, cy, cardW, cardH, 12)
        
        -- Threat / Major Battle / Elite Badge
        if choice.isMilestone or choice.isElite then
            if not self.majorBattleFont then
                self.majorBattleFont = love.graphics.newFont(26)
            end
            local oldFont = love.graphics.getFont()
            love.graphics.setFont(self.majorBattleFont)
            love.graphics.setColor(accentColor)
            love.graphics.printf(choice.isElite and "ELITE THREAT" or "MAJOR BATTLE", cx, cy + 20, cardW, "center")
            love.graphics.setFont(oldFont)
        else
            love.graphics.setColor(accentColor)
            local threatLabel = isSafe and "Low Threat" or ((mult < 1.6) and "Medium Threat" or "High Threat")
            love.graphics.printf(threatLabel, cx, cy + 24, cardW, "center")
        end
        
        -- Incoming Enemies Section
        love.graphics.setColor(0.6, 0.8, 1, 1)
        love.graphics.printf("Incoming Hostiles:", cx + 20, cy + 85, cardW - 40, "left")
        love.graphics.setColor(0.3, 0.5, 0.7, 0.5)
        love.graphics.line(cx + 20, cy + 105, cx + cardW - 20, cy + 105)
        
        local ey = cy + 115
        local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
        for _, enemy in ipairs(choice.enemies or {}) do
            -- Checked live: the scouting level can rise after the forecast was made
            if not Scouting.canSee(enemy.id) then
                love.graphics.setColor(0.6, 0.6, 0.6, 1)
                love.graphics.printf("• ??? (Scouting too low)", cx + 25, ey, cardW - 50, "left")
            else
                love.graphics.setColor(1, 0.45, 0.45, 1)
                love.graphics.printf("• " .. (EnemyRegistry:canonicalEnemyId(enemy.id) or enemy.id), cx + 25, ey, cardW - 50, "left")
            end
            ey = ey + row
        end
        
        -- Rewards Section
        local ry = cy + rewardsTop
        love.graphics.setColor(1, 0.85, 0.3, 1)
        love.graphics.printf("Guaranteed Rewards:", cx + 20, ry, cardW - 40, "left")
        love.graphics.setColor(0.7, 0.6, 0.2, 0.5)
        love.graphics.line(cx + 20, ry + 20, cx + cardW - 20, ry + 20)
        
        ry = ry + 30
        for _, reward in ipairs(choice.rewards or {}) do
            love.graphics.setColor(0.35, 1, 0.6, 1)
            love.graphics.printf("• " .. (reward.description or reward.name), cx + 25, ry, cardW - 50, "left")
            ry = ry + row
        end
        
        if isLaunchMode then
            -- Pre-battle launch mode: Clicking directly chooses and engages this battle!
            local btnW = cardW - 40
            local btnH = 40
            local btnX = cx + 20
            local btnY = cy + cardH - 55
            local btnHover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
            if btnHover then Cursor.wantHand = true end

            Neon.button({ x = btnX, y = btnY, w = btnW, h = btnH, label = "ENGAGE THIS BATTLE", borderColor = Neon.GREEN },
                { hovered = btnHover })

            table.insert(self.levelChoiceButtons, {
                x = btnX, y = btnY, w = btnW, h = btnH,
                cardX = cx, cardY = cy, cardW = cardW, cardH = cardH,
                choice = choice
            })
        end
    end
    
    -- Close / Cancel / Return Button
    local closeBtnW = 220
    local closeBtnH = 38
    local closeBtnX = (VIRTUAL_WIDTH - closeBtnW) / 2
    local closeBtnY = VIRTUAL_HEIGHT - 65
    local closeHover = mx >= closeBtnX and mx <= closeBtnX + closeBtnW and my >= closeBtnY and my <= closeBtnY + closeBtnH
    if closeHover then Cursor.wantHand = true end
    
    local closeText = isLaunchMode and "CANCEL / BACK TO PREPARATION" or "CLOSE SCOUTING REPORT"
    Neon.button({ x = closeBtnX, y = closeBtnY, w = closeBtnW, h = closeBtnH, label = closeText,
        borderColor = { 0.55, 0.6, 0.85 } }, { hovered = closeHover })
    self.closeLevelSelectBtn = { x = closeBtnX, y = closeBtnY, w = closeBtnW, h = closeBtnH }
end

function preparation_scene:mousepressed(x, y, button)
    self:handleMousePressed(x, y, button)
    -- Purchases, upgrades and removals all happen on a click: keep the save in step
    if self.scene_manager.current == self then SaveGame.save("preparation") end
end

function preparation_scene:handleMousePressed(x, y, button)
    if paused == 1 and self.settings then
        local action = self.settings:mousepressed(x, y, button)
        if action == "resume" then
            paused = 0
        elseif action == "exit" then
            paused = 0
            self.scene_manager.switch("menu")
        end
        return
    end
    
    if button ~= 1 then return end

    if self.artifactViewer.isActive then
        self.artifactViewer:mousepressed(x, y)
        return
    end
    
    if self.viewingLevelSelect then
        if self.closeLevelSelectBtn then
            local btn = self.closeLevelSelectBtn
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                self.viewingLevelSelect = false
                self.levelSelectMode = "preview"
                return
            end
        end
        if self.levelSelectMode == "launch" then
            for _, btn in ipairs(self.levelChoiceButtons or {}) do
                if (x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h) or
                   (x >= btn.cardX and x <= btn.cardX + btn.cardW and y >= btn.cardY and y <= btn.cardY + btn.cardH) then
                    self:applyLevelChoice(btn.choice)
                    self.viewingLevelSelect = false
                    self.levelSelectMode = "preview"
                    self:launchBattle()
                    return
                end
            end
        end
        self.viewingLevelSelect = false
        self.levelSelectMode = "preview"
        return
    end

    if self.viewingDeck then
        -- 1. Confirmation Modal
        if self.destroyConfirmCard then
            local btn = self.confirmDestroyBtn
            if btn and x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                self:executeCardRemoval(self.destroyConfirmCard)
                self.destroyConfirmCard = nil
                self.deckTrashMode = false
                return
            end
            btn = self.cancelDestroyBtn
            if btn and x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                self.destroyConfirmCard = nil
                return
            end
            local dw, dh = 480, 270
            local dx = (VIRTUAL_WIDTH - dw) / 2
            local dy = (VIRTUAL_HEIGHT - dh) / 2
            if x < dx or x > dx + dw or y < dy or y > dy + dh then
                self.destroyConfirmCard = nil
                return
            end
            return
        end

        -- 2. Trash button toggle
        if self.deckTrashBtn then
            local btn = self.deckTrashBtn
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")
                local removals = CardUpgradeConfig.Economy.getCardRemovals()
                if self.deckTrashMode then
                    self.deckTrashMode = false
                else
                    if removals > 0 then
                        self.deckTrashMode = true
                    end
                end
                return
            end
        end

        -- 3. Pagination buttons
        if self.deckPage and self.deckPage > 1 and self.prevPageBtn then
            local btn = self.prevPageBtn
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                self.deckPage = self.deckPage - 1
                return
            end
        end
        
        if self.deckPage and self.nextPageBtn then
            local cards = _G.PersistentState.deck and _G.PersistentState.deck:getCards() or {}
            local totalPages = math.max(1, math.ceil(#cards / 8))
            if self.deckPage < totalPages then
                local btn = self.nextPageBtn
                if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                    self.deckPage = self.deckPage + 1
                    return
                end
            end
        end

        -- 4. In Trash Mode: check card clicks
        if self.deckTrashMode then
            local cards = _G.PersistentState.deck and _G.PersistentState.deck:getCards() or {}
            local startIndex = (self.deckPage - 1) * DECK_PER_PAGE + 1
            local endIndex = math.min(self.deckPage * DECK_PER_PAGE, #cards)

            for i = startIndex, endIndex do
                local card = cards[i]
                local cx, cy, cardW, cardH = deckCardRect(i - startIndex)

                if x >= cx and x <= cx + cardW and y >= cy and y <= cy + cardH then
                    self.destroyConfirmCard = card
                    return
                end
            end

            -- Clicked inside modal window but not on a card: stay in deck view
            local modalX, modalY = 100, 45
            local modalW, modalH = VIRTUAL_WIDTH - 200, VIRTUAL_HEIGHT - 90
            if x >= modalX and x <= modalX + modalW and y >= modalY and y <= modalY + modalH then
                return
            end
        end

        -- 5. Clicking outside closes deck view
        local modalX, modalY = 100, 45
        local modalW, modalH = VIRTUAL_WIDTH - 200, VIRTUAL_HEIGHT - 90
        if x < modalX or x > modalX + modalW or y < modalY or y > modalY + modalH then
            self.viewingDeck = false
            self.deckPage = 1
            self.deckTrashMode = false
            self.destroyConfirmCard = nil
            return
        end

        -- Clicking empty space when not in trash mode closes deck view (original behavior)
        if not self.deckTrashMode then
            self.viewingDeck = false
            self.deckPage = 1
            self.deckTrashMode = false
            self.destroyConfirmCard = nil
            return
        end
    end

    if self.viewingUpgrades then
        if self.upgradePage and self.upgradePage > 1 and self.prevUpgradePageBtn then
            local btn = self.prevUpgradePageBtn
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                self.upgradePage = self.upgradePage - 1
                return
            end
        end
        
        if self.upgradePage and self.nextUpgradePageBtn then
            local rawCards = _G.PersistentState.deck and _G.PersistentState.deck:getCards() or {}
            local upgradeableCount = 0
            for _, c in ipairs(rawCards) do
                if isUpgradableCard(c) then upgradeableCount = upgradeableCount + 1 end
            end
            local totalPages = math.max(1, math.ceil(upgradeableCount / 8))
            if self.upgradePage < totalPages then
                local btn = self.nextUpgradePageBtn
                if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                    self.upgradePage = self.upgradePage + 1
                    return
                end
            end
        end
        
        -- Check click on upgrade buttons
        for _, btn in ipairs(self.upgradeButtons or {}) do
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                if btn.canAfford and btn.card then
                    upgradeCard(btn.card)
                end
                return
            end
        end
        
        self.viewingUpgrades = false
        self.upgradePage = 1
        return
    end
    
    btn = self.previewBattlesButton
    if btn and x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
        self.levelSelectMode = "preview"
        self.viewingLevelSelect = true
        self.viewingDeck = false
        self.viewingUpgrades = false
        return
    end

    local btn = self.startButton
    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
        -- Open battle select/confirmation screen (showing choices for regular battles, or the single Major Battle encounter)
        self.levelSelectMode = "launch"
        self.viewingLevelSelect = true
        self.viewingDeck = false
        self.viewingUpgrades = false
        return
    end
    
    btn = self.deckButton
    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
        self.viewingDeck = true
        self.viewingUpgrades = false
        self.deckTrashMode = false
        self.destroyConfirmCard = nil
        return
    end
    
    btn = self.artifactsButton
    local strip = self.artifactStripRect
    if (x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h)
        or (strip and strip.w > 0 and x >= strip.x and x <= strip.x + strip.w and y >= strip.y and y <= strip.y + strip.h) then
        self.artifactViewer:open()
        return
    end

    btn = self.upgradeCardsButton
    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
        self.viewingUpgrades = true
        self.viewingDeck = false
        return
    end
    
    local screen = SCREENS[self.visit.screen]
    if screen then screen.mousepressed(self, self.visit, self:contentArea(), x, y) end
end

function preparation_scene:mousereleased(x, y, button)
    if paused == 1 and self.settings then
        self.settings:mousereleased(x, y, button)
    end
end

function preparation_scene:keypressed(key)
    if DevMode.keypressed(key, nil) then return end

    if key == "escape" or key == "p" then
        if self.artifactViewer.isActive then
            self.artifactViewer:close()
            return
        end
        if self.viewingDeck then
            if self.destroyConfirmCard then
                self.destroyConfirmCard = nil
                return
            end
            if self.deckTrashMode then
                self.deckTrashMode = false
                return
            end
            self.viewingDeck = false
            self.deckPage = 1
            return
        end
        if self.viewingUpgrades then
            self.viewingUpgrades = false
            return
        end
        paused = paused == 1 and 0 or 1
        return
    end

    if key == "return" and not self.viewingDeck and not self.viewingUpgrades and not self.artifactViewer.isActive then
        self:launchBattle()
    end
end

return preparation_scene
