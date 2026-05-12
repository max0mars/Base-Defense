local game_scene = {
    
}
game_scene.__index = game_scene
local scene = require("Scenes.scene") -- Import the base scene class
setmetatable(game_scene, { __index = scene })

local game = require("Game.Core.GameManager") -- Import the game module

function game_scene:load()
    game:load()
    game.time_mul = 1 -- game starts at normal speed
    if AUDIO then AUDIO:playMusic() end
end

function game_scene:mousepressed(x, y, button)
    game.inputHandler:mousepressed(x, y, button) -- Route through InputHandler
end

function game_scene:mousereleased(x, y, button)
    if game.inputHandler.mousereleased then
        game.inputHandler:mousereleased(x, y, button)
    end
end

function game_scene:update(dt)
    if game:isState("gameover") then
        self.gameover = true
    end

    local effectiveDt = dt * game.time_mul
    
    -- Freeze game if paused or a modal menu is active
    if paused == 1 or 
       (game.rewardSystem and game.rewardSystem.isActive) or 
       (game.specialUpgradeManager and game.specialUpgradeManager.isActive) or
       (game.gui.mutation and game.gui.mutation.isActive) or
       (game.gui.confirmation and game.gui.confirmation.active) then
        effectiveDt = 0
    end
    
    game:update(effectiveDt)
end

function game_scene:draw()
    if self.gameover then
        love.graphics.setColor(0, 0, 0, 0.7) -- Semi-transparent black for game over overlay
        love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
        love.graphics.setColor(1, 0, 0) -- Red color for text
        love.graphics.printf("Game Over", 0, VIRTUAL_HEIGHT / 2 - 20, VIRTUAL_WIDTH, "center")
        love.graphics.printf("Final Score: " .. game.xp, 0, VIRTUAL_HEIGHT / 2 + 20, VIRTUAL_WIDTH, "center")
        return
    end
    game:draw()
    if paused == 1 then
        love.graphics.setColor(0, 0, 0, 0.5) -- Semi-transparent black for pause overlay
        love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
        love.graphics.setColor(1, 1, 1) -- Reset color for text
        love.graphics.printf("Game Paused", 0, VIRTUAL_HEIGHT / 2 - 20, VIRTUAL_WIDTH, "center")
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
        game.time_mul = math.min(game.time_mul + 0.5, 5) -- Increase time multiplier up to 5x
    elseif key == "-" then
        game.time_mul = math.max(game.time_mul - 0.5, 0) -- Decrease time multiplier down to 0x
    elseif key == "escape" then
        game.gui.confirmation:activate(
            "Do you want to quit?",
            function() love.event.quit() end,
            function() end
        )
    else 
        game.inputHandler:keypressed(key) -- Route through InputHandler
    end
end

return game_scene