-- Testing/test_leaderboard.lua
-- The online leaderboard client: JSON, names, which runs count, the outbox
-- (order, retries, waiting for a name, turned-down runs) and rebuilding a
-- submitted deck for the viewer. The network is replaced by a fake Http.

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
    keyboard = { isDown = function() return false end, setTextInput = noop, setKeyRepeat = noop },
    graphics = setmetatable({
        getFont = function() return fontStub end,
        newFont = function() return fontStub end,
        newCanvas = function() return {} end,
    }, { __index = function() return noop end }),
}, { __index = function() return setmetatable({}, { __index = function() return noop end }) end })
_G.VIRTUAL_WIDTH = 1280
_G.VIRTUAL_HEIGHT = 720

local realPrint = print
print = function(first, ...)
    if type(first) == "string" and first:find("^%[Leaderboard%]") then return end
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

math.randomseed(11)

-- Fake network: requests wait in `sent` until the test answers them
local sent = {}
package.loaded["Game.Online.Http"] = {
    request = function(method, url, body, callback)
        table.insert(sent, { method = method, url = url, body = body, callback = callback })
    end,
    update = noop,
}
local function answer(status, body)
    local req = table.remove(sent, 1)
    req.callback(status, body)
    return req
end

package.loaded["Game.Core.GameManager"] = { testingMode = false }
local GameManager = package.loaded["Game.Core.GameManager"]
local json = require("Libraries.json")
local Leaderboard = require("Game.Online.Leaderboard")
local MainLazer = require("Buildings.MainTurrets.MainLazer")
local RewardIndex = require("Game.Rewards.RewardIndex")

Leaderboard.URL = "https://example.test"

-- -----------------------------------------------------------------------------
-- 1. JSON
-- -----------------------------------------------------------------------------
local value = { name = 'Ann "the\\best"\n', level = 12, ratio = 0.25, ok = true, list = { 1, 2, 3 },
    nested = { { id = "a" }, { id = "b" } }, empty = json.EMPTY_ARRAY }
local back = json.decode(json.encode(value))
assert(back.name == value.name and back.level == 12 and back.ratio == 0.25 and back.ok == true,
    "JSON round-trips strings with escapes, numbers and booleans")
