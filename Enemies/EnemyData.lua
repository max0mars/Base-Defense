local EnemyData = {}
local Enemy = require("Enemies.Enemy") -- Import the Enemies module
EnemyData.types = {
    basic = {
        speed = 100,
        damage = 10,
        xp = 5,
        size = 5, -- Default size for basic enemies
        shape = "circle", -- Default shape for basic enemies
        color = {1, 0, 0, 1}, -- Default color for basic enemies
        hitbox = {
            shape = "circle",
        }
    },
}

function EnemyData:new(type, x, y)
    local enemyConfig = self.types.basic
    enemyConfig.x = x
    enemyConfig.y = y
    return Enemy:new(enemyConfig) -- Create a new Enemy instance with the final configuration
end

return EnemyData