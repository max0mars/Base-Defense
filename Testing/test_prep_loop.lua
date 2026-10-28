-- Testing/test_prep_loop.lua
-- Preparation phase rework: the five-battle loop of screens, the traveling
-- merchant, the alchemist and the scouting rule.

package.path = package.path .. ";./?.lua"

-- Mock love2d (every love.* function is a no-op)
local noop = function() end
local fontStub = { getWidth = function() return 10 end, getHeight = function() return 10 end, getWrap = function() return 10, { "" } end }
_G.love = setmetatable({
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

local failures = 0
local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

local PrepLoop = require("Game.Prep.PrepLoop")
local Merchant = require("Game.Prep.Merchant")
local Alchemist = require("Game.Prep.Alchemist")
local Scouting = require("Game.Prep.Scouting")
local MaterialRegistry = require("Game.Cards.MaterialRegistry")
local PlayerDeck = require("Game.Cards.PlayerDeck")

local function newState(extra)
    local ps = { battlesCompleted = 1, cash = 0, shopLevel = 1, scoutingLevel = 1, materials = {}, deck = PlayerDeck:new() }
    for k, v in pairs(extra or {}) do ps[k] = v end
    _G.PersistentState = ps
    return ps
end

-- -----------------------------------------------------------------------------
-- 1. The loop: battle 1 quote, 2 merchant, 3 alchemist, 4 merchant, 5 upgrades
-- -----------------------------------------------------------------------------
local expected = { "quote", "merchant", "alchemist", "merchant", "upgrades" }
for battle = 1, 10 do
    local want = expected[(battle - 1) % 5 + 1]
    assert(PrepLoop.screenAfter(battle) == want, "after battle " .. battle .. ": " .. want)
end

local ps = newState({ battlesCompleted = 2 })
local visit = PrepLoop.getVisit()
visit.marker = true
assert(PrepLoop.getVisit().marker, "the visit is kept while the preparation phase lasts")
ps.battlesCompleted = 3
assert(not PrepLoop.getVisit().marker and PrepLoop.getVisit().screen == "alchemist", "the next battle starts a fresh visit")

-- -----------------------------------------------------------------------------
-- 2. Merchant
-- -----------------------------------------------------------------------------
for level = 1, Merchant.MAX_LEVEL do
    newState({ shopLevel = level })
    assert(#Merchant.getStock({}) == Merchant.CARD_COUNT[level], "level " .. level .. " merchant carries " .. Merchant.CARD_COUNT[level] .. " cards")
end
assert(Merchant.investCost(1) == 100 and Merchant.investCost(2) == 200 and Merchant.investCost(4) == 800, "investing costs $100 and doubles each level")

ps = newState({ shopLevel = 1, cash = 1000 })
visit = {}
local stock = Merchant.getStock(visit)
assert(Merchant.getStock(visit) == stock, "the stock is fixed for the visit")
assert(Merchant.invest(visit), "invest in the merchant")
assert(ps.shopLevel == 2 and ps.cash == 900, "investing paid $100 and raised his level")
assert(not Merchant.invest(visit), "only one investment per visit")
assert(#Merchant.getStock(visit) == 3, "this visit's stock doesn't change after investing")
assert(#Merchant.getStock({}) == 4, "the next visit brings the bigger stock")

newState({ shopLevel = Merchant.MAX_LEVEL, cash = 100000 })
assert(not Merchant.invest({}), "can't invest past level " .. Merchant.MAX_LEVEL)
newState({ shopLevel = 1, cash = 99 })
assert(not Merchant.invest({}), "can't invest without the cash")

ps = newState({ cash = 100 })
local item = Merchant.getStock({})[1]
assert(Merchant.buy(item) and item.purchased and ps.cash == 100 - item.cost, "buying a card pays for it")
assert(#ps.deck:getCards() == 1, "the bought card goes into the deck")
assert(not Merchant.buy(item), "a sold card can't be bought again")

-- -----------------------------------------------------------------------------
-- 3. Alchemist
-- -----------------------------------------------------------------------------
local typedIds = {}
for _, mat in ipairs(MaterialRegistry.getTyped()) do typedIds[mat.id] = true end
local sawCounts = {}
for _ = 1, 200 do
    local offers = Alchemist.getOffers({})
    sawCounts[#offers] = true
    local seen = {}
    for _, offer in ipairs(offers) do
        assert(typedIds[offer.materialId] and not seen[offer.materialId], "offers are distinct typed materials") seen[offer.materialId] = true
        assert(offer.stock >= 1 and offer.stock <= 3, "1-3 in stock")
        assert(offer.price >= 25 and offer.price <= 80 and offer.price % 5 == 0, "price is $25-$80")
        if failures > 0 then break end
    end
    if failures > 0 then break end
end
assert(sawCounts[1] and sawCounts[2] and sawCounts[3] and not sawCounts[0] and not sawCounts[4], "1-3 materials on sale")

ps = newState({ cash = 1000 })
visit = {}
local offer = Alchemist.getOffers(visit)[1]
assert(Alchemist.getOffers(visit)[1] == offer, "the market is fixed for the visit")
offer.stock, offer.price = 2, 100
assert(Alchemist.buy(offer) and ps.materials[offer.materialId] == 1 and ps.cash == 900 and offer.stock == 1, "buying takes one unit from stock")
assert(Alchemist.buy(offer) and not Alchemist.buy(offer), "stock runs out")

ps = newState({ materials = { scrap = 2, energy_cells = 1, [MaterialRegistry.UNIVERSAL] = 5 } })
assert(not Alchemist.transmute("scrap"), "transmuting needs 3 of the same material")
assert(ps.materials[MaterialRegistry.UNIVERSAL] == 5, "Universal Essence never covers a transmute")
ps.materials.scrap = 7
assert(Alchemist.transmute("scrap") and ps.materials.scrap == 4 and ps.materials[MaterialRegistry.UNIVERSAL] == 6, "3 scrap -> 1 Universal Essence")
assert(not Alchemist.transmute(MaterialRegistry.UNIVERSAL), "Universal Essence can't be transmuted")

visit = {}
local typed = MaterialRegistry.getTyped()
assert(Alchemist.selectedMaterial(visit).id == typed[1].id, "the first typed material is picked by default")
assert(Alchemist.cycle(visit, -1).id == typed[#typed].id, "the arrows wrap around backwards")
assert(Alchemist.cycle(visit, 1).id == typed[1].id, "and forwards")

-- -----------------------------------------------------------------------------
-- 4. Scouting
-- -----------------------------------------------------------------------------
newState({ scoutingLevel = 1, discoveredEnemies = { Soldier = true } })
assert(Scouting.canSee("Grunt") and Scouting.canSee("Drone"), "level 1 reveals tier 0")
assert(not Scouting.canSee("Soldier"), "level 1 hides tier 1, even an enemy already met")
assert(Scouting.canSee("Tank"), "the boss is always revealed")
assert(Scouting.canSee("Turret Debuffer"), "aliases resolve to their enemy")
assert(not Scouting.canSee("NotAnEnemy"), "unknown enemies stay hidden")
_G.PersistentState.scoutingLevel = 2
assert(Scouting.canSee("Soldier") and not Scouting.canSee("Medic"), "level 2 reveals tier 1 but not tier 2")
_G.PersistentState.scoutingLevel = nil
assert(Scouting.getLevel() == 1, "scouting starts at level 1")

-- -----------------------------------------------------------------------------
-- 5. The preparation scene draws and handles every screen
-- -----------------------------------------------------------------------------
local prep = require("Scenes.preparation_scene")
prep.scene_manager = { switch = noop }
for battle = 0, 4 do
    newState({ battlesCompleted = battle, baseHP = 200, discoveredEnemies = { Grunt = true }, cash = 500 })
    prep:load(true)
    local ok, err = pcall(function()
        prep:draw()
        local area = prep:contentArea()
        prep:mousepressed(area.x + area.w / 2, area.y + area.h / 2, 1)
    end)
    assert(ok, "screen after battle " .. (battle + 1) .. " (" .. prep.visit.screen .. ") draws and takes clicks" .. (ok and "" or (": " .. tostring(err))))
end

-- -----------------------------------------------------------------------------
-- 6. Battle choices: material rewards, the elite option, artifact fallback
-- -----------------------------------------------------------------------------
local BattleManager = require("Game.Core.BattleManager")
local LevelManager = require("Game.Core.LevelManager")
local ArtifactManager = require("Game.Artifacts.ArtifactManager")
newState({ discoveredEnemies = { Grunt = true } })
local bm = BattleManager:new()
local lm = LevelManager:new(bm)

local function materialsPerChoiceSet(level, runs)
    local total = 0
    for _ = 1, runs do
        for _, choice in ipairs(lm:generateChoices(level)) do
            for _, r in ipairs(choice.rewards) do
                if r.type == BattleManager.REWARD_TYPES.UPGRADE_MATERIAL then total = total + 1 end
            end
        end
    end
    return total / runs
end
assert(materialsPerChoiceSet(1, 100) == 0, "battle 1 never offers a material")
for _, level in ipairs({ 2, 4, 11 }) do
    local avg = materialsPerChoiceSet(level, 300)
    assert(avg >= 1, string.format("battle %d: on average at least 1 of 3 choices offers a material (%.2f)", level, avg))
end

for _, level in ipairs({ 3, 8, 13 }) do
    local elites, artifactOnElite = 0, true
    for _, choice in ipairs(lm:generateChoices(level)) do
        if choice.isElite then
            elites = elites + 1
            local hasArtifact = false
            for _, r in ipairs(choice.rewards) do
                if r.type == BattleManager.REWARD_TYPES.RELIC then hasArtifact = true end
            end
            artifactOnElite = artifactOnElite and hasArtifact and choice.difficultyMultiplier == 2.5
        end
    end
    assert(elites == 1 and artifactOnElite, "battle " .. level .. " offers one 2.5x elite battle with an artifact")
end
local noElite = true
for _, level in ipairs({ 1, 2, 4, 6, 9 }) do
    for _, choice in ipairs(lm:generateChoices(level)) do noElite = noElite and not choice.isElite end
end
assert(noElite, "other battles have no elite option")
local sawSafe = false
for _, choice in ipairs(lm:generateChoices(3)) do sawSafe = sawSafe or choice.isSafe end
assert(sawSafe, "elite levels still keep a low-threat choice")

-- Elite rewards scale past the normal 2x budget (every reward comes out of it;
-- if they cost more than it, the cash is 0)
local eliteBudgetOk = true
for _ = 1, 200 do
    local sum, cash = 0, 0
    for _, r in ipairs(bm:generateRewards(2.5, 3)) do
        sum = sum + (r.value or 0)
        if r.type == BattleManager.REWARD_TYPES.GOLD then cash = r.amount end
    end
    local budget = math.floor(70 * 2.5 + 0.5)
    if cash > 0 then
        eliteBudgetOk = eliteBudgetOk and math.abs(sum - budget) <= 1
    else
        eliteBudgetOk = eliteBudgetOk and sum >= budget - 1
    end
end
assert(eliteBudgetOk, "elite battles get a 2.5x reward budget")

-- Artifact reward: a random artifact, or $500 once every artifact is owned
ps = newState({ cash = 0, artifacts = {} })
bm:applyRewards({ BattleManager.artifactReward() })
assert(#ArtifactManager.getOwnedIds() == 1 and ps.cash == 0, "the elite reward grants an artifact")
local origGrant = ArtifactManager.grantRandom
ArtifactManager.grantRandom = function() return nil end
bm:applyRewards({ BattleManager.artifactReward() })
ArtifactManager.grantRandom = origGrant
assert(ps.cash == 500, "with every artifact owned it pays $500 instead")

-- Every quote is attributed
local Quotes = require("Game.Prep.Quotes")
local attributed = true
for _, q in ipairs(Quotes.list) do attributed = attributed and type(q.text) == "string" and type(q.author) == "string" end
assert(attributed, "every quote has its text and who said it")

-- -----------------------------------------------------------------------------
-- 7. Layout: screens stay clear of the artifact strip; battle cards show every reward
-- -----------------------------------------------------------------------------
local MajorUpgrades = require("Game.Prep.MajorUpgrades")
newState({ battlesCompleted = 4, baseHP = 200, discoveredEnemies = { Grunt = true } })
prep:load(true)
local area = prep:contentArea()
local stripLabelTop = VIRTUAL_HEIGHT - 70 - 40 - 18
assert(area.y + area.h < stripLabelTop, "the screen area ends above the artifact strip's label")
local lowest = 0
for i = 1, #MajorUpgrades.list do
    local btn = MajorUpgrades.buyButtonRect(area, i)
    lowest = math.max(lowest, btn.y + btn.h)
end
assert(lowest <= area.y + area.h, "every major upgrade tile fits in the screen area")

-- A battle with many enemies and rewards: every reward line sits above the ENGAGE button
local printed = {}
local realPrintf = love.graphics.printf
love.graphics.printf = function(text, x, y) table.insert(printed, { text = tostring(text), y = y }) end
local busy = { enemies = {}, rewards = {}, difficultyMultiplier = 2.5, isElite = true, slotIndex = 1 }
for _, id in ipairs({ "Grunt", "Scout", "Soldier", "Medic", "Captain", "Tank" }) do table.insert(busy.enemies, { id = id }) end
for i = 1, 6 do table.insert(busy.rewards, { description = "Reward " .. i }) end
prep.levelChoices = { busy, busy, busy }
prep.levelSelectMode = "launch"
prep:drawLevelSelectWindow()
love.graphics.printf = realPrintf
local lastReward, buttonY = 0, nil
for _, p in ipairs(printed) do
    if p.text:match("^• Reward") then lastReward = math.max(lastReward, p.y) end
    if p.text == "ENGAGE THIS BATTLE" then buttonY = buttonY or p.y end
end
assert(buttonY and lastReward > 0 and lastReward + 16 < buttonY - 12, "all 6 rewards are drawn above the ENGAGE button")

print(string.format("\n%d failure(s)", failures))
if failures > 0 then os.exit(1) end
