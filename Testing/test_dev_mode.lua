-- Testing/test_dev_mode.lua
-- Developer mode: started from the title screen with F1, lasts for the run, and
-- each F key does its job in battle / between battles (and nothing in a normal run).

package.path = package.path .. ";./?.lua"

-- Mock love2d (every love.* function is a no-op; GameManager pulls in the whole game)
local noop = function() end
local fontStub = { getWidth = function() return 10 end, getHeight = function() return 10 end, getWrap = function() return 10, { "" } end }
_G.love = setmetatable({
    math = setmetatable({ random = math.random, colorFromBytes = function(...) return ... end }, { __index = function() return noop end }),
    timer = { getTime = function() return 0 end },
    mouse = setmetatable({ getPosition = function() return 0, 0 end }, { __index = function() return noop end }),
    keyboard = { isDown = function() return false end },
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

local DevMode = require("Game.Dev.DevMode")
local Enemy = require("Enemies.Enemy")
local game = require("Game.Core.GameManager")
local menu = require("Scenes.menu_scene")

-- 1. Starting a run from the title screen
local switchedTo
menu.scene_manager = { switch = function(name) switchedTo = name end }
menu:keypressed("return")
assert(not DevMode.isActive(), "Enter starts a normal run (no dev mode)")
assert(not DevMode.keypressed("f8"), "F keys do nothing in a normal run")
menu:keypressed("f1")
assert(DevMode.isActive() and switchedTo == "new_game", "F1 on the title screen starts a new run in dev mode")
assert(_G.PersistentState.baseHP == 200 and _G.PersistentState.cash == 0, "The dev run starts from the normal new-run state")

local function loadGame()
    local ps = _G.PersistentState
    ps.selectedMainTurret = "MainLazer"
    ps.discoveredEnemies = { Grunt = true }
    game:load(nil, false)
end

local function makeEnemy()
    local e = Enemy:new({ game = game, x = 400, y = 300, size = 20, maxHp = 50, hp = 50 })
    game:addObject(e)
    return e
end

-- 2. Battle keys
loadGame()
assert(DevMode.keypressed("f2", game) and DevMode.isOn("infiniteTokens"), "F2 turns on unlimited tokens")
game:update(0)
assert(game.tokens >= DevMode.TOKENS and game.mana >= DevMode.MANA, "Unlimited tokens keeps tokens and mana topped up")
game.tokens = 0
game:update(0)
assert(game.tokens >= DevMode.TOKENS, "Spending tokens is refilled on the next frame")

DevMode.keypressed("f3", game)
local hp = game.base.hp
game.base:takeDamage(50, "ballistic")
assert(DevMode.isOn("invincible") and game.base.hp == hp, "F3 makes the base invincible")

DevMode.keypressed("f4", game)
local picker = game.gui.itemPicker
assert(picker.isActive, "F4 opens the item picker")
DevMode.keypressed("f4", game)
assert(not picker.isActive, "F4 again closes it")

-- Picking a spell puts it straight into the hand, ready to cast
local blizzard
for _, entry in ipairs(picker.items) do
    if entry.item.id == "spell_blizzard" then blizzard = entry end
end
assert(blizzard and blizzard.category == "spell", "Picker lists the ice spells (Blizzard)")
local handSize = #game.hand
picker.isActive = true
picker:select(blizzard)
local added = game.hand[#game.hand]
assert(#game.hand == handSize + 1 and added.id == "spell_blizzard", "Picking a spell adds it to the hand")
assert(added.game == game and added:getCost() > 0, "The added spell is set up for this battle")
assert(not picker.isActive, "Picker closes after picking")
while #game.hand < 10 do picker:select(blizzard) end
picker:select(blizzard)
assert(#game.hand == 10, "Picking a spell with a full hand (10) adds nothing")
game.hand = {}

local owned = #_G.PersistentState.artifacts
DevMode.keypressed("f7", game)
assert(#_G.PersistentState.artifacts == owned + 1, "F7 grants an artifact")
assert(#game.artifacts.artifacts == owned + 1, "F7 applies the artifact to the current battle immediately")

local cash = _G.PersistentState.cash
DevMode.keypressed("f8", game)
assert(_G.PersistentState.cash == cash + DevMode.CASH, "F8 adds cash")

DevMode.keypressed("f9", game)
assert(_G.PersistentState.shopLevel == 2, "F9 raises the shop level")

local e1, e2 = makeEnemy(), makeEnemy()
DevMode.keypressed("f10", game)
assert(e1.destroyed and e2.destroyed, "F10 kills every enemy on the field")

-- F11: enemy spawner
local spawner = game.gui.devSpawner
DevMode.keypressed("f11", game)
assert(spawner.isActive, "F11 opens the enemy spawner")
local function countEnemies(id)
    local n = 0
    for _, obj in ipairs(game.objects) do
        if not obj.destroyed and obj.isType and obj:isType("enemy") and (id == nil or obj.enemyId == id) then n = n + 1 end
    end
    return n
end
local enemies = spawner:getEnemies()
assert(#enemies > 1, "Spawner lists every enemy in the game (" .. #enemies .. ")")
local soldier
for i, e in ipairs(enemies) do if e.id == "Soldier" then soldier = i end end
local cx, cy, cw, ch = spawner:cellRect(soldier)
spawner:mousepressed(cx + 5, cy + 5, 1)
assert(countEnemies("Soldier") == 0 and #spawner.queue == 1, "Clicking an enemy queues it instead of spawning instantly")
spawner:enqueue(enemies[soldier], spawner.BULK)
assert(#spawner.queue == 1 + spawner.BULK, "Bulk queue adds " .. spawner.BULK .. " more")
assert(spawner.isActive, "Spawner stays open after queueing")
assert(pcall(spawner.draw, spawner), "Spawner panel draws")
spawner:update(0)
assert(countEnemies("Soldier") == 0, "Nothing spawns while the battle is frozen (dt = 0)")
spawner:mousepressed(1, 1, 1)
assert(not spawner.isActive, "Clicking outside closes the spawner")

spawner:update(1 / 60)
assert(countEnemies("Soldier") == 1, "Once running, the first queued enemy spawns right away")
local s = game.objects[#game.objects]
assert(s.x == 800 and s.y >= game.battlefieldGrid.y, "Spawned enemy enters at the right edge of the battlefield")
local delay = spawner.timer
assert(delay > 0, "The next enemy waits for the queued spawn delay (" .. delay .. "s)")
spawner:update(delay * 0.5)
assert(countEnemies("Soldier") == 1, "...and doesn't spawn before it")
spawner:update(delay * 0.5 + 1e-6)
assert(countEnemies("Soldier") == 2, "...then spawns once the delay has passed")
for _ = 1, 600 do spawner:update(1 / 60) end
assert(countEnemies("Soldier") == 1 + spawner.BULK and #spawner.queue == 0, "The whole queue is released over time")

DevMode.keypressed("f11", game)
DevMode.keypressed("f11", game)
assert(not spawner.isActive, "F11 toggles it closed again")
spawner:enqueue(enemies[soldier], 3)
DevMode.keypressed("f10", game)
assert(#spawner.queue == 0 and countEnemies() == 0, "F10 kills every enemy and empties the dev queue")

assert(pcall(DevMode.keypressed, "f6", game), "F6 draws cards without error (even from an empty deck)")

DevMode.keypressed("f5", game)
assert(game.battleComplete, "F5 wins the battle")

DevMode.keypressed("f1", game)
assert(not DevMode.showHelp, "F1 hides the key list")
DevMode.keypressed("f1", game)
assert(DevMode.showHelp, "F1 shows it again")
assert(pcall(DevMode.draw, true), "Overlay draws in battle")

-- 3. Toggles last for the whole run
loadGame()
assert(DevMode.isOn("infiniteTokens") and DevMode.isOn("invincible"), "Toggles carry over into the next battle")

-- 4. Between battles (no game): battle-only keys are consumed but do nothing
local level = _G.PersistentState.shopLevel
assert(DevMode.keypressed("f5", nil), "Battle-only key is consumed in the preparation scene")
assert(DevMode.message and DevMode.message:find("during a battle"), "...and explains it only works during a battle")
DevMode.keypressed("f9", nil)
assert(_G.PersistentState.shopLevel == level + 1, "F9 works between battles")
assert(pcall(DevMode.keypressed, "f7", nil), "F7 works between battles")
assert(not DevMode.keypressed("a", nil), "Non-dev keys pass through")
assert(pcall(DevMode.draw, false), "Overlay draws between battles")

-- 5. A new normal run drops dev mode
menu:keypressed("return")
assert(not DevMode.isActive() and not DevMode.isOn("invincible"), "Starting a normal run clears dev mode")

print(string.format("\n%d failure(s)", failures))
if failures > 0 then os.exit(1) end
