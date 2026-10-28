-- =============================================================================
-- LEVEL MANAGER (LevelManager.lua)
-- Manages 3-choice battle encounter selection, difficulty scaling, enemy forecast
-- obfuscation ('???'), and previewable battle rewards.
-- =============================================================================

local BattleIndex = require("Game.Spawning.BattleIndex")
local BattleManager = require("Game.Core.BattleManager")
local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
local WaveDirector = require("Game.Spawning.WaveDirector")
local Scouting = require("Game.Prep.Scouting")

local LevelManager = {}
LevelManager.__index = LevelManager

function LevelManager:new(battleIndex)
    local obj = setmetatable({}, self)
    obj.battleIndex = battleIndex or BattleIndex
    obj.battleManager = BattleManager:new()
    obj.currentChoices = {}
    return obj
end

--- Generates a difficulty multiplier formatted to 2 decimal places.
-- @param isGuaranteedSafe boolean: If true, generates in [1.00, 1.19] (< 1.20).
--                                  If false, generates in [1.00, 2.00].
--
-- MATHEMATICAL GUARANTEE:
-- Range: [1.00, 2.00]
-- Constraint: At least one choice MUST be strictly below 1.20 (< 1.20).
-- When isGuaranteedSafe == true:
--   uniform sample between 1.000 and 1.199.
--   min value = 1.00, max value <= 1.19.
--   Thus, multiplier is mathematically guaranteed to be < 1.20.
function LevelManager:generateMultiplier(isGuaranteedSafe)
    if isGuaranteedSafe then
        -- Strictly below 1.20: range [1.00, 1.19]
        local val = 1.0 + (math.random(0, 19) / 100) -- generates {1.00, 1.01, ..., 1.19}
        return val
    else
        -- Standard range [1.00, 2.00]
        local val = 1.0 + (math.random(0, 100) / 100) -- generates {1.00, 1.01, ..., 2.00}
        return val
    end
end

--- Retrieves eligible BattleTemplates from BattleIndex matching the player's level.
-- If no templates directly match the level range, falls back to the nearest valid template.
function LevelManager:getEligibleTemplates(playerLevel)
    local templates = self.battleIndex
    local eligible = {}

    -- Levels 1, 2, and 3 are fixed in sequence: battle_1, battle_2, battle_3
    if playerLevel == 1 and templates.battle_1 then
        return { templates.battle_1 }
    elseif playerLevel == 2 and templates.battle_2 then
        return { templates.battle_2 }
    elseif playerLevel == 3 and templates.battle_3 then
        return { templates.battle_3 }
    end

    for key, template in pairs(templates) do
        if type(template) == "table" and type(template.isValidForBattle) == "function" then
            if template:isValidForBattle(playerLevel) then
                table.insert(eligible, template)
            end
        end
    end

    -- Fallback: if no template strictly valid for this level, find nearest or any valid template
    if #eligible == 0 then
        local maxRange = -1
        local fallback = nil
        for key, template in pairs(templates) do
            if type(template) == "table" and (template.maximumLevel or (template.validBattleRange and template.validBattleRange.max)) then
                local maxLvl = template.maximumLevel or template.validBattleRange.max
                if maxLvl > maxRange then
                    maxRange = maxLvl
                    fallback = template
                end
            end
        end
        if fallback then
            table.insert(eligible, fallback)
        end
    end

    return eligible
end

--- Picks a random template from eligible ones, weighted by template.weight
function LevelManager:pickRandomTemplate(eligibleTemplates)
    if #eligibleTemplates == 0 then return nil end

    local totalWeight = 0
    for _, t in ipairs(eligibleTemplates) do
        totalWeight = totalWeight + (t.weight or 10)
    end

    local roll = math.random(1, totalWeight)
    local running = 0
    for _, t in ipairs(eligibleTemplates) do
        running = running + (t.weight or 10)
        if roll <= running then
            return t
        end
    end

    return eligibleTemplates[1]
end

--- Obfuscates enemy name: returns enemyId if the scouting level reveals it, or "???".
function LevelManager:getEnemyDisplayName(enemyId)
    return Scouting.canSee(enemyId) and enemyId or "???"
end

