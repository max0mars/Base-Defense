local test_scene = {}
test_scene.__index = test_scene
local scene = require("Scenes.scene")
local RewardPool = require("Game.Rewards.RewardPool")


setmetatable(test_scene, { __index = scene })

function test_scene:load()
    print("Test scene loaded (SpecialUpgradeManager test removed).")
end

function test_scene:draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Special Upgrade Pairing Tests are running in the Console.", 100, 100)
    love.graphics.print("Press 'Enter' to return to menu", 100, 150)
end

function test_scene:keypressed(key)
    if key == "return" then
        self.scene_manager.switch("menu")
    end
end

return test_scene
