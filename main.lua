VIRTUAL_WIDTH = 800
VIRTUAL_HEIGHT = 600

scalify = require("Libraries.scalify")

-- Override mouse position to always return virtual coordinates
local originalGetPosition = love.mouse.getPosition
function love.mouse.getPosition()
    local x, y = originalGetPosition()
    if scalify and scalify._SCALE then
        local gx, gy = scalify:toGame(x, y)
        if not gx then gx = x < scalify._OFFSET.x and 0 or VIRTUAL_WIDTH end
        if not gy then gy = y < scalify._OFFSET.y and 0 or VIRTUAL_HEIGHT end
        return gx, gy
    end
    return x, y
end
local state = 0
local scene_manager = require("Scenes.scene_manager")

scene_manager.scenes.menu = require("Scenes.menu_scene")
scene_manager.scenes.game = require("Scenes.game_scene")
scene_manager.scenes.test = require("Scenes.test_scene")

scene_manager.current = scene_manager.scenes.menu -- Set the initial scene to menu_scene

function love.load()
    love.window.setTitle("Base Defense")
    scalify:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, 800, 600, { resizable = true, vsync = true, highdpi = true })
    math.randomseed( os.time() )
    love.graphics.setDefaultFilter("nearest", "nearest")
    scene_manager:load() -- Load the initial scene
end

function love.resize(w, h)
    scalify:resize(w, h)
end

function love.mousepressed(x, y, button)
    local virtualX, virtualY = scalify:toGame(x, y)
    if virtualX and virtualY then
        scene_manager:mousepressed(virtualX, virtualY, button)
    end
end

function love.update(dt)
    scene_manager:update(dt)
end

function love.draw()
    scalify:start()
    love.graphics.clear(0, 0, 0) -- Clear the screen with a dark color
    scene_manager:draw() -- Draw the current scene
    scalify:finish()
end

function love.keypressed(key)
    scene_manager:keypressed(key) -- Handle key presses in the current scene
    if key == "escape" then
        love.event.quit() -- Exit the game when Escape is pressed
    end
end