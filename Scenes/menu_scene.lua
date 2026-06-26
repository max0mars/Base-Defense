local menu_scene = {}
menu_scene.__index = menu_scene
local scene = require("Scenes.scene") -- Import the base scene class
local game = require("Game.Core.GameManager")
local SettingsPanel = require("Game.GUI.SettingsPanel")
local Cursor = require("Game.GUI.Cursor")
local PlayerDeck = require("Game.Cards.PlayerDeck")
local Card = require("Game.Cards.Card")
local ExecutionType = require("Game.Cards.ExecutionType")
local Sentry = require("Buildings.Turrets.Sentry")
local Blaster = require("Buildings.Turrets.Blaster")
local AutoCannon = require("Buildings.Turrets.AutoCannon")
local ShotgunTurret = require("Buildings.Turrets.ShotgunTurret")
local HeavyGun = require("Buildings.Turrets.HeavyGun")

-- Starting deck creation has been moved to individual Main Turret classes.

setmetatable(menu_scene, { __index = scene })

-- Vertical offset to center the main-menu title banner on the 720 canvas.
local MENU_OFFSET_Y = 80

function menu_scene:load()
    love.mouse.setVisible(true)
    self.handCursor = love.mouse.getSystemCursor("hand")
    self.arrowCursor = love.mouse.getSystemCursor("arrow")
    self.page = "main" -- "main" | "settings"

    local cx = (VIRTUAL_WIDTH - 240) / 2
    self.mainButtons = {
        { x = cx, y = 290, w = 240, h = 45, label = "PLAY GAME", type = "main", action = "play",
          color = {0.1, 0.45, 0.25, 1}, hoverColor = {0.18, 0.7, 0.4, 1}, borderColor = {0.3, 0.9, 0.5, 1} },
        { x = cx, y = 345, w = 240, h = 45, label = "TUTORIAL", type = "main", action = "tutorial",
          color = {0.3, 0.2, 0.55, 1}, hoverColor = {0.48, 0.32, 0.8, 1}, borderColor = {0.7, 0.5, 1, 1} },
        { x = cx, y = 400, w = 240, h = 45, label = "SETTINGS", type = "main", action = "settings",
          color = {0.18, 0.32, 0.45, 1}, hoverColor = {0.28, 0.5, 0.7, 1}, borderColor = {0.4, 0.7, 0.95, 1} },
        { x = cx, y = 480, w = 240, h = 45, label = "QUIT GAME", type = "main", action = "quit",
          color = {0.3, 0.18, 0.2, 1}, hoverColor = {0.5, 0.28, 0.3, 1}, borderColor = {0.9, 0.5, 0.5, 1} },
    }

    self.settings = SettingsPanel:new({
        title = "SETTINGS",
        bottomButtons = {
            { label = "BACK", action = "back",
              color = {0.3, 0.2, 0.22, 1}, hoverColor = {0.5, 0.32, 0.34, 1}, borderColor = {0.9, 0.55, 0.55, 1} },
        },
    })

    self.confirmation = require("Game.GUI.ConfirmationUI"):new({inputHandler = {}})
end

function menu_scene:update(dt)
    self.confirmation:update(dt)
    if self.page == "settings" then self.settings:update(dt) end
end

function menu_scene:drawMainButtons(mx, my)
    for _, btn in ipairs(self.mainButtons) do
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
end

