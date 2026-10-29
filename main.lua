VIRTUAL_WIDTH = 1280
VIRTUAL_HEIGHT = 720

-- First, so its print/printf wrappers (text stays out of the glow) are in place
local Glow = require("Graphics.Glow")
local Settings = require("Game.Core.Settings")

scalify = require("Libraries.scalify")
local Layout = require("Game.GUI.Layout")
local Cursor = require("Game.GUI.Cursor")

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
        local view = Layout.view
        if x then
            local vx, vy = Layout.worldToScreen(x, y)
            local s = view and view.scale or Layout.scale
            x, y, w, h = vx, vy, w * s, h * s
            -- Inside a view (e.g. the enemy entry's demo strip), stay within its
            -- bounds: a clip that replaced them would let fills spill outside
            if view and view.clip then
                local c = view.clip
                local x2, y2 = math.min(x + w, c.x + c.w), math.min(y + h, c.y + c.h)
                x, y = math.max(x, c.x), math.max(y, c.y)
                w, h = math.max(0, x2 - x), math.max(0, y2 - y)
            end
        else
            local clip = (view and view.clip) or Layout.field
            x, y, w, h = clip.x, clip.y, clip.w, clip.h
        end
    elseif not x then
        if scalify and not scalify._canvas then
            love.graphics.setScissor(scalify._OFFSET.x, scalify._OFFSET.y, scalify._WWIDTH * scalify._SCALE.x, scalify._WHEIGHT * scalify._SCALE.y)
        else
            love.graphics.setScissor()
        end
        return
    end

    local rx, ry, rw, rh = x, y, w, h
    if scalify and not scalify._canvas then
        rx, ry = scalify:toReal(x, y)
        rw, rh = w * scalify._SCALE.x, h * scalify._SCALE.y
    end
    if Layout and Layout.worldActive then
        -- World clips (enemy HP fills) follow smoothly moving shapes: round each
        -- edge to the nearest pixel so the clip never drifts more than half a
        -- pixel from the shape it cuts
        local x1, y1 = math.floor(rx + 0.5), math.floor(ry + 0.5)
        local x2, y2 = math.floor(rx + rw + 0.5), math.floor(ry + rh + 0.5)
        love.graphics.setScissor(x1, y1, math.max(0, x2 - x1), math.max(0, y2 - y1))
    else
        love.graphics.setScissor(math.floor(rx), math.floor(ry), math.floor(rw), math.ceil(rh))
    end
end

--- The game's cursor, on top of everything (and crisp: after the glow pass).
--- Uses the raw mouse position so it's still drawn over the letterbox bars.
local function drawCursor()
    if not love.window.hasMouseFocus() then return end
    Cursor.drawOnScreen(originalGetPosition())
end

local state = 0
local scene_manager = require("Scenes.scene_manager")

scene_manager.scenes.menu = require("Scenes.menu_scene")
scene_manager.scenes.new_game = require("Scenes.new_game_scene")
scene_manager.scenes.preparation = require("Scenes.preparation_scene")
scene_manager.scenes.game = require("Scenes.game_scene")
scene_manager.scenes.test = require("Scenes.test_scene")
scene_manager.scenes.gameover = require("Scenes.game_over_scene")

scene_manager.current = scene_manager.scenes.menu -- Set the initial scene to menu_scene

local AudioManager = require("Audio.AudioManager")

function love.load()
    love.graphics.setDefaultFilter("linear", "linear")
    love.window.setTitle("Base Defense")
    Settings.load()
    local windowW, windowH = Settings.windowSize(2560, 1440)
    scalify:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, windowW, windowH, { resizable = true, vsync = true, highdpi = true, canvas = false})
    Settings.applyDisplay(scalify)
    scalify:setBorderColor(0.03, 0.04, 0.06)
    love.mouse.setVisible(false) -- the game draws its own cursor (Game/GUI/Cursor.lua)
    math.randomseed( os.time() )
    love.graphics.setBlendMode("alpha", "alphamultiply")
    
    -- Initialize global Audio Subsystem
    AUDIO = AudioManager:new()
    Settings.applyAudio(AUDIO)
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
    Cursor.reset() -- the scene flags what's under the mouse as it draws
    Glow.begin()
    scalify:start()
    love.graphics.clear(0.03, 0.04, 0.06) -- Clear the screen with a dark color
    scene_manager:draw() -- Draw the current scene
    scalify:finish()
    Glow.finish()
    drawCursor()
end

function love.keypressed(key)
    scene_manager:keypressed(key) -- Handle key presses in the current scene
    if key == "escape" then
        -- Removed immediate quit. Scenes will handle escape to show confirmation.
    end
end
