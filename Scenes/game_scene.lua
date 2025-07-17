local game_scene = {
    
}
game_scene.__index = game_scene
local scene = require("Scenes.scene") -- Import the base scene class
setmetatable(game_scene, { __index = scene })

local time_mul = 1
local game = require("Scripts.game") -- Import the game module

function game_scene:load()
    time_mul = 1 -- game starts frozen
    game:load()
end

function game_scene:mousepressed(x, y, button)
    game:mousepressed(x, y, button) -- Pass mouse events to the game module
end

function game_scene:update(dt)
    if paused == 1 then
        return -- Skip update if paused
    end
    game:update(dt * time_mul) -- Update the game state with time multiplier
end

function game_scene:draw()
    game:draw()
    if paused == 1 then
        love.graphics.setColor(0, 0, 0, 0.5) -- Semi-transparent black for pause overlay
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1) -- Reset color for text
        love.graphics.printf("Game Paused", 0, love.graphics.getHeight() / 2 - 20, love.graphics.getWidth(), "center")
        for _, obj in ipairs(game.objects) do
            print(obj.tag, obj.x, obj.y) -- Debugging output for object positions
        end
    end
end

function game_scene:keypressed(key)
    if key == "p" then
        paused = paused == 1 and 0 or 1 -- Toggle pause
    end
end

return game_scene