function menu_scene:draw()
    Cursor.reset() -- hover flag re-set by buttons / settings panel below

    -- Subtle tactical grid background (both pages).
    love.graphics.setColor(0.15, 0.15, 0.18, 0.35)
    for gx = 0, VIRTUAL_WIDTH, 40 do love.graphics.line(gx, 0, gx, VIRTUAL_HEIGHT) end
    for gy = 0, VIRTUAL_HEIGHT, 40 do love.graphics.line(0, gy, VIRTUAL_WIDTH, gy) end

    local mx, my = love.mouse.getPosition()

    if self.page == "settings" then
        self.settings:draw()
    else
        -- Glowing title banner + BASE DEFENSE.
        love.graphics.setColor(0.12, 0.25, 0.4, 0.15)
        love.graphics.rectangle("fill", 0, 65 + MENU_OFFSET_Y, VIRTUAL_WIDTH, 65)
        love.graphics.setColor(0.2, 0.45, 0.7, 0.5)
        love.graphics.line(0, 65 + MENU_OFFSET_Y, VIRTUAL_WIDTH, 65 + MENU_OFFSET_Y)
        love.graphics.line(0, 130 + MENU_OFFSET_Y, VIRTUAL_WIDTH, 130 + MENU_OFFSET_Y)

        love.graphics.push()
        love.graphics.translate(0, MENU_OFFSET_Y)
        love.graphics.scale(2.5, 2.5)
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.printf("BASE DEFENSE", 1, 31, VIRTUAL_WIDTH / 2.5, "center")
        love.graphics.setColor(0.3, 0.7, 1, 1)
        love.graphics.printf("BASE DEFENSE", 0, 30, VIRTUAL_WIDTH / 2.5, "center")
        love.graphics.pop()

        love.graphics.setColor(0.55, 0.6, 0.7, 1)
        love.graphics.printf("Protect the Core. Upgrade your Arsenal.", 0, 148 + MENU_OFFSET_Y, VIRTUAL_WIDTH, "center")

        self:drawMainButtons(mx, my)
    end

    self.confirmation:draw()

    -- Swap the OS cursor to a hand over clickable elements.
    love.mouse.setCursor(Cursor.wantHand and self.handCursor or self.arrowCursor)
end

function menu_scene:mousepressed(x, y, button)
    if self.confirmation:mousepressed(x, y, button) then return true end

    if self.page == "settings" then
        local action = self.settings:mousepressed(x, y, button)
        if action == "back" then self.page = "main" end
        return
    end

    if button == 1 then
        for _, btn in ipairs(self.mainButtons) do
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                if btn.action == "play" then
                    _G.PersistentState = { 
                        baseHP = 200, 
                        cash = 0, 
                        deck = nil, -- Will be set in new_game_scene
                        globalDifficulty = 1,
                        battlesCompleted = 0,
                        damageTracker = {},
                        activeMutations = {},
                        discoveredEnemies = { ["Basic"] = true },
                        startingTokens = 3,
                        startingHandSize = 4,
                        waveCompleteDrawSize = 4,
                        incomeTokens = 3,
                        startBattleExtraSlotsUnlocked = 0,
                        upgradeCostTokens = 20,
                        upgradeCostHand = 20,
                        upgradeCostIncome = 20
                    }
                    game.testingMode = false
                    self.scene_manager.switch("new_game")
                elseif btn.action == "tutorial" then
                    self.scene_manager.switch("tutorial")
                elseif btn.action == "settings" then
                    self.page = "settings"
                elseif btn.action == "quit" then
                    love.event.quit()
                end
                break
            end
        end
    end
end

function menu_scene:keypressed(key)
    if self.page == "settings" then
        if key == "escape" then self.page = "main" end
        return
    end

    if key == "return" then
        _G.PersistentState = { 
            baseHP = 200, 
            cash = 0, 
            deck = nil, -- Will be set in new_game_scene
            shopLevel = 1,
            shopXP = 0,
            globalDifficulty = 1,
            battlesCompleted = 0,
            damageTracker = {},
            activeMutations = {},
            discoveredEnemies = { ["Basic"] = true },
            startingTokens = 3,
            startingHandSize = 4,
            waveCompleteDrawSize = 4,
            incomeTokens = 3,
            startBattleExtraSlotsUnlocked = 0,
            upgradeCostTokens = 20,
            upgradeCostHand = 20,
            upgradeCostIncome = 20
        }
        game.testingMode = false
        self.scene_manager.switch("new_game")
    elseif key == "t" then
        game.testingMode = true
        self.scene_manager.switch("game")
    elseif key == "escape" then
        love.event.quit()
    end
end

function menu_scene:mousereleased(x, y, button)
    if self.page == "settings" then self.settings:mousereleased(x, y, button) end
end

return menu_scene
