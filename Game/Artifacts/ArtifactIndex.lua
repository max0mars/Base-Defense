-- =============================================================================
-- ARTIFACT INDEX (ArtifactIndex.lua)
-- Every artifact in the game. Artifacts are run-long relics that grant a strong
-- passive effect, usually built around a synergy (a damage type, a firing
-- style, a role) so they pull a run in a direction.
--
-- Definition fields (see ArtifactManager for how they are used):
--   id, name, description, color, icon   -- identity / display
--   effects       static effect templates, applied for the whole battle
--   getEffects    function(self, game) -> templates; re-evaluated whenever the
--                 board changes, for effects that scale with what's placed
--   getTurretEffects  function(self, game, turret) -> templates applied to that
--                 one turret (e.g. based on its neighbours); re-evaluated with
--                 getEffects
--   hooks         any ArtifactManager hook (onBattleStart, onEnemyKilled,
--                 modifyMaxTokens, ...) as a method on the definition
--
-- An effect template is a regular EffectManager effect (statModifiers,
-- targetTypes, ...) plus `target`: "player" (turrets/buildings, the default)
-- or "enemy" (every enemy).
-- =============================================================================

local Chill = require("Game.Effects.StatusEffects.Chill")
local Burn = require("Game.Effects.StatusEffects.Burn")

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

--- Distinct ice turrets orthogonally next to `turret` on the base grid
--- (0 for turrets that aren't on the base grid).
local function countAdjacentIceTurrets(game, turret)
    local grid = game.base and game.base.buildGrid
    if not grid or turret.buildGrid ~= grid or not turret.slot then return 0 end
    local seen, count = {}, 0
    for _, slot in ipairs(turret:getSlotsFromPattern(turret.slot)) do
        local x = (slot - 1) % grid.width
        local y = math.floor((slot - 1) / grid.width)
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            local nx, ny = x + d[1], y + d[2]
            if nx >= 0 and nx < grid.width and ny >= 0 and ny < grid.height then
                local neighbour = grid.buildings[ny * grid.width + nx + 1]
                if neighbour and neighbour ~= turret and not seen[neighbour]
                   and not neighbour.destroyed and Chill.isIceTurret(neighbour) then
                    seen[neighbour] = true
                    count = count + 1
                end
            end
        end
    end
    return count
end

ArtifactIndex.list = {
    -- -------------------------------------------------------------------------
    -- Damage-type / firing-style synergies
    -- -------------------------------------------------------------------------
    {
        id = "overclocked_capacitor",
        name = "Overclocked Capacitor",
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
        icon = "spread",
        color = {1, 0.85, 0.3, 1},
        description = "Shotgun turrets fire 5 extra pellets.",
        effects = {
            { targetTypes = { shotgun = true }, statModifiers = { pelletCount = { add = 5 } } },
        },
    },
    {
        id = "prismatic_core",
        name = "Prismatic Core",
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
        icon = "hexagon",
        color = {0.85, 0.45, 1, 1},
        description = "All turrets deal +6% damage for each different damage type among your turrets on the field (including your main turret).",
        PER_TYPE = 0.06,
        getEffects = function(self, game)
            local seen, count = {}, 0
            for _, t in ipairs(fieldTurrets(game, true)) do
                local dt = t.damageType or "physical"
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
        icon = "chevron",
        color = {1, 0.4, 0.4, 1},
        description = "Turrets of your most common damage type on the field deal +5% damage for each turret of that type (max +50%).",
        PER_TURRET = 0.05,
        MAX_BONUS = 0.5,
        getEffects = function(self, game)
            local counts = {}
            local bestType, bestCount = nil, 0
            for _, t in ipairs(fieldTurrets(game)) do
                local dt = t.damageType or "physical"
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
        icon = "crystal",
        color = {0.55, 0.85, 1, 1},
        description = "Frozen enemies take double damage.",
        BONUS = 1.0,
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
        icon = "diamond",
        color = {0.75, 0.95, 1, 1},
        description = "When a frozen enemy thaws, it takes damage equal to 15% of its max HP.",
        MAX_HP_FRACTION = 0.15,
        onEnemyThaw = function(self, game, enemy)
            if enemy.destroyed then return end
            local damage = enemy:getStat("maxHp") * self.MAX_HP_FRACTION
            -- Damage (and the kill) count for whichever turret froze it
            enemy:takeDamage(damage, "ice", nil, nil, { "thaw" }, Chill.getFreezer(enemy))
        end,
    },
    {
        id = "cryo_coolant",
        name = "Cryo Coolant",
        icon = "drop",
        color = {0.45, 0.8, 1, 1},
        description = "Non-ice turrets fire 10% faster for each ice turret next to them.",
        PER_ICE_TURRET = 0.1,
        getTurretEffects = function(self, game, turret)
            if Chill.isIceTurret(turret) then return {} end
            local count = countAdjacentIceTurrets(game, turret)
            if count == 0 then return {} end
            return {
                { statModifiers = { fireRate = { mult = self.PER_ICE_TURRET * count } } },
            }
        end,
    },

    -- -------------------------------------------------------------------------
    -- Fire synergy (burn, see Burn.lua)
    -- -------------------------------------------------------------------------
    {
        id = "fuel_tank",
        name = "Fuel Tank",
        icon = "drop",
        color = {1, 0.6, 0.2, 1},
        description = "Every time burn is applied, it applies 1 extra stack.",
        EXTRA_STACKS = 1,
        modifyBurnApplied = function(self, game, amount, enemy, source)
            return amount + self.EXTRA_STACKS
        end,
    },
    {
        id = "persistent_flames",
        name = "Persistent Flames",
        icon = "flame",
        color = {1, 0.45, 0.1, 1},
        description = "Burn decays 30% slower.",
        effects = {
            { target = "enemy", burnDecayMult = 0.7 },
        },
    },
    {
        id = "combustion",
        name = "Combustion",
        icon = "burst",
        color = {1, 0.35, 0.05, 1},
        description = "When a burning enemy is killed, its burn spreads to the nearest enemy.",
        RANGE = 120,
        onBurningEnemyDied = function(self, game, enemy, burnState)
            local nearest, bestDist = nil, self.RANGE * self.RANGE
            for _, obj in ipairs(game.objects or {}) do
                if obj ~= enemy and obj:isType("enemy") and not obj.destroyed and not obj.isDead then
                    local d = (obj.x - enemy.x) ^ 2 + (obj.y - enemy.y) ^ 2
                    if d <= bestDist then nearest, bestDist = obj, d end
                end
            end
            if not nearest then return end

            -- Each turret keeps credit for the stacks it added
            local stacks = burnState.stacks
            local shares = {}
            for turret, share in pairs(burnState.credit.creditShares) do shares[turret] = share end
            local function spread()
                local credited = 0
                for turret, share in pairs(shares) do
                    Burn.addRaw(nearest, share, turret)
                    credited = credited + share
                end
                Burn.addRaw(nearest, stacks - credited)
            end
            if game.spawnDebuffProjectile then
                local c = Burn.getColor(stacks)
                game:spawnDebuffProjectile(enemy.x, enemy.y, nearest, spread, { c[1], c[2], c[3], 1 })
            else
                spread()
            end
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
