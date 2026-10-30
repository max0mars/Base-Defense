-- =============================================================================
-- ARTIFACT MANAGER (ArtifactManager.lua)
-- Owns the run's artifacts and applies them to a battle.
--
-- Ownership is persistent: the ids live in _G.PersistentState.artifacts, in the
-- order they were acquired. Use the static helpers (grant / remove / owns) to
-- change it from anywhere, e.g. a future reward screen.
--
-- Each battle, GameManager builds an ArtifactManager instance that:
--   * applies every artifact's stat effects to the global player/enemy
--     EffectManagers (so they reach every turret / enemy through the parent
--     chain and show up in turret tooltips), plus per-turret effects to the
--     turrets themselves, re-evaluating board-dependent effects whenever the
--     board changes (refresh)
--   * forwards game events to artifact hooks (trigger)
--   * lets artifacts adjust values the game computes (modify)
--
-- Event hooks  -- artifact:hook(game, ...)
--   onBattleStart()                    battle loaded, before the mulligan
--   onWaveStart()                      a wave was launched
--   onWaveComplete()                   a wave was cleared
--   onEnemyKilled(enemy, killingBlow)  an enemy died to damage (not by reaching
--                                      the base); killingBlow = {source,
--                                      damageType, damageTags}
--   onEnemyThaw(enemy)                 a frozen enemy started thawing
--   onBurningEnemyDied(enemy, burnState)  a burning enemy was killed (see Burn.lua)
--
-- Modifier hooks  -- artifact:hook(game, value, ...) -> new value
--   modifyMaxTokens(maxTokens)
--   modifyEnemyDamage(amount, enemy, damageType, damageTags, source)
--   modifyBaseDamage(amount, sourceEntity)
--   modifyBurnApplied(stacks, enemy, source)  stacks one burn application adds
-- =============================================================================

local ArtifactIndex = require("Game.Artifacts.ArtifactIndex")

local ArtifactManager = {}
ArtifactManager.__index = ArtifactManager

-- -----------------------------------------------------------------------------
-- Persistent ownership
-- -----------------------------------------------------------------------------

--- The owned artifact ids (live table from PersistentState; empty outside a run).
function ArtifactManager.getOwnedIds()
    local ps = _G.PersistentState
    if not ps then return {} end
    ps.artifacts = ps.artifacts or {}
    return ps.artifacts
end

function ArtifactManager.owns(id)
    for _, owned in ipairs(ArtifactManager.getOwnedIds()) do
        if owned == id then return true end
    end
    return false
end

--- Adds an artifact to the run. Artifacts are unique: returns false if already owned.
function ArtifactManager.grant(id)
    if not ArtifactIndex.get(id) then
        error("Developer Error: unknown artifact id '" .. tostring(id) .. "'")
    end
    if not _G.PersistentState or ArtifactManager.owns(id) then return false end
    table.insert(ArtifactManager.getOwnedIds(), id)
    return true
end

function ArtifactManager.remove(id)
    local ids = ArtifactManager.getOwnedIds()
    for i = #ids, 1, -1 do
        if ids[i] == id then
            table.remove(ids, i)
            return true
        end
    end
    return false
end

--- Definitions of every artifact the run doesn't own yet.
function ArtifactManager.getUnowned()
    local unowned = {}
    for _, def in ipairs(ArtifactIndex.list) do
        if not ArtifactManager.owns(def.id) then
            table.insert(unowned, def)
        end
    end
    return unowned
end

