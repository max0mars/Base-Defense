-- test_drone_game_load.lua
-- Simulate start game loading with Drone as the first enemy

-- Mock LOVE functions that are usually defined globally
love = {
    math = {
        random = math.random,
        colorFromBytes = function(...) return ... end
    },
    graphics = {
        getWidth = function() return 800 end,
        getHeight = function() return 600 end,
        newCanvas = function() return {} end,
        setCanvas = function() end,
        clear = function() end,
        setColor = function() end,
        setLineWidth = function() end,
        rectangle = function() end,
        circle = function() end,
        polygon = function() end,
        push = function() end,
        pop = function() end,
        translate = function() end,
        rotate = function() end,
        scale = function() end,
        printf = function() end,
        print = function() end,
        getFont = function() return { getWidth = function() return 10 end, getHeight = function() return 10 end } end,
        newFont = function() return { getWidth = function() return 10 end, getHeight = function() return 10 end } end,
    },
    mouse = {
        setVisible = function() end
    },
    timer = {
        getTime = function() return 0 end
    }
}

-- Mocks
VIRTUAL_WIDTH = 800
VIRTUAL_HEIGHT = 600
SetGameScissor = function() end

local game = require("Game.Core.GameManager")

-- Mock PersistentState as if we just clicked Start Game
_G.PersistentState = {
    selectedMainTurret = "MainLazer",
    globalDifficulty = 1,
    battlesCompleted = 0,
    discoveredEnemies = { ["Drone"] = true, ["Grunt"] = true, ["Scout"] = true, ["Critter"] = true }
}

print("Simulating game load...")
game:load(nil, false) -- isTesting = false

print("Simulating update to trigger wave initialization...")
-- This will trigger WaveSpawner:update(0) which will prepare the upcoming wave and generate the battle
game.WaveSpawner:update(0.1)

print("Starting next wave...")
game.WaveSpawner:startNextWave()

print("Updating WaveSpawner in a loop to force enemy spawning...")
for i = 1, 100 do
    game.WaveSpawner:update(0.1)
    if #game.objects > 1 then -- more than just the base
        print("Spawned objects count: " .. #game.objects)
        for _, obj in ipairs(game.objects) do
            if obj.isType and obj:isType("enemy") then
                print("Spawned enemy: " .. tostring(obj.name) .. ", type: " .. tostring(obj.type))
                if obj.update then
                    print("Updating spawned enemy...")
                    obj:update(0.1)
                end
            end
        end
        break
    end
end

print("Simulating drawing of WavePreviewUI...")
local WavePreviewUI = require("Game.GUI.WavePreviewUI")
local preview = WavePreviewUI:new(game)
preview:draw(800, 300)

print("[PASS] Game loaded and updated successfully with Drone without crashing.")

