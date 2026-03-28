local test_scene = {}
test_scene.__index = test_scene
local scene = require("Scenes.scene")
local RewardPool = require("Game.Rewards.RewardPool")
local SpecialUpgradeManager = require("Game.Rewards.SpecialUpgradeManager")

setmetatable(test_scene, { __index = scene })

function test_scene:load()
    print("\n" .. string.rep("=", 60))
    print("SPECIAL UPGRADE PAIRING TEST")
    print(string.rep("=", 60))

    -- 1. Setup Mock Reward Indices
    local testPlayerIndex = {
        common = { {id="pc1"}, {id="pc2"} },
        uncommon = { {id="pu1"}, {id="pu2"} },
        rare = { {id="pr1"}, {id="pr2"} },
        epic = { {id="pe1"}, {id="pe2"} },
        legendary = { {id="pl1"}, {id="pl2"} }
    }
    local testEnemyIndex = {
        common = { {id="ec1"}, {id="ec2"} },
        uncommon = { {id="eu1"}, {id="eu2"} },
        rare = { {id="er1"}, {id="er2"} },
        epic = { {id="ee1"}, {id="ee2"} },
        legendary = { {id="el1"}, {id="el2"} }
    }

    -- 2. Mock GameManager with Luck and Managers
    local mockGame = { 
        luck = 1,
        wave = 5,
        playerEffectManager = { applyEffect = function() end },
        enemyEffectManager = { applyEffect = function() end }
    }
    
    -- Inject our test indices into the manager's pools
    local mgr = SpecialUpgradeManager:new(mockGame)
    mgr.playerPool = RewardPool:new(testPlayerIndex)
    mgr.enemyPool = RewardPool:new(testEnemyIndex)

    -- 3. Run Statistical Test across Luck Levels
    local sampleSize = 100
    print(string.format("%-4s | %-15s | %-10s", "LUCK", "PAIR RARITY", "MATCHED?"))
    print(string.rep("-", 40))

    for luck = 1, 10 do
        mockGame.luck = luck
        local stats = { common=0, uncommon=0, rare=0, epic=0, legendary=0 }
        local mismatches = 0
        
        for i = 1, sampleSize do
            mgr:generatePairs(3, luck)
            for _, pair in ipairs(mgr.currentPairs) do
                local pRarity = pair.player.rarity
                local eRarity = pair.enemy.rarity
                
                stats[pRarity] = stats[pRarity] + 1
                if pRarity ~= eRarity then
                    mismatches = mismatches + 1
                end
            end
        end

        -- Find dominant rarity for this luck level to show progression
        local topRarity = "common"
        local maxCount = 0
        for r, count in pairs(stats) do
            if count > maxCount then
                maxCount = count
                topRarity = r
            end
        end

        print(string.format("%-4d | %-15s | %-10s", 
            luck, 
            topRarity:upper(), 
            mismatches == 0 and "YES (100%)" or "FAIL ("..mismatches..")"
        ))
    end

    -----------------------------------------------------------
    -- 4. Test Uniqueness (The Hand should never have duplicate IDs)
    -----------------------------------------------------------
    print("\n[TEST] Verifying Uniqueness in a single hand")
    mgr:generatePairs(3, 10)
    local ids = {}
    local duplicates = false
    for _, pair in ipairs(mgr.currentPairs) do
        if ids[pair.player.id] or ids[pair.enemy.id] then
            duplicates = true
        end
        ids[pair.player.id] = true
        ids[pair.enemy.id] = true
    end
    
    if not duplicates then
        print("  SUCCESS: Hand contains unique pairings.")
    else
        print("  FAILED: Duplicates found in special upgrade hand.")
    end

    print("\n" .. string.rep("=", 60))
    print("TEST SUITE COMPLETE")
    print(string.rep("=", 60))
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