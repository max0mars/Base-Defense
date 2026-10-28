local menu_scene = {}
menu_scene.__index = menu_scene
local scene = require("Scenes.scene") -- Import the base scene class
local game = require("Game.Core.GameManager")
local SettingsPanel = require("Game.GUI.SettingsPanel")
local Cursor = require("Game.GUI.Cursor")
local PlayerDeck = require("Game.Cards.PlayerDeck")
local Card = require("Game.Cards.Card")
local ExecutionType = require("Game.Cards.ExecutionType")
local DevMode = require("Game.Dev.DevMode")
local SaveGame = require("Game.Core.SaveGame")
local Neon = require("Game.GUI.Neon")


-- Starting deck creation has been moved to individual Main Turret classes.

setmetatable(menu_scene, { __index = scene })

-- Vertical offset to center the main-menu title banner on the 720 canvas.
local MENU_OFFSET_Y = 80

--- Fresh persistent state for a new run.
local function newRunState()
    return {
        baseHP = 200,
        cash = 0,
        deck = nil, -- Will be set in new_game_scene
        shopLevel = 1, -- the traveling merchant's level (raised by investing)
        scoutingLevel = 1,
        upgradePurchases = {}, -- major upgrade id -> times bought
        globalDifficulty = 1,
        battlesCompleted = 0,
        damageTracker = {}, -- level -> enemy name -> damage it did to the base
        totalDamageDealt = 0, -- damage dealt to enemies this run
        totalKills = 0,
        activeMutations = {},
        discoveredEnemies = { ["Grunt"] = true, ["Basic"] = true },
        startingTokens = 3,
        startingHandSize = 4,
        waveCompleteDrawSize = 4,
        incomeTokens = 3,
        startBattleExtraSlotsUnlocked = 0,
        maxMana = 100,
        manaRegenPerWave = 15,
        upgradeCostTokens = 20,
        upgradeCostHand = 20,
        upgradeCostIncome = 20,
        materials = { ["Card Removal"] = 2 }, -- Upgrade materials are granted in new_game_scene
        cardRemovals = 2
    }
end

--- Starts a new run (optionally in developer mode) at main turret selection.
function menu_scene:startRun(devMode)
    _G.PersistentState = newRunState()
    if devMode then DevMode.enable() end
    game.testingMode = false
    self.scene_manager.switch("new_game")
end

--- Starts a normal run, asking first if that would replace a saved one.
function menu_scene:requestNewRun()
    if SaveGame.exists() then
        self.confirmingNewRun = true
    else
        self:startRun(false)
    end
end

--- Resumes the saved run where it was saved (preparation or the start of a battle).
function menu_scene:continueRun()
    local scene = SaveGame.load()
    if not scene then
        self.notice = "Your saved run couldn't be loaded."
        self:buildMainButtons(false)
        return
    end
    game.testingMode = false
    self.scene_manager.switch(scene)
end

function menu_scene:buildMainButtons(hasSave)
    local cx = (VIRTUAL_WIDTH - 240) / 2
    local buttons = {
        -- Shown greyed out without a save, so players know runs can be continued
        { label = "CONTINUE", action = "continue", disabled = not hasSave,
          color = {0.45, 0.32, 0.08, 1}, hoverColor = {0.62, 0.45, 0.12, 1}, borderColor = {0.95, 0.75, 0.3, 1} },
        { label = "NEW GAME", action = "play",
          color = {0.1, 0.45, 0.25, 1}, hoverColor = {0.18, 0.7, 0.4, 1}, borderColor = {0.3, 0.9, 0.5, 1} },
        { label = "TUTORIAL", action = "tutorial",
          color = {0.3, 0.2, 0.55, 1}, hoverColor = {0.48, 0.32, 0.8, 1}, borderColor = {0.7, 0.5, 1, 1} },
        { label = "SETTINGS", action = "settings",
          color = {0.18, 0.32, 0.45, 1}, hoverColor = {0.28, 0.5, 0.7, 1}, borderColor = {0.4, 0.7, 0.95, 1} },
        { label = "QUIT GAME", action = "quit", gap = 25,
          color = {0.3, 0.18, 0.2, 1}, hoverColor = {0.5, 0.28, 0.3, 1}, borderColor = {0.9, 0.5, 0.5, 1} },
    }
    local y = 260
    for _, btn in ipairs(buttons) do
        y = y + (btn.gap or 0)
        btn.x, btn.y, btn.w, btn.h, btn.type = cx, y, 240, 45, "main"
        y = y + 55
    end
    self.mainButtons = buttons
