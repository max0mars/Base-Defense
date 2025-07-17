local EnemyData = {}
local Enemy = require("Enemies.Enemy") -- Import the Enemies module
EnemyData.types = {
    basic = {
        speed = 25,
        damage = 10,
        xp = 5,
        size = 8, -- Default size for basic enemies
        shape = "circle", -- Default shape for basic enemies
        color = {1, 0, 0, 1}, -- Default color for basic enemies
        hitbox = {
            shape = "circle",
        },
        hp = 100, -- Default health for basic enemies
        maxHp = 100, -- Maximum health for basic enemies
        tag = "enemy", -- Tag for collision detection
    },
}

function EnemyData:new(gameRef, type, x, y)
    -- Create a copy of the enemy config instead of using the shared table
    local baseConfig = self.types.basic
    local enemyConfig = {
        speed = baseConfig.speed,
        damage = baseConfig.damage,
        xp = baseConfig.xp,
        size = baseConfig.size,
        shape = baseConfig.shape,
        color = {baseConfig.color[1], baseConfig.color[2], baseConfig.color[3], baseConfig.color[4]}, -- Copy color array
        hitbox = {
            shape = baseConfig.hitbox.shape,
        },
        hp = baseConfig.hp,
        maxHp = baseConfig.maxHp,
        tag = baseConfig.tag,
        x = x,
        y = y,
        game = gameRef, -- Reference to the game object
    }
    return Enemy:new(enemyConfig) -- Create a new Enemy instance with the final configuration
end

return EnemyData