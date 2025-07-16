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
    game:update(dt * time_mul) -- Update the game state with time multiplier
end

function game_scene:draw()
    game:draw()
end

function game_scene:keypressed(key)
    if key == "p" then
        time_mul = time_mul == 1 and 0 or 1 -- Toggle pause
    end
end

return game_scene