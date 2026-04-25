local state = 0
local scene_manager = require("Scenes.scene_manager")
local push = require("Libraries.push")

scene_manager.scenes.menu = require("Scenes.menu_scene")
scene_manager.scenes.game = require("Scenes.game_scene")
scene_manager.scenes.test = require("Scenes.test_scene")

scene_manager.current = scene_manager.scenes.menu -- Set the initial scene to menu_scene

-- Virtual resolution (16:9, all game logic uses this)
local VIRTUAL_WIDTH = 1066
local VIRTUAL_HEIGHT = 600

function love.load()
    love.window.setTitle("Base Defense")
    math.randomseed( os.time() )
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Default window size
    local windowWidth, windowHeight = 1280, 720

    push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, windowWidth, windowHeight, {
        fullscreen = false,
        resizable = true,
        vsync = true,
        highdpi = false,
        canvas = true
    })

    scene_manager:load() -- Load the initial scene
end

function love.resize(w, h)
    push:resize(w, h)
end

function love.mousepressed(x, y, button)
    local gx, gy = push:toGame(x, y)
    if gx and gy then
        scene_manager:mousepressed(gx, gy, button)
    end
end

function love.update(dt)
    scene_manager:update(dt)
end

function love.draw()
    push:start()
    love.graphics.clear(0, 0, 0) -- Clear the screen with a dark color
    scene_manager:draw() -- Draw the current scene
    push:finish()
end

function love.keypressed(key)
    scene_manager:keypressed(key) -- Handle key presses in the current scene
    if key == "escape" then
        love.event.quit() -- Exit the game when Escape is pressed
    end
end
