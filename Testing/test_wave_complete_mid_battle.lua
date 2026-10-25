-- Regression: completing wave 5 of a battle with waves remaining crashed with
-- "attempt to call method 'getMutationOptions' (a nil value)". The in-battle
-- mutation menu outlived the registry API it called; mutations now trigger
-- between battles (preparation_scene), so a mid-battle wave goes to "preparing".

_G.love = {
    graphics = {
        getFont = function() return { getHeight = function() return 10 end, getWidth = function() return 10 end } end,
        print = function() end,
        rectangle = function() end,
        setColor = function() end
    },
    mouse = { getPosition = function() return 0, 0 end, setVisible = function() end },
    math = { colorFromBytes = function() return 1, 1, 1, 1 end, random = math.random },
    timer = { getTime = function() return 0 end }
}

local GameManager = require("Game.Core.GameManager")

local function newGameAtWaveEnd(wave)
    _G.PersistentState = {
        cash = 0,
        baseHP = 100,
        upcomingWaves = { { {} }, { {} } },
        upcomingSummaries = { { "next" }, { "after" } }
    }
    local game = setmetatable({}, GameManager)
    game.pulseTimer = 0
    game.animations = {}
    game.objects = {}
    game.tokens = 0
    game.maxTokens = 3
    game.hand = {}
    game.discardPile = {}
    game.drawPile = {}
    game.consumedPile = {}
    game.exiledPile = {}
    game.wave = wave
    game.base = { hp = 100, maxHp = 100 }
    game.gui = {
        update = function() end,
        incomeFeedback = { triggerSequence = function() end }
    }
    local noop = { update = function() end }
    game.WaveSpawner = { waveState = "complete", update = function() end }
    game.inventory = noop
    game.inputHandler = noop
    local effects = {
        update = function() end,
        triggerEvent = function() end,
        clearWaveEffects = function() end,
        recalculateStats = function() end
    }
    game.playerEffectManager = effects
    game.enemyEffectManager = effects
    game:setState("wave")
    return game
end

print("--- STARTING MID-BATTLE WAVE COMPLETION VERIFICATION ---")

for _, wave in ipairs({ 5, 8, 10 }) do
    local game = newGameAtWaveEnd(wave)
    local ok, err = pcall(game.update, game, 0)
    assert(ok, "Completing wave " .. wave .. " mid-battle crashed: " .. tostring(err))
    assert(game:isState("preparing"), "Wave " .. wave .. " should move to preparing, got " .. tostring(game.state))
    print("[PASS] Wave " .. wave .. " completes mid-battle and moves to preparing.")
end

print("--- ALL MID-BATTLE WAVE COMPLETION TESTS PASSED ---")
