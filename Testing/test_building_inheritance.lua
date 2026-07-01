-- Testing/test_building_inheritance.lua
-- Standalone test script to verify that all buildings (turrets, main turrets, blockers, buffs) inherit from Buildings.Building and have type 'building'.

package.path = package.path .. ";./?.lua"

-- Mock global love library in case any files request or use it during require/new
_G.love = {
    math = {
        random = math.random
    },
    timer = {
        getTime = function() return 0 end
    }
}

print("--- Starting Building Type Inheritance Tests ---")

local EffectManager = require("Game.Effects.EffectManager")
local mockGame = {
    objects = {},
    addObject = function(self, obj) table.insert(self.objects, obj) end,
    base = {
        buildGrid = {
            width = 10,
            height = 10,
            cellSize = 32,
            buildings = {}
        }
    }
}
mockGame.playerEffectManager = EffectManager:new(nil, mockGame)
mockGame.enemyEffectManager = EffectManager:new(nil, mockGame)

local failures = 0
local passes = 0

local function verifyBuilding(classPath, name, customConfig)
    local status, ClassOrErr = pcall(require, classPath)
    if not status then
        print("[FAIL] Failed to require " .. classPath .. ": " .. tostring(ClassOrErr))
        failures = failures + 1
        return
    end
    
    local Class = ClassOrErr
    
    -- Prepare configuration
    local config = {
        game = mockGame,
        types = { test = true },
        name = name,
        rotation = 0,

        fireRate = 1,
        damage = 10,
        bulletSpeed = 100,
        range = 200,
        barrel = 10,
        firingArc = { direction = 0, minRange = 0, angle = 1 },
        shapePattern = {{0,0}},
        color = {1,1,1,1}
    }
    
    -- If it's a turret, populate configuration from its template
    if Class.template then
        for k, v in pairs(Class.template) do
            if type(v) == "table" then
                config[k] = {}
                for k2, v2 in pairs(v) do config[k][k2] = v2 end
            else
                config[k] = v
            end
        end
    end
    
    -- Apply custom config overrides
    if customConfig then
        for k, v in pairs(customConfig) do
            config[k] = v
        end
    end
    
    -- Instantiation
    local instStatus, instOrErr = xpcall(function() return Class:new(config) end, debug.traceback)
    if not instStatus then
        print("[FAIL] Failed to instantiate " .. name .. " (" .. classPath .. "):\n" .. tostring(instOrErr))
        failures = failures + 1
        return
    end
    
    local inst = instOrErr
    if not inst then
        print("[FAIL] Instantiation of " .. name .. " returned nil")
        failures = failures + 1
        return
    end
    
    -- Check type 'building'
    if inst:isType("building") then
        print("[PASS] " .. name .. " has type 'building'")
        passes = passes + 1
    else
        local keys = {}
        if inst.types then
            for k in pairs(inst.types) do table.insert(keys, k) end
        end
        print("[FAIL] " .. name .. " does NOT have type 'building'. Types present: " .. table.concat(keys, ", "))
        failures = failures + 1
    end
end

-- 1. Standard Turrets
local turrets = {
    { path = "Buildings.Turrets.ChainLaser", name = "ChainLaser" },
    { path = "Buildings.Turrets.SequenceTurret", name = "SequenceTurret" },
    { path = "Buildings.Turrets.Turret", name = "Turret" },
}

for _, t in ipairs(turrets) do
    verifyBuilding(t.path, t.name)
end

-- 2. Buffs/Totems/Banks
-- Buffs are passive, so affectedSlots are required
local buffs = {
    { path = "Buildings.Passives.Buff", name = "Base Buff" },
    { path = "Buildings.Passives.Bank", name = "Bank" },
    { path = "Buildings.Passives.ExplosiveTotem", name = "ExplosiveTotem" },
    { path = "Buildings.Passives.PoisonTotem", name = "PoisonTotem" },
    { path = "Buildings.Passives.RangeBuff", name = "RangeBuff" },
    { path = "Buildings.Passives.ShardBullets", name = "ShardBullets" },
    { path = "Buildings.Passives.ToxicTotem", name = "ToxicTotem" },
    { path = "Buildings.Passives.IndustrialBattery", name = "IndustrialBattery" },
}

for _, b in ipairs(buffs) do
    verifyBuilding(b.path, b.name, {
        types = { passive = true },
        affectedSlots = {{1, 0}},
        shapePattern = {{0, 0}}
    })
end

-- 3. Blockers
local blockers = {
    { path = "Buildings.Blockers.Blocker", name = "Base Blocker" },
    { path = "Buildings.Blockers.SlottedBlocker", name = "SlottedBlocker" },
    { path = "Buildings.Blockers.SlowBlocker", name = "SlowBlocker" },
    { path = "Buildings.Blockers.SmallBox", name = "SmallBox" },
    { path = "Buildings.Blockers.SmallFence", name = "SmallFence" },
}

for _, bl in ipairs(blockers) do
    verifyBuilding(bl.path, bl.name, {
        types = { blocker = true },
        shapePattern = {{0, 0}}
    })
end

-- 4. Main Turrets
local mainTurrets = {
    { path = "Buildings.MainTurrets.StandardMainTurret", name = "StandardMainTurret" },
    { path = "Buildings.MainTurrets.FastMainTurret", name = "FastMainTurret" },
    { path = "Buildings.MainTurrets.MainLazer", name = "MainLazer" },
}

for _, mt in ipairs(mainTurrets) do
    verifyBuilding(mt.path, mt.name)
end

print(string.format("--- Building Type Inheritance Tests Completed: %d passes, %d failures ---", passes, failures))
os.exit(failures > 0 and 1 or 0)
