-- Testing/test_spell_deck.lua
-- Spells live in their own deck: sending a wave discards the build hand and
-- draws spells, mana regenerates per wave (capped), number keys pick a spell
-- and a held mouse button never casts it.

package.path = package.path .. ";./?.lua"

local mouseX, mouseY = 0, 0
local noop = function() end
_G.love = setmetatable({
    math = { random = math.random, colorFromBytes = function(...) return ... end },
    timer = { getTime = function() return 0 end },
    mouse = { getPosition = function() return mouseX, mouseY end, setVisible = noop },
    keyboard = { isDown = function() return false end },
}, { __index = function() return setmetatable({}, { __index = function() return noop end }) end })
_G.VIRTUAL_WIDTH = 1280
_G.VIRTUAL_HEIGHT = 720

local failures = 0
local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

local GameManager = require("Game.Core.GameManager")
local InputHandler = require("Game.Input.InputHandler")
local HandUI = require("Game.GUI.HandUI")
local Layout = require("Game.GUI.Layout")

-- Cards: build cards are plain tables; spells answer isType("spell").
local casts = {}
local function spell(id, cost)
    return {
        id = id, cost = cost, quantity = 1, types = { spell = true },
        isType = function(self, t) return self.types[t] == true end,
        getCost = function(self) return self.cost end,
        executionType = "Spell",
        execute = function(self, x, y, game) casts[#casts + 1] = self.id; return true end,
    }
end
local function build(id)
    return { id = id, quantity = 1, getCost = function() return 1 end, executionType = 1 }
end

_G.PersistentState = {
    deck = { getCards = function()
        return { build("b1"), build("b2"), build("b3"), spell("s1", 20), spell("s2", 30), spell("s3", 90) }
    end },
}

local game = setmetatable({}, GameManager)
game.objects, game.animations = {}, {}
game.maxMana, game.manaRegenPerWave, game.mana = 100, 25, 100
game.spellHandSize = 4
game.inputMode = "idle"
game.spawnFloatingText = noop
game.WaveSpawner = { startNextWave = noop, startCustomWave = noop }
game:setState("preparing")

-- 1. The run deck splits into a build deck and a spell deck
game:initBattleDeck()
assert(#game.drawPile == 3, "Build cards go to the draw pile")
assert(#game.spellDrawPile == 3, "Spells go to the spell draw pile")
game:drawCard(3)
for _, c in ipairs(game.hand) do
    assert(not game:isSpellCard(c), "Build hand never draws spells: " .. c.id)
end

-- 2. Sending the wave swaps the build hand for spells
game:startWave()
assert(game:isState("wave"), "Wave started")
assert(#game.discardPile == 3, "Build hand was discarded")
assert(#game.hand == 3, "Hand drew the whole (3-card) spell deck")
for _, c in ipairs(game.hand) do
    assert(game:isSpellCard(c), "Wave hand is all spells: " .. c.id)
end

-- 3. Number keys pick spells left to right; a held button never casts
local ih = InputHandler:new(game)
local fired = 0
game.inputHandler = ih
game.mainLazer = { PlayerClick = function() fired = fired + 1 end }
-- A build grid far off the field, so idle clicks don't hit a slot.
game.base = { buildGrid = { x = 0, y = -10000, width = 1, height = 1, cellSize = 1, buildings = {}, unlocked = {} } }
local hand = setmetatable({ game = game, drawAnims = {}, cardX = {}, inHand = {}, falling = {}, drawHold = 0, flyAnims = {} }, HandUI)
game.gui = { hand = hand, mousepressed = function() return false end, overlayActive = function() return false end }

mouseX = Layout.field.x + Layout.field.w / 2
mouseY = Layout.field.y + Layout.field.h / 2
ih.screenMouseX, ih.screenMouseY = mouseX, mouseY
ih.mouseX, ih.mouseY = Layout.mouseToField(mouseX, mouseY)

ih:mousepressed(mouseX, mouseY, 1) -- start holding fire
ih:handleButtonHold()
assert(fired == 1, "Holding the button fires the main turret")

ih:keypressed("2")
assert(game.activeCard == game.hand[2], "Key 2 selects the second spell")
assert(game.inputMode == "targeting_spell", "Spell enters targeting mode")
ih:handleButtonHold()
assert(fired == 1, "No turret fire while targeting a spell")
assert(#casts == 0, "Spell not cast while the button is still held")

ih:mousereleased(mouseX, mouseY, 1)
assert(#casts == 0, "Releasing the button does not cast")

local target = game.hand[2]
ih:mousepressed(mouseX, mouseY, 1) -- fresh click casts
assert(#casts == 1 and casts[1] == target.id, "Fresh click casts the selected spell")
assert(game.mana == 100 - target.cost, "Cast spends mana")
assert(game.spellDiscardPile[1] == target, "Cast spell goes to the spell discard pile")
ih:handleButtonHold()
assert(fired == 1, "The casting click does not turn into turret fire while held")
ih:mousereleased(mouseX, mouseY, 1)
ih:mousepressed(mouseX, mouseY, 1)
ih:handleButtonHold()
assert(fired == 2, "Firing resumes after releasing and clicking again")
ih:mousereleased(mouseX, mouseY, 1)

ih:keypressed("1")
ih:keypressed("1")
assert(game.activeCard == nil and game.inputMode == "idle", "Pressing the same number again cancels")

ih:keypressed("9")
assert(game.activeCard == nil, "A number past the last spell does nothing")

-- 4. Unaffordable spells don't enter targeting
game.mana = 10
ih:keypressed("1")
assert(game.activeCard == nil, "Can't target a spell without enough mana")

-- 5. Mana regenerates per wave, capped at maxMana
game.mana = 50
game:addMana(game.manaRegenPerWave)
assert(game.mana == 75, "Wave regen adds mana")
game:addMana(100)
assert(game.mana == 100, "Mana is capped at maxMana")

-- 6. Ending the wave returns spells to the spell deck
game:discardHand()
assert(#game.hand == 0, "Hand emptied")
assert(#game.spellDiscardPile == 3, "All spells are back in the spell discard pile")
assert(#game.discardPile == 3, "Build discard pile untouched")

-- 7. Outside a wave, number keys pick from the whole build hand
game:setState("startup")
local function buildCard(name)
    return { name = name, executionType = "Targeted", getCost = function() return 0 end }
end
game.hand = { buildCard("b1"), buildCard("b2") }
hand:update(0)
hand.drawAnims = {} -- skip the draw animation
game.tokens = 10
ih:keypressed("2")
assert(game.activeCard == game.hand[2] and game.inputMode == "targeting_card", "Key 2 selects the second build card")
ih:keypressed("2")
assert(game.activeCard == nil, "Pressing it again puts the card back")
game.gui.overlayActive = function() return true end
ih:keypressed("1")
assert(game.activeCard == nil, "Number keys do nothing behind an overlay")
game.gui.overlayActive = function() return false end

if failures > 0 then
    print(failures .. " test(s) failed")
    os.exit(1)
end
print("All spell deck tests passed")
