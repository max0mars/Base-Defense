-- WaveSpawner.lua: Worker responsible for executing the spawn list from WaveDirector.

local WaveSpawner = {}
WaveSpawner.__index = WaveSpawner

local default = {
    spawnRate = 0.2,
    spawntimer = 0,
    waveList = {}, -- Buffer of enemy classes to spawn
    waveInitialized = false,
    waveState = "idle"
}

function WaveSpawner:new(config)
    if(config.game == nil) then
        error("Game reference is required to create WaveSpawner")
    end
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    local instance = setmetatable({}, WaveSpawner)
    for k, v in pairs(config) do 
        instance[k] = v
    end
    
    if not instance.activeSectors then
        instance:updateActiveSectors()
    end
    
    return instance
end

function WaveSpawner:update(dt)
    if self.waveState == "idle" then
        return
    elseif self.waveState == "active" then
        if not self.waveInitialized then
            self.game.wave = self.game.wave + 1
            self.spawnRate = 0.5 * (0.95 ^ (self.game.wave))

            -- Use the pre-calculated waves from preparation_scene
            local summary
            if _G.PersistentState and _G.PersistentState.upcomingWaves and #_G.PersistentState.upcomingWaves > 0 then
                self.waveList = table.remove(_G.PersistentState.upcomingWaves, 1)
                summary = table.remove(_G.PersistentState.upcomingSummaries, 1)
            else
                self.waveList, summary = self.game.waveDirector:generateWaveList(self.game.wave, _G.PersistentState and _G.PersistentState.globalDifficulty or 1)
            end
            
            self:buildLiveRoster(summary)
            self.waveInitialized = true
        else
            if #self.waveList == 0 then
                -- Check if all enemies are defeated
                local enemiesAlive = 0
                for _, obj in ipairs(self.game.objects) do
                    if obj:isType("enemy") and not obj.destroyed then
                        enemiesAlive = enemiesAlive + 1
                    end
                end
            
                if enemiesAlive == 0 then
                    self.waveState = "complete"
                end
                return
            end
            
            self.spawntimer = self.spawntimer - dt
            if self.spawntimer < 0 then
                local grid = self.game.battlefieldGrid
                -- Exclude outermost rows to prevent edge-creeping spawns
                local minRow = (grid.height > 2) and 2 or 1
                local maxRow = (grid.height > 2) and (grid.height - 1) or grid.height
                
                -- Shuffled deck logic for sectors
                if not self.sectorDeck or #self.sectorDeck == 0 then
                    self.sectorDeck = {}
                    local numLanes = #self.activeSectors
                    local amountPerLane = math.floor(6 / numLanes)
                    for _, sector in ipairs(self.activeSectors) do
                        for i = 1, amountPerLane do
                            table.insert(self.sectorDeck, sector)
                        end
                    end
                    for i = #self.sectorDeck, 2, -1 do
                        local j = math.random(1, i)
                        self.sectorDeck[i], self.sectorDeck[j] = self.sectorDeck[j], self.sectorDeck[i]
                    end
                end
                local currentSector = table.remove(self.sectorDeck)
                
                local totalRows = maxRow - minRow + 1
                local sectorSize = totalRows / 3.0
                
                local sectorMinRow = minRow + math.floor(currentSector * sectorSize)
                local sectorMaxRow = minRow + math.floor((currentSector + 1) * sectorSize) - 1
                if sectorMinRow > sectorMaxRow then sectorMaxRow = sectorMinRow end
                if sectorMaxRow > maxRow then sectorMaxRow = maxRow end
                
                local randomRow = math.random(sectorMinRow, sectorMaxRow)
                local startY = grid.y + (randomRow - 1) * grid.cellSize + grid.cellSize / 2
                
                local enemyClass = table.remove(self.waveList, 1)
                local spawnConfig = {
                    game = self.game,
                    x = 800,
                    y = startY
                }
                
                local enemyInstance = enemyClass:new(spawnConfig)

                -- Apply Mutation Upgrades
                local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
                EnemyRegistry:applyActiveMutations(enemyInstance)

                -- Codex: mark this enemy type as seen.
                if self.game.seenEnemies and enemyInstance.name then
                    self.game.seenEnemies[enemyInstance.name] = true
                end

                self.game:addObject(enemyInstance)
                
                self.spawntimer = self.spawnRate
            end
        end
    elseif self.waveState == "complete" then
        self:updateActiveSectors()
        -- Logic for transitioning after wave completion handled by GameManager or UI
        self.waveState = "idle"        
    end
end

function WaveSpawner:startNextWave()
    if self.waveState == "idle" then
        self.waveState = "active"
        self.waveInitialized = false
    end
end

