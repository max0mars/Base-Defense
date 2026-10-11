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

_G.PersistentState = {
    cash = 50,
    baseHP = 100,
    upcomingWaves = { { {} }, { {} } },
    upcomingSummaries = { { "wave1" }, { "wave2" } }
}

local GameManager = require("Game.Core.GameManager")
local game = setmetatable({}, GameManager)
game.tokens = 0
game.maxTokens = 3
game.objects = {}
game.animations = {}
game.hand = {}
game.discardPile = {}
game.drawPile = {}
game.consumedPile = {}
game.exiledPile = {}
game.base = { hp = 100, maxHp = 100 }
game.battleComplete = false
game.spawnFloatingText = function() end
game.gui = { incomeFeedback = { triggerSequence = function() end } }

local WaveSpawner = require("Game.Spawning.WaveSpawner")
game.WaveSpawner = WaveSpawner:new({ game = game })
game.WaveSpawner.waveState = "active"
game.WaveSpawner.waveList = { { {} } }

-- Add an enemy, an enemy bullet, and a player bullet
local enemy = { isType = function(self, t) return t == "enemy" end, destroyed = false }
local enemyBullet = { isType = function(self, t) return t == "bullet" end, targetType = "building", destroyed = false }
local playerBullet = { isType = function(self, t) return t == "bullet" end, targetType = "enemy", destroyed = false }
table.insert(game.objects, enemy)
table.insert(game.objects, enemyBullet)
table.insert(game.objects, playerBullet)

game:winBattle()

assert(game.battleComplete == true, "battleComplete should be true")
assert(_G.PersistentState.cash == 150, "Persistent cash should increase by 100")
assert(#_G.PersistentState.upcomingWaves == 0, "Upcoming waves should be emptied")
assert(game.WaveSpawner.waveState == "idle", "WaveSpawner state should be idle")
assert(#game.WaveSpawner.waveList == 0, "WaveSpawner waveList should be empty")
assert(enemy.destroyed == true, "Enemy should be destroyed")
assert(enemyBullet.destroyed == true, "Enemy bullet should be destroyed")
assert(playerBullet.destroyed == false, "Player bullet should not be destroyed by enemy filter")

print("test_win_battle: All assertions passed!")
