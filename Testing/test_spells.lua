-- Testing/test_spells.lua
-- Standalone script to verify the Spell card logic and visual integration

package.path = package.path .. ";./?.lua"

-- Mock Layout and hook it into package.loaded
local mockLayout = {
    worldToScreen = function(wx, wy)
        -- simple scale of 1.5, offset of 100, 100
        return 100 + wx * 1.5, 100 + wy * 1.5
    end,
    inFieldScreen = function(sx, sy)
        -- simple battlefield rect: 100 to 900 x, 100 to 500 y
        return sx >= 100 and sx <= 900 and sy >= 100 and sy <= 500
    end
}
_G.Layout = mockLayout
package.loaded["Game.GUI.Layout"] = mockLayout

local SpellCardRegistry = require("Spells.SpellCardRegistry")
local Spell = require("Spells.Spell")

print("--- Starting Spell Card System Tests ---")

local failures = 0

local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

-- 1. Test Registry Loading
assert(SpellCardRegistry.Fireball ~= nil, "Fireball spell loaded")
assert(SpellCardRegistry.StunBurst ~= nil, "Stun Burst spell loaded")
assert(SpellCardRegistry.AcidCloud ~= nil, "Acid Cloud spell loaded")
assert(SpellCardRegistry.Judgment ~= nil, "Judgment spell loaded")

-- 2. Test Card Properties
local fireball = SpellCardRegistry.Fireball
assert(fireball.cost == 1, "Fireball cost is 1")
assert(fireball.radius == 60, "Fireball radius is 60")
assert(fireball.isGlobalSpell == false, "Fireball is not global")

local judgment = SpellCardRegistry.Judgment
assert(judgment.cost == 2, "Judgment cost is 2")
assert(judgment.isGlobalSpell == true, "Judgment is a global spell")

-- 3. Test isValidTarget
-- World (0,0) converts to screen (100, 100) -> valid
assert(fireball:isValidTarget(0, 0) == true, "Valid world coordinate (0,0) allowed")
-- World (-100, -100) converts to screen (-50, -50) -> invalid
assert(fireball:isValidTarget(-100, -100) == false, "Invalid world coordinate rejected")
-- Global spell should accept any coordinates
assert(judgment:isValidTarget(-100, -100) == true, "Global spell accepts invalid field coordinates")

-- 4. Test Fireball execution
local mockGame = {
    objects = {
        {
            x = 10, y = 10,
            destroyed = false,
            takeDamage = function(self, dmg, dtype)
                self.damageTaken = (self.damageTaken or 0) + dmg
                self.damageType = dtype
            end,
            isType = function(self, t) return t == "enemy" end
        },
        {
            x = 200, y = 200, -- far away
            destroyed = false,
            takeDamage = function(self, dmg, dtype)
                self.damageTaken = (self.damageTaken or 0) + dmg
            end,
            isType = function(self, t) return t == "enemy" end
        }
    },
    animations = {}
}

