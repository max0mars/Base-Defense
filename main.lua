local state = 0
local scene_manager = require("Scripts.scene_manager")

scene_manager.scenes.menu = require("scenes.menu_scene")
scene_manager.scenes.game = require("scenes.game_scene")

scene_manager.current = scene_manager.scenes.menu -- Set the initial scene to menu_scene

function love.load()
    love.window.setTitle("Enemy and Base Example")
    love.window.setMode(800, 600, { resizable = false, vsync = true })
    scene_manager:load() -- Load the initial scene
end

function love.mousepressed(x, y, button)
    scene_manager:mousepressed(x, y, button)
end

function love.update(dt)
    scene_manager:update(dt)
end

function love.draw()
    love.graphics.clear(0, 0, 0) -- Clear the screen with a dark color
    scene_manager:draw() -- Draw the current scene
end

function love.keypressed(key)
    scene_manager:keypressed(key) -- Handle key presses in the current scene
    if key == "escape" then
        love.event.quit() -- Exit the game when Escape is pressed
    end
end