assert(#back.list == 3 and back.nested[2].id == "b", "JSON round-trips arrays and nested objects")
assert(json.encode({ empty = json.EMPTY_ARRAY }) == '{"empty":[]}', "EMPTY_ARRAY encodes as []")
assert(json.decode('"\\u00e9\\ud83d\\ude00"') == "\195\169\240\159\152\128", "\\u escapes (and surrogate pairs) decode to UTF-8")
local decoded = json.decode('{"scores":[{"id":1,"name":"x","deck":[],"note":null}]}')
assert(decoded.scores[1].name == "x" and decoded.scores[1].note == nil, "decodes a server response; null becomes nil")
assert(not pcall(json.decode, '{"a":1'), "malformed JSON is an error")
assert(not pcall(json.decode, '{"a":1} x'), "trailing characters are an error")

-- -----------------------------------------------------------------------------
-- 2. Names and player id
-- -----------------------------------------------------------------------------
assert(Leaderboard.cleanName("  Max\tM\195\169  ") == "MaxM", "names are trimmed to printable ASCII")
assert(Leaderboard.cleanName("   ") == nil, "a blank name is no name")
assert(#Leaderboard.cleanName(string.rep("a", 40)) == Leaderboard.NAME_MAX, "names are cut to NAME_MAX")
assert(Leaderboard.getName() == nil, "no name until one is picked")
local profile = json.decode(files["leaderboard_profile.json"])
assert(type(profile.playerId) == "string" and profile.playerId:match("^%x+$") and #profile.playerId == 32,
    "a 32-hex-digit player id is made and saved on first use")

-- -----------------------------------------------------------------------------
-- 3. Which runs count
-- -----------------------------------------------------------------------------
local function newRun()
    return { selectedMainTurret = "MainLazer", battlesCompleted = 0, deck = MainLazer.getStartingDeck(),
        artifacts = {}, totalDamageDealt = 1234.6, totalKills = 56 }
end

local dev = newRun()
dev.devMode = {}
Leaderboard.startRun(dev)
assert(dev.leaderboardRunId == nil and #sent == 0, "developer-mode runs aren't registered")

GameManager.testingMode = true
local testing = newRun()
Leaderboard.startRun(testing)
assert(testing.leaderboardRunId == nil, "testing-mode runs aren't registered")
GameManager.testingMode = false

Leaderboard.URL = ""
local offline = newRun()
Leaderboard.startRun(offline)
assert(offline.leaderboardRunId == nil, "nothing is registered while the leaderboard isn't set up")
Leaderboard.URL = "https://example.test"

local unregistered = newRun()
assert(Leaderboard.submitRun(unregistered) == nil, "a run that was never registered (an older save) isn't submitted")

-- -----------------------------------------------------------------------------
-- 4. Registering and submitting
-- -----------------------------------------------------------------------------
local run = newRun()
Leaderboard.startRun(run)
assert(type(run.leaderboardRunId) == "string" and #run.leaderboardRunId == 32, "a started run gets a run id")
Leaderboard.update(0)
assert(#sent == 1 and sent[1].method == "POST" and sent[1].url == "https://example.test/runs", "the start is sent to /runs")
local startBody = json.decode(sent[1].body)
assert(startBody.runId == run.leaderboardRunId and startBody.playerId == profile.playerId, "with the run and player ids")
Leaderboard.update(0)
assert(#sent == 1, "one request at a time")
answer(200, '{"ok":true}')

run.battlesCompleted = 6
run.artifacts = { "a1", "a2" }
local runId = Leaderboard.submitRun(run)
assert(runId == run.leaderboardRunId, "submitRun returns the run id")
assert(Leaderboard.submitRun(run) == nil, "a run is only submitted once")
assert(Leaderboard.getRunStatus(runId).state == "needs_name", "the result waits for a name")
Leaderboard.update(0)
assert(#sent == 0, "nothing is sent without a name")

assert(not Leaderboard.setName("   "), "a blank name is refused")
assert(Leaderboard.setName("  Max "), "a name is accepted")
assert(json.decode(files["leaderboard_profile.json"]).name == "Max", "the name is saved")

Leaderboard.update(0)
assert(#sent == 1 and sent[1].url == "https://example.test/scores", "with a name, the result goes to /scores")
assert(Leaderboard.getRunStatus(runId).state == "sending", "status: sending")
local score = json.decode(sent[1].body)
assert(score.name == "Max" and score.level == 7 and score.mainTurret == "MainLazer", "it holds the name, level reached and main turret")
assert(score.damageDealt == 1234 and score.kills == 56, "and the damage dealt and kills")
assert(#score.artifacts == 2 and score.artifacts[1] == "a1", "and the artifacts")
local copies = 0
for _, c in ipairs(score.deck) do copies = copies + c.quantity end
local expected = 0
for _, c in ipairs(run.deck.cards) do expected = expected + (c.quantity or 1) end
assert(#score.deck == #run.deck.cards and copies == expected and score.deck[1].tier, "and the deck as id / tier / quantity")

-- Server unreachable: kept, retried after RETRY_DELAY
answer(0, nil)
assert(Leaderboard.getRunStatus(runId).state == "offline", "no answer: status offline")
Leaderboard.update(1)
assert(#sent == 0, "not retried straight away")
Leaderboard.update(Leaderboard.RETRY_DELAY)
Leaderboard.update(0)
assert(#sent == 1, "retried after the delay")
answer(200, '{"ok":true,"rank":3}')
local status = Leaderboard.getRunStatus(runId)
assert(status.state == "sent" and status.rank == 3, "sent, with the rank the server gave")
assert(#json.decode(files["leaderboard_outbox.json"]) == 0, "the outbox is empty once everything is sent")

-- Turned down by the server
local fast = newRun()
Leaderboard.startRun(fast)
fast.battlesCompleted = 40
local fastId = Leaderboard.submitRun(fast)
Leaderboard.update(0)
answer(200, '{"ok":true}')
Leaderboard.update(0)
answer(422, '{"error":"too_fast","message":"Level 41 in 0m 03s is faster than the 13m 20s minimum."}')
status = Leaderboard.getRunStatus(fastId)
assert(status.state == "rejected" and status.message:find("faster"), "a turned-down run shows the server's reason")
Leaderboard.update(0)
assert(#sent == 0, "a turned-down run isn't retried")

-- -----------------------------------------------------------------------------
-- 5. The outbox survives a restart, empty lists included
-- -----------------------------------------------------------------------------
local later = newRun()
Leaderboard.startRun(later)
later.artifacts = {}
Leaderboard.submitRun(later)
local saved = json.decode(files["leaderboard_outbox.json"])
assert(#saved == 2 and saved[1].kind == "start" and saved[2].kind == "score", "waiting requests are saved in order")

package.loaded["Game.Online.Leaderboard"] = nil
local Restarted = require("Game.Online.Leaderboard")
Restarted.URL = "https://example.test"
assert(Restarted.getRunStatus(later.leaderboardRunId).state == "queued", "after a restart the waiting result is queued again")
Restarted.update(0)
assert(sent[1].url == "https://example.test/runs", "the run start is still sent first")
answer(200, '{"ok":true}')
Restarted.update(0)
assert(sent[1].body:find('"artifacts":%[%]'), "an empty artifact list is still sent as a JSON list")
answer(200, '{"ok":true,"rank":9}')

-- -----------------------------------------------------------------------------
-- 5b. Going offline during a run never costs the player their result
-- -----------------------------------------------------------------------------
local realTime = os.time
local clock = realTime()
os.time = function() return clock end
local offlineRun = newRun()
Restarted.startRun(offlineRun)
assert(offlineRun.leaderboardStartedAt == clock, "a run remembers when it started, by the player's clock")
Restarted.update(0)
answer(0, nil) -- offline: the start can't be sent
clock = clock + 3600 -- an hour of play later the run ends
offlineRun.battlesCompleted = 9
local offlineId = Restarted.submitRun(offlineRun)
Restarted.update(Restarted.RETRY_DELAY)
Restarted.update(0)
answer(0, nil) -- still offline
assert(Restarted.getRunStatus(offlineId).state == "offline", "a result stuck behind an unsent run start shows as offline")
Restarted.update(Restarted.RETRY_DELAY)
Restarted.update(0)
answer(200, '{"ok":true}') -- back online: the start goes through late
Restarted.update(0)
local offlineScore = json.decode(sent[1].body)
assert(offlineScore.runSeconds == 3600, "the result says how long the run took by the player's clock")
answer(409, '{"error":"already_submitted","message":"This run is already on the leaderboard."}')
assert(Restarted.getRunStatus(offlineId).state == "sent", "already on the leaderboard (an answer that got lost) counts as sent")
os.time = realTime

-- -----------------------------------------------------------------------------
-- 6. A leaderboard deck rebuilt for the viewer
-- -----------------------------------------------------------------------------
local entry = json.decode(json.encode({ mainTurret = "MainLazer", deck = score.deck }))
local cards = Restarted.buildDeckCards(entry)
assert(#cards == copies, "every copy of every card comes back")
assert(cards[1].getCardDraw ~= nil, "as real cards the deck viewer can draw")

-- A main turret's unique card, without putting it in the reward pool
local unique = MainLazer.getUniqueCards().rare[1]
local poolBefore = #RewardIndex.rare
cards = Restarted.buildDeckCards({ mainTurret = "MainLazer", deck = { { id = unique.id, tier = 2, quantity = 1 } } })
assert(#cards == 1 and cards[1].id == unique.id and cards[1].tier == 2, "unique cards are rebuilt too")
assert(#RewardIndex.rare == poolBefore, "without adding them to the reward pool")

cards = Restarted.buildDeckCards({ mainTurret = "MainLazer", deck = { { id = "no_such_card", tier = 1, quantity = 1 }, "junk" } })
assert(#cards == 0, "unknown cards and junk entries are skipped")

assert(Restarted.mainTurretName("FastMainTurret") == "Machine Gun", "main turret ids show as their names")
assert(Restarted.mainTurretName("Nope") == "Nope", "an unknown main turret shows its id")

-- -----------------------------------------------------------------------------
-- 7. The leaderboard scene: list, details, deck viewer, name editor
-- -----------------------------------------------------------------------------
local switchedTo
local sceneManager = require("Scenes.scene_manager")
sceneManager.switch = function(name) switchedTo = name end
local LeaderboardScene = require("Scenes.leaderboard_scene")

LeaderboardScene:load("gameover")
assert(LeaderboardScene.loading and sent[1].url == "https://example.test/scores?limit=" .. Restarted.FETCH_LIMIT,
    "opening the scene fetches the top runs")
local entries = {}
for i = 1, 12 do
    entries[i] = { id = i, name = "P" .. i, level = 20 - i, mainTurret = "MainLazer", damageDealt = 1000, kills = 10,
        durationSeconds = 600, createdAt = 1760000000000, deck = score.deck, artifacts = { require("Game.Artifacts.ArtifactIndex").list[1].id } }
end
answer(200, json.encode({ scores = entries }))
assert(not LeaderboardScene.loading and #LeaderboardScene.entries == 12 and LeaderboardScene:getPageCount() == 2,
    "the runs arrive, ranked, two pages of them")
assert(pcall(LeaderboardScene.draw, LeaderboardScene), "the list draws")

local view = LeaderboardScene.viewButtons[2]
LeaderboardScene:mousepressed(view.x + 1, view.y + 1, 1)
assert(LeaderboardScene.selected and LeaderboardScene.selected.entry.rank == 2, "VIEW opens that run's details")
assert(#LeaderboardScene.selected.artifacts == 1 and #LeaderboardScene.selected.cards == copies, "with its artifacts and deck")
assert(pcall(LeaderboardScene.draw, LeaderboardScene), "the details draw")
local deckBtn = LeaderboardScene.detailButtons.deck
LeaderboardScene:mousepressed(deckBtn.x + 1, deckBtn.y + 1, 1)
assert(LeaderboardScene.deckViewer.isActive and #LeaderboardScene.deckViewer.cards == copies, "VIEW DECK shows the run's deck")
assert(pcall(LeaderboardScene.draw, LeaderboardScene), "the deck viewer draws over it")
LeaderboardScene:keypressed("escape")
LeaderboardScene:keypressed("escape")
assert(not LeaderboardScene.deckViewer.isActive and not LeaderboardScene.selected, "escape closes the deck, then the details")

LeaderboardScene:keypressed("right")
assert(LeaderboardScene.page == 2, "arrow keys turn the page")

LeaderboardScene:startEditingName()
LeaderboardScene:textinput("Zed")
LeaderboardScene:keypressed("return")
assert(Restarted.getName() == "MaxZed" and not LeaderboardScene.editingName, "the name can be changed")
assert(pcall(LeaderboardScene.draw, LeaderboardScene), "the scene draws after editing the name")

LeaderboardScene:keypressed("escape")
assert(switchedTo == "gameover", "BACK returns to where the leaderboard was opened from")

-- A failed fetch shows a message instead of the list
LeaderboardScene:load()
answer(0, nil)
assert(LeaderboardScene.error and #LeaderboardScene.entries == 0, "a failed fetch shows an error")
assert(pcall(LeaderboardScene.draw, LeaderboardScene), "the error draws")

print(failures == 0 and "\nAll leaderboard tests passed" or ("\n" .. failures .. " leaderboard test(s) failed"))
os.exit(failures == 0 and 0 or 1)
