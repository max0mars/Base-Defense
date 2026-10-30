-- Testing/test_card_icons.lua
-- Cards show synergy icons in the bottom left of their description box: firing
-- types first (projectile, hitscan, shotgun, lobber, beam), then damage types.
-- Turrets work theirs out from their stats; other cards list them explicitly.

package.path = package.path .. ";./?.lua"

-- Mock love2d (every love.* function is a no-op)
local noop = function() end
local fontStub = { getWidth = function() return 10 end, getHeight = function() return 10 end, getWrap = function() return 10, { "" } end }
_G.love = setmetatable({
    math = setmetatable({ random = math.random, triangulate = function() return {} end }, { __index = function() return noop end }),
    timer = { getTime = function() return 0 end },
    graphics = setmetatable({
        getFont = function() return fontStub end,
        newFont = function() return fontStub end,
        getColor = function() return 1, 1, 1, 1 end,
    }, { __index = function() return noop end }),
}, { __index = function() return setmetatable({}, { __index = function() return noop end }) end })
_G.VIRTUAL_WIDTH = 1280
_G.VIRTUAL_HEIGHT = 720

local log = print
print = noop -- silence game logging

local failures = 0
local function assert(condition, message)
    if not condition then
        log("[FAIL] " .. message)
        failures = failures + 1
    else
        log("[PASS] " .. message)
    end
end

local function same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

local CardIcons = require("Game.Cards.CardIcons")
local CardDraw = require("Game.Cards.CardDraw")
local CardFactory = require("Game.Cards.CardFactory")
local TurretIndex = require("Buildings.TurretIndex")
local SpellCardRegistry = require("Spells.SpellCardRegistry")

local turrets = {}
for _, tier in pairs(TurretIndex) do
    for _, t in ipairs(tier) do turrets[t.id] = t end
end

local function iconsOf(id) return CardIcons.resolve(turrets[id]) end
local function show(icons) return "{" .. table.concat(icons, ", ") .. "}" end

-- Turrets derive their icons
local expected = {
    sentry = { "projectile", "physical" },
    blaster = { "projectile", "energy" },
    shotgunTurret = { "projectile", "shotgun", "physical" },
    plasmaScattershot = { "projectile", "shotgun", "energy" },
    sniper = { "hitscan", "physical" },
    grenadier = { "lobber", "explosive" },
    mortar = { "lobber", "explosive" },
    missileLauncher = { "projectile", "explosive" },
    poisonTurret = { "projectile", "poison" },
    cryoBeam = { "beam", "ice" },
    glacialMonolith = { "ice" },
    flareGun = { "projectile", "fire" },
    cinderMortar = { "shotgun", "lobber", "fire" },
    infernoTower = { "beam", "fire" },
}
for id, icons in pairs(expected) do
    assert(same(iconsOf(id), icons), id .. " shows " .. show(icons) .. " (got " .. show(iconsOf(id)) .. ")")
end

-- Every turret leads with a firing type, unless it doesn't shoot (waves, meteors)
local noFiringType = { glacialMonolith = true, meteor = true }
local firing = {}
for _, name in ipairs(CardIcons.FIRING_TYPES) do firing[name] = true end
for id, t in pairs(turrets) do
    local icons = CardIcons.resolve(t)
    if not noFiringType[id] then
        assert(#icons >= 2 and firing[icons[1]], id .. " starts with a firing type and has a damage type")
    end
end

-- Explicit lists are reordered so firing types always come first
assert(same(CardIcons.order({ "ice", "beam", "projectile" }), { "projectile", "beam", "ice" }),
    "firing types are drawn before damage types")

-- Spells, instants and passives carry their own icons into their card draw
assert(same(SpellCardRegistry.Fireball:getCardDraw().icons, { "fire" }), "Fireball shows the fire icon")
assert(#SpellCardRegistry.StunBurst:getCardDraw().icons == 0, "Stun Gas has no icons")

local function rewardCard(id)
    local RewardIndex = require("Game.Rewards.RewardIndex")
    for _, tier in pairs(RewardIndex) do
        if type(tier) == "table" then
            for _, r in ipairs(tier) do
                if r.id == id then return CardFactory.fromReward(r) end
            end
        end
    end
end

assert(same(rewardCard("unstable_laser"):getCardDraw().icons, { "energy", "fire" }), "Unstable Laser shows energy then fire")
assert(same(rewardCard("ammoCache"):getCardDraw().icons, {}), "Ammo Cache has no icons")
assert(same(rewardCard("bank"):getCardDraw().icons, { "token" }), "Bank shows the token icon")
assert(same(rewardCard("conduit"):getCardDraw().icons, { "mana" }), "Conduit shows the mana icon")
assert(same(rewardCard("vault"):getCardDraw().icons, { "money" }), "The Vault shows the money icon")
assert(same(rewardCard("iceMarket"):getCardDraw().icons, { "ice", "money" }), "Ice Market shows ice then money")
assert(same(rewardCard("inst_cryoelectronics_1"):getCardDraw().icons, { "energy", "ice" }), "Cryoelectronics shows energy and ice")
assert(same(rewardCard("heavyShotgun"):getCardDraw().icons, { "projectile", "shotgun", "physical" }), "deck turret cards keep their icons")

-- Reward choices (the raw index entry) get the same icons
assert(same(CardDraw.new(0, 0, turrets.mortar).icons, { "lobber", "explosive" }), "reward cards draw the turret's icons")

-- Drawing a card with icons doesn't error
local ok, err = pcall(function() CardDraw.new(0, 0, turrets.cryoBeam):draw(0, 0) end)
assert(ok, "a card with icons draws (" .. tostring(err) .. ")")

if failures > 0 then
    log(failures .. " test(s) failed")
    os.exit(1)
end
log("All card icon tests passed")
