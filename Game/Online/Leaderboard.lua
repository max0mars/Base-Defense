-- =============================================================================
-- LEADERBOARD (Leaderboard.lua)
-- The online leaderboard: the highest level each run reached, with the run's
-- deck and artifacts. The server is the Cloudflare Worker in Server/leaderboard.
--
-- A run is registered with the server when it starts (POST /runs) and its
-- result submitted at game over (POST /scores). The server times the run from
-- its own clock and turns down results reached impossibly fast. Developer-mode
-- and testing-mode runs are never registered or submitted.
--
-- Requests that can't reach the server wait in an outbox file and are retried,
-- in order, until they get an answer; a result is only sent once the player
-- has picked a name.
--
-- Files (save folder)
--   leaderboard_profile.json  { playerId, name }
--   leaderboard_outbox.json   requests not sent yet
-- =============================================================================

local Http = require("Game.Online.Http")
local json = require("Libraries.json")

local Leaderboard = {}

-- The deployed Worker, e.g. "https://base-defense-leaderboard.<account>.workers.dev".
-- Empty turns the leaderboard off.
Leaderboard.URL = ""

Leaderboard.NAME_MAX = 16
Leaderboard.FETCH_LIMIT = 50
Leaderboard.RETRY_DELAY = 30 -- seconds before retrying after the server couldn't be reached

local PROFILE_FILE = "leaderboard_profile.json"
local OUTBOX_FILE = "leaderboard_outbox.json"

local profile -- { playerId, name }, loaded on first use
local outbox  -- list of { path, body, runId, kind }
local sending = false
local retryTimer = 0
local runStatus = {} -- runId -> { state, message, rank }

-- -----------------------------------------------------------------------------
-- Files
-- -----------------------------------------------------------------------------

local function readJson(file)
    if not love.filesystem.getInfo(file) then return nil end
    local ok, data = pcall(json.decode, love.filesystem.read(file) or "")
    if ok and type(data) == "table" then return data end
    print("[Leaderboard] " .. file .. " is unreadable; starting it over")
end

local function writeJson(file, data)
    local ok, text = pcall(json.encode, data)
    if not ok or not love.filesystem.write(file, text) then
        print("[Leaderboard] Couldn't write " .. file)
    end
end

local function newId()
    local digits = {}
    for i = 1, 32 do digits[i] = string.format("%x", math.random(0, 15)) end
    return table.concat(digits)
end

local function getProfile()
    if not profile then
        profile = readJson(PROFILE_FILE) or {}
        if type(profile.playerId) ~= "string" or #profile.playerId ~= 32 then
            profile.playerId = newId()
            writeJson(PROFILE_FILE, profile)
        end
    end
    return profile
end

local function getOutbox()
    if not outbox then
        outbox = readJson(OUTBOX_FILE) or {}
        for _, item in ipairs(outbox) do
            if item.kind == "score" then runStatus[item.runId] = { state = "queued" } end
        end
    end
    return outbox
end

