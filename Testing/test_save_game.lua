-- Testing/test_save_game.lua
-- Save / load of a run: what is saved, when saving is off, and that a loaded
-- run (deck, merchant, alchemist, battle choices, waves) matches the saved one.

package.path = package.path .. ";./?.lua"

-- In-memory save folder
local files = {}
local filesystem = {
    write = function(name, text) files[name] = text return true end,
    read = function(name) return files[name] end,
    getInfo = function(name) return files[name] and { type = "file" } or nil end,
    remove = function(name) local had = files[name] ~= nil files[name] = nil return had end,
}

-- Mock love2d (every other love.* function is a no-op)
local noop = function() end
local fontStub = { getWidth = function() return 10 end, getHeight = function() return 10 end, getWrap = function() return 10, { "" } end }
_G.love = setmetatable({
    filesystem = filesystem,
    math = setmetatable({ random = math.random, colorFromBytes = function(...) return ... end }, { __index = function() return noop end }),
    timer = { getTime = function() return 0 end },
    mouse = setmetatable({ getPosition = function() return 0, 0 end, getSystemCursor = function() return {} end }, { __index = function() return noop end }),
    keyboard = { isDown = function() return false end },
    graphics = setmetatable({
        getFont = function() return fontStub end,
        newFont = function() return fontStub end,
        newCanvas = function() return {} end,
    }, { __index = function() return noop end }),
}, { __index = function() return setmetatable({}, { __index = function() return noop end }) end })
_G.VIRTUAL_WIDTH = 1280
_G.VIRTUAL_HEIGHT = 720
_G.paused = 0

-- Keep the battle generator's logging out of the results
local realPrint = print
print = function(first, ...)
    if type(first) == "string" and (first:find("^%[Wave") or first:find("^maxDistinct")) then return end
    realPrint(first, ...)
end

local failures = 0
local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

math.randomseed(7)

package.loaded["Game.Core.GameManager"] = { testingMode = false }
local GameManager = package.loaded["Game.Core.GameManager"]
local SaveGame = require("Game.Core.SaveGame")
local MainLazer = require("Buildings.MainTurrets.MainLazer")
local Card = require("Game.Cards.Card")
local PrepLoop = require("Game.Prep.PrepLoop")
local Merchant = require("Game.Prep.Merchant")
local Alchemist = require("Game.Prep.Alchemist")
local Quotes = require("Game.Prep.Quotes")
local LevelManager = require("Game.Core.LevelManager")
local BattleDirector = require("Game.Spawning.BattleDirector")
local BattleIndex = require("Game.Spawning.BattleIndex")
local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
local RewardIndex = require("Game.Rewards.RewardIndex")
local SpellCardRegistry = require("Spells.SpellCardRegistry")
local ArtifactManager = require("Game.Artifacts.ArtifactManager")
local ArtifactIndex = require("Game.Artifacts.ArtifactIndex")

local function newRun(extra)
    files = {}
    filesystem.read = function(name) return files[name] end
    local ps = {
        baseHP = 150, cash = 420, selectedMainTurret = "MainLazer", shopLevel = 2, scoutingLevel = 2,
        battlesCompleted = 2, globalDifficulty = 3, upgradePurchases = { hand = 1 },
        materials = { ["Card Removal"] = 1, energy = 4 }, cardRemovals = 1,
        discoveredEnemies = { Grunt = true, Scout = true }, activeMutations = {},
        damageTracker = { [1] = { Grunt = { damage = 30, color = {1, 0, 0, 1}, w = 20 } } },
        deck = MainLazer.getStartingDeck(),
    }
    for k, v in pairs(extra or {}) do ps[k] = v end
    _G.PersistentState = ps
    return ps
end

local function deckSummary(deck)
    local out = {}
    for _, card in ipairs(deck.cards) do
        table.insert(out, card.id .. ":" .. (card.tier or 1) .. "x" .. (card.quantity or 1))
    end
    return table.concat(out, ",")
end

local function countId(list, id)
    local n = 0
    for _, entry in ipairs(list) do if entry.id == id then n = n + 1 end end
    return n
end

-- -----------------------------------------------------------------------------
-- 1. A full preparation visit survives a save and load
-- -----------------------------------------------------------------------------
RewardIndex.injectCards(MainLazer.getUniqueCards())
local ps = newRun()

-- Deck changes: an upgraded card and a bought one
local deck = ps.deck
for _, card in ipairs(deck.cards) do
    if card.id == "sentry" then card.tier = 3 end
end
local visit = PrepLoop.getVisit()
local stock = Merchant.getStock(visit)
Merchant.buy(stock[1])
visit.invested = true
local offers = Alchemist.getOffers(visit)
Alchemist.buy(offers[1])
visit.alchemistSelected = 2
Quotes.get(visit)
ArtifactManager.grant(ArtifactIndex.list[1].id)

