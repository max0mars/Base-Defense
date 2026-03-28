local test_scene = {}
test_scene.__index = test_scene
local scene = require("Scenes.scene")
local EffectManager = require("Game.StatusEffects.EffectManager")
local RewardPool = require("Game.Rewards.RewardPool")
local PoisonTurret = require("Buildings.Turrets.PoisonTurret")

setmetatable(test_scene, { __index = scene })

function test_scene:load()
    

    print("\n" .. string.rep("=", 60))
    print("OBJECT TYPE INHERITANCE TEST")
    print(string.rep("=", 60))

    -- Mock game environment
    local mockGame = { 
        ground = { x=0, y=0, w=1000, h=1000 },
        battlefieldGrid = { cellSize = 25 }
    }
    
    -- Create a PoisonTurret (which inherits from Turret -> Building -> Object)
    print("\n[TEST 6] Testing recursive type merging for PoisonTurret")
    local pt = PoisonTurret:new({ 
        game = mockGame, 
        x = 100, y = 100, 
        buildGrid = { width=10, height=10, cellSize=25, x=0, y=0 } 
    })
    
    local typesToTest = {"building", "turret", "poison"}
    local allPassed = true
    
    for _, tName in ipairs(typesToTest) do
        local hasType = pt:isType(tName)
        print(string.format("  Checking isType('%s'): %s", tName, hasType and "YES" or "NO"))
        if not hasType then allPassed = false end
    end
    
    if allPassed then
        print("  SUCCESS: PoisonTurret correctly inherited types from its entire ancestry.")
    else
        print("  FAILED: One or more base types were missing in the subclass.")
    end

    print("\n" .. string.rep("=", 60))
    print("TEST SUITE COMPLETE")
    print(string.rep("=", 60))
end

function test_scene:draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Detailed Hierarchy Tests are running in the Console.", 100, 100)
    love.graphics.print("Press 'Enter' to return to menu", 100, 150)
end

function test_scene:keypressed(key)
    if key == "return" then
        self.scene_manager.switch("menu")
    end
end

return test_scene