local preparation_scene = {}
preparation_scene.__index = preparation_scene
local scene = require("Scenes.scene")
setmetatable(preparation_scene, { __index = scene })

local Cursor = require("Game.GUI.Cursor")
local BattleDirector = require("Game.Spawning.BattleDirector")
local LevelManager = require("Game.Core.LevelManager")
local BattleManager = require("Game.Core.BattleManager")
local RewardPool = require("Game.Rewards.RewardPool")
local RewardIndex = require("Game.Rewards.RewardIndex")
local Card = require("Game.Cards.Card")
local ExecutionType = require("Game.Cards.ExecutionType")
local PlayerDeck = require("Game.Cards.PlayerDeck")
local SettingsPanel = require("Game.GUI.SettingsPanel")
local CardDraw = require("Game.Cards.CardDraw")

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
    love.mouse.setVisible(true)
    self.handCursor = love.mouse.getSystemCursor("hand")
    self.arrowCursor = love.mouse.getSystemCursor("arrow")
    
    _G.PersistentState = _G.PersistentState or {}
    _G.PersistentState.materials = _G.PersistentState.materials or { ["Upgrade Material"] = 5, ["Card Removal"] = 2 }
    if _G.PersistentState.cardRemovals == nil then
        _G.PersistentState.cardRemovals = (_G.PersistentState.materials and _G.PersistentState.materials["Card Removal"]) or 2
    end
    _G.PersistentState.materials["Card Removal"] = _G.PersistentState.cardRemovals
    
    if isPostBattle then
        _G.PersistentState.battlesCompleted = (_G.PersistentState.battlesCompleted or 0) + 1
        _G.PersistentState.globalDifficulty = (_G.PersistentState.globalDifficulty or 1) + 1
        
        -- Give 1 XP after each battle, except the first one (where it starts at level 1 with 0 XP)
        if _G.PersistentState.battlesCompleted > 1 then
            self:addShopXP(1)
        end
        
        if _G.PersistentState.battlesCompleted % 3 == 0 then
            local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
            EnemyRegistry:triggerRandomMutation()
        end
        
        if _G.PersistentState.battlesCompleted > 0 and _G.PersistentState.battlesCompleted % 5 == 0 then
            self.showUpgradeChoice = true
            local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")
            CardUpgradeConfig.Economy.addCardRemovals(1)
        end
    end
    
    if self.showUpgradeChoice then
        local cardW = 220
        local cardH = 340
        local spacing = 40
        local startX = (VIRTUAL_WIDTH - (3 * cardW + 2 * spacing)) / 2
        local startY = (VIRTUAL_HEIGHT - cardH) / 2
        
        self.upgradeChoices = {
            {
                id = "card_draw",
                x = startX,
                y = startY,
                w = cardW,
                h = cardH,
                title = "+1 CARD DRAW",
                desc = "Draw +1 card at the\nstart of battle and\nbetween waves.",
                color = {0.15, 0.35, 0.6, 1},
                hoverColor = {0.2, 0.45, 0.75, 1},
                borderColor = {0.3, 0.7, 1, 1}
            },
            {
                id = "tokens",
                x = startX + cardW + spacing,
                y = startY,
                w = cardW,
                h = cardH,
                title = "+1 TOKEN / TURN",
                desc = "Start waves and\nbattles with +1\nmaximum Token.",
                color = {0.15, 0.5, 0.3, 1},
                hoverColor = {0.2, 0.65, 0.4, 1},
                borderColor = {0.3, 0.9, 0.5, 1}
            },
            {
                id = "slots",
                x = startX + 2 * (cardW + spacing),
                y = startY,
                w = cardW,
                h = cardH,
                title = "+4 START SLOTS",
                desc = "Unlock 4 additional\nadjacent turret slots\nat the start of each\nbattle.",
                color = {0.45, 0.15, 0.5, 1},
                hoverColor = {0.6, 0.2, 0.7, 1},
                borderColor = {0.8, 0.3, 0.9, 1}
            }
        }
    end

    local cx = (VIRTUAL_WIDTH - 240) / 2
    local cy = VIRTUAL_HEIGHT - 60
    
    self.settings = SettingsPanel:new({
        title = "PAUSED",
        bottomButtons = {
            { label = "RESUME", action = "resume",
              color = {0.1, 0.45, 0.25, 1}, hoverColor = {0.18, 0.7, 0.4, 1}, borderColor = {0.3, 0.9, 0.5, 1} },
            { label = "EXIT", action = "exit",
              color = {0.4, 0.18, 0.2, 1}, hoverColor = {0.6, 0.28, 0.3, 1}, borderColor = {0.95, 0.45, 0.45, 1} },
        },
    })
    
    self.startButton = {
        x = cx, y = cy, w = 240, h = 45, label = "START NEXT BATTLE",
        color = {0.1, 0.45, 0.25, 1}, hoverColor = {0.18, 0.7, 0.4, 1}, borderColor = {0.3, 0.9, 0.5, 1}
    }
    
    self.deckButton = {
        x = 20, y = VIRTUAL_HEIGHT - 60, w = 140, h = 45, label = "VIEW DECK",
        color = {0.3, 0.3, 0.4, 1}, hoverColor = {0.4, 0.4, 0.5, 1}, borderColor = {0.6, 0.6, 0.8, 1}
    }
    
    self.upgradeCardsButton = {
        x = 175, y = VIRTUAL_HEIGHT - 60, w = 170, h = 45, label = "UPGRADE CARDS",
        color = {0.15, 0.4, 0.3, 1}, hoverColor = {0.2, 0.55, 0.4, 1}, borderColor = {0.3, 0.85, 0.6, 1}
    }
    
    self.previewBattlesButton = {
        x = VIRTUAL_WIDTH - 200, y = 20, w = 180, h = 42, label = "SCOUTING REPORT",
        color = {0.15, 0.35, 0.55, 1}, hoverColor = {0.2, 0.48, 0.75, 1}, borderColor = {0.4, 0.75, 1, 1}
    }
    
    self.rerollButton = {
        x = 20, y = 140, w = 160, h = 40, label = "Reroll Shop (20$)",
        color = {0.4, 0.3, 0.1, 1}, hoverColor = {0.6, 0.45, 0.15, 1}, borderColor = {0.8, 0.6, 0.2, 1}
    }

    self.buyXPButton = {
        x = 200, y = 140, w = 160, h = 40, label = "Buy XP (30$)",
        color = {0.5, 0.1, 0.5, 1}, hoverColor = {0.7, 0.2, 0.7, 1}, borderColor = {0.9, 0.3, 0.9, 1}
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
    self:rollShop()
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
        -- Use LevelManager to generate choices for the regular current level
        self.levelChoices = self.levelManager:generateChoices(currentLevel)
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
    local upcomingWaves, upcomingSummaries, forecastTotals = bd:generateBattle(choice.difficultyMultiplier or 1, { template = template, roster = choice.roster })
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

function preparation_scene:getRequiredXP(level)
    if level < 3 then return 2 end
    if level < 5 then return 3 end
    if level < 7 then return 4 end
    if level < 9 then return 5 end
    return 6
end

function preparation_scene:addShopXP(amount)
    if not _G.PersistentState.shopLevel then _G.PersistentState.shopLevel = 1 end
    if not _G.PersistentState.shopXP then _G.PersistentState.shopXP = 0 end
    
    if _G.PersistentState.shopLevel >= 10 then return end
    
    _G.PersistentState.shopXP = _G.PersistentState.shopXP + amount
    local req = self:getRequiredXP(_G.PersistentState.shopLevel)
    
    while _G.PersistentState.shopXP >= req do
        _G.PersistentState.shopXP = _G.PersistentState.shopXP - req
        _G.PersistentState.shopLevel = math.min(10, _G.PersistentState.shopLevel + 1)
        
        if _G.PersistentState.shopLevel >= 10 then
            _G.PersistentState.shopXP = 0
            break
        end
        req = self:getRequiredXP(_G.PersistentState.shopLevel)
    end
end

function preparation_scene:rollShop()
    local shopLevel = _G.PersistentState.shopLevel or 1
    
    -- Mock game for eligibility
    local dummyGame = {
        base = {
            mainLazer = { id = "standard_main", upgrades = {} }
        }
    }
    
    local poolLogic = RewardPool:new(RewardIndex, dummyGame)
    local choices = poolLogic:generateChoices(3, shopLevel)
    
    self.shopItems = {}
    
    local prices = { common = 20, uncommon = 30, rare = 40, epic = 50, legendary = 75 }
    local startX = (VIRTUAL_WIDTH - (3 * 220)) / 2 + 10
    
    for i, choice in ipairs(choices) do
        local rarity = choice.rarity or "common"
        local itemCost = prices[rarity] or 50
        
        local card
        if choice.type == "spell" then
            local SpellCardRegistry = require("Spells.SpellCardRegistry")
            local baseSpell = nil
            for _, s in pairs(SpellCardRegistry) do
                if type(s) == "table" and s.id == choice.id then
                    baseSpell = s
                    break
                end
            end
            if baseSpell then
                local Utils = require("Classes.Utils")
                card = Utils.deepCopy(baseSpell)
                card.quantity = 1
            end
        elseif choice.type == "instant" then
            local InstantCardRegistry = require("Instants.InstantCardRegistry")
            local baseInstant = nil
            for _, inst in pairs(InstantCardRegistry) do
                if type(inst) == "table" and inst.id == choice.id then
                    baseInstant = inst
                    break
                end
            end
            if baseInstant then
                local Utils = require("Classes.Utils")
                card = Utils.deepCopy(baseInstant)
                card.quantity = 1
            end
        end
        
        if not card then
            local isGlobal = choice.type == "main_upgrade"
            local cardPayload = { rarity = rarity }
            if isGlobal then
                cardPayload.isMainUpgrade = true
            else
                cardPayload.buildingClass = choice.building
                cardPayload.config = choice
            end
            
            card = Card:new({
                id = choice.id,
                name = choice.name,
                description = choice.description,
                executionType = isGlobal and ExecutionType.Targeted or ExecutionType.Placement,
                payload = cardPayload
            })
            cardPayload.rewardCard = card:getCardDraw()
        end
        
        table.insert(self.shopItems, {
            x = startX + (i-1) * 220,
            y = 220,
            w = 200,
            h = 280,
            card = card,
            cost = itemCost,
            purchased = false
        })
    end
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
    
    love.graphics.setColor(isHovered and btn.hoverColor or btn.color)
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 6, 6)
    
    love.graphics.setColor(btn.borderColor)
    love.graphics.setLineWidth(isHovered and 2 or 1)
    love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 6, 6)
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.printf(btn.label, btn.x + 1, btn.y + btn.h / 2 - 6, btn.w, "center")
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(btn.label, btn.x, btn.y + btn.h / 2 - 7, btn.w, "center")
end