end

function menu_scene:load()
    love.mouse.setVisible(true)
    self.handCursor = love.mouse.getSystemCursor("hand")
    self.arrowCursor = love.mouse.getSystemCursor("arrow")
    self.page = "main" -- "main" | "settings"
    self.notice = nil
    self.confirmingNewRun = false

    self:buildMainButtons(SaveGame.exists())
    local mx = VIRTUAL_WIDTH / 2
    self.confirmButtons = {
        { x = mx - 190, y = 400, w = 180, h = 45, label = "START NEW RUN", action = "confirm",
          color = {0.4, 0.18, 0.2, 1}, hoverColor = {0.6, 0.28, 0.3, 1}, borderColor = {0.95, 0.45, 0.45, 1} },
        { x = mx + 10, y = 400, w = 180, h = 45, label = "CANCEL", action = "cancel",
          color = {0.18, 0.32, 0.45, 1}, hoverColor = {0.28, 0.5, 0.7, 1}, borderColor = {0.4, 0.7, 0.95, 1} },
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

function menu_scene:drawMainButtons(mx, my, buttons)
    for _, btn in ipairs(buttons or self.mainButtons) do
        local isHovered = not btn.disabled and mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h
        if isHovered then Cursor.wantHand = true end
        Neon.button(btn, { hovered = isHovered, disabled = btn.disabled })
    end
end

function menu_scene:draw()
    Cursor.reset() -- hover flag re-set by buttons / settings panel below

    -- Subtle tactical grid background (both pages).
    love.graphics.setColor(0.1, 0.2, 0.35, 0.3)
    for gx = 0, VIRTUAL_WIDTH, 40 do love.graphics.line(gx, 0, gx, VIRTUAL_HEIGHT) end
    for gy = 0, VIRTUAL_HEIGHT, 40 do love.graphics.line(0, gy, VIRTUAL_WIDTH, gy) end

    local mx, my = love.mouse.getPosition()

    if self.page == "settings" then
        self.settings:draw()
    else
        -- Neon title banner + glowing BASE DEFENSE.
        love.graphics.setColor(0.0, 0.5, 0.8, 0.07)
        love.graphics.rectangle("fill", 0, 65 + MENU_OFFSET_Y, VIRTUAL_WIDTH, 65)
        Neon.line(0, 65 + MENU_OFFSET_Y, VIRTUAL_WIDTH, 65 + MENU_OFFSET_Y, Neon.CYAN, 2)
        Neon.line(0, 130 + MENU_OFFSET_Y, VIRTUAL_WIDTH, 130 + MENU_OFFSET_Y, Neon.MAGENTA, 2)
        Neon.title("BASE DEFENSE", 0, 75 + MENU_OFFSET_Y, VIRTUAL_WIDTH, "center", Neon.hot(Neon.CYAN, 0.35), 2.5)

        love.graphics.setColor(0.55, 0.6, 0.7, 1)
        love.graphics.printf("Protect the Core. Upgrade your Arsenal.", 0, 148 + MENU_OFFSET_Y, VIRTUAL_WIDTH, "center")

        if self.confirmingNewRun then
            Neon.panel(VIRTUAL_WIDTH / 2 - 220, 290, 440, 175, Neon.RED)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf("Start a new run?\nYour saved run will be lost.", VIRTUAL_WIDTH / 2 - 200, 320, 400, "center")
            self:drawMainButtons(mx, my, self.confirmButtons)
        else
            self:drawMainButtons(mx, my)
        end
        if self.notice then
            love.graphics.setColor(0.95, 0.55, 0.45, 1)
            love.graphics.printf(self.notice, 0, 600, VIRTUAL_WIDTH, "center")
        end
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

    if button == 1 and self.confirmingNewRun then
        for _, btn in ipairs(self.confirmButtons) do
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                self.confirmingNewRun = false
                if btn.action == "confirm" then
                    SaveGame.delete()
                    self:startRun(false)
                end
                break
            end
        end
        return
    end

    if button == 1 then
        for _, btn in ipairs(self.mainButtons) do
            if not btn.disabled and x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                if btn.action == "continue" then
                    self:continueRun()
                elseif btn.action == "play" then
                    self:requestNewRun()
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

    if self.confirmingNewRun then
        if key == "escape" then self.confirmingNewRun = false end
        return
    end

    if key == "return" then
        self:requestNewRun()
    elseif key == "f1" then
        self:startRun(true)
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