--- Generates and caches the next wave's enemy list + composition summary while idle
--- (i.e. during the 'preparing'/'startup' phases) so the preview is accurate.
function WaveSpawner:prepareUpcomingWave()
    -- Testing mode spawns waves manually (Enemy Spawner), so skip precomputing
    -- a director wave — it's meaningless there and must not interfere.
    if self.game.testingMode then return end
    if self.waveState ~= "idle" then return end
    local nextWaveNum = self.game.wave + 1
    if self.pendingWaveNum == nextWaveNum and self.pendingWaveList then return end
    local list, summary = self.game.waveDirector:generateWaveList(nextWaveNum, _G.PersistentState and _G.PersistentState.globalDifficulty or 1)
    self.pendingWaveList = list
    self.pendingSummary = summary
    self.pendingWaveNum = nextWaveNum
end

--- Returns the upcoming wave's composition summary and wave number (for the preview UI).
function WaveSpawner:getUpcomingSummary()
    self:prepareUpcomingWave()
    return self.pendingSummary, self.pendingWaveNum
end

-- ---------------------------------------------------------------------------
-- Live roster: per-enemy-type kill tracking for the in-progress wave panel.
-- Buckets are keyed by registry id, which equals the spawned enemy's `name`.
-- ---------------------------------------------------------------------------

function WaveSpawner:buildLiveRoster(summary)
    self.liveRoster = {}
    self.rosterIndex = {}
    if not summary then return end
    for _, item in ipairs(summary) do
        local bucket = { id = item.id, type = item.type, total = item.count, killed = 0, flashUntil = 0 }
        table.insert(self.liveRoster, bucket)
        self.rosterIndex[item.id] = bucket
    end
end

--- Records a kill against its roster bucket and arms a brief explosion flash on
--- that card. Extra kills beyond the original count (e.g. from carrier/split
--- spawns) are ignored so the panel cleanly drains the previewed roster to zero.
function WaveSpawner:notifyEnemyKilled(enemy)
    if not self.rosterIndex then return end
    local bucket = enemy and enemy.name and self.rosterIndex[enemy.name]
    if not bucket or bucket.killed >= bucket.total then return end
    bucket.killed = bucket.killed + 1
    bucket.flashUntil = love.timer.getTime() + 0.55
end

--- The current wave's roster (or nil if none built yet).
function WaveSpawner:getLiveRoster()
    return self.liveRoster
end

function WaveSpawner:startCustomWave(waveList)
    if self.waveState == "idle" then
        self.waveState = "active"
        self.waveList = waveList
        self.waveInitialized = true
        self.pendingWaveList = nil
        self.pendingSummary = nil
        self.pendingWaveNum = nil
        self.game.wave = self.game.wave + 1
        self.spawnRate = 0.5 * (0.95 ^ (self.game.wave))
    end
end

function WaveSpawner:updateActiveSectors()
    local nextWave = (self.game and self.game.wave) and (self.game.wave + 1) or 1
    local numLanes = 1
    if nextWave == 3 or nextWave == 4 then
        numLanes = 2
    elseif nextWave >= 5 then
        numLanes = 3
    end
    
    local sectors = {0, 1, 2}
    for i = 3, 2, -1 do
        local j = math.random(1, i)
        sectors[i], sectors[j] = sectors[j], sectors[i]
    end
    
    self.activeSectors = {}
    for i = 1, numLanes do
        table.insert(self.activeSectors, sectors[i])
    end
    
    self.sectorDeck = {}
    local amountPerLane = math.floor(6 / numLanes)
    for _, sector in ipairs(self.activeSectors) do
        for i = 1, amountPerLane do
            table.insert(self.sectorDeck, sector)
        end
    end
    
    for i = #self.sectorDeck, 2, -1 do
        local j = math.random(1, i)
        self.sectorDeck[i], self.sectorDeck[j] = self.sectorDeck[j], self.sectorDeck[i]
    end
end

function WaveSpawner:draw()
    if (self.game:isState("preparing") or self.game:isState("startup")) and self.activeSectors then
        local grid = self.game.battlefieldGrid
        local minRow = (grid.height > 2) and 2 or 1
        local maxRow = (grid.height > 2) and (grid.height - 1) or grid.height
        local totalRows = maxRow - minRow + 1
        local sectorSize = totalRows / 3.0
        
        -- Draw pulsing arrows indicating the active sectors
        local pulse = (math.sin(love.timer.getTime() * 5) + 1) / 2
        love.graphics.setColor(1, 0, 0, 0.5 + 0.5 * pulse)
        
        for _, sector in ipairs(self.activeSectors) do
            local sectorMinRow = minRow + math.floor(sector * sectorSize)
            local sectorMaxRow = minRow + math.floor((sector + 1) * sectorSize) - 1
            if sectorMinRow > sectorMaxRow then sectorMaxRow = sectorMinRow end
            if sectorMaxRow > maxRow then sectorMaxRow = maxRow end
            
            local startY = grid.y + (sectorMinRow - 1) * grid.cellSize
            local endY = grid.y + sectorMaxRow * grid.cellSize
            local midY = (startY + endY) / 2
            
            -- Draw an arrow pointing left from the spawn location
            local arrowX = 780
            love.graphics.polygon("fill", arrowX, midY - 15, arrowX, midY + 15, arrowX - 30, midY)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return WaveSpawner