-- Testing/test_game_over.lua
-- The game over screen: run totals (damage dealt, kills) and base hits grouped by level.


package.path = package.path .. ";./?.lua"

-- Mock love2d (every love.* function is a no-op; GameManager pulls in the whole game)
local noop = function() end
local fontStub = { getWidth = function() return 10 end, getHeight = function() return 10 end, getWrap = function() return 10, { "" } end }
_G.love = setmetatable({
    math = setmetatable({ random = math.random, colorFromBytes = function(...) return ... end }, { __index = function() return noop end }),
    timer = { getTime = function() return 0 end },
    mouse = setmetatable({ getPosition = function() return 0, 0 end }, { __index = function() return noop end }),
    keyboard = { isDown = function() return false end, setTextInput = noop, setKeyRepeat = noop },
    graphics = setmetatable({
        getFont = function() return fontStub end,
        newFont = function() return fontStub end,
        newCanvas = function() return {} end,
        getWidth = function() return 1280 end,
        getHeight = function() return 720 end,
    }, { __index = function() return noop end }),
}, { __index = function() return setmetatable({}, { __index = function() return noop end }) end })
_G.VIRTUAL_WIDTH = 1280
_G.VIRTUAL_HEIGHT = 720
_G.SetGameScissor = noop
_G.paused = 0
math.atan2 = math.atan2 or math.atan

local failures = 0
local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

-- Fake network for the leaderboard: requests wait in `sent` until answered
local sent = {}
package.loaded["Game.Online.Http"] = {
    request = function(method, url, body, callback) table.insert(sent, { url = url, body = body, callback = callback }) end,
    update = noop,
}

local game = require("Game.Core.GameManager")
local menu = require("Scenes.menu_scene")
local Enemy = require("Enemies.Enemy")
local game_over_scene = require("Scenes.game_over_scene")

menu.scene_manager = { switch = noop }
menu:keypressed("return")
_G.PersistentState.selectedMainTurret = "MainLazer"
_G.PersistentState.discoveredEnemies = { Grunt = true }
_G.PersistentState.artifacts = {}
game:load(nil, false)
game:setState("wave")
local ps = _G.PersistentState

-- 1. A new run starts its totals at zero
assert(ps.totalDamageDealt == 0 and ps.totalKills == 0, "a new run starts with no damage dealt or kills")

-- 2. Damage dealt (any source, spells included, no overkill) and kills add up
local function enemy(hp)
    local e = Enemy:new({ game = game, x = 300, y = 300, name = "Grunt", maxHp = hp })
    game:addObject(e)
    return e
end
local a = enemy(100)
a:takeDamage(30, "physical")
assert(ps.totalDamageDealt == 30, "damage without a turret behind it (e.g. a spell) counts")
a:takeDamage(500, "physical")
assert(ps.totalDamageDealt == 100 and ps.totalKills == 1, "overkill doesn't count; the kill does")
local b = enemy(50)
b:takeDamage(50, "fire")
assert(ps.totalDamageDealt == 150 and ps.totalKills == 2, "totals carry across enemies")

-- An enemy reaching the base isn't a kill
local c = enemy(50)
c.reachedBase = true
game:EnemyDied(c)
assert(ps.totalKills == 2, "an enemy that reached the base isn't a kill")

