VIRTUAL_WIDTH = 1280
VIRTUAL_HEIGHT = 720

scalify = require("Libraries.scalify")
local Layout = require("Game.GUI.Layout")

-- Override mouse position to always return virtual coordinates
local originalGetPosition = love.mouse.getPosition
function love.mouse.getPosition()
    local x, y = originalGetPosition()
    if scalify and scalify._SCALE then
        local gx, gy = scalify:toGame(x, y)
        if not gx then gx = x < scalify._OFFSET.x and 0 or VIRTUAL_WIDTH end
        if not gy then gy = y < scalify._OFFSET.y and 0 or VIRTUAL_HEIGHT end
        return math.floor(gx), math.floor(gy)
    end
    return x, y
end

function SetGameScissor(x, y, w, h)
    -- Inside the world viewport, callers pass WORLD coordinates; convert them to
    -- virtual (the field is translated + scaled on screen). A no-arg call there
    -- restores the clip to the field rect rather than the whole canvas.
    if Layout and Layout.worldActive then
        if x then
            local vx, vy = Layout.worldToScreen(x, y)
            x, y, w, h = vx, vy, w * Layout.scale, h * Layout.scale
        else
            x, y, w, h = Layout.field.x, Layout.field.y, Layout.field.w, Layout.field.h
        end
    elseif not x then
        if scalify and not scalify._canvas then
            love.graphics.setScissor(scalify._OFFSET.x, scalify._OFFSET.y, scalify._WWIDTH * scalify._SCALE.x, scalify._WHEIGHT * scalify._SCALE.y)
        else
            love.graphics.setScissor()
        end
        return
    end

    if scalify and not scalify._canvas then
        local rx, ry = scalify:toReal(x, y)
        local rw = w * scalify._SCALE.x
        local rh = h * scalify._SCALE.y
        love.graphics.setScissor(math.floor(rx), math.floor(ry), math.floor(rw), math.ceil(rh))
    else
        love.graphics.setScissor(math.floor(x), math.floor(y), math.floor(w), math.ceil(h))
    end
end

local state = 0
local scene_manager = require("Scenes.scene_manager")

scene_manager.scenes.menu = require("Scenes.menu_scene")
scene_manager.scenes.preparation = require("Scenes.preparation_scene")
scene_manager.scenes.game = require("Scenes.game_scene")
scene_manager.scenes.test = require("Scenes.test_scene")
scene_manager.scenes.tutorial = require("Scenes.tutorial_scene")
scene_manager.scenes.gameover = require("Scenes.game_over_scene")

scene_manager.current = scene_manager.scenes.menu -- Set the initial scene to menu_scene

local AudioManager = require("Audio.AudioManager")

function love.load()
    love.graphics.setDefaultFilter("linear", "linear")
    love.window.setTitle("Base Defense")
    scalify:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, 1280, 720, { resizable = true, vsync = true, highdpi = true, canvas = false})
    scalify:setBorderColor(0.03, 0.04, 0.06)
    math.randomseed( os.time() )
    love.graphics.setBlendMode("alpha", "alphamultiply")
    
    -- Initialize global Audio Subsystem
    AUDIO = AudioManager:new()
    AUDIO:playMusic()
    
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

function love.mousereleased(x, y, button)
    local virtualX, virtualY = scalify:toGame(x, y)
    if virtualX and virtualY then
        if scene_manager.mousereleased then scene_manager:mousereleased(virtualX, virtualY, button) end
    else
        if scene_manager.mousereleased then scene_manager:mousereleased(x, y, button) end
    end
end

function love.update(dt)
    if AUDIO then AUDIO:update(dt) end
    scene_manager:update(dt)
end

function love.draw()
    scalify:start()
    love.graphics.clear(0.03, 0.04, 0.06) -- Clear the screen with a dark color
    scene_manager:draw() -- Draw the current scene
    scalify:finish()
end

function love.keypressed(key)
    scene_manager:keypressed(key) -- Handle key presses in the current scene
    if key == "escape" then
        -- Removed immediate quit. Scenes will handle escape to show confirmation.
    end
end