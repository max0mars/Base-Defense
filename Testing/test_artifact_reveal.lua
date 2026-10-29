-- Testing/test_artifact_reveal.lua
-- Artifact reveal after an elite battle: the animation and where it sits between the win and the summary.


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
local function near(a, b) return math.abs(a - b) < 1e-6 end

local game = require("Game.Core.GameManager")
local menu = require("Scenes.menu_scene")

local ArtifactReveal = require("Graphics.Animations.ArtifactReveal")
local ArtifactIndex = require("Game.Artifacts.ArtifactIndex")
local BattleManager = require("Game.Core.BattleManager")

local def = ArtifactIndex.get("cryo_coolant")
assert(def, "test artifact exists")

-- 1. The reveal: slides up face down, builds up, slams face up, then waits for a click
local reveal = ArtifactReveal.new(def)
local function stepTo(t) while reveal.t < t - 1e-9 do reveal:update(math.min(0.01, t - reveal.t)) end end
local function shakeAt(t)
    stepTo(t)
    local cx, cy = VIRTUAL_WIDTH / 2, VIRTUAL_HEIGHT / 2
    local worst = 0
    for _ = 1, 200 do
        local x, y = reveal:pose()
        worst = math.max(worst, math.abs(x - cx))
    end
    return worst
end

local _, y0, scale0, _, _, face0 = reveal:pose()
assert(y0 > VIRTUAL_HEIGHT and not face0 and scale0 == 1, "starts face down below the screen")
local early = shakeAt(0.3)
local _, _, scaleEarly = reveal:pose()
local late = shakeAt(1.5)
local _, yLate, scaleLate, _, _, faceLate = reveal:pose()
assert(early == 0 and late > 5, string.format("the shake builds up as it reaches the top (%.1f -> %.1f)", early, late))
assert(scaleLate > scaleEarly + 0.2, "it zooms in as it builds up")
assert(math.abs(yLate - VIRTUAL_HEIGHT / 2) < 13 and not faceLate, "it hangs at the centre, still face down")
assert(not reveal.impacted, "no impact before the slam")

stepTo(1.73)
local _, _, scaleSlam, flipSlam, _, faceSlam = reveal:pose()
assert(reveal.impacted and #reveal.sparks > 0, "the slam lands with a burst of sparks")
assert(faceSlam, "the card is face up after the slam")
local sx = reveal:screenShake()
assert(sx ~= 0 or select(2, reveal:screenShake()) ~= 0, "the slam shakes the screen")

stepTo(1.85)
local _, _, scaleLanded = reveal:pose()
assert(reveal:isLanded() and scaleLanded < 1, "it lands slightly squashed")
reveal:click()
assert(not reveal.done, "a click right after landing doesn't skip it")
stepTo(3)
local _, _, scaleSettled, flipSettled = reveal:pose()
assert(math.abs(scaleSettled - 1) < 1e-6 and flipSettled == 1, "it settles at full size")
assert(reveal:screenShake() == 0, "the screen shake has faded")
reveal:click()
assert(reveal.done, "a click then moves on")
assert(pcall(function() reveal:draw() end), "the reveal draws")

-- 2. The battle scene plays the reveal after the win and before the summary
local game = require("Game.Core.GameManager")
local menu = require("Scenes.menu_scene")
local scene = require("Scenes.game_scene")
menu.scene_manager = { switch = noop }
scene.scene_manager = { switch = noop }
menu:keypressed("return")
_G.PersistentState.selectedMainTurret = "MainLazer"
_G.PersistentState.discoveredEnemies = { Grunt = true }
_G.PersistentState.artifacts = {}
game:load(nil, false)
_G.PersistentState.selectedBattle = { rewards = { { type = "gold", name = "Cash", amount = 50 }, BattleManager.artifactReward() } }
game:winBattle()
assert(#game.newArtifacts == 1, "winning an elite battle queues its artifact for a reveal")

local switchedTo
scene.scene_manager = { switch = function(name) switchedTo = name end }
scene:update(0.016)
assert(scene.showingSummary and not scene.artifactReveal, "the summary shows first")
local hidden = false
for _, r in ipairs(scene.summaryOtherRewards) do hidden = hidden or r == "Artifact" end
assert(hidden, "the summary lists the artifact without spoiling which one")
scene:mousepressed(0, 0, 1)
assert(not scene.showingSummary and scene.showingRewards, "clicking the summary moves on to the rewards")
scene:update(0.016)
assert(scene.artifactReveal, "then the reveal plays")
assert(pcall(function() scene:draw() end), "the battle scene draws the reveal")
for _ = 1, 400 do scene:update(0.01) end
scene:mousepressed(0, 0, 1)
assert(scene.artifactReveal and scene.artifactReveal.done, "clicking after it lands finishes the reveal")
scene:update(0.016)
assert(not switchedTo, "it doesn't leave the battle the same frame the reveal finishes")
scene:update(0.016)
assert(not scene.showingRewards and switchedTo == "preparation", "then it switches to the prep scene")
scene.scene_manager = { switch = noop }

-- 2b. A card draft is offered after the summary too, not over the battle
game:load(nil, false)
_G.PersistentState.selectedBattle = { rewards = { { type = "gold", name = "Cash", amount = 50 }, { type = "card_draw", name = "Card Draft", amount = 1 } } }
game:winBattle()
assert(not game.rewardSystem.isActive, "the card draft doesn't open over the battle")
switchedTo = nil
scene.scene_manager = { switch = function(name) switchedTo = name end }
scene:update(0.016)
assert(scene.showingSummary, "the summary shows first")
scene:mousepressed(0, 0, 1)
scene:update(0.016)
assert(game.rewardSystem.isActive and game.rewardSystem.mode == "cards", "then the card draft opens")
assert(pcall(function() scene:draw() end), "the battle scene draws the card draft")
game.rewardSystem:close()
scene:update(0.016)
assert(switchedTo == "preparation", "once it's picked or skipped, on to the prep scene")
scene.scene_manager = { switch = noop }

-- 3. With every artifact owned, the elite pays $500 and there's nothing to reveal
game:load(nil, false)
local ArtifactManager = require("Game.Artifacts.ArtifactManager")
local realGrant = ArtifactManager.grantRandom
ArtifactManager.grantRandom = function() return nil end
_G.PersistentState.selectedBattle = { rewards = { { type = "gold", name = "Cash", amount = 50 }, BattleManager.artifactReward() } }
game:winBattle()
ArtifactManager.grantRandom = realGrant
scene:update(0.016)
assert(not scene.artifactReveal and scene.showingSummary, "no reveal when the elite paid cash instead")
assert(scene.summaryOtherRewards[1] == "$500 (every artifact owned)", "the summary shows the $500 instead")
scene.showingSummary = false

-- 4. The elite battle preview never names the artifact
local reward = BattleManager.artifactReward()
assert(reward.artifactId == nil and reward.description == "Random Artifact", "the battle preview only says 'Random Artifact'")

print(string.format("\n%d failure(s)", failures))
if failures > 0 then os.exit(1) end
