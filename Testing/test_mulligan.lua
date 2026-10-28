-- Testing/test_mulligan.lua
-- Standalone script to verify the Mulligan / starting reroll logic

_G.love = {
    graphics = { 
        getFont = function() 
            return {
                getHeight = function() return 10 end, 
                getWidth = function() return 10 end
            } 
        end, 
        print = function() end, 
        rectangle = function() end, 
        setColor = function() end 
    },
    mouse = { 
        getPosition = function() return 0, 0 end, 
        setVisible = function() end 
    },
    math = { 
        colorFromBytes = function() return 1, 1, 1, 1 end, 
        random = math.random 
    }
}

-- Mock dependencies required for GameManager loading
package.loaded["Game.Core.Base"] = {
    new = function()
        return {
            hp = 100,
            initMainLazer = function() end,
            getStat = function() return 100 end
        }
    end
}
package.loaded["Game.Core.BattlefieldGrid"] = {
    new = function() return {} end
}
package.loaded["Physics.collisionSystem_brute"] = {
    setGrid = function() end
}
package.loaded["Game.Input.InputHandler"] = {
    new = function() return {} end
}
package.loaded["Game.Spawning.WaveSpawner"] = {
    new = function() return {} end
}
package.loaded["Game.Spawning.WaveDirector"] = {
    new = function() return {} end
}
package.loaded["Game.Rewards.RewardSystem"] = {
    new = function() return {} end
}

package.loaded["Game.Inventory.Inventory"] = {
    new = function() return {} end
}
package.loaded["Game.Effects.EffectManager"] = {
    new = function() return { recalculateStats = function() end } end
}
package.loaded["Game.GUI.GUIManager"] = {
    new = function() return {} end
}
package.loaded["Game.GUI.Layout"] = {
    W = 1280,
    H = 720
}
package.loaded["Game.GUI.Cursor"] = {
    reset = function() end,
    applyOS = function() end
}
package.loaded["Game.Spawning.EnemyRegistry"] = {
    reset = function() end
}
package.loaded["Graphics.Animations.ParticleExplosion"] = {}
package.loaded["Graphics.Animations.CircleFade"] = {}
package.loaded["Graphics.Animations.DamageNumber"] = {}
package.loaded["Graphics.Animations.LightningBolt"] = {}
package.loaded["Graphics.Animations.ExpandingCircle"] = {}
package.loaded["Graphics.Animations.ArmorBreak"] = {}
package.loaded["Graphics.Animations.DebuffArrows"] = {}
package.loaded["Graphics.Animations.DebuffProjectile"] = {}
package.loaded["Enemies.Enemy"] = {}

local GameManager = require("Game.Core.GameManager")
local ExecutionType = require("Game.Cards.ExecutionType")

print("--- Starting Mulligan / Reroll System Tests ---")

local failures = 0

local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

-- Setup Game Manager instance
local game = setmetatable({}, GameManager)
game:load(nil, true)

-- Verify initial state
assert(game:isState("mulligan"), "Initial state should be 'mulligan'")
assert(next(game.mulliganLockedSlots) == nil, "No slot has been rerolled yet")

-- Mock hand and draw pile
local c1 = { id = "card1", getCardDraw = function() return { draw = function() end } end }
local c2 = { id = "card2", getCardDraw = function() return { draw = function() end } end }
local c3 = { id = "card3", getCardDraw = function() return { draw = function() end } end }
local replacementCard = { id = "replacement", getCardDraw = function() return { draw = function() end } end }
local replacement2 = { id = "replacement2", getCardDraw = function() return { draw = function() end } end }
local replacement3 = { id = "replacement3", getCardDraw = function() return { draw = function() end } end }

game.hand = { c1, c2, c3 }
game.drawPile = { replacementCard }

-- Verify layout calculation
local layout = game:getMulliganLayout()
assert(#layout.cards == 3, "Layout cards count matches hand size")
assert(layout.skipBtn ~= nil, "Skip button position is calculated")

-- Test single card reroll
local unpack_fn = table.unpack or unpack
local oldHand = { unpack_fn(game.hand) }
local originalRandom = math.random
math.random = function(i) return i end
game:rerollCard(2)
math.random = originalRandom

assert(game.mulliganLockedSlots[2], "Slot 2 is used up")
assert(game.hand[2].id == "replacement", "Card at index 2 was successfully replaced")
assert(game.hand[1].id == "card1", "Card at index 1 remains untouched")
assert(game.hand[3].id == "card3", "Card at index 3 remains untouched")
assert(game.drawPile[1].id == "card2", "Old card was returned to the draw pile")

-- Test handleMulliganClick for Skip/Start button click
game:handleMulliganClick(layout.skipBtn.x + 10, layout.skipBtn.y + 10, 1)
assert(game:isState("startup"), "Clicking skip button transitions game to 'startup' state")

-- Each card can be rerolled once: no overall limit, but a slot can't go twice
game:setState("mulligan")
game.drawPile = { replacement2 }
local arrow2 = layout.cards[2]
game:handleMulliganClick(arrow2.arrowX, arrow2.arrowY, 1)
assert(game.hand[2].id == "replacement", "A rerolled slot can't be rerolled again")

for i = 1, 3, 2 do
    game.drawPile = { i == 1 and replacement2 or replacement3 }
    local arrow = layout.cards[i]
    game:handleMulliganClick(arrow.arrowX, arrow.arrowY, 1)
end
assert(game.hand[1].id == "replacement2" and game.hand[3].id == "replacement3", "Every card in the hand can be rerolled once")
local before = game.hand[1].id
game.drawPile = { c1 }
game:handleMulliganClick(layout.cards[1].arrowX, layout.cards[1].arrowY, 1)
assert(game.hand[1].id == before, "...but only once")

print("--- Mulligan Tests Completed with " .. failures .. " failures ---")
os.exit(failures == 0 and 0 or 1)