local function saveOutbox()
    writeJson(OUTBOX_FILE, #outbox > 0 and outbox or json.EMPTY_ARRAY)
end

-- -----------------------------------------------------------------------------
-- Player
-- -----------------------------------------------------------------------------

function Leaderboard.isConfigured()
    return Leaderboard.URL ~= ""
end

--- The player's leaderboard name, or nil if they haven't picked one.
function Leaderboard.getName()
    return getProfile().name
end

--- A name cleaned up for the leaderboard: printable ASCII, trimmed, at most
--- NAME_MAX characters. Nil if nothing is left.
function Leaderboard.cleanName(name)
    name = tostring(name or ""):gsub("[^\32-\126]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    name = name:sub(1, Leaderboard.NAME_MAX)
    return name ~= "" and name or nil
end

--- Sets the player's name. Returns false if it's empty once cleaned up.
function Leaderboard.setName(name)
    name = Leaderboard.cleanName(name)
    if not name then return false end
    getProfile().name = name
    writeJson(PROFILE_FILE, profile)
    retryTimer = 0 -- a result may have been waiting for the name
    return true
end

-- -----------------------------------------------------------------------------
-- Runs
-- -----------------------------------------------------------------------------

--- True if a run counts for the leaderboard (not developer or testing mode).
function Leaderboard.isEligible(ps)
    if not Leaderboard.isConfigured() or not ps or ps.devMode ~= nil then return false end
    if require("Game.Core.GameManager").testingMode then return false end
    return ps.selectedMainTurret ~= nil
end

local function enqueue(item)
    table.insert(getOutbox(), item)
    saveOutbox()
end

--- Registers a run that just started (its main turret is chosen): the server
--- times the run from now.
function Leaderboard.startRun(ps)
    if not Leaderboard.isEligible(ps) then return end
    ps.leaderboardRunId = newId()
    enqueue({ kind = "start", runId = ps.leaderboardRunId, path = "/runs",
        body = { runId = ps.leaderboardRunId, playerId = getProfile().playerId } })
end

--- The run's deck as { id, tier, quantity } entries.
function Leaderboard.encodeDeck(deck)
    local out = {}
    for _, card in ipairs(deck and deck.getCards and deck:getCards() or {}) do
        table.insert(out, { id = card.id, tier = card.tier or 1, quantity = card.quantity or 1 })
    end
    return out
end

--- Submits a finished run. Returns its run id, or nil if it doesn't count.
function Leaderboard.submitRun(ps)
    if not Leaderboard.isEligible(ps) or not ps.leaderboardRunId or ps.leaderboardSubmitted then return nil end
    ps.leaderboardSubmitted = true
    local artifacts = {}
    for _, id in ipairs(ps.artifacts or {}) do table.insert(artifacts, id) end
    enqueue({ kind = "score", runId = ps.leaderboardRunId, path = "/scores", body = {
        runId = ps.leaderboardRunId,
        playerId = getProfile().playerId,
        level = (ps.battlesCompleted or 0) + 1,
        mainTurret = ps.selectedMainTurret,
        damageDealt = math.floor(ps.totalDamageDealt or 0),
        kills = ps.totalKills or 0,
        deck = Leaderboard.encodeDeck(ps.deck),
        artifacts = artifacts,
    } })
    runStatus[ps.leaderboardRunId] = { state = "queued" }
    return ps.leaderboardRunId
end

--- Where a submitted run is: { state, message, rank }. States: "queued",
--- "sending", "needs_name", "offline" (will retry), "sent", "rejected".
function Leaderboard.getRunStatus(runId)
    getOutbox() -- results waiting from an earlier session are queued
    local status = runId and runStatus[runId]
    if status and status.state == "queued" and not Leaderboard.getName() then
        return { state = "needs_name" }
    end
    return status
end

-- -----------------------------------------------------------------------------
-- Sending
-- -----------------------------------------------------------------------------

local function decodeBody(body)
    local ok, data = pcall(json.decode, body or "")
    return ok and type(data) == "table" and data or {}
end

-- Arrays read back from the outbox file lose their array-ness when empty
local function prepareBody(item)
    local body = item.body
    if item.kind == "score" then
        body.name = Leaderboard.getName()
        if #(body.deck or {}) == 0 then body.deck = json.EMPTY_ARRAY end
        if #(body.artifacts or {}) == 0 then body.artifacts = json.EMPTY_ARRAY end
    end
    return json.encode(body)
end

local function finish(item, state, data)
    table.remove(outbox, 1)
    saveOutbox()
    if item.kind == "score" then
        runStatus[item.runId] = { state = state, message = data.message or data.error, rank = data.rank }
    end
end

local function sendNext()
    local item = getOutbox()[1]
    if not item then return end
    if item.kind == "score" and not Leaderboard.getName() then return end -- waits for a name

    sending = true
    if item.kind == "score" then runStatus[item.runId] = { state = "sending" } end
    Http.request("POST", Leaderboard.URL .. item.path, prepareBody(item), function(status, body, err)
        sending = false
        local data = decodeBody(body)
        if status >= 200 and status < 300 then
            finish(item, "sent", data)
        elseif status >= 400 and status < 500 then
            print(string.format("[Leaderboard] %s turned down (%d): %s", item.path, status, tostring(data.message or data.error)))
            finish(item, "rejected", data)
        else
            -- No answer, or a server error: try again later
            print(string.format("[Leaderboard] %s failed (%d): %s", item.path, status, tostring(err or data.error)))
            retryTimer = Leaderboard.RETRY_DELAY
            if item.kind == "score" then runStatus[item.runId] = { state = "offline" } end
        end
    end)
end

--- Call every frame: delivers responses and sends whatever is waiting.
function Leaderboard.update(dt)
    Http.update()
    if not Leaderboard.isConfigured() or sending then return end
    if retryTimer > 0 then
        retryTimer = retryTimer - dt
        return
    end
    sendNext()
end

-- -----------------------------------------------------------------------------
-- Reading
-- -----------------------------------------------------------------------------

--- Fetches the top runs. `callback(entries)` on success, `callback(nil, message)` on failure.
--- Each entry: { id, name, level, mainTurret, damageDealt, kills, deck, artifacts, createdAt }.
function Leaderboard.fetchTop(callback)
    if not Leaderboard.isConfigured() then
        callback(nil, "The leaderboard isn't set up.")
        return
    end
    Http.request("GET", Leaderboard.URL .. "/scores?limit=" .. Leaderboard.FETCH_LIMIT, nil, function(status, body, err)
        local data = decodeBody(body)
        if status == 200 and type(data.scores) == "table" then
            callback(data.scores)
        elseif status == 0 then
            print("[Leaderboard] Fetch failed: " .. tostring(err))
            callback(nil, "Couldn't reach the leaderboard.")
        else
            callback(nil, "The leaderboard sent an error (" .. status .. ").")
        end
    end)
end

--- A leaderboard entry's deck rebuilt as cards (one entry per copy), for the deck viewer.
function Leaderboard.buildDeckCards(entry)
    local decodeCard = require("Game.Core.SaveGame").decodeCard
    local cards = {}
    for _, saved in ipairs(entry.deck or {}) do
        if type(saved) == "table" and type(saved.id) == "string" then
            local ok, card = pcall(decodeCard, { id = saved.id, tier = tonumber(saved.tier) or 1,
                quantity = tonumber(saved.quantity) or 1 }, entry.mainTurret)
            if ok and card then
                for _ = 1, card.quantity or 1 do table.insert(cards, card) end
            end
        end
    end
    return cards
end

--- Display name of a main turret id ("FastMainTurret" -> "Machine Gun").
function Leaderboard.mainTurretName(id)
    local ok, turret = pcall(require, "Buildings.MainTurrets." .. tostring(id))
    if ok and type(turret) == "table" and turret.template and turret.template.name then
        return turret.template.name
    end
    return tostring(id or "?")
end

return Leaderboard
