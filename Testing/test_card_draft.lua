-- Testing/test_card_draft.lua
-- Card draft: drafted cards show their real type and cost, skip works,
-- and rarity weights scale with the current battle level.
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

-- Mock love2d (every love.* function is a no-op)
local noop = function() end
local font = { getHeight = function() return 10 end, getWidth = function() return 10 end,
               getWrap = function() return 0, {} end }
_G.love = setmetatable({
    graphics = setmetatable({ getFont = function() return font end }, { __index = function() return noop end }),
    mouse = { getPosition = function() return 0, 0 end },
}, { __index = function() return setmetatable({}, { __index = function() return noop end }) end })

_G.VIRTUAL_WIDTH = 1280
_G.VIRTUAL_HEIGHT = 720

-- Card flip animation is visual only; stub it so no particle systems are needed
package.loaded["Graphics.Animations.CardReveal"] = {
    new = function(_, reward) return { reward = reward, state = "revealed", update = function() end, draw = function() end } end
}

local RewardPool = require("Game.Rewards.RewardPool")
local RewardIndex = require("Game.Rewards.RewardIndex")
local RewardSystem = require("Game.Rewards.RewardSystem")
local CardFactory = require("Game.Cards.CardFactory")
local PlayerDeck = require("Game.Cards.PlayerDeck")

-- 1. CardFactory builds the right card type and cost for every reward in the index
local function findInIndex(pred)
    for _, rarity in ipairs(RewardPool.RarityOrder) do
        for _, item in ipairs(RewardIndex[rarity]) do
            if pred(item) then return item end
        end
    end
end

local instant = findInIndex(function(i) return i.type == "instant" end)
local spell = findInIndex(function(i) return i.type == "spell" end)
local passive = findInIndex(function(i) return i.iconCategory == "buff" end)
local turret = findInIndex(function(i) return i.iconCategory == "turret" end)

local instDraw = CardFactory.fromReward(instant):getCardDraw()
assert(instDraw.cardType == "Instant", "Instant draft card draws as Instant (got " .. tostring(instDraw.cardType) .. ")")
assert(instDraw.cost == instant.cost and instDraw.cost > 0, "Instant draft card shows its cost")

local spellDraw = CardFactory.fromReward(spell):getCardDraw()
assert(spellDraw.cardType == "Instant" and spellDraw.instantType == "Spell", "Spell draft card draws as Spell")
assert(spellDraw.cost == spell.cost, "Spell draft card shows its cost")

local passiveDraw = CardFactory.fromReward(passive):getCardDraw()
assert(passiveDraw.buildingType == "Buffer", "Passive draft card draws as Buffer, not Turret")
assert(passiveDraw.cost == passive.cost, "Passive draft card shows its cost")

local turretDraw = CardFactory.fromReward(turret):getCardDraw()
assert(turretDraw.buildingType == "Turret", "Turret draft card draws as Turret")
assert(turretDraw.cost == turret.cost, "Turret draft card shows its cost")

-- 2. Draft rarity scale by battle level
local w1 = RewardPool.getCardDraftRarityWeights(1)
assert(w1.rare == 0 and w1.epic == 0 and w1.legendary == 0, "Battle level 1 drafts only common/uncommon")

local prevLegendary, prevCommon, monotonic = -1, math.huge, true
for lvl = 1, 25 do
    local w = RewardPool.getCardDraftRarityWeights(lvl)
    if w.legendary < prevLegendary or w.common > prevCommon then monotonic = false end
    prevLegendary, prevCommon = w.legendary, w.common
end
assert(monotonic, "Higher battle levels never lower legendary odds or raise common odds")

local w20 = RewardPool.getCardDraftRarityWeights(20)
local w99 = RewardPool.getCardDraftRarityWeights(99)
assert(w20.legendary == w99.legendary and w20.common == w99.common, "Battle levels past 20 use the level 20 weights")

local w0 = RewardPool.getCardDraftRarityWeights(0)
assert(w0.common == w1.common, "Battle levels below 1 clamp to level 1")

-- 3. RewardSystem draft uses battle level (not shop level) and supports skip
_G.PersistentState = { battlesCompleted = 0, deck = PlayerDeck:new() }
local game = { shopLevel = 10, tokens = 0 }
local rs = RewardSystem:new(game)

local usedWeights
local origGen = RewardPool.generateChoicesWithWeights
RewardPool.generateChoicesWithWeights = function(self, count, weights)
    usedWeights = weights
    return origGen(self, count, weights)
end
rs:activate("cards", 3)
RewardPool.generateChoicesWithWeights = origGen

assert(usedWeights and usedWeights.legendary == 0 and usedWeights.rare == 0,
    "Draft at battle level 1 ignores shop level 10 rarity odds")
assert(#rs.currentChoices == 3, "Draft offers 3 choices")
for i, c in ipairs(rs.currentChoices) do
    assert(c.reward.deckCard ~= nil and c.reward.rewardCard == c.reward.deckCard:getCardDraw(),
        "Draft choice " .. i .. " displays the deck card it grants")
end

_G.PersistentState.selectedBattle = { playerLevel = 12 }
assert(rs:getBattleLevel() == 12, "Battle level comes from the selected battle")
_G.PersistentState.selectedBattle = nil

local deckSize = #_G.PersistentState.deck.cards
rs:mousepressed(rs.skipBtnX + 1, rs.skipBtnY + 1, 1)
assert(not rs.isActive, "Skip button closes the card draft")
assert(#_G.PersistentState.deck.cards == deckSize, "Skipping adds no card to the deck")

if failures > 0 then
    print(failures .. " test(s) failed")
    os.exit(1)
end
print("All card draft tests passed")
