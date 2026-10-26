-- Testing/test_turret_aim_spread.lua
-- Every turret in the index fires its shots toward where it is aiming, within a
-- small spread cone (regression: Airburst's spread = math.pi made it fire randomly).

package.path = package.path .. ";./?.lua"

_G.love = {
    math = { random = math.random },
    timer = { getTime = function() return 0 end }
}
math.atan2 = math.atan2 or math.atan

local EffectManager = require("Game.Effects.EffectManager")

local mockGame = {
    objects = {},
    ground = { x = 0, y = 0, w = 1000, h = 1000 },
    base = {
        x = 0, y = 100, w = 32,
        takeDamage = function() end,
        buildGrid = { x = 0, y = 0, width = 10, height = 10, cellSize = 32, buildings = {} }
    },
    addObject = function(self, obj) table.insert(self.objects, obj) end,
    spawnParticleExplosion = function() end,
    spawnDamageNumber = function() end
}
mockGame.playerEffectManager = EffectManager:new(nil, mockGame)
mockGame.enemyEffectManager = EffectManager:new(nil, mockGame)

local failures = 0
local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

local TurretIndex = require("Buildings.TurretIndex")

-- Widest aim deviation any turret should have from where it points (shotgun pellet
-- cones are ±7.5°; anything near ±90° or more means shots fly off in random directions)
local MAX_DEVIATION = math.rad(30)
local SHOTS = 200

local function angleDiff(a, b)
    local d = (a - b) % (2 * math.pi)
    if d > math.pi then d = d - 2 * math.pi end
    return math.abs(d)
end

for _, rarity in ipairs({ "common", "uncommon", "rare", "epic", "legendary" }) do
    for _, entry in ipairs(TurretIndex[rarity] or {}) do
        if entry.building and entry.building.new then
            local config = {}
            for k, v in pairs(entry) do config[k] = v end
            config.game = mockGame
            config.x, config.y = 100, 100
            config.rotation = 0

            local ok, turret = pcall(entry.building.new, entry.building, config)
            if ok and turret and turret.fire then
                mockGame.objects = {}
                local aim = 1.0 -- radians; any fixed direction
                turret.rotation = aim
                for _ = 1, SHOTS do
                    pcall(turret.fire, turret)
                end

                local worst, fired = 0, 0
                for _, obj in ipairs(mockGame.objects) do
                    if obj.angle then
                        fired = fired + 1
                        worst = math.max(worst, angleDiff(obj.angle, aim))
                    end
                end

                if fired > 0 then
                    assert(worst <= MAX_DEVIATION, string.format(
                        "%s fires toward its aim (worst deviation %.1f°)", entry.id, math.deg(worst)))
                end
            end
        end
    end
end

if failures > 0 then
    print(failures .. " test(s) failed")
    os.exit(1)
end
print("All turret aim spread tests passed")
