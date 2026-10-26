-- =============================================================================
-- ARTIFACT INDEX (ArtifactIndex.lua)
-- Every artifact in the game. Artifacts are run-long relics that grant a strong
-- passive effect, usually built around a synergy (a damage type, a firing
-- style, a role) so they pull a run in a direction.
--
-- Definition fields (see ArtifactManager for how they are used):
--   id, name, rarity, description, color, icon   -- identity / display
--   effects       static effect templates, applied for the whole battle
--   getEffects    function(self, game) -> templates; re-evaluated whenever the
--                 board changes, for effects that scale with what's placed
--   hooks         any ArtifactManager hook (onBattleStart, onEnemyKilled,
--                 modifyMaxTokens, ...) as a method on the definition
--
-- An effect template is a regular EffectManager effect (statModifiers,
-- targetTypes, ...) plus `target`: "player" (turrets/buildings, the default)
-- or "enemy" (every enemy).
-- =============================================================================

local Chill = require("Game.Effects.StatusEffects.Chill")

local ArtifactIndex = {}

--- Living turrets on the field; the main turret is left out unless includeMain is set.
local function fieldTurrets(game, includeMain)
    local turrets = {}
    for _, obj in ipairs(game.objects or {}) do
        if not obj.destroyed and obj.isType and obj:isType("turret") and (includeMain or not obj:isType("mainturret")) then
            table.insert(turrets, obj)
        end
    end
    return turrets
end

ArtifactIndex.list = {
    -- -------------------------------------------------------------------------
    -- Damage-type / firing-style synergies
    -- -------------------------------------------------------------------------
    {
        id = "overclocked_capacitor",
        name = "Overclocked Capacitor",
        rarity = "uncommon",
        icon = "bolt",
        color = {0.3, 0.6, 1, 1},
        description = "Energy turrets fire 30% faster.",
        effects = {
            { targetTypes = { energy = true }, statModifiers = { fireRate = { mult = 0.3 } } },
        },
    },
    {
        id = "volatile_payload",
        name = "Volatile Payload",
        rarity = "uncommon",
        icon = "burst",
        color = {1, 0.6, 0.2, 1},
        description = "Explosive turrets have 40% larger blasts and deal 15% more damage.",
        effects = {
            { targetTypes = { explosive = true }, statModifiers = { radius = { mult = 0.4 }, damage = { mult = 0.15 }, explosionDamage = { mult = 0.15 } } },
        },
    },
    {
        id = "buckshot_choke",
        name = "Buckshot Choke",
        rarity = "rare",
        icon = "spread",
        color = {1, 0.85, 0.3, 1},
        description = "Shotgun turrets fire 2 extra pellets.",
        effects = {
            { targetTypes = { shotgun = true }, statModifiers = { pelletCount = { add = 2 } } },
        },
    },
    {
        id = "prismatic_core",
        name = "Prismatic Core",
        rarity = "uncommon",
        icon = "diamond",
        color = {0.4, 1, 0.9, 1},
        description = "Your main turret deals 40% more damage and fires 20% faster.",
        effects = {
            { targetTypes = { mainturret = true }, statModifiers = { damage = { mult = 0.4 }, fireRate = { mult = 0.2 } } },
        },
    },

    -- -------------------------------------------------------------------------
    -- Board-composition synergies (re-evaluated whenever the board changes)
    -- -------------------------------------------------------------------------
    {
        id = "arms_race",
        name = "Arms Race",
        rarity = "rare",
        icon = "hexagon",
        color = {0.85, 0.45, 1, 1},
        description = "All turrets deal +6% damage for each different damage type among your turrets on the field (including your main turret).",
        PER_TYPE = 0.06,
        getEffects = function(self, game)
            local seen, count = {}, 0
            for _, t in ipairs(fieldTurrets(game, true)) do
                local dt = t.damageType or "ballistic"
                if not seen[dt] then
                    seen[dt] = true
                    count = count + 1
                end
            end
            if count == 0 then return {} end
            return {
                { targetTypes = { turret = true }, statModifiers = { damage = { mult = self.PER_TYPE * count } } },
            }
        end,
    },
    {
        id = "specialist_doctrine",
        name = "Specialist Doctrine",
        rarity = "rare",
        icon = "chevron",
        color = {1, 0.4, 0.4, 1},
        description = "Turrets of your most common damage type on the field deal +5% damage for each turret of that type (max +50%).",
        PER_TURRET = 0.05,
        MAX_BONUS = 0.5,
        getEffects = function(self, game)
            local counts = {}
            local bestType, bestCount = nil, 0
            for _, t in ipairs(fieldTurrets(game)) do
                local dt = t.damageType or "ballistic"
                counts[dt] = (counts[dt] or 0) + 1
                if counts[dt] > bestCount then
                    bestType, bestCount = dt, counts[dt]
                end
            end
            if not bestType then return {} end
            local bonus = math.min(self.MAX_BONUS, self.PER_TURRET * bestCount)
            return {
                { targetTypes = { [bestType] = true }, statModifiers = { damage = { mult = bonus } } },
            }
        end,
    },

    -- -------------------------------------------------------------------------
    -- Ice synergy (chill / freeze, see Chill.lua)
    -- -------------------------------------------------------------------------
    {
        id = "brittle_ice",
        name = "Brittle Ice",
        rarity = "rare",
        icon = "crystal",
        color = {0.55, 0.85, 1, 1},
        description = "Frozen enemies take 30% more damage.",
        BONUS = 0.3,
        modifyEnemyDamage = function(self, game, amount, enemy)
            if Chill.isFrozen(enemy) then
                return amount * (1 + self.BONUS)
            end
            return amount
        end,
    },
    {
        id = "heart_of_the_tundra",
        name = "Heart of the Tundra",
        rarity = "rare",
        icon = "diamond",
        color = {0.75, 0.95, 1, 1},
        description = "When a frozen enemy thaws, it takes damage equal to 15% of its max HP.",
        MAX_HP_FRACTION = 0.15,
        onEnemyThaw = function(self, game, enemy)
            if enemy.destroyed then return end
            local damage = enemy:getStat("maxHp") * self.MAX_HP_FRACTION
            enemy:takeDamage(damage, "ice", nil, nil, { "thaw" })
        end,
    },
}

ArtifactIndex.byId = {}
for _, def in ipairs(ArtifactIndex.list) do
    if ArtifactIndex.byId[def.id] then
        error("Developer Error: duplicate artifact id '" .. def.id .. "'")
    end
    ArtifactIndex.byId[def.id] = def
end

function ArtifactIndex.get(id)
    return ArtifactIndex.byId[id]
end

return ArtifactIndex
