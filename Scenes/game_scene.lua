local game_scene = {
    
}
game_scene.__index = game_scene
local scene = require("Scenes.scene") -- Import the base scene class
setmetatable(game_scene, { __index = scene })

local time_mul = 1
local game = require("Game.GameManager") -- Import the game module

function game_scene:load()
    time_mul = 1 -- game starts frozen
    game:load()
end

function game_scene:mousepressed(x, y, button)
    game.inputHandler:mousepressed(x, y, button) -- Route through InputHandler
end

function game_scene:update(dt)
    if game:isState("gameover") then
        self.gameover = true
    end
    if paused == 1 then
        return -- Skip update if paused
    end
    game:update(dt * time_mul) -- Update the game state with time multiplier
end

function game_scene:draw()
    if self.gameover then
        love.graphics.setColor(0, 0, 0, 0.7) -- Semi-transparent black for game over overlay
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 0, 0) -- Red color for text
        love.graphics.printf("Game Over", 0, love.graphics.getHeight() / 2 - 20, love.graphics.getWidth(), "center")
        love.graphics.printf("Final Score: " .. game.xp, 0, love.graphics.getHeight() / 2 + 20, love.graphics.getWidth(), "center")
        return
    end
    game:draw()
    if paused == 1 then
        love.graphics.setColor(0, 0, 0, 0.5) -- Semi-transparent black for pause overlay
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1) -- Reset color for text
        love.graphics.printf("Game Paused", 0, love.graphics.getHeight() / 2 - 20, love.graphics.getWidth(), "center")
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Score: " .. game.xp, 10, 10)
    love.graphics.print("Time Multiplier: " .. string.format("%.1f", time_mul) .. "x", 10, 30)
    love.graphics.print("Wave: " .. game.wave, 10, 50)
    love.graphics.print("Game State: " .. game.state, 10, 70)
    love.graphics.print("Wave State: " .. game.WaveSpawner.waveState, 200, 10)
end

function game_scene:keypressed(key)
    if key == "p" then
        paused = paused == 1 and 0 or 1 -- Toggle pause
    elseif key == "+" or key == "=" then
        time_mul = math.min(time_mul + 0.5, 5) -- Increase time multiplier up to 5x
    elseif key == "-" then
        time_mul = math.max(time_mul - 0.5, 0) -- Decrease time multiplier down to 0x
    else 
        game.inputHandler:keypressed(key) -- Route through InputHandler
    end
end

return game_scene