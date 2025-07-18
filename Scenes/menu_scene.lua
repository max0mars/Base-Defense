local menu_scene = {}
menu_scene.__index = menu_scene
local scene = require("Scenes.scene") -- Import the base scene class
setmetatable(menu_scene, { __index = scene })

function menu_scene:draw()
    love.graphics.setColor(1, 1, 1) -- Set color to white
    love.graphics.print("Welcome to the Base Defense Game!", 100, 100)
    love.graphics.print("Press 'Enter' to Start", 100, 150)
end

function menu_scene:keypressed(key)
    if key == "return" then
        self.scene_manager.switch("game") -- Switch to the game scene when Enter is pressed
    end
end

return menu_scene