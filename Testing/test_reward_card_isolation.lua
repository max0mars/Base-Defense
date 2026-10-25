-- Regression: late-game lag on card click, battle select and mulligan.
-- RewardSystem gave each reward the live game, and Reward:new built its preview
-- building straight from that config, so the card added to the deck carried
-- game + effectManager. initBattleDeck and Card:execute deep-copy card payloads,
-- so every battle copied the whole game graph (including older card copies),
-- growing exponentially until clicks and battle loads took seconds.

local function stubNamespace()
    return setmetatable({}, { __index = function()
        return function()
            return setmetatable({}, { __index = function() return function() return 10, 10 end end })
        end
    end })
end
_G.love = {
    graphics = stubNamespace(), mouse = stubNamespace(), keyboard = stubNamespace(), audio = stubNamespace(),
    filesystem = stubNamespace(), window = stubNamespace(), image = stubNamespace(), sound = stubNamespace(),
    math = { random = math.random, colorFromBytes = function(...) return ... end },
    timer = { getTime = os.clock }
}
love.mouse.getPosition = function() return 0, 0 end
love.graphics.getWidth = function() return 1280 end
love.graphics.getHeight = function() return 720 end
love.graphics.getDimensions = function() return 1280, 720 end
_G.VIRTUAL_WIDTH, _G.VIRTUAL_HEIGHT = 1280, 720
_G.SetGameScissor = function() end
_G.unpack = _G.unpack or table.unpack

-- Counts every table reachable from root (keys, values and metatables)
local function reach(root)
    local seen, n, stack = {}, 0, { root }
    while #stack > 0 do
        local v = table.remove(stack)
        if type(v) == "table" and not seen[v] then
            seen[v] = true
            n = n + 1
            for k, x in next, v do
                stack[#stack + 1] = k
                stack[#stack + 1] = x
            end
            local mt = getmetatable(v)
            if mt then stack[#stack + 1] = mt end
        end
    end
    return n
end

local realPrint = print
print = function() end -- silence game logging

local Reward = require("Game.Rewards.Reward")
local TurretIndex = require("Buildings.TurretIndex")

realPrint("--- STARTING REWARD CARD ISOLATION VERIFICATION ---")

-- 1. Reward:new must not turn the caller's config into a live building
local sentry = TurretIndex.common[1]
local cfg = {}
for k, v in pairs(sentry) do cfg[k] = v end
local fakeGame = { objects = {}, base = { x = 0, w = 100 } }
cfg.game = fakeGame
local keysBefore = {}
for k in pairs(cfg) do keysBefore[k] = true end

local reward = Reward:new(cfg)
for k in pairs(cfg) do
    assert(keysBefore[k], "Reward:new added '" .. tostring(k) .. "' to the caller's config")
end
assert(reward.dummyBuilding, "Reward should still build a preview building")
assert(reward.rawConfig.game == nil, "rawConfig must not carry the live game")
assert(reward.rawConfig.effectManager == nil, "rawConfig must not carry runtime building state")
realPrint("[PASS] Reward:new leaves the caller's config and rawConfig clean.")

-- 2. End to end: a battle-end card reward must enter the deck without runtime state
local MainLazer = require("Buildings.MainTurrets.MainLazer")
_G.PersistentState = {
    selectedMainTurret = "MainLazer", globalDifficulty = 1, battlesCompleted = 0, cash = 0,
    discoveredEnemies = { Grunt = true }, deck = MainLazer.getStartingDeck()
}
local game = require("Game.Core.GameManager")
game:load(nil, false)

local deckBefore = {}
for _, c in ipairs(PersistentState.deck:getCards()) do deckBefore[c] = c.quantity or 1 end

-- Draft until a building card lands in the deck (draft choices are random)
local drafted
for _ = 1, 50 do
    game.rewardSystem:activate("cards", 3)
    for i, choice in ipairs(game.rewardSystem.currentChoices) do
        if choice.reward.type == "building" then
            choice.state = "revealed"
            game.rewardSystem:selectReward(i)
            break
        end
    end
    for _, c in ipairs(PersistentState.deck:getCards()) do
        if not deckBefore[c] and c.payload and c.payload.config then drafted = c end
    end
    if drafted then break end
end
assert(drafted, "Expected a drafted building card in the deck")

local config = drafted.payload.config
assert(config.game == nil, "Drafted card config must not reference the live game")
assert(config.effectManager == nil, "Drafted card config must not carry an effectManager")
local size = reach(drafted.payload)
assert(size < 100, "Drafted card payload should be small, reaches " .. size .. " tables")
realPrint("[PASS] Drafted card enters the deck without runtime state (" .. size .. " tables).")

-- 3. Payload size stays flat across battles (no exponential copy chain)
local sizes = {}
for battle = 1, 3 do
    game:load(nil, false)
    local biggest = 0
    for _, pile in ipairs({ game.drawPile, game.hand }) do
        for _, c in ipairs(pile) do
            if c.id == drafted.id then biggest = math.max(biggest, reach(c.payload)) end
        end
    end
    assert(biggest > 0, "Drafted card should be in the draw pile or hand in battle " .. battle)
    sizes[battle] = biggest
end
assert(sizes[3] <= sizes[1], string.format("Drafted card copies grew across battles: %d -> %d -> %d", sizes[1], sizes[2], sizes[3]))
realPrint(string.format("[PASS] Drafted card copies stay flat across battles (%d -> %d -> %d tables).", sizes[1], sizes[2], sizes[3]))

realPrint("--- ALL REWARD CARD ISOLATION TESTS PASSED ---")
