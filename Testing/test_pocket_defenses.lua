-- Testing/test_pocket_defenses.lua
-- Pocket Defenses: spawned turrets get a rarity rolled at a flat rate
-- and their card colour matches that rarity.
package.path = "./?.lua;" .. package.path

local failures = 0
local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

-- Mock love2d (every love.* function is a no-op, random uses math.random)
local noop = function() end
local font = { getHeight = function() return 10 end, getWidth = function() return 10 end,
               getWrap = function() return 0, {} end }
_G.love = setmetatable({
    graphics = setmetatable({ getFont = function() return font end }, { __index = function() return noop end }),
    math = { random = function(...) return math.random(...) end },
}, { __index = function() return setmetatable({}, { __index = function() return noop end }) end })

_G.VIRTUAL_WIDTH = 1280
_G.VIRTUAL_HEIGHT = 720

local RewardPool = require("Game.Rewards.RewardPool")
local RewardIndex = require("Game.Rewards.RewardIndex")
local InstantCardRegistry = require("Instants.InstantCardRegistry")

local function makeGame(battleLevel)
    return {
        hand = {},
        rewardSystem = { getBattleLevel = function() return battleLevel end },
        spawnFloatingText = noop,
    }
end

-- Rarity of each cost-1 turret, straight from the reward index
local turretRarity = {}
for rarity, group in pairs(RewardIndex) do
    if type(group) == "table" then
        for _, reward in ipairs(group) do
            if reward.cost == 1 and reward.building and reward.type == "building"
               and reward.iconCategory == "turret" then
                turretRarity[reward.id] = rarity
            end
        end
    end
end

-- 1. rollRarity respects weights
math.randomseed(1)
local allRare = { common = 0, uncommon = 0, rare = 10, epic = 0, legendary = 0 }
local onlyRare = true
for _ = 1, 200 do
    if RewardPool.rollRarity(allRare) ~= "rare" then onlyRare = false end
end
assert(onlyRare, "rollRarity only returns rarities with weight")
assert(RewardPool.rollRarity({ common = 0, uncommon = 0, rare = 0, epic = 0, legendary = 0 }) == "common",
    "rollRarity falls back to common when all weights are zero")

-- 2. Spawned cards carry a rarity that matches the turret's real rarity, and draw in that colour
local function runPocket(battleLevel, runs)
    local counts = {}
    local allMatch, allColoured, allFree = true, true, true
    for _ = 1, runs do
        local game = makeGame(battleLevel)
        InstantCardRegistry.PocketDefenses.customExecute(game)
        for _, card in ipairs(game.hand) do
            local rarity = card.payload.rarity
            counts[rarity] = (counts[rarity] or 0) + 1
            if turretRarity[card.id] ~= rarity then allMatch = false end
            if card:getCardDraw().rarity ~= rarity then allColoured = false end
            if card:getCost() ~= 0 or not card.isConsume then allFree = false end
        end
    end
    return counts, allMatch, allColoured, allFree
end

math.randomseed(42)
local low, matchLow, colouredLow, freeLow = runPocket(1, 300)
assert(matchLow, "Level 1: every spawned card's rarity matches its turret's rarity")
assert(colouredLow, "Level 1: card draw uses the rolled rarity for its colour")
assert(freeLow, "Level 1: spawned cards still cost 0 and are consumed")
assert((low.common or 0) > (low.uncommon or 0) and (low.uncommon or 0) > (low.rare or 0),
    "Level 1: common > uncommon > rare")
assert((low.rare or 0) > 0, "Level 1: rares can appear")

-- 3. Rarity is a flat rate: same seed gives identical results at any battle level
math.randomseed(42)
local high, matchHigh, colouredHigh = runPocket(20, 300)
assert(matchHigh, "Level 20: every spawned card's rarity matches its turret's rarity")
assert(colouredHigh, "Level 20: card draw uses the rolled rarity for its colour")
local same = true
for _, r in ipairs(RewardPool.RarityOrder) do
    if (low[r] or 0) ~= (high[r] or 0) then same = false end
end
assert(same, "Rarity odds don't change with battle level")

print(string.format("  level 1:  common %d, uncommon %d, rare %d",
    low.common or 0, low.uncommon or 0, low.rare or 0))
print(string.format("  level 20: common %d, uncommon %d, rare %d",
    high.common or 0, high.uncommon or 0, high.rare or 0))

-- 4. Hand limit still respected
local fullGame = makeGame(1)
for i = 1, 9 do fullGame.hand[i] = {} end
InstantCardRegistry.PocketDefenses.customExecute(fullGame)
assert(#fullGame.hand == 10, "Stops adding cards when the hand is full (10)")

if failures > 0 then
    print(failures .. " test(s) failed")
    os.exit(1)
end
print("All Pocket Defenses tests passed")
