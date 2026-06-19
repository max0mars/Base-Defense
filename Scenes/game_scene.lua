local game_scene = {
    
}
game_scene.__index = game_scene
local scene = require("Scenes.scene") -- Import the base scene class
setmetatable(game_scene, { __index = scene })

local game = require("Game.Core.GameManager") -- Import the game module
local SettingsPanel = require("Game.GUI.SettingsPanel")
local Cursor = require("Game.GUI.Cursor")
local Blocker = require("Buildings.Blockers.Blocker")

function game_scene:load()
    local isTesting = game.testingMode
    game:load(nil, isTesting)
    game.time_mul = 1 -- game starts at normal speed
    paused = 0
    self.gameover = false
    if AUDIO and not AUDIO:isPlayingMusic() then AUDIO:playMusic() end

    -- In-game pause menu: the shared settings panel with Resume / Exit.
    self.settings = SettingsPanel:new({
        title = "PAUSED",
        bottomButtons = {
            { label = "RESUME", action = "resume",
              color = {0.1, 0.45, 0.25, 1}, hoverColor = {0.18, 0.7, 0.4, 1}, borderColor = {0.3, 0.9, 0.5, 1} },
            { label = "EXIT", action = "exit",
              color = {0.4, 0.18, 0.2, 1}, hoverColor = {0.6, 0.28, 0.3, 1}, borderColor = {0.95, 0.45, 0.45, 1} },
        },
    })
end

function game_scene:mousepressed(x, y, button)
    if self.showingSummary then
        self.showingSummary = false
        self.scene_manager.switch("preparation", true)
        return
    end

    if paused == 1 then
        local action = self.settings:mousepressed(x, y, button)
        if action == "resume" then
            paused = 0
        elseif action == "exit" then
            paused = 0
            self.scene_manager.switch("menu")
        end
        return
    end
    game.inputHandler:mousepressed(x, y, button) -- Route through InputHandler
end

function game_scene:mousereleased(x, y, button)
    if paused == 1 then
        self.settings:mousereleased(x, y, button)
        return
    end
    if game.inputHandler.mousereleased then
        game.inputHandler:mousereleased(x, y, button)
    end
end

function game_scene:update(dt)
    if paused == 1 then
        self.settings:update(dt)
    end
    if game:isState("gameover") and not self.gameover then
        self.gameover = true
        self.scene_manager.switch("gameover")
    end

    if game.battleComplete then
        game.battleComplete = false
        self.showingSummary = true
        self.summaryDamage = game.damageTakenThisBattle or 0
        self.summaryIncome = game.battleReward or 0
        self.summaryPerfectBonus = (self.summaryDamage == 0) and 25 or 0
        
        local currentCash = _G.PersistentState and _G.PersistentState.cash or 0
        local cashBeforeBattle = currentCash - self.summaryIncome
        if cashBeforeBattle < 0 then cashBeforeBattle = 0 end
        self.summaryInterest = math.floor(cashBeforeBattle * 0.10 + 0.5)
        
        if _G.PersistentState then
            _G.PersistentState.cash = currentCash + self.summaryInterest + self.summaryPerfectBonus
            self.summaryTotalCash = _G.PersistentState.cash
        else
            self.summaryTotalCash = 0
        end
        return
    end
    
    if self.showingSummary then return end

    local effectiveDt = dt * game.time_mul
    
    -- Freeze game if paused or a modal menu is active
    if paused == 1 or
       (game.gui.codex and game.gui.codex.isActive) or
       (game.rewardSystem and game.rewardSystem.isActive) or
       (game.specialUpgradeManager and game.specialUpgradeManager.isActive) or
       (game.gui.mutation and game.gui.mutation.isActive) or
       (game.gui.confirmation and game.gui.confirmation.active) or
       (game.gui.enemySpawner and game.gui.enemySpawner.isActive) or
       (game.gui.itemPicker and game.gui.itemPicker.isActive) then
        effectiveDt = 0
    end
    
    if game.rewardSystem and game.rewardSystem.isActive then
        game.rewardSystem:update(dt)
    end
    
    game:update(effectiveDt)
end

function game_scene:draw()
    game:draw()
    if paused == 1 then
        love.graphics.setColor(0, 0, 0, 0.6) -- Dim overlay behind the pause menu
        love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
        self.settings:draw()
        -- Real OS hand/arrow cursor over the pause menu (matches the main menu).
        Cursor.applyOS()
    end
    if self.showingSummary then
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("BATTLE COMPLETE", 0, VIRTUAL_HEIGHT / 2 - 100, VIRTUAL_WIDTH, "center")
        
        love.graphics.printf("Damage Taken: " .. self.summaryDamage, 0, VIRTUAL_HEIGHT / 2 - 50, VIRTUAL_WIDTH, "center")
        love.graphics.setColor(0.2, 0.8, 0.2, 1)
        love.graphics.printf("Income: +$" .. self.summaryIncome, 0, VIRTUAL_HEIGHT / 2 - 20, VIRTUAL_WIDTH, "center")
        love.graphics.printf("Perfect Bonus: +$" .. self.summaryPerfectBonus, 0, VIRTUAL_HEIGHT / 2 + 10, VIRTUAL_WIDTH, "center")
        love.graphics.printf("Interest: +$" .. self.summaryInterest, 0, VIRTUAL_HEIGHT / 2 + 40, VIRTUAL_WIDTH, "center")
        
        love.graphics.setColor(0.2, 1.0, 0.2, 1)
        love.graphics.printf("Total Cash: $" .. self.summaryTotalCash, 0, VIRTUAL_HEIGHT / 2 + 80, VIRTUAL_WIDTH, "center")
        
        love.graphics.setColor(0.6, 0.6, 0.6, 1)
        love.graphics.printf("Click anywhere to continue", 0, VIRTUAL_HEIGHT / 2 + 120, VIRTUAL_WIDTH, "center")
    end
    
    -- love.graphics.print("Tokens: " .. game.tokens, 10, 10)
    -- --love.graphics.print("Time Multiplier: " .. string.format("%.1f", time_mul) .. "x", 10, 30)
    -- love.graphics.print("Wave: " .. game.wave, 10, 30)
    -- --love.graphics.print("Game State: " .. game.state, 10, 70)
    -- --love.graphics.print("Wave State: " .. game.WaveSpawner.waveState, 200, 10)
    -- --love.graphics.print("Selected Turret: " .. (game.inputHandler.selectedTurret and game.inputHandler.selectedTurret.id or "None"), 200, 30)
    -- --love.graphics.print("Spawn Rate: " .. game.WaveSpawner.spawnRate, 200, 50)
    -- love.graphics.print("Debug: " .. tostring(game.debugMode or false), 10, 50)
end

function game_scene:keypressed(key)
    -- Codex (if open) captures Esc to close itself first.
    if game.gui.codex and game.gui.codex.isActive then
        game.gui.codex:keypressed(key)
        return
    end

    -- Esc / P toggle the pause menu (the shared settings panel).
    if key == "escape" or key == "p" then
        paused = paused == 1 and 0 or 1
        return
    end

    if paused == 1 then return end -- ignore gameplay keys while paused

    if key == "+" or key == "=" then
        game.time_mul = math.min(game.time_mul + 0.5, 2) -- Increase time multiplier up to 2x
    elseif key == "-" then
        game.time_mul = math.max(game.time_mul - 0.5, 0.5) -- Decrease time multiplier down to 0.5x
    else
        game.inputHandler:keypressed(key) -- Route through InputHandler
    end
end

return game_scene