-- Battle choices (level 8 has an elite option) and the selected battle's waves
local lm = LevelManager:new()
visit.levelChoices = lm:generateChoices(8)
ps.upcomingMajorBattle = { level = 10, choices = lm:generateChoices(10) }
local chosen = visit.levelChoices[2]
ps.selectedBattle = chosen
ps.upcomingWaves, ps.upcomingSummaries = BattleDirector:new({}):generateBattle(chosen.difficultyMultiplier,
    { template = chosen.template, roster = chosen.roster, level = chosen.playerLevel })

local before = {
    deck = deckSummary(deck),
    cash = ps.cash,
    stock = {},
    offers = {},
    waves = {},
    quote = visit.quote,
    artifacts = table.concat(ArtifactManager.getOwnedIds(), ","),
}
for i, item in ipairs(stock) do before.stock[i] = item.card.id .. "|" .. item.cost .. "|" .. tostring(item.purchased) end
for i, offer in ipairs(offers) do before.offers[i] = offer.materialId .. "|" .. offer.stock .. "|" .. offer.price end
for w, wave in ipairs(ps.upcomingWaves) do
    local ids = {}
    for _, lane in ipairs(wave) do
        for _, class in ipairs(lane) do table.insert(ids, class.enemyId) end
        table.insert(ids, "/")
    end
    before.waves[w] = table.concat(ids, ",")
end

local saved = SaveGame.save("preparation")
assert(saved, "save succeeds")
assert(SaveGame.exists(), "save file exists")
assert(files[SaveGame.FILE] == files[SaveGame.BACKUP], "backup matches the save")

_G.PersistentState = nil
local scene = SaveGame.load()
assert(scene == "preparation", "resumes in preparation")
local loaded = _G.PersistentState
assert(loaded ~= nil and loaded ~= ps, "state replaced")

assert(deckSummary(loaded.deck) == before.deck, "deck ids, tiers and counts match")
assert(getmetatable(loaded.deck) == require("Game.Cards.PlayerDeck"), "deck is a PlayerDeck")
local sentry, fireball
for _, card in ipairs(loaded.deck.cards) do
    if card.id == "sentry" then sentry = card end
    if card.id == "spell_fireball" then fireball = card end
end
assert(sentry and getmetatable(sentry) == Card and sentry.tier == 3, "upgraded turret card rebuilt as a tier 3 Card")
assert(sentry and sentry.payload.buildingClass ~= nil, "turret card keeps its building class")
assert(fireball and fireball ~= SpellCardRegistry.Fireball and fireball.getCardDraw ~= nil,
    "spell card rebuilt as its own copy")
local surge
for _, card in ipairs(loaded.deck.cards) do if card.id == "inst_energy_surge_1" then surge = card end end
assert(surge and surge.statModifiers and surge.statModifiers.damage, "starting-deck-only card rebuilt")

assert(loaded.cash == before.cash and loaded.baseHP == 150 and loaded.shopLevel == 2, "plain fields match")
assert(loaded.materials.energy == ps.materials.energy, "materials match")
assert(loaded.damageTracker[1].Grunt.damage == 30, "damage history kept")
assert(table.concat(loaded.artifacts or {}, ",") == before.artifacts, "artifacts match")

