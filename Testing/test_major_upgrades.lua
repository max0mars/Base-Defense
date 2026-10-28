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

-- Anything else in love.graphics (canvases, particle systems...) is a no-op object
local noopObject = setmetatable({}, { __index = function() return function() end end })
setmetatable(love.graphics, { __index = function() return function() return noopObject end end })

local preparation_scene = require("Scenes.preparation_scene")
local GameManager = require("Game.Core.GameManager")
local Base = require("Game.Core.Base")
local MainLazer = require("Buildings.MainTurrets.MainLazer")

print("--- Starting Major Upgrades Tests ---")
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
    cardRemovals = 2,
    discoveredEnemies = { ["Basic"] = true }
}

local MajorUpgrades = require("Game.Prep.MajorUpgrades")
local failures = 0
local function check(condition, message)
    print((condition and "[PASS] " or "[FAIL] ") .. message)
    if not condition then failures = failures + 1 end
end

-- Load preparation scene (simulating completing the 5th battle)
preparation_scene:load(true)
check(_G.PersistentState.battlesCompleted == 5, "Battles completed incremented to 5")
check(preparation_scene.visit.screen == "upgrades", "The 5th battle opens the major upgrade screen")
check(_G.PersistentState.cardRemovals == 2, "No free card removal after the 5th battle")

-- Upgrades cost money now; each one has its own starting price
check(not MajorUpgrades.buy("card_draw"), "Can't buy an upgrade without the cash")
check(MajorUpgrades.price("card_draw") == 150 and MajorUpgrades.price("tokens") == 150, "Card draw and token income start at $150")
check(MajorUpgrades.price("slots") == 100 and MajorUpgrades.price("scouting") == 100, "Starting slots and scouting start at $100")
check(MajorUpgrades.price("max_mana") == 80 and MajorUpgrades.price("mana_regen") == 80, "Max mana and mana regen start at $80")
_G.PersistentState.cash = 1000
check(MajorUpgrades.buy("card_draw"), "Bought card draw")
check(_G.PersistentState.cash == 850, "Card draw cost $150")
check(MajorUpgrades.price("card_draw") == 300, "Card draw rises by $150")
check(MajorUpgrades.price("tokens") == 150, "Other upgrades keep their own price")
check(_G.PersistentState.startingHandSize == 5 and _G.PersistentState.waveCompleteDrawSize == 5, "Card draw stats incremented")