fireball:execute(0, 0, mockGame)
assert(#mockGame.animations == 1, "FireballVisual animation added to game.animations")

local fbVisual = mockGame.animations[1]
assert(fbVisual.targetY == 0, "FireballVisual target Y set correctly")
assert(fbVisual.startY == -400, "FireballVisual start Y is high up")

-- Simulate falling update
fbVisual:update(0.4) -- Trigger landing impact
assert(fbVisual.destroyed == true, "FireballVisual marked destroyed on impact")

-- Assert damage applied correctly to nearby enemy
local closeEnemy = mockGame.objects[1]
local farEnemy = mockGame.objects[2]
assert(closeEnemy.damageTaken ~= nil and closeEnemy.damageTaken > 0, "Close enemy took damage from Fireball")
assert(closeEnemy.damageType == "explosive", "Fireball damage type is explosive")
assert(farEnemy.damageTaken == nil, "Far enemy did not take damage from Fireball")

-- 5. Test Stun Burst execution
local mockStunGame = {
    objects = {
        {
            x = 5, y = 5,
            destroyed = false,
            isType = function(self, t) return t == "enemy" end,
            effectManager = {
                applyEffect = function(self, effect)
                    self.appliedEffect = effect
                end
            }
        }
    },
    animations = {}
}

local stunburst = SpellCardRegistry.StunBurst
stunburst:execute(0, 0, mockStunGame)

assert(#mockStunGame.animations == 1, "StunBurstVisual added to animations")
local stEnemy = mockStunGame.objects[1]
assert(stEnemy.effectManager.appliedEffect ~= nil, "Stun effect applied to close enemy")
assert(stEnemy.effectManager.appliedEffect.name == "stun", "Stun effect is named stun")
assert(stEnemy.effectManager.appliedEffect.duration == 2.0, "Stun effect duration is 2.0 seconds")

-- 6. Test Acid Cloud execution
local mockAcidGame = {
    objects = {
        {
            x = 10, y = 10,
            destroyed = false,
            isType = function(self, t) return t == "enemy" end,
            takeDamage = function(self, dmg, dtype)
                self.damageTaken = (self.damageTaken or 0) + dmg
                self.damageType = dtype
            end
        },
        {
            x = 300, y = 300, -- far away
            destroyed = false,
            isType = function(self, t) return t == "enemy" end,
            takeDamage = function(self, dmg, dtype)
                self.damageTaken = (self.damageTaken or 0) + dmg
            end
        }
    },
    animations = {},
    enemyEffectManager = {
        activeEffects = {},
        applyEffect = function(self, effect)
            table.insert(self.activeEffects, effect)
        end
    }
}

local acidcloud = SpellCardRegistry.AcidCloud
acidcloud:execute(0, 0, mockAcidGame)

assert(#mockAcidGame.animations == 1, "AcidCloudVisual added to animations")
assert(#mockAcidGame.enemyEffectManager.activeEffects == 1, "AcidCloudEffect applied to global enemyEffectManager")

local acidEffect = mockAcidGame.enemyEffectManager.activeEffects[1]
assert(acidEffect.x == 0 and acidEffect.y == 0, "AcidCloudEffect position set correctly")

-- Simulate 1 second update
acidEffect:onUpdate(1.0, nil)
local acidCloseEnemy = mockAcidGame.objects[1]
local acidFarEnemy = mockAcidGame.objects[2]
assert(acidCloseEnemy.damageTaken ~= nil and acidCloseEnemy.damageTaken > 0, "Enemy in Acid Cloud took tick damage")
assert(acidCloseEnemy.damageType == "poison", "Acid Cloud damage type is poison")
assert(acidFarEnemy.damageTaken == nil, "Enemy outside Acid Cloud took no damage")

-- 7. Test Judgment execution
local mockJudgmentGame = {
    objects = {
        {
            x = 10, y = 10,
            destroyed = false,
            isType = function(self, t) return t == "enemy" end,
            takeDamage = function(self, dmg, dtype)
                self.damageTaken = (self.damageTaken or 0) + dmg
                self.damageType = dtype
            end
        },
        {
            x = 20, y = 20,
            destroyed = false,
            isType = function(self, t) return t == "enemy" end,
            takeDamage = function(self, dmg, dtype)
                self.damageTaken = (self.damageTaken or 0) + dmg
                self.damageType = dtype
            end
        }
    },
    lightningSpawnCount = 0,
    spawnLightningBolt = function(self, tx, ty)
        self.lightningSpawnCount = self.lightningSpawnCount + 1
    end
}

judgment:execute(0, 0, mockJudgmentGame)
local e1 = mockJudgmentGame.objects[1]
local e2 = mockJudgmentGame.objects[2]
assert(e1.damageTaken == 500, "Enemy 1 took 500 damage (1000 split by 2)")
assert(e2.damageTaken == 500, "Enemy 2 took 500 damage (1000 split by 2)")
assert(e1.damageType == "trueDamage", "Judgment damage type is trueDamage")
assert(mockJudgmentGame.lightningSpawnCount == 2, "Lightning bolts spawned on both enemies")

-- Test Spell Injection into RewardIndex
local RewardIndex = require("Game.Rewards.NormalRewardIndex")
local SpellCardRegistry = require("Spells.SpellCardRegistry")

-- Count spells in registry
local regCount = 0
for _, _ in pairs(SpellCardRegistry) do
    regCount = regCount + 1
end

RewardIndex.injectSpells(SpellCardRegistry)

-- Verify that spells are present in RewardIndex under their lowercased rarities
for key, spell in pairs(SpellCardRegistry) do
    local rarityKey = spell.rarity:lower()
    local found = false
    for _, item in ipairs(RewardIndex[rarityKey] or {}) do
        if item.id == spell.id then
            found = true
            assert(item.type == "spell", "Injected spell has type='spell'")
            assert(item.name == spell.name, "Injected spell name matches")
            break
        end
    end
    assert(found, "Spell " .. spell.id .. " should be dynamically injected into RewardIndex")
end

-- Injecting again should not create duplicates
local prevCount = 0
for rarityKey, _ in pairs(RewardIndex) do
    if type(RewardIndex[rarityKey]) == "table" then
        prevCount = prevCount + #RewardIndex[rarityKey]
    end
end

RewardIndex.injectSpells(SpellCardRegistry)

local postCount = 0
for rarityKey, _ in pairs(RewardIndex) do
    if type(RewardIndex[rarityKey]) == "table" then
        postCount = postCount + #RewardIndex[rarityKey]
    end
end
assert(prevCount == postCount, "Re-injecting spells should not create duplicate entries")

print("--- Spell Card System Tests Completed with " .. failures .. " failures ---")
os.exit(failures == 0 and 0 or 1)
