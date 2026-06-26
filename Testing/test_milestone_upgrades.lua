-- Mock love global functions for scene loading
love = {
    mouse = {
        setVisible = function() end,
        getSystemCursor = function() return "cursor" end,
        setCursor = function() end,
        getPosition = function() return 0, 0 end
    },
    graphics = {
        getFont = function()
            return {
                getWidth = function() return 10 end,
                getHeight = function() return 10 end
            }
        end,
        newFont = function()
            return {
                getWidth = function() return 10 end,
                getHeight = function() return 10 end
            }
        end
    },
    math = {
        colorFromBytes = function(...) return ... end
    }
}

local preparation_scene = require("Scenes.preparation_scene")
local GameManager = require("Game.Core.GameManager")
local Base = require("Game.Core.Base")
local MainLazer = require("Buildings.MainTurrets.MainLazer")

print("--- Starting Milestone Upgrades Tests ---")
VIRTUAL_WIDTH = 800
VIRTUAL_HEIGHT = 600

-- Create a mock scene manager
local mockSceneManager = {
    switch = function(name) print("Switched scene to: " .. name) end
}
preparation_scene.scene_manager = mockSceneManager

-- 1. Mock _G.PersistentState
_G.PersistentState = {
    baseHP = 200,
    cash = 0,
    deck = nil,
    globalDifficulty = 1,
    battlesCompleted = 4, -- 4 battles completed
    startingTokens = 3,
    startingHandSize = 4,
    waveCompleteDrawSize = 4,
    incomeTokens = 3,
    startBattleExtraSlotsUnlocked = 0,
    discoveredEnemies = { ["Basic"] = true }
}

-- Load preparation scene (simulating completing the 5th battle)
preparation_scene:load(true)

print("Battles Completed:", _G.PersistentState.battlesCompleted)
print("Show Upgrade Choice overlay:", preparation_scene.showUpgradeChoice)

if _G.PersistentState.battlesCompleted == 5 then
    print("[PASS] Battles completed correctly incremented to 5.")
else
    print("[FAIL] Battles completed increment failed.")
end

if preparation_scene.showUpgradeChoice == true then
    print("[PASS] Upgrade choice overlay successfully active on 5th battle.")
else
    print("[FAIL] Upgrade choice overlay should be active.")
end

-- Simulating clicking Option 1: +1 Card Draw
local cardDrawChoice = preparation_scene.upgradeChoices[1]
print("Simulating click on: " .. cardDrawChoice.title)
preparation_scene:mousepressed(cardDrawChoice.x + 5, cardDrawChoice.y + 5, 1)

print("Show Upgrade Choice after click:", preparation_scene.showUpgradeChoice)
print("New Starting Hand Size:", _G.PersistentState.startingHandSize)
print("New Wave Complete Draw Size:", _G.PersistentState.waveCompleteDrawSize)

if preparation_scene.showUpgradeChoice == false then
    print("[PASS] Overlay dismissed after choice selection.")
else
    print("[FAIL] Overlay did not dismiss.")
end

if _G.PersistentState.startingHandSize == 5 and _G.PersistentState.waveCompleteDrawSize == 5 then
    print("[PASS] Card draw stats successfully incremented.")
else
    print("[FAIL] Card draw stats incorrect.")
end

-- Verify GameManager uses new stats
-- Define mock deck with cards
_G.PersistentState.deck = {
    getCards = function()
        return {
            { name = "Sentry", quantity = 10 }
        }
    end
}

local mockGame = {
    objects = {},
    testingMode = false,
    maxTokens = 3,
    tokens = 0,
    hand = {},
    drawPile = {},
    discardPile = {},
    spawnFloatingText = function() end
}
setmetatable(mockGame, { __index = GameManager })

mockGame:load(nil, false)
print("Game starting hand draw amount: (Expected 5) - Hand size is:", #mockGame.hand)
if #mockGame.hand == 5 then
    print("[PASS] GameManager successfully drew 5 cards starting hand.")
else
    print("[FAIL] GameManager starting hand size incorrect.")
end

-- Simulating completing 5 more battles and picking Option 2: +1 Token / Turn
_G.PersistentState.battlesCompleted = 9
preparation_scene:load(true)
local tokenChoice = preparation_scene.upgradeChoices[2]
print("Simulating click on: " .. tokenChoice.title)
preparation_scene:mousepressed(tokenChoice.x + 5, tokenChoice.y + 5, 1)

print("New Starting Tokens:", _G.PersistentState.startingTokens)
print("New Income Tokens:", _G.PersistentState.incomeTokens)

if _G.PersistentState.startingTokens == 4 and _G.PersistentState.incomeTokens == 4 then
    print("[PASS] Token stats successfully incremented.")
else
    print("[FAIL] Token stats incorrect.")
end

-- Re-check GameManager loader uses updated starting/max tokens
local anotherGame = {
    objects = {},
    testingMode = false
}
setmetatable(anotherGame, { __index = GameManager })
anotherGame:load(nil, false)
print("Game starting tokens: (Expected 4) - Tokens:", anotherGame.tokens)
print("Game max tokens: (Expected 4) - MaxTokens:", anotherGame.maxTokens)

if anotherGame.tokens == 4 and anotherGame.maxTokens == 4 then
    print("[PASS] GameManager initialized tokens and max tokens correctly using upgrades.")
else
    print("[FAIL] GameManager tokens initialization incorrect.")
end

-- Simulating completing 5 more battles and picking Option 3: +4 Initial Turret Slots
_G.PersistentState.battlesCompleted = 14
preparation_scene:load(true)
local slotsChoice = preparation_scene.upgradeChoices[3]
print("Simulating click on: " .. slotsChoice.title)
preparation_scene:mousepressed(slotsChoice.x + 5, slotsChoice.y + 5, 1)

print("New Start Battle Extra Slots Unlocked:", _G.PersistentState.startBattleExtraSlotsUnlocked)
if _G.PersistentState.startBattleExtraSlotsUnlocked == 1 then
    print("[PASS] Slots upgrade tracker incremented successfully.")
else
    print("[FAIL] Slots upgrade tracker incorrect.")
end

-- Verify slots are unlocked at start of battle in Base:initMainLazer
local baseConfig = {
    game = anotherGame,
    buildGrid = {
        x = 0,
        y = 100,
        cellSize = 25,
        width = 4,
        height = 16,
        buildings = {}
    }
}
local testBase = Base:new(baseConfig)
anotherGame.base = testBase

-- Count unlocked slots before initMainLazer
local countUnlockedBefore = 0
for s, val in pairs(testBase.buildGrid.unlocked) do
    if val then countUnlockedBefore = countUnlockedBefore + 1 end
end
print("Unlocked slots before init:", countUnlockedBefore)

testBase:initMainLazer(MainLazer)

-- Count unlocked slots after initMainLazer
local countUnlockedAfter = 0
for s, val in pairs(testBase.buildGrid.unlocked) do
    if val then countUnlockedAfter = countUnlockedAfter + 1 end
end
print("Unlocked slots after init (should be 12 + 4 = 16):", countUnlockedAfter)

if countUnlockedAfter == 16 then
    print("[PASS] Base successfully unlocked 4 extra starting slots.")
else
    print("[FAIL] Base failed to unlock correct number of extra starting slots.")
end

print("--- Milestone Upgrades Tests Completed ---")
