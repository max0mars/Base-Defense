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
    return instance
end

function WaveSpawner:update(dt)
    if self.waveState == "idle" then
        return
    elseif self.waveState == "active" then
        if not self.waveInitialized then
            self.game.wave = self.game.wave + 1
            self.spawnRate = 0.5 * (0.95 ^ (self.game.wave))
            
            -- Ask Director for the list of enemies
            self.waveList = self.game.waveDirector:generateWaveList(self.game.wave)
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
                local randomRow = math.random(minRow, maxRow)
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
                
                self.game:addObject(enemyInstance)
                
                self.spawntimer = self.spawnRate
            end
        end
    elseif self.waveState == "complete" then
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

return WaveSpawner