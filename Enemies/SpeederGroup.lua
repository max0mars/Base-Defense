local Speeder = require("Enemies.Speeder")

local SpeederGroup = {}
SpeederGroup.__index = SpeederGroup

function SpeederGroup:new(config)
    config = config or {}
    -- 1. Create the main instance that WaveSpawner expects to receive, mutate, and add.
    local mainSpeeder = Speeder:new(config)
    
    -- 2. Create the additional 2 squad members in a wedge formation behind the leader.
    if config.game then
        local offsets = {
            {x = 16 + math.random(-8, 8), y = -16 + math.random(-6, 6)},
            {x = 16 + math.random(-8, 8), y = 16 + math.random(-6, 6)}
        }
        local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
        for _, off in ipairs(offsets) do
            local subConfig = {}
            for k, v in pairs(config) do subConfig[k] = v end
            subConfig.x = (config.x or 800) + off.x
            subConfig.y = (config.y or 0) + off.y
            
            local squadMember = Speeder:new(subConfig)
            EnemyRegistry:applyActiveMutations(squadMember)
            config.game:addObject(squadMember)
        end
    end
    
    return mainSpeeder
end

return SpeederGroup
