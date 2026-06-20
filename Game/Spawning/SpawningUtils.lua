local SpawningUtils = {}

function SpawningUtils.getScaledDelay(baseDelay, globalDifficulty)
    local difficulty = globalDifficulty or 1
    -- Subtract 5% of the base delay per difficulty level above 1, capped at 60% reduction.
    local reductionPercent = math.min(0.60, (difficulty - 1) * 0.05)
    local scaled = baseDelay * (1 - reductionPercent)
    return math.max(0.05, scaled)
end

-- Boilerplate/Runtime Spawner Structure
local BattleLoop = {}
BattleLoop.__index = BattleLoop

function BattleLoop:new(laneQueues, globalDifficulty)
    local obj = setmetatable({}, BattleLoop)
    obj.laneQueues = laneQueues or {}
    obj.globalDifficulty = globalDifficulty or 1
    
    -- Initialize independent spawn timers for each lane.
    -- Each lane starts with the difficulty-scaled delay of its first enemy.
    obj.laneTimers = {}
    for i = 1, #obj.laneQueues do
        local queue = obj.laneQueues[i]
        if queue and #queue > 0 then
            local enemyClass = queue[1]
            local baseDelay = enemyClass.baseSpawnDelay or 1.0
            obj.laneTimers[i] = SpawningUtils.getScaledDelay(baseDelay, obj.globalDifficulty)
        else
            obj.laneTimers[i] = 0
        end
    end
    
    return obj
end

function BattleLoop:updateSpawns(dt)
    for laneIndex, queue in ipairs(self.laneQueues) do
        if #queue > 0 then
            self.laneTimers[laneIndex] = self.laneTimers[laneIndex] - dt
            if self.laneTimers[laneIndex] <= 0 then
                -- Pop the next enemy from this specific lane's queue
                local enemyClass = table.remove(queue, 1)
                
                -- "Spawn" the enemy (using print as requested)
                print(string.format("[Spawn] Spawning enemy on Lane %d (Class: %s)", laneIndex, tostring(enemyClass)))
                
                -- Set the timer for the *next* enemy in the queue
                if #queue > 0 then
                    local nextEnemy = queue[1]
                    local baseDelay = nextEnemy.baseSpawnDelay or 1.0
                    local nextDelay = SpawningUtils.getScaledDelay(baseDelay, self.globalDifficulty)
                    self.laneTimers[laneIndex] = nextDelay
                else
                    self.laneTimers[laneIndex] = 0
                end
            end
        end
    end
end

SpawningUtils.BattleLoop = BattleLoop

return SpawningUtils
