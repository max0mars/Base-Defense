local game_scene = {
    
}
game_scene.__index = game_scene
local scene = require("Scenes.scene") -- Import the base scene class
setmetatable(game_scene, { __index = scene })

local game = require("Game.Core.GameManager") -- Import the game module

function game_scene:load()
    local isTesting = game.testingMode
    game:load(nil, isTesting)
    game.time_mul = 1 -- game starts at normal speed
    self.gameover = false
    if AUDIO and not AUDIO:isPlayingMusic() then AUDIO:playMusic() end
    local AudioSlidersUI = require("Game.GUI.AudioSlidersUI")
    self.sliders = AudioSlidersUI:new({ x = (VIRTUAL_WIDTH - 200) / 2, y = VIRTUAL_HEIGHT / 2 + 40, w = 200 })
end

function game_scene:mousepressed(x, y, button)
    if paused == 1 then
        if self.sliders and self.sliders:mousepressed(x, y, button) then
            return
        end
        return
    end
    game.inputHandler:mousepressed(x, y, button) -- Route through InputHandler
end

function game_scene:mousereleased(x, y, button)
    if paused == 1 then
        if self.sliders then self.sliders:mousereleased(x, y, button) end
        return
    end
    if game.inputHandler.mousereleased then
        game.inputHandler:mousereleased(x, y, button)
    end
end

function game_scene:update(dt)
    if paused == 1 and self.sliders then
        self.sliders:update(dt)
    end
    if game:isState("gameover") and not self.gameover then
        self.gameover = true
        self.scene_manager.switch("gameover")
    end

    local effectiveDt = dt * game.time_mul
    
    -- Freeze game if paused or a modal menu is active
    if paused == 1 or 
       (game.rewardSystem and game.rewardSystem.isActive) or 
       (game.specialUpgradeManager and game.specialUpgradeManager.isActive) or
       (game.gui.mutation and game.gui.mutation.isActive) or
       (game.gui.confirmation and game.gui.confirmation.active) or
       (game.gui.enemySpawner and game.gui.enemySpawner.isActive) then
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
        love.graphics.setColor(0, 0, 0, 0.5) -- Semi-transparent black for pause overlay
        love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
        love.graphics.setColor(1, 1, 1) -- Reset color for text
        love.graphics.printf("Game Paused", 0, VIRTUAL_HEIGHT / 2 - 20, VIRTUAL_WIDTH, "center")
        if self.sliders then self.sliders:draw() end
    end
    love.graphics.setColor(1, 1, 1, 1)
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
    if key == "p" then
        paused = paused == 1 and 0 or 1 -- Toggle pause
    elseif key == "+" or key == "=" then
        game.time_mul = math.min(game.time_mul + 0.5, 2) -- Increase time multiplier up to 2x
    elseif key == "-" then
        game.time_mul = math.max(game.time_mul - 0.5, 0.5) -- Decrease time multiplier down to 0.5x
    elseif key == "escape" then
        if game.gui.confirmation.active then
            game.gui.confirmation.active = false
            if game.gui.confirmation.onCancel then game.gui.confirmation.onCancel() end
        else
            game.gui.confirmation:activate(
                "Game Paused",
                function() 
                    paused = 0
                    self:load() 
                end,
                function() end, -- Cancel via ESC closes without action
                nil,
                "Retry",
                "Quit",
                function() love.event.quit() end
            )
        end
    else 
        game.inputHandler:keypressed(key) -- Route through InputHandler
    end
end

return game_scene