local lvisit = loaded.prepVisit
assert(lvisit.battle == visit.battle and lvisit.screen == visit.screen, "visit kept")
assert(lvisit.invested == true and lvisit.merchantLevel == visit.merchantLevel, "merchant invest and level kept")
assert(#lvisit.merchantStock == #before.stock, "merchant stock size kept")
local stockOk = true
for i, item in ipairs(lvisit.merchantStock) do
    if item.card.id .. "|" .. item.cost .. "|" .. tostring(item.purchased) ~= before.stock[i] then stockOk = false end
    if not item.card.getCardDraw then stockOk = false end
end
assert(stockOk, "merchant stock cards, prices and sold flags kept")
assert(Merchant.getStock(lvisit) == lvisit.merchantStock, "merchant doesn't reroll after load")
local offersOk = #lvisit.alchemistOffers == #before.offers
for i, offer in ipairs(lvisit.alchemistOffers) do
    if offer.materialId .. "|" .. offer.stock .. "|" .. offer.price ~= before.offers[i] then offersOk = false end
end
assert(offersOk, "alchemist offers, stock and prices kept")
assert(lvisit.alchemistSelected == 2 and lvisit.quote == before.quote, "alchemist selection and quote kept")

assert(#lvisit.levelChoices == 3, "battle choices kept")
local templatesOk = true
for _, choice in ipairs(lvisit.levelChoices) do
    if BattleIndex[choice.templateId] ~= choice.template and choice.template ~= nil then
        local found = false
        for _, t in pairs(BattleIndex) do if t == choice.template then found = true end end
        if not found then templatesOk = false end
    end
    for _, entry in ipairs(choice.roster or {}) do
        if type(entry.class) ~= "table" or type(entry.class.new) ~= "function" then templatesOk = false end
    end
end
assert(templatesOk, "choice templates and roster classes rebuilt")
local hasElite = false
for _, choice in ipairs(lvisit.levelChoices) do if choice.isElite then hasElite = true end end
assert(hasElite, "elite choice kept")
assert(loaded.upcomingMajorBattle.level == 10 and #loaded.upcomingMajorBattle.choices == 1, "major battle kept")
assert(loaded.selectedBattle.templateId == chosen.templateId
    and loaded.selectedBattle.difficultyMultiplier == chosen.difficultyMultiplier, "selected battle kept")

local wavesOk = #loaded.upcomingWaves == #before.waves
for w, wave in ipairs(loaded.upcomingWaves) do
    local ids = {}
    for _, lane in ipairs(wave) do
        for _, class in ipairs(lane) do
            table.insert(ids, class.enemyId)
            if type(class.new) ~= "function" then wavesOk = false end
        end
        table.insert(ids, "/")
    end
    if table.concat(ids, ",") ~= before.waves[w] then wavesOk = false end
end
assert(wavesOk, "waves rebuilt with the same enemies")

-- -----------------------------------------------------------------------------
-- 2. Resume scene, unique cards, re-saving a loaded run
-- -----------------------------------------------------------------------------
assert(SaveGame.save("game"), "a loaded run saves again")
assert(SaveGame.load() == "game", "resumes at the battle")
local uniqueCount = 0
for _, list in pairs(RewardIndex) do
    if type(list) == "table" then uniqueCount = uniqueCount + countId(list, "low_power_operating") end
end
assert(uniqueCount == 1, "unique cards injected once across loads")

-- -----------------------------------------------------------------------------
-- 3. Dev mode and testing mode are never saved
-- -----------------------------------------------------------------------------
newRun({ devMode = {} })
assert(not SaveGame.save("preparation"), "dev run isn't saved")
assert(not SaveGame.exists(), "no file for a dev run")

newRun()
GameManager.testingMode = true
assert(not SaveGame.save("preparation"), "testing mode isn't saved")
assert(not SaveGame.exists(), "no file in testing mode")
GameManager.testingMode = false

newRun({ selectedMainTurret = false })
_G.PersistentState.selectedMainTurret = nil
assert(not SaveGame.save("preparation"), "a run without a main turret (not started) isn't saved")

-- -----------------------------------------------------------------------------
-- 4. Broken saves
-- -----------------------------------------------------------------------------
newRun()
assert(SaveGame.save("preparation"), "save before corrupting")
files[SaveGame.FILE] = files[SaveGame.FILE]:sub(1, 200) -- crash while writing
assert(SaveGame.load() == "preparation", "a half-written save falls back to the backup")

newRun()
SaveGame.save("preparation")
files[SaveGame.FILE] = files[SaveGame.FILE]:gsub("\"version\"%] = 1", "\"version\"] = 999")
files[SaveGame.BACKUP] = files[SaveGame.FILE]
_G.PersistentState = nil
assert(SaveGame.load() == nil and _G.PersistentState == nil, "a save from another version isn't loaded")

newRun()
files["savegame.lua"] = "return os.exit(1)"
files[SaveGame.BACKUP] = nil
assert(SaveGame.load() == nil, "a save can't run code")

newRun({ broken = function() end })
assert(not SaveGame.save("preparation"), "unsaveable state fails the save")
assert(not SaveGame.exists(), "a failed save writes nothing")

newRun()
SaveGame.save("preparation")
SaveGame.delete()
assert(not SaveGame.exists(), "delete removes the save and its backup")

-- -----------------------------------------------------------------------------
-- 5. Battle choices are rolled once per visit
-- -----------------------------------------------------------------------------
_G.paused = 0
newRun({ battlesCompleted = 3 })
local prep = require("Scenes.preparation_scene")
prep:load(false)
local firstChoices = _G.PersistentState.prepVisit.levelChoices
assert(firstChoices ~= nil and #firstChoices == 3, "prep caches its battle choices in the visit")
assert(SaveGame.exists(), "entering preparation saves")
SaveGame.load()
prep:load(false)
local again = _G.PersistentState.prepVisit.levelChoices
local same = #again == #firstChoices
for i, choice in ipairs(again) do
    if choice.templateId ~= firstChoices[i].templateId or choice.difficultyMultiplier ~= firstChoices[i].difficultyMultiplier then
        same = false
    end
end
assert(same, "reloading preparation shows the same battle choices")
assert(_G.PersistentState.battlesCompleted == 3, "resuming preparation doesn't count a battle")

print(string.format("\n%d failure(s)", failures))
if failures > 0 then os.exit(1) end
