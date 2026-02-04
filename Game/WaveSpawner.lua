-- store each wave as a table of enemies with their locations
-- spawn all enemies at once off screen
-- make it so they are 'untargetable' until they enter the play area

WaveSpawner = {}
WaveSpawner.__index = WaveSpawner

local default = {
    spawnRate = 0.5, -- Time in seconds between spawns
    spawntimer = 0,
    waveEnemies = {},
    waveInitialized = false,
    Enemies = {
        {
            name = "Speeder",
            spawnAmount = -4,
            maxSpawnAmount = -4,
            factor = 1.1,
            initial = 10,
            reference = require("Enemies.Speeder")
        },
        {
            spawnAmount = 3,
            name = "Basic",
            maxSpawnAmount = 3,
            factor = 1.3,
            reference = require("Enemies.Enemy")
        },
        {
            name = "Tank",
            spawnAmount = -2,
            maxSpawnAmount = -2,
            factor = 1.3,
            reference = require("Enemies.Tank")
        }
    }
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
    instance.Enemies = default.Enemies
    instance.waveState = "idle"
    -- local instance = setmetatable({}, WaveSpawner)
    -- instance.game = config.game
    -- instance.spawnRate = config.spawnRate
    -- instance.spawntimer = config.spawntimer
    -- instance.spawnAmount = config.spawnAmount
    return instance
end




function WaveSpawner:update(dt)
    if self.waveState == "idle" then
        -- Wait for GameManager to activate the wave
        return
    elseif self.waveState == "active" then
        -- Initialize wave if just activated
        if not self.waveInitialized then
            self.game.wave = self.game.wave + 1
            self.waveEnemies = {}
            self.waveInitialized = true

            for i, e in ipairs(self.Enemies) do
                if(e.maxSpawnAmount > 0) then
                    table.insert(self.waveEnemies, i)
                end
            end
        else
            if(#self.waveEnemies == 0) then
                -- Check if all enemies are defeated
                local enemiesAlive = 0
                for _, obj in ipairs(self.game.objects) do
                    if obj.tag == "enemy" and not obj.destroyed then
                        enemiesAlive = enemiesAlive + 1
                    end
                end
            
                if enemiesAlive == 0 then
                    -- Show reward selection at end of wave
                    self.waveState = "complete"
                end
                return -- Stop spawning if the wave is complete
            end
            self.spawntimer = self.spawntimer - dt
            if self.spawntimer < 0 then -- Adjust the spawn rate as needed
                config = {
                    game = self.game,
                    x = 800,
                    y = math.random(110, 490)
                }
                index = math.random(1, #self.waveEnemies)
                reference = self.waveEnemies[index]
                self.game:addObject(self.Enemies[reference].reference:new(config))
                self.Enemies[reference].spawnAmount = self.Enemies[reference].spawnAmount - 1
                if(self.Enemies[reference].spawnAmount <= 0) then
                    table.remove(self.waveEnemies, index)
                end
                self.spawntimer = self.spawnRate -- Reset the spawn timer
            end
        end
    elseif self.waveState == "complete" then
        for i, e in ipairs(self.Enemies) do
            if(e.maxSpawnAmount <= -1) then
                e.maxSpawnAmount = e.maxSpawnAmount + 1
            elseif (e.maxSpawnAmount == 0) then
                e.maxSpawnAmount = e.initial or 1
                e.spawnAmount = e.maxSpawnAmount
            else
                e.maxSpawnAmount = e.maxSpawnAmount * e.factor
                e.spawnAmount = e.maxSpawnAmount
            end
        end
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