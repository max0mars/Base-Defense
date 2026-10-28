-- Game/Prep/Scouting.lua
-- Scouting level decides which enemies a scouting report names. An enemy is
-- revealed when its tier is below the scouting level; bosses are always shown.
-- Having met an enemy before doesn't reveal it.

local EnemyIndex = require("Game.Spawning.EnemyIndex")

local Scouting = {}

Scouting.START_LEVEL = 1 -- tier 0 enemies are visible from the start
Scouting.MAX_LEVEL = 4   -- reveals tiers 0-3
Scouting.BOSS_TIER = 5

function Scouting.getLevel()
    local ps = _G.PersistentState or {}
    return ps.scoutingLevel or Scouting.START_LEVEL
end

local function findEntry(nameOrId)
    for _, e in ipairs(EnemyIndex) do
        if e.id == nameOrId or e.type == nameOrId then return e end
    end
end

--- Tier of an enemy by id, type or alias; nil if unknown.
function Scouting.tierOf(enemyId)
    if not enemyId then return nil end
    local entry = findEntry(enemyId)
    if not entry then
        local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
        entry = findEntry(EnemyRegistry:canonicalEnemyId(enemyId))
    end
    return entry and (entry.tier or 0)
end

--- True if the scouting report names this enemy (otherwise it shows as ???).
function Scouting.canSee(enemyId)
    local tier = Scouting.tierOf(enemyId)
    if not tier then return false end
    return tier >= Scouting.BOSS_TIER or tier < Scouting.getLevel()
end

return Scouting