-- 3. Base hits are grouped by level, biggest hitters first, wrapping long levels
local history = {
    { level = 2, name = "Grunt", damage = 10 },
    { level = 1, name = "Grunt", damage = 5 },
    { level = 2, name = "Tank", damage = 40 },
}
for i = 1, 12 do table.insert(history, { level = 3, name = "E" .. i, damage = i }) end
local rows = game_over_scene.buildRows(history)
assert(#rows == 4, "levels 1, 2 and two rows for level 3's 12 enemies")
assert(rows[1].level == 1 and rows[2].level == 2 and rows[3].level == 3, "rows are in level order")
assert(rows[2].enemies[1].name == "Tank" and rows[2].levelDamage == 50, "a level lists its biggest hitter first, with its total")
assert(rows[3].first and not rows[4].first and #rows[3].enemies == 11 and #rows[4].enemies == 1,
    "a level with more enemies than fit wraps onto a continued row")

-- 4. The screen loads and draws with the run's numbers
game_over_scene.scene_manager = { switch = noop, scenes = { menu = menu } }
ps.battlesCompleted = 4
game.base:takeDamage(20, "physical", 0, 0, { name = "Grunt" })
game_over_scene:load()
assert(game_over_scene.level == 5 and game_over_scene.totalDamage == 150 and game_over_scene.totalKills == 2,
    "the screen shows the level reached and the run totals")
assert(#game_over_scene.rows >= 1 and game_over_scene.rows[#game_over_scene.rows].level == 5, "the base hit is listed under its level")
local ok, err = pcall(game_over_scene.draw, game_over_scene)
assert(ok, "the screen draws: " .. tostring(err))

-- 4b. Each enemy lists how many of it hit the base that level ("x 3")
for _ = 1, 2 do game.base:takeDamage(20, "physical", 0, 0, { name = "Grunt" }) end
game.base:takeDamage(5, "physical", 0, 0, { name = "Speeder" })
local counts = {}
for _, item in ipairs(game.base:getProcessedDamageHistory()) do
    if item.level == 5 then counts[item.name] = item end
end
assert(counts.Grunt and counts.Grunt.hits == 3 and counts.Grunt.damage == 60, "three Grunts hit the base: x 3, 60 damage")
assert(counts.Speeder and counts.Speeder.hits == 1, "one Speeder: x 1")
game_over_scene:load()
ok, err = pcall(game_over_scene.draw, game_over_scene)
assert(ok, "the screen draws with hit counts: " .. tostring(err))
-- An entry from an older save has no count: it still draws (without one)
_G.PersistentState.damageTracker[5].Grunt.hits = nil
game_over_scene:load()
ok, err = pcall(game_over_scene.draw, game_over_scene)
assert(ok, "and with an older save's entry that has no count: " .. tostring(err))

-- 5. The run's artifacts are shown, and View Deck opens the run's deck
local ArtifactIndex = require("Game.Artifacts.ArtifactIndex")
ps.artifacts = { ArtifactIndex.list and ArtifactIndex.list[1] and ArtifactIndex.list[1].id or "buckshot_choke" }
ok, err = pcall(game_over_scene.draw, game_over_scene)
assert(ok, "the screen draws with artifacts: " .. tostring(err))

ps.deck = require("Buildings.MainTurrets.MainLazer").getStartingDeck()
local copies = 0
for _, c in ipairs(ps.deck:getCards()) do copies = copies + (c.quantity or 1) end
assert(#game_over_scene.getDeckCards() == copies and copies > 0, "the deck view lists every copy of every card")
local layout = game_over_scene:getLayout()
game_over_scene:mousepressed(layout.viewDeck.x + 5, layout.viewDeck.y + 5, 1)
assert(game_over_scene.deckViewer.isActive and #game_over_scene.deckViewer.cards == copies, "View Deck opens the deck")
ok, err = pcall(game_over_scene.draw, game_over_scene)
assert(ok, "the screen draws with the deck open: " .. tostring(err))
local switched = false
game_over_scene.scene_manager.scenes.menu = { startRun = function() switched = true end }
game_over_scene:mousepressed(layout.retry.x + 5, layout.retry.y + 5, 1)
assert(not switched and not game_over_scene.deckViewer.isActive, "a click with the deck open only closes it")
game_over_scene:mousepressed(layout.viewDeck.x + 5, layout.viewDeck.y + 5, 1)
game_over_scene:keypressed("escape")
assert(not game_over_scene.deckViewer.isActive, "Escape closes the deck view")

-- 6. The run goes onto the leaderboard (after the player picks a name)
local Leaderboard = require("Game.Online.Leaderboard")
assert(Leaderboard.getRunStatus(game_over_scene.leaderboardRunId) == nil, "with the leaderboard off, nothing is submitted")
Leaderboard.URL = "https://example.test"
Leaderboard.startRun(ps)
Leaderboard.update(0)
table.remove(sent, 1).callback(200, '{"ok":true}')
game_over_scene:load()
local status = Leaderboard.getRunStatus(game_over_scene.leaderboardRunId)
assert(status and status.state == "needs_name", "a finished run waits for the player's name")
ok, err = pcall(game_over_scene.draw, game_over_scene)
assert(ok, "the screen draws with the name box: " .. tostring(err))

local input = game_over_scene.nameInput
game_over_scene:mousepressed(input.x + 5, input.y + 5, 1)
game_over_scene:textinput("Ada")
game_over_scene:mousepressed(layout.submitName.x + 5, layout.submitName.y + 5, 1)
assert(Leaderboard.getName() == "Ada", "typing a name and pressing SUBMIT sets it")
Leaderboard.update(0)
assert(#sent == 1 and sent[1].url == "https://example.test/scores" and sent[1].body:find('"level":5'),
    "then the run is sent, with the level it reached")
table.remove(sent, 1).callback(200, '{"ok":true,"rank":2}')
assert(Leaderboard.getRunStatus(game_over_scene.leaderboardRunId).rank == 2, "and the rank comes back")
ok, err = pcall(game_over_scene.draw, game_over_scene)
assert(ok, "the screen draws with the rank: " .. tostring(err))

-- 7. YOUR RANK: the runs around this one, shown once they arrive
assert(game_over_scene.tab == "hits", "the base hits show until the run's place arrives")
game_over_scene:update(0)
assert(#sent == 1 and sent[1].url == "https://example.test/scores/around?runId=" .. game_over_scene.leaderboardRunId,
    "once the run is on the leaderboard, its place is fetched")
game_over_scene:update(0)
assert(#sent == 1, "only once")
local function around(rank, you)
    return { id = rank, rank = rank, name = "P" .. rank, level = 10 - rank, mainTurret = "MainLazer",
        damageDealt = 100, kills = 5, createdAt = 1760000000000, deck = {}, artifacts = {}, you = you }
end
table.remove(sent, 1).callback(200, require("Libraries.json").encode({ rank = 2, total = 9,
    scores = { around(1), around(2, true), around(3), around(4), around(5) } }))
assert(game_over_scene.tab == "rank" and #game_over_scene.around.scores == 5, "then the screen switches to YOUR RANK")
ok, err = pcall(game_over_scene.draw, game_over_scene)
assert(ok, "the screen draws the runs around this one: " .. tostring(err))

game_over_scene:mousepressed(layout.hitsTab.x + 5, layout.hitsTab.y + 5, 1)
assert(game_over_scene.tab == "hits", "the BASE HITS tab switches back")
game_over_scene:mousepressed(layout.rankTab.x + 5, layout.rankTab.y + 5, 1)
assert(game_over_scene.tab == "rank", "and YOUR RANK shows the place again")

game_over_scene:load() -- back from the leaderboard screen
assert(Leaderboard.getRunStatus(game_over_scene.leaderboardRunId).state == "sent" and #sent == 0,
    "coming back to the screen doesn't submit the run again")
local switchedTo
game_over_scene.scene_manager.switch = function(name) switchedTo = name end
game_over_scene:mousepressed(layout.leaderboard.x + 5, layout.leaderboard.y + 5, 1)
assert(switchedTo == "leaderboard", "the Leaderboard button opens the leaderboard")

-- 8. Main Menu goes back to the title screen
switchedTo = nil
game_over_scene:mousepressed(layout.mainMenu.x + 5, layout.mainMenu.y + 5, 1)
assert(switchedTo == "menu", "the Main Menu button goes to the title screen")

print("--- Game Over Tests Completed with " .. failures .. " failures ---")
os.exit(failures == 0 and 0 or 1)
