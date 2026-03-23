local test_scene = {}
test_scene.__index = test_scene
local scene = require("Scenes.scene")
local EffectManager = require("Game.StatusEffects.EffectManager")

setmetatable(test_scene, { __index = scene })

function test_scene:load()
    print("\n" .. string.rep("=", 40))
    print("EFFECT MANAGER TEST SUITE STARTING...")
    print(string.rep("=", 40))

    -- Mock owner structure
    local owner = {
        name = "TestDummy",
        getHealthBarRect = function() return 100, 100, 100, 10 end
    }

    local em = EffectManager:new(owner)

    -----------------------------------------------------------
    -- Test 1: Base Stat check and Caching
    -----------------------------------------------------------
    print("\n[TEST 1] Testing base stat and dirty flag cache")
    local s1 = em:getStat("speed", 100)
    print("  Initial speed: " .. s1)
    
    -- Check if it actually caches (we can't easily peek but we'll check it remains consistent)
    local s2 = em:getStat("speed", 100)
    if s1 == s2 then
        print("  SUCCESS: Base speed is consistent at " .. s1)
    end

    -----------------------------------------------------------
    -- Test 2: Mult & Flat Modifiers
    -----------------------------------------------------------
    -- Formula: (Base + AdditiveSum) * (1 + MultiplierSum)
    print("\n[TEST 2] Testing Formula (Base + Flat) * (1 + Mult)")
    
    local buff1 = {
        name = "boots",
        statModifiers = { speed = { add = 10 } }
    }
    local buff2 = {
        name = "haste",
        statModifiers = { speed = { mult = 0.5 } }
    }
    
    em:applyEffect(buff1)
    em:applyEffect(buff2)
    
    local speed = em:getStat("speed", 100)
    local expectedValue = (100 + 10) * (1 + 0.5) -- 110 * 1.5 = 165
    
    if speed == expectedValue then
        print("  SUCCESS: Speed is " .. speed .. " (110 * 1.5)")
    else
        print("  FAILED: Speed should be " .. expectedValue .. ", got " .. speed)
    end

    -----------------------------------------------------------
    -- Test 3: Tag-based Damage
    -----------------------------------------------------------
    print("\n[TEST 3] Testing Damage Tags")
    
    local fireAmp = {
        name = "fire_amp",
        targetTags = { "fire" },
        statModifiers = { damage = { mult = 1.0 } } -- +100% fire damage
    }
    
    em:applyEffect(fireAmp)
    
    local normalDmg = em:getDamage(100, { "physical" })
    local fireDmg = em:getDamage(100, { "fire" })
    
    print("  - Base Damage: 100")
    print("  - Physical Tag: " .. normalDmg)
    print("  - Fire Tag (+100%): " .. fireDmg)
    
    if normalDmg == 100 and fireDmg == 200 then
        print("  SUCCESS: Damage tags correctly filtered")
    else
        print("  FAILED: Tag filtering failed")
    end

    -----------------------------------------------------------
    -- Test 4: Trigger Events
    -----------------------------------------------------------
    print("\n[TEST 4] Testing triggerEvent hooks")
    
    local hookPassed = false
    local counter = 0
    local hookEffect = {
        name = "counter_strike",
        onHit = function(self, bullet)
            counter = counter + 1
            print("  - Hook called by: " .. (bullet.tag or "unknown"))
            hookPassed = true
        end
    }
    
    em:applyEffect(hookEffect)
    em:triggerEvent("onHit", { tag = "bullet" })
    
    if hookPassed and counter == 1 then
        print("  SUCCESS: triggerEvent executed hook correctly")
    end

    -----------------------------------------------------------
    -- Test 5: Stack Limits
    -----------------------------------------------------------
    print("\n[TEST 5] Testing Stack Limits")
    
    local stacker = {
        name = "stacker",
        maxStacks = 2,
        statModifiers = { power = { add = 1 } }
    }
    
    em:applyEffect(stacker)
    em:applyEffect(stacker)
    em:applyEffect(stacker) -- This 3rd stack should be ignored
    
    local power = em:getStat("power", 0)
    if power == 2 then
        print("  SUCCESS: Max stacks (2) respected correctly")
    else
        print("  FAILED: Expected 2 stacks, got " .. power)
    end

    print("\n" .. string.rep("=", 40))
    print("ALL TESTS COMPLETE")
    print(string.rep("=", 40))
end

function test_scene:draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Tests Outputted to Console/Terminal", 100, 100)
    love.graphics.print("Press 'Enter' to return to menu", 100, 150)
end

function test_scene:keypressed(key)
    if key == "return" then
        self.scene_manager.switch("menu")
    end
end

return test_scene