--- Grants a random unowned artifact. Returns its definition, or nil if all are owned.
function ArtifactManager.grantRandom()
    local pool = ArtifactManager.getUnowned()
    if #pool == 0 then return nil end
    local def = pool[math.random(#pool)]
    ArtifactManager.grant(def.id)
    return def
end

--- Definitions of the owned artifacts, in acquisition order.
function ArtifactManager.getOwnedDefinitions()
    local defs = {}
    for _, id in ipairs(ArtifactManager.getOwnedIds()) do
        local def = ArtifactIndex.get(id)
        if def then table.insert(defs, def) end
    end
    return defs
end

-- -----------------------------------------------------------------------------
-- Per-battle instance
-- -----------------------------------------------------------------------------

--- @param ids table|nil artifact ids to run with (defaults to the owned ones)
function ArtifactManager:new(game, ids)
    local m = setmetatable({ game = game, artifacts = {} }, self)
    for _, id in ipairs(ids or ArtifactManager.getOwnedIds()) do
        m:addInstance(id)
    end
    return m
end

--- Per-battle instance of a definition: `state` holds battle-local counters.
function ArtifactManager:addInstance(id)
    local def = ArtifactIndex.get(id)
    if not def then
        error("Developer Error: unknown artifact id '" .. tostring(id) .. "'")
    end
    table.insert(self.artifacts, setmetatable({ state = {} }, { __index = def }))
end

function ArtifactManager:has(id)
    for _, a in ipairs(self.artifacts) do
        if a.id == id then return true end
    end
    return false
end

--- Removes every artifact effect from the player and enemy EffectManagers, and
--- the per-turret ones (getTurretEffects) from every object.
function ArtifactManager:clearEffects()
    local managers = { self.game.playerEffectManager, self.game.enemyEffectManager }
    for _, obj in ipairs(self.game.objects or {}) do
        if obj.effectManager then table.insert(managers, obj.effectManager) end
    end
    for _, em in ipairs(managers) do
        for i = #em.activeEffects, 1, -1 do
            local effect = em.activeEffects[i]
            if effect.isArtifactEffect then
                local key = em:getStackingKey(effect)
                em.effectCounts[key] = (em.effectCounts[key] or 1) - 1
                table.remove(em.activeEffects, i)
            end
        end
    end
end

local function addArtifactEffect(em, artifact, template, key)
    local effect = {}
    for k, v in pairs(template) do effect[k] = v end
    effect.target = nil
    effect.name = "artifact_" .. artifact.id .. "_" .. key
    effect.displayName = artifact.name
    effect.isArtifactEffect = true
    table.insert(em.activeEffects, effect)
    em.effectCounts[effect.name] = (em.effectCounts[effect.name] or 0) + 1
end

--- (Re)applies every artifact's stat effects. Call whenever the board changes so
--- board-dependent effects (getEffects, getTurretEffects) stay current.
function ArtifactManager:refresh()
    local game = self.game
    if not (game.playerEffectManager and game.enemyEffectManager) then return end
    -- Nothing applied and nothing to apply: skip the stat propagation pass
    if #self.artifacts == 0 and not self.effectsApplied then return end
    self:clearEffects()
    self.effectsApplied = true

    for _, artifact in ipairs(self.artifacts) do
        local templates = {}
        for _, t in ipairs(artifact.effects or {}) do table.insert(templates, t) end
        if artifact.getEffects then
            for _, t in ipairs(artifact:getEffects(game)) do table.insert(templates, t) end
        end

        for i, template in ipairs(templates) do
            local em = (template.target == "enemy") and game.enemyEffectManager or game.playerEffectManager
            addArtifactEffect(em, artifact, template, i)
        end

        if artifact.getTurretEffects then
            for _, obj in ipairs(game.objects or {}) do
                if not obj.destroyed and obj.effectManager and obj.isType and obj:isType("turret") then
                    for i, template in ipairs(artifact:getTurretEffects(game, obj)) do
                        addArtifactEffect(obj.effectManager, artifact, template, "turret_" .. i)
                    end
                end
            end
        end
    end

    -- Push the new modifiers down the parent chain in one pass
    game.playerEffectManager:recalculateStats()
    game.enemyEffectManager:recalculateStats()
    game.playerEffectManager:propagateRecalculation()
end

--- Calls `eventName` on every artifact that implements it.
function ArtifactManager:trigger(eventName, ...)
    for _, artifact in ipairs(self.artifacts) do
        local hook = artifact[eventName]
        if type(hook) == "function" then
            hook(artifact, self.game, ...)
        end
    end
end

--- Folds `value` through every artifact implementing `hookName` and returns the result.
function ArtifactManager:modify(hookName, value, ...)
    for _, artifact in ipairs(self.artifacts) do
        local hook = artifact[hookName]
        if type(hook) == "function" then
            value = hook(artifact, self.game, value, ...)
        end
    end
    return value
end

return ArtifactManager
