local EnemyRegistry = {
    enemies = {
        {
            type = "Basic",
            class = require("Enemies.Enemy"),
            spawnCost = 10,
            spawnWeight = 100,
            minWave = 1
        },
        {
            type = "Speeder",
            class = require("Enemies.Speeder"),
            spawnCost = 15,
            spawnWeight = 50,
            minWave = 3
        },
        {
            type = "Tank",
            class = require("Enemies.Tank"),
            spawnCost = 40,
            spawnWeight = 20,
            minWave = 5
        }
    }
}

function EnemyRegistry:getAvailableEnemies(waveNumber)
    local available = {}
    for _, e in ipairs(self.enemies) do
        if waveNumber >= (e.minWave or 1) then
            table.insert(available, e)
        end
    end
    return available
end

return EnemyRegistry