--- Generates incoming enemy summary for a template, hiding enemies the scouting level doesn't reveal.
function LevelManager:generateEnemyForecast(template, multiplier, dummyGame, existingRoster)
    local BattleDirector = require("Game.Spawning.BattleDirector")
    local bd = BattleDirector:new(dummyGame or {})
    local roster = existingRoster or bd:buildBattleRoster(template)

    local incomingEnemies = {}
    local addedIds = {}

    for _, enemy in ipairs(roster or {}) do
        if enemy and enemy.id and not addedIds[enemy.id] then
            addedIds[enemy.id] = true
            local isScouted = Scouting.canSee(enemy.id)
            table.insert(incomingEnemies, {
                id = enemy.id,
                displayName = isScouted and enemy.id or "???",
                isScouted = isScouted
            })
        end
    end

    -- Fallback safety: if empty, default to Grunt
    if #incomingEnemies == 0 then
        local isScouted = Scouting.canSee("Grunt")
        table.insert(incomingEnemies, {
            id = "Grunt",
            displayName = isScouted and "Grunt" or "???",
            isScouted = isScouted
        })
    end

    return incomingEnemies, roster
end

-- The 3rd battle of every five-battle loop offers an elite option
LevelManager.ELITE_LOOP_POSITION = 3
LevelManager.ELITE_DIFFICULTY = 2.5

--- Checks whether a given battle level offers an elite battle (3, 8, 13...).
function LevelManager:isEliteLevel(playerLevel)
    return (playerLevel or 1) % 5 == LevelManager.ELITE_LOOP_POSITION
end

--- Checks whether a given battle level is a milestone battle (every 5th battle).
function LevelManager:isMilestoneBattle(playerLevel)
    local level = playerLevel or 1
    return (level > 0 and (level % 5 == 0))
end

--- Generates level choices for the player's next encounter.
-- On milestone battles: exactly 1 non-optional milestone battle choice is returned.
-- On regular battles: exactly 3 choices are generated, with at least one having difficultyMultiplier < 1.20.
-- @param playerLevel number: Current player level / battle number
-- @param dummyGame table: Optional mock game object
-- @return table: List of level choice objects (1 on milestone, 3 on standard)
function LevelManager:generateChoices(playerLevel, dummyGame)
    local level = playerLevel or 1
    local eligible = self:getEligibleTemplates(level)
    local choices = {}

    -- MILESTONE BATTLE: Player doesn't have a choice
    if self:isMilestoneBattle(level) then
        local template = self:pickRandomTemplate(eligible)
        -- Fixed difficulty for milestone battles (always 2.00 multiplier)
        local multiplier = 2.00
        local rewards = self.battleManager:generateRewards(multiplier, level)
        local enemies, roster = self:generateEnemyForecast(template, multiplier, dummyGame)

        local choice = {
            index = 1,
            slotIndex = 1,
            templateId = template and template.id or ("battle_" .. level),
            template = template,
            roster = roster,
            difficultyMultiplier = multiplier,
            playerLevel = level,
            enemies = enemies,
            rewards = rewards,
            title = string.format("Level %d [MAJOR BATTLE]", level),
            isMilestone = true,
            isSafe = false
        }
        table.insert(choices, choice)
        self.currentChoices = choices
        return choices
    end

    -- REGULAR BATTLES: Constraint: 3 choices, at least 1 must have difficultyMultiplier < 1.20
    -- Designate slot 1 as guaranteed safe (< 1.20), slots 2 and 3 as standard [1.00, 2.00]
    -- On elite levels slot 3 is the elite battle: fixed 2.5x, always rewards an artifact
    local safeIndex = 1
    local eliteIndex = self:isEliteLevel(level) and 3 or nil

    for i = 1, 3 do
        local isSafe = (i == safeIndex)
        local isElite = (i == eliteIndex)
        local multiplier = isElite and LevelManager.ELITE_DIFFICULTY or self:generateMultiplier(isSafe)
        local template = self:pickRandomTemplate(eligible)

        -- Generate precomputed rewards viewable by the player
        local rewards = self.battleManager:generateRewards(multiplier, level)
        if isElite then table.insert(rewards, BattleManager.artifactReward()) end

        -- Generate incoming enemy roster with discovery obfuscation ('???')
        local enemies, roster = self:generateEnemyForecast(template, multiplier, dummyGame)

        local choice = {
            index = i,
            templateId = template and template.id or ("battle_" .. level),
            template = template,
            roster = roster,
            difficultyMultiplier = multiplier,
            playerLevel = level,
            enemies = enemies,
            rewards = rewards,
            title = string.format("Sector %d", level),
            isMilestone = false,
            isElite = isElite,
            isSafe = (multiplier < 1.20)
        }
        table.insert(choices, choice)
    end

    -- Shuffle choices (Fisher-Yates) so the guaranteed safe choice (< 1.20) is placed at a random slot
    for i = #choices, 2, -1 do
        local j = math.random(1, i)
        choices[i], choices[j] = choices[j], choices[i]
    end

    -- Re-assign index property for UI binding
    for i, choice in ipairs(choices) do
        choice.slotIndex = i
    end

    self.currentChoices = choices
    return choices
end

return LevelManager
