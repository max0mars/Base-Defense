local test_scene = {}
test_scene.__index = test_scene
local scene = require("Scenes.scene")
local EffectManager = require("Game.StatusEffects.EffectManager")
local RewardPool = require("Game.Rewards.RewardPool")

setmetatable(test_scene, { __index = scene })

function test_scene:load()
    print("\n" .. string.rep("=", 60))
    print("GLOBAL-LOCAL HIERARCHY TEST SUITE")
    print(string.rep("=", 60))

    -- Setup managers
    local globalEM = EffectManager:new() -- Global
    local localOwner = { name = "LocalUnit", getHealthBarRect = function() return 100, 100, 50, 5 end }
    local localEM = EffectManager:new(localOwner)
    localEM.parent = globalEM

    -----------------------------------------------------------
    -- Test 1: Global Inheritance
    -----------------------------------------------------------
    print("\n[TEST 1] Testing Global inheritance of stats")
    print("  Setup: Base speed = 100. Applying a +100% mult buff to GLOBAL manager.")
    
    globalEM:applyEffect({
        name = "world_speed",
        statModifiers = { speed = { mult = 1.0 } }
    })
    
    local speed = localEM:getStat("speed", 100)
    print("  Action: Checking speed on LOCAL manager (linked to Global).")
    
    if speed == 200 then
        print("  SUCCESS: Global speed buff reached local unit. (Speed is 200)")
    else
        print("  FAILED: Local speed should be 200, got " .. speed)
    end

    -----------------------------------------------------------
    -- Test 2: Combined Formulas
    -----------------------------------------------------------
    print("\n[TEST 2] Testing stacked Local/Global formula")
    print("  Setup: Global buff (+100% mult) already active.")
    print("  Action: Applying LOCAL flat buff (+20) to unit.")
    
    localEM:applyEffect({
        name = "boots",
        statModifiers = { speed = { add = 20 } }
    })
    
    speed = localEM:getStat("speed", 100)
    local expected = (100 + 20) * (1 + 1.0) -- 240
    print("  Calculation: (Base 100 + Local 20) * (1 + Global 100%) = " .. expected)
    
    if speed == expected then
        print("  SUCCESS: Buffs from multiple managers combined correctly. (Speed is " .. speed .. ")")
    else
        print("  FAILED: Multi-source formula error. Expected " .. expected .. ", got " .. speed)
    end

    -----------------------------------------------------------
    -- Test 3: Versioning & Invalidation
    -----------------------------------------------------------
    print("\n[TEST 3] Testing version-based cache invalidation")
    print("  Status: Local speed " .. speed .. " is currently cached.")
    print("  Action: Adding an additional GLOBAL buff (+0.5 mult) while unit is idle.")
    
    globalEM:applyEffect({
        name = "super_haste",
        statModifiers = { speed = { mult = 0.5 } }
    })
    
    print("  Detail: Global version changed. Checking if Local cache invalidates and recalculates...")
    speed = localEM:getStat("speed", 100)
    expected = (100 + 20) * (1 + 1.0 + 0.5) -- 300
    
    if speed == 300 then
        print("  SUCCESS: Local manager detected Global version increase and updated. (Speed is 300)")
    else
        print("  FAILED: Version tracking failed to update cache. Got " .. speed)
    end

    -----------------------------------------------------------
    -- Test 4: Selective Damage Scaling (Tags)
    -----------------------------------------------------------
    print("\n[TEST 4] Testing Damage Tags across hierarchy")
    print("  Setup: Global fire scaling (+50%) and Local fire scaling (+10 flat).")
    
    globalEM:applyEffect({
        name = "global_ignite",
        targetTags = { "fire" },
        statModifiers = { damage = { mult = 0.5 } }
    })
    localEM:applyEffect({
        name = "local_ignite",
        targetTags = { "fire" },
        statModifiers = { damage = { add = 10 } }
    })
    
    print("  Action: Checking 'physical' damage (should ignore fire buffs) vs 'fire' damage.")
    local phys = localEM:getDamage(100, { "physical" })
    local fire = localEM:getDamage(100, { "fire" })
    local expFire = (100 + 10) * (1 + 0.5) -- 165
    
    print("  Result: Physical Damage = " .. phys .. ", Fire Damage = " .. fire)
    
    if phys == 100 and fire == expFire then
        print("  SUCCESS: Tag matching is filtering correctly across all layers.")
    else
        print("  FAILED: Tag evaluation error.")
    end

    -----------------------------------------------------------
    -- Test 5: triggerEvent Hook Bubbling
    -----------------------------------------------------------
    print("\n[TEST 5] Testing hook propagation (bubbling)")
    print("  Setup: Adding high-level hook to GLOBAL manager for 'onScanned' event.")
    
    local globalSignal = false
    globalEM:applyEffect({
        name = "global_eye",
        onScanned = function() globalSignal = true end
    })
    
    print("  Action: Triggering 'onScanned' event on LOCAL manager instance.")
    localEM:triggerEvent("onScanned")
    
    if globalSignal then
        print("  SUCCESS: Global hook successfully fired from local event trigger.")
    else
        print("  FAILED: Event failed to bubble up to parent manager.")
    end

    print("\n" .. string.rep("=", 60))
    print("REWARD POOL STATISTICAL TEST")
    print(string.rep("=", 60))

    -- Create test Reward Index
    local testIndex = {
        common = { {id="c1"}, {id="c2"}, {id="c3"}, {id="c4"}, {id="c5"} },
        uncommon = { {id="u1"}, {id="u2"}, {id="u3"}, {id="u4"} },
        rare = { {id="r1"}, {id="r2"}, {id="r3"}, {id="r4"}, {id="r5"} },
        epic = { {id="e1"}, {id="e2"}, {id="e3"}, {id="e4"}, {id="e5"} },
        legendary = { {id="l1"}, {id="l2"}, {id="l3"} }
    }
    
    local pool = RewardPool:new(testIndex)
    local sampleSize = 1000
    local rarities = {"common", "uncommon", "rare", "epic", "legendary"}

    print(string.format("%-4s | %-12s | %-12s | %-12s | %-12s | %-12s", "LUCK", "COMMON", "UNCOMMON", "RARE", "EPIC", "LEG"))
    print(string.format("%-4s | %-12s | %-12s | %-12s | %-12s | %-12s", "", "Exp / Obs", "Exp / Obs", "Exp / Obs", "Exp / Obs", "Exp / Obs"))
    print(string.rep("-", 75))

    for luckLevel = 1, 10 do
        local stats = { common=0, uncommon=0, rare=0, epic=0, legendary=0 }
        
        for i = 1, sampleSize do
            local choices = pool:generateChoices(3, luckLevel)
            for _, choice in ipairs(choices) do
                stats[choice.rarity] = stats[choice.rarity] + 1
            end
        end

        local total = sampleSize * 3
        local expected = pool.LuckTable[luckLevel]
        
        local function fmt(rarity)
            local obs = (stats[rarity] / total) * 100
            local exp = expected[rarity] or 0
            return string.format("%d / %.1f", exp, obs)
        end

        local row = string.format("%-4d | %-12s | %-12s | %-12s | %-12s | %-12s", 
            luckLevel,
            fmt("common"),
            fmt("uncommon"),
            fmt("rare"),
            fmt("epic"),
            fmt("legendary")
        )
        print(row)
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