-- Clicking an upgrade's buy button on the screen buys it
local btn = MajorUpgrades.buyButtonRect(preparation_scene:contentArea(), 1)
_G.PersistentState.cash = 300
preparation_scene:mousepressed(btn.x + 5, btn.y + 5, 1)
check(_G.PersistentState.startingHandSize == 6 and _G.PersistentState.cash == 0, "Clicking the first tile's button buys card draw")

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
check(#mockGame.hand == 6, "GameManager draws the upgraded starting hand")

-- Buy +1 token income
_G.PersistentState.cash = 150
check(MajorUpgrades.buy("tokens"), "Bought token income")
check(_G.PersistentState.startingTokens == 4 and _G.PersistentState.incomeTokens == 4, "Token stats incremented")

-- Mana upgrades
_G.PersistentState.cash = 160
check(MajorUpgrades.buy("max_mana") and MajorUpgrades.buy("mana_regen"), "Bought max mana and mana regen")

-- Re-check GameManager loader uses updated starting/max tokens
local anotherGame = {
    objects = {},
    testingMode = false
}
setmetatable(anotherGame, { __index = GameManager })
anotherGame:load(nil, false)
print("Game starting tokens: (Expected 4) - Tokens:", anotherGame.tokens)
print("Game max tokens: (Expected 4) - MaxTokens:", anotherGame.maxTokens)

check(anotherGame.tokens == 4 and anotherGame.maxTokens == 4, "GameManager starts with the upgraded tokens")
check(anotherGame.maxMana == 125 and anotherGame.mana == 125, "GameManager starts with the upgraded max mana")
check(anotherGame.manaRegenPerWave == 35, "GameManager uses the upgraded mana regen")

-- Buy +4 starting slots
_G.PersistentState.cash = 100
check(MajorUpgrades.buy("slots"), "Bought starting slots")
check(_G.PersistentState.startBattleExtraSlotsUnlocked == 1, "Slots upgrade tracker incremented")

-- Pricing rules after the first purchase
check(MajorUpgrades.price("slots") == 150, "Starting slots rise by $50")
check(MajorUpgrades.price("max_mana") == 120, "Max mana rises by $40")
check(MajorUpgrades.price("tokens") == 300, "Token income rises by $150")
_G.PersistentState.cash = 100000
for _ = 1, 3 do MajorUpgrades.buy("max_mana") MajorUpgrades.buy("mana_regen") end
check(_G.PersistentState.upgradePurchases.max_mana == 4 and _G.PersistentState.upgradePurchases.mana_regen == 4, "Max mana and regen bought 4 times")
check(MajorUpgrades.isMaxed("max_mana") and not MajorUpgrades.buy("max_mana"), "Max mana caps after 4 upgrades")
check(MajorUpgrades.isMaxed("mana_regen") and not MajorUpgrades.buy("mana_regen"), "Mana regen caps after 4 upgrades")
for _ = 1, 10 do MajorUpgrades.buy("slots") end
check(_G.PersistentState.startBattleExtraSlotsUnlocked == 11 and not MajorUpgrades.isMaxed("slots"), "Starting slots never cap")
check(MajorUpgrades.price("slots") == 100 + 50 * 11, "Starting slots keep rising by $50")
MajorUpgrades.buy("card_draw")
check(MajorUpgrades.isMaxed("card_draw") and not MajorUpgrades.buy("card_draw"), "Card draw caps after 3 upgrades")
MajorUpgrades.buy("tokens") MajorUpgrades.buy("tokens")
check(MajorUpgrades.isMaxed("tokens") and not MajorUpgrades.buy("tokens"), "Token income caps after 3 upgrades")
_G.PersistentState.startingHandSize, _G.PersistentState.waveCompleteDrawSize = 6, 6
_G.PersistentState.startingTokens, _G.PersistentState.incomeTokens = 4, 4
_G.PersistentState.startBattleExtraSlotsUnlocked = 1
_G.PersistentState.maxMana, _G.PersistentState.manaRegenPerWave = 125, 35

-- Scouting tops out at level 4
_G.PersistentState.cash = 100000
check(MajorUpgrades.buy("scouting") and MajorUpgrades.price("scouting") == 200, "Scouting rises by $100")
MajorUpgrades.buy("scouting")
check(MajorUpgrades.price("scouting") == 300, "Scouting's next level costs $300")
MajorUpgrades.buy("scouting")
check(_G.PersistentState.scoutingLevel == 4, "Scouting rises to level 4")
check(MajorUpgrades.isMaxed("scouting") and not MajorUpgrades.buy("scouting"), "Scouting can't go past level 4")
_G.PersistentState.cash = 0

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

check(countUnlockedAfter == 16, "Base unlocks 4 extra starting slots")

-- Extra starting slots are spread evenly: each upgrade adds one slot to each quarter
local function layout(extra)
    _G.PersistentState.startBattleExtraSlotsUnlocked = extra
    local b = Base:new({ game = anotherGame, buildGrid = { x = 0, y = 100, cellSize = 25, width = 4, height = 16, buildings = {} } })
    anotherGame.base = b
    b:initMainLazer(MainLazer)
    return b.buildGrid
end
local plain = layout(0)
local function quarterCounts(grid)
    local counts = { 0, 0, 0, 0 }
    for s = 1, grid.width * grid.height do
        if grid.unlocked[s] and not plain.unlocked[s] then
            local x, y = ((s - 1) % grid.width) + 1, math.ceil(s / grid.width)
            local q = (y < 8.5 and 0 or 2) + (x < 2.5 and 1 or 2)
            counts[q] = counts[q] + 1
        end
    end
    return counts
end
for extra = 1, 3 do
    local grid = layout(extra)
    local c = quarterCounts(grid)
    check(c[1] == extra and c[2] == extra and c[3] == extra and c[4] == extra,
        string.format("%d slots upgrade(s): one new slot per quarter each time (%d/%d/%d/%d)", extra, c[1], c[2], c[3], c[4]))
    -- Mirror-symmetric, left to right and top to bottom
    local symmetric = true
    for s = 1, grid.width * grid.height do
        local x, y = ((s - 1) % grid.width) + 1, math.ceil(s / grid.width)
        local mirror = (y - 1) * grid.width + (grid.width + 1 - x)
        if (grid.unlocked[s] or false) ~= (grid.unlocked[mirror] or false) then symmetric = false end
        local fy = 17 - y
        if fy >= 1 and fy <= 16 and (grid.unlocked[s] or false) ~= (grid.unlocked[(fy - 1) * grid.width + x] or false) then symmetric = false end
    end
    check(symmetric, extra .. " slots upgrade(s): the layout is symmetric")
    if extra == 2 then
        for y = 1, 16 do
            local row = ""
            for x = 1, 4 do
                local s = (y - 1) * 4 + x
                row = row .. (plain.unlocked[s] and "#" or (grid.unlocked[s] and "+" or "."))
            end
            print("  " .. row)
        end
    end
end
_G.PersistentState.startBattleExtraSlotsUnlocked = 1

if failures > 0 then os.exit(1) end
print("--- Major Upgrades Tests Completed ---")
