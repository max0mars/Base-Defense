_G.love = {
    graphics = { getFont = function() return {getHeight = function() return 10 end, getWidth = function() return 10 end} end, print = function() end, rectangle = function() end, setColor = function() end },
    mouse = { getPosition = function() return 0, 0 end, setVisible = function() end },
    math = { colorFromBytes = function() return 1, 1, 1, 1 end, random = math.random }
}
local GameManager = require("Game.Core.GameManager")
local ExecutionType = require("Game.Cards.ExecutionType")

local game = setmetatable({}, GameManager)
game.tokens = 0
game.maxTokens = 3
game.objects = {}
game:initBattleDeck()

-- Create mock cards
local mockCost = function() return 1 end
local c1 = { id = "c1", executionType = ExecutionType.Placement, getCost = mockCost }
local c2 = { id = "c2", executionType = ExecutionType.Targeted, getCost = mockCost }
local c3 = { id = "c3", executionType = "Global", getCost = mockCost }

game.drawPile = { c1, c2, c3 }
game.hand = {}
game:drawCard(3)

game:consumeCard(c1)
game:consumeCard(c2)
game:consumeCard(c3)

print("ConsumedPile size:", #game.consumedPile)
for _, c in ipairs(game.consumedPile) do print(" - Consumed:", c.id, tostring(c.executionType)) end
print("DiscardPile size:", #game.discardPile)
for _, c in ipairs(game.discardPile) do print(" - Discarded:", c.id, tostring(c.executionType)) end

-- Mock spawnFloatingText so drawCard doesn't error
function game:spawnFloatingText() end
-- Mock wave Complete dependencies
game.gui = { incomeFeedback = { triggerSequence = function() end } }

game:waveComplete()
print("Hand size after waveComplete:", #game.hand)
print("DiscardPile size after waveComplete:", #game.discardPile)
print("DrawPile size after waveComplete:", #game.drawPile)