function preparation_scene:drawShop(mx, my)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("SHOP", 0, 100, VIRTUAL_WIDTH, "center")
    
    for _, item in ipairs(self.shopItems) do
        if not item.purchased then
            local isHovered = mx >= item.x and mx <= item.x + item.w and my >= item.y and my <= item.y + item.h
            if isHovered then Cursor.wantHand = true end
            
            local cardDraw = nil
            if type(item.card.getCardDraw) == "function" then
                cardDraw = item.card:getCardDraw()
            elseif item.card.payload and item.card.payload.rewardCard then
                cardDraw = item.card.payload.rewardCard
            end
            
            if cardDraw then
                cardDraw:draw(item.x, item.y, item.w, item.h, isHovered)
            end
            
            local afford = (_G.PersistentState.cash or 0) >= item.cost
            love.graphics.setColor(afford and {0.2, 0.8, 0.2, 1} or {0.8, 0.2, 0.2, 1})
            love.graphics.printf("$" .. item.cost, item.x, item.y + item.h + 10, item.w, "center")
        end
    end
end

function preparation_scene:drawForecast()
    local fw = 230
    local fh = 260
    local fx = VIRTUAL_WIDTH - fw - 20
    local fy = 20
    
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", fx, fy, fw, fh, 8)
    
    local mult = (self.selectedChoice and self.selectedChoice.difficultyMultiplier) or 1.0
    local isSafe = (mult < 1.20)
    local isMilestone = (self.selectedChoice and self.selectedChoice.isMilestone)
    local multColor = isSafe and {0.2, 0.9, 0.4, 1} or ((mult < 1.6) and {1, 0.8, 0.2, 1} or {1, 0.35, 0.35, 1})
    local threatTierName = isSafe and "Low Threat" or ((mult < 1.6) and "Medium Threat" or "High Threat")
    if isMilestone then
        threatTierName = "MAJOR BATTLE"
        multColor = {1, 0.2, 0.2, 1}
    end
    love.graphics.setColor(multColor)
    love.graphics.rectangle("line", fx, fy, fw, fh, 8)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("BATTLE FORECAST", fx, fy + 8, fw, "center")
    
    if isMilestone then
        if not self.threatBadgeFont then
            self.threatBadgeFont = love.graphics.newFont(22)
        end
        local oldFont = love.graphics.getFont()
        love.graphics.setFont(self.threatBadgeFont)
        love.graphics.setColor(1, 0.2, 0.2, 1)
        love.graphics.printf(threatTierName, fx, fy + 24, fw, "center")
        love.graphics.setFont(oldFont)
    else
        love.graphics.setColor(multColor)
        love.graphics.printf(threatTierName, fx, fy + 26, fw, "center")
    end
    
    -- Enemy preview header
    love.graphics.setColor(0.7, 0.85, 1, 1)
    love.graphics.printf("Incoming Enemies:", fx + 10, fy + 48, fw - 20, "left")
    
    local yOff = fy + 66
    if self.selectedChoice and self.selectedChoice.enemies then
        local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
        for idx, enemy in ipairs(self.selectedChoice.enemies) do
            if idx <= 4 then
                local rawId = enemy.id or (enemy.displayName ~= "???" and enemy.displayName)
                local canonicalId = EnemyRegistry:canonicalEnemyId(rawId) or rawId
                local isDiscovered = false
                if canonicalId then
                    if _G.PersistentState and _G.PersistentState.discoveredEnemies then
                        isDiscovered = _G.PersistentState.discoveredEnemies[canonicalId] or (rawId and _G.PersistentState.discoveredEnemies[rawId])
                    end
                    if not isDiscovered and EnemyRegistry.discoveredEnemiesMap then
                        isDiscovered = EnemyRegistry.discoveredEnemiesMap[canonicalId] or (rawId and EnemyRegistry.discoveredEnemiesMap[rawId])
                    end
                end
                if not isDiscovered and enemy.displayName and enemy.displayName ~= "???" then
                    isDiscovered = true
                end

                if not isDiscovered then
                    love.graphics.setColor(0.65, 0.65, 0.65, 1)
                    love.graphics.printf("• ??? (Unknown)", fx + 15, yOff, fw - 30, "left")
                else
                    love.graphics.setColor(1, 0.4, 0.4, 1)
                    local displayName = canonicalId or rawId or enemy.displayName
                    love.graphics.printf("• " .. displayName, fx + 15, yOff, fw - 30, "left")
                end
                yOff = yOff + 18
            end
        end
    end
    
    -- Rewards preview header
    yOff = math.max(yOff + 4, fy + 144)
    love.graphics.setColor(1, 0.85, 0.3, 1)
    love.graphics.printf("Expected Rewards:", fx + 10, yOff, fw - 20, "left")
    yOff = yOff + 18
    
    if self.selectedChoice and self.selectedChoice.rewards then
        for idx, reward in ipairs(self.selectedChoice.rewards) do
            if idx <= 3 then
                love.graphics.setColor(0.3, 1, 0.5, 1)
                love.graphics.printf("• " .. (reward.description or reward.name), fx + 15, yOff, fw - 30, "left")
                yOff = yOff + 16
            end
        end
    end
    
    -- Select / Change Level button (Disabled / hidden on milestone battles where player has no choice)
    local isMilestone = self.selectedChoice and self.selectedChoice.isMilestone
    if not isMilestone then
        local mx, my = love.mouse.getPosition()
        local btnW = fw - 20
        local btnH = 28
        local btnX = fx + 10
        local btnY = fy + fh - 35
        local isHover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
        if isHover then Cursor.wantHand = true end
        
        love.graphics.setColor(isHover and {0.25, 0.5, 0.8, 1} or {0.15, 0.35, 0.6, 1})
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 5)
        love.graphics.setColor(0.4, 0.75, 1, 1)
        love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 5)
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("PREVIEW NEXT BATTLES", btnX, btnY + 7, btnW, "center")
        self.chooseBattleBtn = { x = btnX, y = btnY, w = btnW, h = btnH }
    else
        self.chooseBattleBtn = nil
        love.graphics.setColor(0.8, 0.3, 0.3, 0.9)
        love.graphics.printf("MANDATORY ENCOUNTER", fx + 10, fy + fh - 28, fw - 20, "center")
    end
