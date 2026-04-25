local menu_scene = {}
menu_scene.__index = menu_scene
local scene = require("Scenes.scene") -- Import the base scene class
local push = require("Libraries.push")
setmetatable(menu_scene, { __index = scene })

local resolutions = {
    { w = 1280, h = 720,  label = "1280x720 (720p)" },
    { w = 1366, h = 768,  label = "1366x768" },
    { w = 1600, h = 900,  label = "1600x900" },
    { w = 1920, h = 1080, label = "1920x1080 (1080p)" },
    { w = 2560, h = 1440, label = "2560x1440 (1440p)" },
    { w = 3840, h = 2160, label = "3840x2160 (4K)" },
}

local selectedResolution = 1 -- Default to 1280x720
local fullscreen = false

function menu_scene:draw()
    local w = push:getWidth()
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Base Defense", 0, 80, w, "center")

    love.graphics.printf("Press 'Enter' to Start", 0, 140, w, "center")
    love.graphics.printf("Press 'T' for Tests", 0, 170, w, "center")

    -- Resolution selection
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("Resolution (Up/Down to change):", 0, 240, w, "center")

    for i, res in ipairs(resolutions) do
        if i == selectedResolution then
            love.graphics.setColor(0, 1, 0)
            love.graphics.printf("> " .. res.label .. " <", 0, 265 + (i - 1) * 22, w, "center")
        else
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.printf(res.label, 0, 265 + (i - 1) * 22, w, "center")
        end
    end

    love.graphics.setColor(0.7, 0.7, 0.7)
    local fsText = fullscreen and "Fullscreen: ON" or "Fullscreen: OFF"
    love.graphics.printf(fsText .. "  (F to toggle)", 0, 265 + #resolutions * 22 + 10, w, "center")

    love.graphics.setColor(1, 1, 1, 1)
end

function menu_scene:applyResolution()
    local res = resolutions[selectedResolution]
    push:setupScreen(1066, 600, res.w, res.h, {
        fullscreen = fullscreen,
        resizable = true,
        vsync = true,
        highdpi = false,
        canvas = true
    })
end

function menu_scene:keypressed(key)
    if key == "return" then
        self:applyResolution()
        self.scene_manager.switch("game")
    elseif key == "t" then
        self:applyResolution()
        self.scene_manager.switch("test")
    elseif key == "up" then
        selectedResolution = math.max(1, selectedResolution - 1)
    elseif key == "down" then
        selectedResolution = math.min(#resolutions, selectedResolution + 1)
    elseif key == "f" then
        fullscreen = not fullscreen
    end
end

return menu_scene
