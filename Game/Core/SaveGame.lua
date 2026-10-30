-- =============================================================================
-- SAVE GAME (SaveGame.lua)
-- One autosave slot for the current run: _G.PersistentState written to disk.
--
-- When it saves
--   * entering the preparation phase, and after every click in it (purchases,
--     upgrades and removals can't be undone by quitting)      -> "preparation"
--   * right before a battle starts                              -> "game"
--   * the save is deleted when the run ends (game over)
-- Quitting mid-battle therefore restarts that battle, with the same waves.
-- Developer-mode and testing-mode runs are never saved.
--
-- The state is written as a Lua table literal. Most of it is plain data; the
-- few live objects in it are written as ids and rebuilt on load:
--   deck cards (Card / Spell / Instant)  {__card = {id, tier, quantity}}
--   the deck itself (PlayerDeck)         {__deck = {cards...}}
--   enemy classes (waves, rosters)       {__enemy = id}
--   battle templates                     {__battle = id}
-- Anything else that can't be written (a function, an unknown object) fails
-- the save loudly instead of writing a save that loads wrong.
-- =============================================================================

local Utils = require("Classes.Utils")

local SaveGame = {}

SaveGame.VERSION = 1
SaveGame.FILE = "savegame.lua"
-- Written first, so a crash while writing FILE still leaves a complete save
SaveGame.BACKUP = "savegame.lua.bak"

-- Keys of _G.PersistentState that are never saved
local SKIPPED_KEYS = { devMode = true }

-- -----------------------------------------------------------------------------
-- Rules
-- -----------------------------------------------------------------------------

--- True if the current run may be saved (or its save deleted).
function SaveGame.isEnabled()
    local ps = _G.PersistentState
    if not ps or ps.devMode ~= nil then return false end
    if require("Game.Core.GameManager").testingMode then return false end
    return ps.selectedMainTurret ~= nil
end

function SaveGame.exists()
    return love.filesystem.getInfo(SaveGame.FILE) ~= nil
        or love.filesystem.getInfo(SaveGame.BACKUP) ~= nil
end

function SaveGame.delete()
    love.filesystem.remove(SaveGame.FILE)
    love.filesystem.remove(SaveGame.BACKUP)
end

-- -----------------------------------------------------------------------------
-- Encoding: live objects -> plain data
-- -----------------------------------------------------------------------------

local function isCard(t)
    return type(t.id) == "string" and type(t.getCardDraw) == "function"
end

local function isEnemyClass(t)
    return type(rawget(t, "new")) == "function"
end

local function isBattleTemplate(t)
    return type(t.id) == "string" and type(t.isValidForBattle) == "function"
end

local encode

local function encodeCard(card)
    return { __card = { id = card.id, tier = card.tier or 1, quantity = card.quantity or 1 } }
end

function encode(value, path, visiting)
    local kind = type(value)
    if kind == "string" or kind == "number" or kind == "boolean" then return value end
    if kind ~= "table" then
        error("can't save " .. kind .. " at " .. path, 0)
    end
    if visiting[value] then error("can't save a cycle at " .. path, 0) end

    if getmetatable(value) == require("Game.Cards.PlayerDeck") then
        local cards = {}
        for i, card in ipairs(value.cards) do cards[i] = encodeCard(card) end
        return { __deck = cards }
    end
    if isCard(value) then return encodeCard(value) end
    if isBattleTemplate(value) then return { __battle = value.id } end
    if isEnemyClass(value) then
        local id = rawget(value, "enemyId")
        if not id then error("can't save an enemy class without an id at " .. path, 0) end
        return { __enemy = id }
    end
    if getmetatable(value) ~= nil then
        error("can't save an object at " .. path, 0)
    end

    visiting[value] = true
    local out = {}
    for k, v in pairs(value) do
        local keyKind = type(k)
        if keyKind ~= "string" and keyKind ~= "number" then
            error("can't save a " .. keyKind .. " key at " .. path, 0)
        end
        out[k] = encode(v, path .. "." .. tostring(k), visiting)
    end
    visiting[value] = nil
    return out
end

--- Plain-data copy of a run state, ready to write. Errors if anything in it can't be saved.
function SaveGame.encodeState(ps)
    local out = {}
    for k, v in pairs(ps) do
        if not SKIPPED_KEYS[k] then out[k] = encode(v, tostring(k), {}) end
    end
    return out
end

-- -----------------------------------------------------------------------------
-- Decoding: plain data -> live objects
-- -----------------------------------------------------------------------------

local function findReward(id)
    for _, list in pairs(require("Game.Rewards.RewardIndex")) do
        if type(list) == "table" then
            for _, reward in ipairs(list) do
                if reward.id == id then return reward end
            end
        end
    end
end

local function findInRegistry(registry, id)
    for _, entry in pairs(registry) do
        if type(entry) == "table" and entry.id == id then return entry end
    end
end

--- A fresh deck card for `id`, built the way it was first made: from the main
--- turret's starting deck (which has cards found nowhere else), the reward pool,
--- or the spell / instant registries.
local function newCard(id, mainTurretId)
    local Card = require("Game.Cards.Card")
    local ok, turret = pcall(require, "Buildings.MainTurrets." .. tostring(mainTurretId))
    if ok and turret.getStartingDeck then
        local deck = turret.getStartingDeck()
        for _, card in ipairs(deck and deck.cards or {}) do
            if card.id == id then
                -- Spells and instants in the starting deck are the shared registry objects
                return getmetatable(card) == Card and card or Utils.deepCopy(card)
            end
        end
    end
    local reward = findReward(id)
    -- The main turret's unique cards, for callers that haven't injected them
    -- into the reward pool (the leaderboard shows other players' decks)
    if not reward and ok and turret.getUniqueCards then
        for rarity, cards in pairs(turret.getUniqueCards() or {}) do
            for _, card in ipairs(cards) do
                if card.id == id then
                    reward = card
                    reward.rarity = reward.rarity or rarity
                end
            end
        end
    end
    if reward then return require("Game.Cards.CardFactory").fromReward(reward, reward) end
    local entry = findInRegistry(require("Instants.InstantCardRegistry"), id)
        or findInRegistry(require("Spells.SpellCardRegistry"), id)
    if entry then return Utils.deepCopy(entry) end
end

--- A deck card rebuilt from { id, tier, quantity } (nil if the id is unknown).
local function decodeCard(saved, mainTurretId)
    local card = newCard(saved.id, mainTurretId)
    if not card then
        print("[SaveGame] Unknown card '" .. tostring(saved.id) .. "' dropped from the save")
        return nil
    end
    card.tier = saved.tier
    card.quantity = saved.quantity
    if card.payload then card.payload.rewardCard = nil end -- cached art is per tier
    return card
end
SaveGame.decodeCard = decodeCard

local function enemyClass(id)
    local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
    for _, enemy in ipairs(EnemyRegistry.allEnemies or {}) do
        if enemy.id == id then return enemy.class end
    end
    error("unknown enemy '" .. tostring(id) .. "'", 0)
end

local function battleTemplate(id)
    for _, template in pairs(require("Game.Spawning.BattleIndex")) do
        if type(template) == "table" and template.id == id then return template end
    end
    error("unknown battle template '" .. tostring(id) .. "'", 0)
end

local function decode(value, mainTurretId)
    if type(value) ~= "table" then return value end
    if value.__deck then
        local deck = require("Game.Cards.PlayerDeck"):new()
        for _, saved in ipairs(value.__deck) do
            local card = decodeCard(saved.__card, mainTurretId)
            if card then table.insert(deck.cards, card) end
        end
        return deck
    end
    if value.__card then return decodeCard(value.__card, mainTurretId) end
    if value.__enemy then return enemyClass(value.__enemy) end
    if value.__battle then return battleTemplate(value.__battle) end
    local out = {}
    for k, v in pairs(value) do out[k] = decode(v, mainTurretId) end
    return out
end

--- Rebuilds a run state from SaveGame.encodeState output.
function SaveGame.decodeState(data)
    -- Unique cards must be in the reward pool before cards are rebuilt from it
    local ok, turret = pcall(require, "Buildings.MainTurrets." .. tostring(data.selectedMainTurret))
    if ok and turret.getUniqueCards then
        require("Game.Rewards.RewardIndex").injectCards(turret.getUniqueCards())
    end
    -- Builds the enemy classes waves and rosters point at
    require("Game.Spawning.EnemyRegistry"):reset()
    return decode(data, data.selectedMainTurret)
end

-- -----------------------------------------------------------------------------
-- Writing and reading
-- -----------------------------------------------------------------------------

local function serialize(value, indent, out)
    local kind = type(value)
    if kind == "string" then
        table.insert(out, string.format("%q", value))
    elseif kind == "number" then
        if value ~= value then
            table.insert(out, "0/0")
        elseif value == math.huge or value == -math.huge then
            table.insert(out, value > 0 and "math.huge" or "-math.huge")
        elseif value == math.floor(value) and math.abs(value) < 2 ^ 53 then
            table.insert(out, string.format("%d", value))
        else
            table.insert(out, string.format("%.17g", value))
        end
    elseif kind == "boolean" then
        table.insert(out, tostring(value))
    else
        local inner = indent .. "  "
        table.insert(out, "{\n")
        -- Sorted keys keep the file stable between saves
        local keys = {}
        for k in pairs(value) do table.insert(keys, k) end
        table.sort(keys, function(a, b)
            if type(a) == type(b) then return a < b end
            return type(a) == "number"
        end)
        for _, k in ipairs(keys) do
            table.insert(out, inner .. "[")
            serialize(k, inner, out)
            table.insert(out, "] = ")
            serialize(value[k], inner, out)
            table.insert(out, ",\n")
        end
        table.insert(out, indent .. "}")
    end
end

--- Saves the current run. `scene` is where Continue resumes: "preparation" or "game".
-- Returns true on success; does nothing (returns false) when saving is disabled.
function SaveGame.save(scene)
    if not SaveGame.isEnabled() then return false end
    local ok, result = pcall(SaveGame.encodeState, _G.PersistentState)
    if not ok then
        print("[SaveGame] Save failed: " .. tostring(result))
        return false
    end
    local out = { "return " }
    serialize({ version = SaveGame.VERSION, scene = scene, state = result }, "", out)
    local text = table.concat(out)
    if not love.filesystem.write(SaveGame.BACKUP, text) then
        print("[SaveGame] Save failed: couldn't write " .. SaveGame.BACKUP)
        return false
    end
    if not love.filesystem.write(SaveGame.FILE, text) then
        print("[SaveGame] Couldn't write " .. SaveGame.FILE .. "; the backup has this save")
    end
    return true
end

local function parse(text, name)
    if not text then return nil end
    local chunk
    if setfenv then
        chunk = loadstring(text, name)
        if chunk then setfenv(chunk, { math = { huge = math.huge } }) end
    else
        chunk = load(text, name, "t", { math = { huge = math.huge } })
    end
    if not chunk then return nil end
    local ok, data = pcall(chunk)
    if ok and type(data) == "table" and data.version == SaveGame.VERSION and type(data.state) == "table" then
        return data
    end
end

local function readSave()
    for _, file in ipairs({ SaveGame.FILE, SaveGame.BACKUP }) do
        if love.filesystem.getInfo(file) then
            local data = parse(love.filesystem.read(file), file)
            if data then return data end
            print("[SaveGame] " .. file .. " is unreadable or from another version")
        end
    end
end

--- Loads the saved run into _G.PersistentState.
-- @return string|nil: the scene to resume ("preparation" or "game"), nil if there's no usable save
function SaveGame.load()
    local data = readSave()
    if not data then return nil end
    local ok, state = pcall(SaveGame.decodeState, data.state)
    if not ok then
        print("[SaveGame] Load failed: " .. tostring(state))
        return nil
    end
    _G.PersistentState = state
    return data.scene == "game" and "game" or "preparation"
end

return SaveGame