end

function preparation_scene:drawDeck()
    local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")
    local removals = CardUpgradeConfig.Economy.getCardRemovals()
    local mx, my = love.mouse.getPosition()

    love.graphics.setColor(0, 0, 0, 0.92)
    love.graphics.rectangle("fill", 100, 45, VIRTUAL_WIDTH - 200, VIRTUAL_HEIGHT - 90, 10)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", 100, 45, VIRTUAL_WIDTH - 200, VIRTUAL_HEIGHT - 90, 10)
    
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
        love.graphics.setColor(isTrashBtnHover and {0.9, 0.25, 0.25, 1} or {0.8, 0.18, 0.18, 1})
        love.graphics.rectangle("fill", self.deckTrashBtn.x, self.deckTrashBtn.y, self.deckTrashBtn.w, self.deckTrashBtn.h, 6)
        love.graphics.setColor(1, 0.5, 0.5, 1)
        love.graphics.rectangle("line", self.deckTrashBtn.x, self.deckTrashBtn.y, self.deckTrashBtn.w, self.deckTrashBtn.h, 6)
        self:drawTrashIcon(self.deckTrashBtn.x + 22, self.deckTrashBtn.y + 18, 20, {1, 1, 1, 1})
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("CANCEL", self.deckTrashBtn.x + 36, self.deckTrashBtn.y + 10, self.deckTrashBtn.w - 40, "center")
    else
        local canTrash = removals > 0
        local btnBg = canTrash and (isTrashBtnHover and {0.35, 0.15, 0.18, 1} or {0.24, 0.11, 0.14, 0.95})
                                or {0.18, 0.18, 0.2, 0.7}
        local btnBorder = canTrash and (isTrashBtnHover and {0.95, 0.4, 0.4, 1} or {0.75, 0.28, 0.28, 1})
                                   or {0.4, 0.4, 0.45, 0.8}
        love.graphics.setColor(btnBg)
        love.graphics.rectangle("fill", self.deckTrashBtn.x, self.deckTrashBtn.y, self.deckTrashBtn.w, self.deckTrashBtn.h, 6)
        love.graphics.setColor(btnBorder)
        love.graphics.rectangle("line", self.deckTrashBtn.x, self.deckTrashBtn.y, self.deckTrashBtn.w, self.deckTrashBtn.h, 6)

        local iconColor = canTrash and (isTrashBtnHover and {1, 0.4, 0.4, 1} or {0.9, 0.35, 0.35, 1})
                                   or {0.5, 0.5, 0.5, 1}
        self:drawTrashIcon(self.deckTrashBtn.x + 22, self.deckTrashBtn.y + 18, 20, iconColor)

        love.graphics.setColor(canTrash and {1, 1, 1, 1} or {0.55, 0.55, 0.6, 1})
        local label = canTrash and ("Destroy (" .. removals .. ")") or "Destroy (0)"
        love.graphics.printf(label, self.deckTrashBtn.x + 36, self.deckTrashBtn.y + 10, self.deckTrashBtn.w - 40, "center")
    end

    if _G.PersistentState.deck then
        local cards = _G.PersistentState.deck:getCards()
        
        local cols = 4
        local cardW = 200
        local cardH = 240
        local spacingX = 40
        local spacingY = 30
        local startX = (VIRTUAL_WIDTH - (cols * cardW + (cols - 1) * spacingX)) / 2
        local startY = 96
        
        local maxPerPage = 8
        local totalPages = math.max(1, math.ceil(#cards / maxPerPage))
        self.deckPage = self.deckPage or 1
        if self.deckPage > totalPages then self.deckPage = totalPages end
        if self.deckPage < 1 then self.deckPage = 1 end
        
        local startIndex = (self.deckPage - 1) * maxPerPage + 1
        local endIndex = math.min(self.deckPage * maxPerPage, #cards)
        
        for i = startIndex, endIndex do
            local displayIndex = i - startIndex
            local card = cards[i]
            local col = (displayIndex % cols)
            local row = math.floor(displayIndex / cols)
            
            local cx = startX + col * (cardW + spacingX)
            local cy = startY + row * (cardH + spacingY)
            
            local isTargetedForDestruction = (self.destroyConfirmCard ~= nil and self.destroyConfirmCard == card)
            local isHovered = false
            if not self.destroyConfirmCard then
                isHovered = mx >= cx and mx <= cx + cardW and my >= cy and my <= cy + cardH
                if isHovered and self.deckTrashMode then
                    Cursor.wantHand = true
                end
            end

            if card.getCardDraw and card:getCardDraw() then
                card:getCardDraw():draw(cx, cy, cardW, cardH, isHovered and not self.deckTrashMode)
                
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
        
        self.prevPageBtn = { x = 120, y = VIRTUAL_HEIGHT - 90, w = 120, h = 40, label = "Prev Page" }
        self.nextPageBtn = { x = VIRTUAL_WIDTH - 240, y = VIRTUAL_HEIGHT - 90, w = 120, h = 40, label = "Next Page" }
        
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
        love.graphics.printf("Page " .. self.deckPage .. " / " .. totalPages, 0, VIRTUAL_HEIGHT - 75, VIRTUAL_WIDTH, "center")
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
    love.graphics.setColor(0.12, 0.12, 0.16, 0.98)
    love.graphics.rectangle("fill", dx, dy, dw, dh, 10)
    love.graphics.setColor(0.85, 0.25, 0.25, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", dx, dy, dw, dh, 10)
    love.graphics.setLineWidth(1)
    
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
    if isConfirmHover then Cursor.wantHand = true end
    love.graphics.setColor(isConfirmHover and {0.9, 0.22, 0.22, 1} or {0.75, 0.18, 0.18, 1})
    love.graphics.rectangle("fill", self.confirmDestroyBtn.x, self.confirmDestroyBtn.y, self.confirmDestroyBtn.w, self.confirmDestroyBtn.h, 6)
    love.graphics.setColor(1, 0.4, 0.4, 1)
    love.graphics.rectangle("line", self.confirmDestroyBtn.x, self.confirmDestroyBtn.y, self.confirmDestroyBtn.w, self.confirmDestroyBtn.h, 6)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("DESTROY", self.confirmDestroyBtn.x, self.confirmDestroyBtn.y + 12, self.confirmDestroyBtn.w, "center")
    
    -- Draw Cancel Button
    local isCancelHover = mx >= self.cancelDestroyBtn.x and mx <= self.cancelDestroyBtn.x + self.cancelDestroyBtn.w and my >= self.cancelDestroyBtn.y and my <= self.cancelDestroyBtn.y + self.cancelDestroyBtn.h
    if isCancelHover then Cursor.wantHand = true end
    love.graphics.setColor(isCancelHover and {0.4, 0.4, 0.46, 1} or {0.28, 0.28, 0.34, 1})
    love.graphics.rectangle("fill", self.cancelDestroyBtn.x, self.cancelDestroyBtn.y, self.cancelDestroyBtn.w, self.cancelDestroyBtn.h, 6)
    love.graphics.setColor(0.6, 0.6, 0.7, 1)
    love.graphics.rectangle("line", self.cancelDestroyBtn.x, self.cancelDestroyBtn.y, self.cancelDestroyBtn.w, self.cancelDestroyBtn.h, 6)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("CANCEL", self.cancelDestroyBtn.x, self.cancelDestroyBtn.y + 12, self.cancelDestroyBtn.w, "center")
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
        if iconCat == "buff" or iconCat == "blocker" or iconCat == "spell" or iconCat == "instant" then return false end

        local function checkType(col, name)
            if not col then return false end
            if type(col) == "table" then
                for _, t in ipairs(col) do if t == name then return true end end
                if col[name] == true then return true end
            elseif col == name then return true end
            return false
        end

        local bClass = payload.buildingClass
        if checkType(payload.types, "passive") or checkType(payload.types, "buff") or checkType(payload.types, "blocker") or
           checkType(cfg.types, "passive") or checkType(cfg.types, "buff") or checkType(cfg.types, "blocker") or
           checkType(c.types, "passive") or checkType(c.types, "buff") or checkType(c.types, "blocker") or
           (bClass and (checkType(bClass.types, "passive") or checkType(bClass.types, "buff") or checkType(bClass.types, "blocker"))) then
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
    if c.upgradeCosts and c.upgradeCosts[nextTier] then
        return c.upgradeCosts[nextTier]
    end
    return CardUpgradeConfig.DEFAULT_COSTS[nextTier]
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
    love.graphics.setColor(0, 0, 0, 0.92)
    love.graphics.rectangle("fill", 100, 45, VIRTUAL_WIDTH - 200, VIRTUAL_HEIGHT - 90, 10)
    love.graphics.setColor(0.3, 0.85, 0.6, 1)
    love.graphics.rectangle("line", 100, 45, VIRTUAL_WIDTH - 200, VIRTUAL_HEIGHT - 90, 10)
    
    -- 2. Header: Title and Resource Balances
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("UPGRADE CARDS", 100, 55, VIRTUAL_WIDTH - 200, "center")
    
    local cash = CardUpgradeConfig.Economy.getResource("cash") or CardUpgradeConfig.Economy.getResource("gold")
    local mats = CardUpgradeConfig.Economy.getResource("Upgrade Material")
    love.graphics.setColor(1, 0.85, 0.2, 1)
    love.graphics.printf("Cash: $" .. cash, 120, 55, 200, "left")
    love.graphics.setColor(0.3, 0.85, 1, 1)
    love.graphics.printf("Upgrade Material: " .. mats, VIRTUAL_WIDTH - 320, 55, 200, "right")

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
                
                -- Display exact modular costs (Gold and Upgrade Material or specific items)
                local costParts = {}
                if cost then
                    if cost.gold or cost.cash then
                        table.insert(costParts, "$" .. (cost.gold or cost.cash))
                    end
                    for resName, amount in pairs(cost) do
                        if resName ~= "gold" and resName ~= "cash" then
                            table.insert(costParts, amount .. " " .. resName)
                        end
                    end
                end
                local costStr = #costParts > 0 and table.concat(costParts, ", ") or "Free"
                
                local isBtnHover = mx >= cx and mx <= cx + cardW and my >= btnY and my <= btnY + btnH
                if isBtnHover then Cursor.wantHand = true end
                
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
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("PREPARATION PHASE", 0, 20, VIRTUAL_WIDTH, "center")
    
    local hp = _G.PersistentState and _G.PersistentState.baseHP or 200
    local cash = _G.PersistentState and _G.PersistentState.cash or 0
    local shopLevel = _G.PersistentState and _G.PersistentState.shopLevel or 1
    local shopXP = _G.PersistentState and _G.PersistentState.shopXP or 0
    
    love.graphics.setColor(0.8, 0.2, 0.2, 1)
    love.graphics.printf("Base HP: " .. hp .. " / 200", 20, 20, 200, "left")
    
    love.graphics.setColor(0.2, 0.8, 0.2, 1)
    love.graphics.printf("Cash: $" .. cash, 20, 45, 200, "left")
    
    love.graphics.setColor(0.8, 0.2, 0.8, 1)
    love.graphics.printf("Shop Level: " .. shopLevel, 20, 70, 200, "left")
    
    local upgradeMats = (_G.PersistentState and _G.PersistentState.materials and _G.PersistentState.materials["Upgrade Material"]) or 0
    love.graphics.setColor(0.3, 0.85, 1, 1)
    love.graphics.printf("Materials: " .. upgradeMats, 20, 115, 200, "left")
    
    local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")
    local removals = CardUpgradeConfig.Economy.getCardRemovals()
    self:drawTrashIcon(150, 122, 18, {0.9, 0.35, 0.35, 1})
    love.graphics.setColor(0.9, 0.45, 0.45, 1)
    love.graphics.printf("Removals: " .. removals, 165, 115, 150, "left")
    
    -- Draw XP circles
    if shopLevel < 10 then
        local reqXP = self:getRequiredXP(shopLevel)
        local startX = 20
        local cy = 95
        local radius = 6
        local spacing = 18
        
        for i = 1, reqXP do
            local drawX = startX + (i - 1) * spacing
            if i <= shopXP then
                love.graphics.setColor(0.8, 0.2, 0.8, 1)
                love.graphics.circle("fill", drawX, cy, radius)
            else
                love.graphics.setColor(0.8, 0.2, 0.8, 1)
                love.graphics.circle("line", drawX, cy, radius)
                love.graphics.setColor(0.2, 0.05, 0.2, 1)
                love.graphics.circle("fill", drawX, cy, radius - 1)
            end
        end
    else
        love.graphics.setColor(0.8, 0.2, 0.8, 1)
        love.graphics.printf("MAX LEVEL", 20, 90, 200, "left")
    end
    
    self:drawShop(mx, my)
    
    self:drawButton(self.rerollButton, mx, my)
    self:drawButton(self.buyXPButton, mx, my)
    
    self:drawButton(self.startButton, mx, my)
    self:drawButton(self.deckButton, mx, my)
    self:drawButton(self.upgradeCardsButton, mx, my)
    self:drawButton(self.previewBattlesButton, mx, my)
    
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

    if self.showUpgradeChoice then
        self:drawUpgradeChoice(mx, my)
        Cursor.wantHand = true
    end

    love.mouse.setCursor(Cursor.wantHand and self.handCursor or self.arrowCursor)
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
    local cardH = 380
    local spacing = 40
    local isSingleCard = (#(displayedChoices or {}) == 1)
    local totalW = isSingleCard and cardW or ((#(displayedChoices or {}) * cardW) + ((#(displayedChoices or {}) - 1) * spacing))
    local startX = (VIRTUAL_WIDTH - totalW) / 2
    local startY = 125
    
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
        local accentColor = choice.isMilestone and {1, 0.2, 0.2, 1}
            or (isSafe and {0.2, 0.9, 0.4, 1} or ((mult < 1.6) and {1, 0.8, 0.2, 1} or {1, 0.35, 0.35, 1}))
        
        -- Card background
        love.graphics.setColor(0.08, 0.08, 0.12, 0.95)
        love.graphics.rectangle("fill", cx, cy, cardW, cardH, 12)
        
        -- Card border: Always highlighted in danger color
        love.graphics.setColor(accentColor)
        love.graphics.setLineWidth(isHovered and 3 or 2)
        love.graphics.rectangle("line", cx, cy, cardW, cardH, 12)
        
        -- Threat / Major Battle Badge
        if choice.isMilestone then
            if not self.majorBattleFont then
                self.majorBattleFont = love.graphics.newFont(26)
            end
            local oldFont = love.graphics.getFont()
            love.graphics.setFont(self.majorBattleFont)
            -- Solid vibrant red text
            love.graphics.setColor(1, 0.2, 0.2, 1)
            love.graphics.printf("MAJOR BATTLE", cx, cy + 20, cardW, "center")
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
            local rawId = enemy.id or (enemy.displayName ~= "???" and enemy.displayName)
            local canonicalId = EnemyRegistry:canonicalEnemyId(rawId) or rawId
            local isDiscovered = false
            if canonicalId then
                if _G.PersistentState and _G.PersistentState.discoveredEnemies then
                    isDiscovered = _G.PersistentState.discoveredEnemies[canonicalId] or (rawId and _G.PersistentState.discoveredEnemies[rawId])
                end
                if not isDiscovered and EnemyRegistry.discoveredEnemiesMap then
                    isDiscovered = EnemyRegistry.discoveredEnemiesMap[canonicalId] or (rawId and EnemyRegistry.discoveredEnemiesMap[rawId])
                end
            end
            if not isDiscovered and enemy.displayName and enemy.displayName ~= "???" then
                isDiscovered = true
            end

            if not isDiscovered then
                love.graphics.setColor(0.6, 0.6, 0.6, 1)
                love.graphics.printf("• ??? (Undiscovered)", cx + 25, ey, cardW - 50, "left")
            else
                love.graphics.setColor(1, 0.45, 0.45, 1)
                local displayName = canonicalId or rawId or enemy.displayName
                love.graphics.printf("• " .. displayName, cx + 25, ey, cardW - 50, "left")
            end
            ey = ey + 22
        end
        
        -- Rewards Section
        local ry = cy + 240
        love.graphics.setColor(1, 0.85, 0.3, 1)
        love.graphics.printf("Guaranteed Rewards:", cx + 20, ry, cardW - 40, "left")
        love.graphics.setColor(0.7, 0.6, 0.2, 0.5)
        love.graphics.line(cx + 20, ry + 20, cx + cardW - 20, ry + 20)
        
        ry = ry + 30
        for _, reward in ipairs(choice.rewards or {}) do
            love.graphics.setColor(0.35, 1, 0.6, 1)
            love.graphics.printf("• " .. (reward.description or reward.name), cx + 25, ry, cardW - 50, "left")
            ry = ry + 22
        end
        
        if isLaunchMode then
            -- Pre-battle launch mode: Clicking directly chooses and engages this battle!
            local btnW = cardW - 40
            local btnH = 40
            local btnX = cx + 20
            local btnY = cy + cardH - 55
            local btnHover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
            if btnHover then Cursor.wantHand = true end

            love.graphics.setColor(btnHover and {0.2, 0.7, 0.35, 1} or {0.12, 0.5, 0.25, 1})
            love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 8)
            love.graphics.setColor(0.4, 1, 0.6, 1)
            love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 8)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf("ENGAGE THIS BATTLE", btnX, btnY + 12, btnW, "center")

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
    
    love.graphics.setColor(closeHover and {0.3, 0.3, 0.38, 1} or {0.2, 0.2, 0.28, 1})
    love.graphics.rectangle("fill", closeBtnX, closeBtnY, closeBtnW, closeBtnH, 8)
    love.graphics.setColor(0.6, 0.6, 0.8, 1)
    love.graphics.rectangle("line", closeBtnX, closeBtnY, closeBtnW, closeBtnH, 8)
    love.graphics.setColor(1, 1, 1, 1)
    local closeText = isLaunchMode and "CANCEL / BACK TO PREPARATION" or "CLOSE SCOUTING REPORT"
    love.graphics.printf(closeText, closeBtnX, closeBtnY + 11, closeBtnW, "center")
    self.closeLevelSelectBtn = { x = closeBtnX, y = closeBtnY, w = closeBtnW, h = closeBtnH }
end

function preparation_scene:drawUpgradeChoice(mx, my)
    -- Dark overlay
    love.graphics.setColor(0.02, 0.02, 0.05, 0.92)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    
    -- Title
    love.graphics.setColor(1, 0.8, 0.2, 1)
    love.graphics.printf("MILESTONE BATTLE COMPLETE!", 0, 80, VIRTUAL_WIDTH, "center")
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.printf("Choose a major permanent upgrade to your arsenal:", 0, 115, VIRTUAL_WIDTH, "center")
    
    for _, choice in ipairs(self.upgradeChoices) do
        local isHovered = mx >= choice.x and mx <= choice.x + choice.w and my >= choice.y and my <= choice.y + choice.h
        if isHovered then Cursor.wantHand = true end
        
        -- Panel fill
        love.graphics.setColor(isHovered and choice.hoverColor or choice.color)
        love.graphics.rectangle("fill", choice.x, choice.y, choice.w, choice.h, 12, 12)
        
        -- Panel border
        love.graphics.setColor(choice.borderColor)
        love.graphics.setLineWidth(isHovered and 3 or 1.5)
        love.graphics.rectangle("line", choice.x, choice.y, choice.w, choice.h, 12, 12)
        love.graphics.setLineWidth(1)
        
        -- Title text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(choice.title, choice.x + 10, choice.y + 40, choice.w - 20, "center")
        
        -- Separator line
        love.graphics.setColor(choice.borderColor[1], choice.borderColor[2], choice.borderColor[3], 0.5)
        love.graphics.line(choice.x + 20, choice.y + 80, choice.x + choice.w - 20, choice.y + 80)
        
        -- Description text
        love.graphics.setColor(0.95, 0.95, 0.95, 1)
        love.graphics.printf(choice.desc, choice.x + 20, choice.y + 130, choice.w - 40, "center")
    end
end

function preparation_scene:mousepressed(x, y, button)
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
    
    if self.showUpgradeChoice then
        if button == 1 then
            for _, choice in ipairs(self.upgradeChoices) do
                if x >= choice.x and x <= choice.x + choice.w and y >= choice.y and y <= choice.y + choice.h then
                    if choice.id == "card_draw" then
                        _G.PersistentState.startingHandSize = (_G.PersistentState.startingHandSize or 4) + 1
                        _G.PersistentState.waveCompleteDrawSize = (_G.PersistentState.waveCompleteDrawSize or 4) + 1
                    elseif choice.id == "tokens" then
                        _G.PersistentState.startingTokens = (_G.PersistentState.startingTokens or 3) + 1
                        _G.PersistentState.incomeTokens = (_G.PersistentState.incomeTokens or 3) + 1
                    elseif choice.id == "slots" then
                        _G.PersistentState.startBattleExtraSlotsUnlocked = (_G.PersistentState.startBattleExtraSlotsUnlocked or 0) + 1
                    end
                    self.showUpgradeChoice = false
                    break
                end
            end
        end
        return
    end
    
    if button ~= 1 then return end
    
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
                    self.scene_manager.switch("game")
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
            local maxPerPage = 8
            local startIndex = (self.deckPage - 1) * maxPerPage + 1
            local endIndex = math.min(self.deckPage * maxPerPage, #cards)
            local cols = 4
            local cardW = 200
            local cardH = 240
            local spacingX = 40
            local spacingY = 30
            local startX = (VIRTUAL_WIDTH - (cols * cardW + (cols - 1) * spacingX)) / 2
            local startY = 96

            for i = startIndex, endIndex do
                local displayIndex = i - startIndex
                local card = cards[i]
                local col = (displayIndex % cols)
                local row = math.floor(displayIndex / cols)
                local cx = startX + col * (cardW + spacingX)
                local cy = startY + row * (cardH + spacingY)

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
    
    btn = self.upgradeCardsButton
    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
        self.viewingUpgrades = true
        self.viewingDeck = false
        return
    end
    
    btn = self.rerollButton
    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
        if (_G.PersistentState.cash or 0) >= 20 then
            _G.PersistentState.cash = _G.PersistentState.cash - 20
            self:rollShop()
        end
        return
    end
    

    btn = self.buyXPButton
    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
        if (_G.PersistentState.cash or 0) >= 30 and (_G.PersistentState.shopLevel or 1) < 10 then
            _G.PersistentState.cash = _G.PersistentState.cash - 30
            self:addShopXP(1)
        end
        return
    end
    
    for _, item in ipairs(self.shopItems) do
        if not item.purchased and x >= item.x and x <= item.x + item.w and y >= item.y and y <= item.y + item.h then
            if (_G.PersistentState.cash or 0) >= item.cost then
                _G.PersistentState.cash = _G.PersistentState.cash - item.cost
                item.purchased = true
                
                local qty = 1
                item.card.quantity = qty
                _G.PersistentState.deck:addCard(item.card)
            end
        end
    end
end

function preparation_scene:mousereleased(x, y, button)
    if paused == 1 and self.settings then
        self.settings:mousereleased(x, y, button)
    end
end

function preparation_scene:keypressed(key)
    if key == "escape" or key == "p" then
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

    if key == "return" and not self.viewingDeck and not self.viewingUpgrades then
        self.scene_manager.switch("game")
    end
end

return preparation_scene
