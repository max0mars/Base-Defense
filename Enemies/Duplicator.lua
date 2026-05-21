local Enemy = require("Enemies.Enemy")
local Duplicator = setmetatable({}, {__index = Enemy})
Duplicator.__index = Duplicator

local default = {
    speed = 22,
    damage = 20,
    maxHp = 200,
    color = {0.2, 0.8, 0.4, 1}, -- Toxic Green/Cellular color
    types = { duplicator = true, bio = true },
    size = 18,
    reward = 10, -- Base reward, splits will also give rewards
    generation = 0, -- Default generation 0
    radius = 80, -- Healing wave radius
    healWaveOnSplit = false,
    acceleratedMitosis = false,
    extraFinalClone = false,
    
    mutations = {
        {
            name = "Symbiotic Burst",
            target = "Duplicator",
            description = "On duplication, releases a healing wave affecting all enemies.",
            modifiers = { healWaveOnSplit = { set = true } },
            tier = 1,
            color = {0.1, 0.9, 0.3}
        },
        {
            name = "Accelerated Mitosis",
            target = "Duplicator",
            description = "Each duplication stage has increased movement speed.",
            modifiers = { acceleratedMitosis = { set = true } },
            tier = 2,
            color = {0.3, 0.8, 0.9}
        },
        {
            name = "Hyper-Replication",
            target = "Duplicator",
            description = "The last duplication stage spawns 1 extra clone.",
            modifiers = { extraFinalClone = { set = true } },
            tier = 3,
            color = {0.9, 0.2, 0.9}
        }
    }
}

function Duplicator:new(config)
    config = config or {}
    if not config.types then config.types = {} end
    for key, value in pairs(default) do
        if key ~= "mutations" then
            if config[key] == nil then
                config[key] = value
            end
        end
    end
    for key in pairs(default.types) do
        config.types[key] = true
    end
    
    local instance = Enemy:new(config)
    setmetatable(instance, Duplicator)
    
    return instance
end

function Duplicator:died()
    -- Prevent multiple triggers
    if self.isDead then return end
    self.isDead = true
    
    -- Trigger standard death effects and sound
    if self.effectManager then
        self.effectManager:triggerEvent("onDeath", self)
    end
    if AUDIO then AUDIO:playSFX("explosion_01") end

    -- Check if it died by hitting the base
    if self.x > self.target then
        -- UPGRADE 1: Symbiotic Burst (Heal Wave on Split)
        if self.healWaveOnSplit then
            local healRadiusSq = self.radius * self.radius
            -- Spawn visual expanding circle
            self.game:spawnExpandingCircle(self.x, self.y, 0, self.radius, {0.1, 0.9, 0.3}, 0.8)
            
            -- Find all enemies in radius and heal them
            if self.game and self.game.objects then
                for _, obj in ipairs(self.game.objects) do
                    if obj.isType and obj:isType("enemy") and not obj.destroyed and obj ~= self then
                        local dx = obj.x - self.x
                        local dy = obj.y - self.y
                        if (dx*dx + dy*dy) <= healRadiusSq then
                            local healAmount = 25
                            obj.hp = math.min(obj.hp + healAmount, obj:getStat("maxHp"))
                            self.game:spawnDamageNumber(healAmount, obj.x, obj.y, "heal")
                        end
                    end
                end
            end
        end

        -- Splitting Logic
        -- Gen 0 splits to Gen 1. Gen 1 splits to Gen 2. Gen 2 does not split.
        if self.generation < 2 then
            local childGeneration = self.generation + 1
            
            -- Default to 2 clones per split
            local numClones = 2
            
            -- UPGRADE 3: Hyper-Replication (Extra clone on final split)
            if self.extraFinalClone and self.generation == 1 then
                numClones = 3
            end
            
            -- Prepare child config
            local childMaxHp = math.max(1, math.floor(self:getStat("maxHp") / 2))
            local childSpeed = self:getStat("speed")
            local childSize = math.max(8, self.w * 0.75) -- Visually shrink clones
            local childDamage = math.max(10, self:getStat("damage") / 2)
            
            -- UPGRADE 2: Accelerated Mitosis
            if self.acceleratedMitosis then
                if childGeneration == 1 then
                    childSpeed = childSpeed * 1.5
                elseif childGeneration == 2 then
                    childSpeed = childSpeed * 2.5
                end
            end
            
            for i = 1, numClones do
                local spawnConfig = {
                    game = self.game,
                    x = self.x + math.random(-5, 5),
                    y = self.y + math.random(-20, 20),
                    generation = childGeneration,
                    maxHp = childMaxHp,
                    hp = childMaxHp,
                    damage = childDamage,
                    speed = childSpeed,
                    size = childSize,
                    radius = self.radius,
                    -- Carry over the mutation flags so children can continue applying them
                    healWaveOnSplit = self.healWaveOnSplit,
                    acceleratedMitosis = self.acceleratedMitosis,
                    extraFinalClone = self.extraFinalClone
                }
                
                -- Instantiate child
                local childInstance = Duplicator:new(spawnConfig)
                
                -- Interface with existing logic: Apply current active mutations from EnemyRegistry
                local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
                EnemyRegistry:applyActiveMutations(childInstance)
                
                -- Finally add child to the game
                self.game:addObject(childInstance)
            end
        end
    end
    
    self.game:EnemyDied(self) -- tell game manager I dead
    self:destroy() -- Call the destroy method from the base living_object
end

function Duplicator:getTargetPos()
    -- Duplicator visual diamond reaches size/2 from center, perfectly matching default collision
    self.target = self.game.base.x + self.game.base.w / 2 + self.w / 2
end

-- Custom visual representation for the Duplicator
function Duplicator:drawCustomShape(mode, cx, cy)
    local size = self.w / 2
    local pts = {
        cx, cy - size,           -- Top
        cx + size, cy,           -- Right
        cx, cy + size,           -- Bottom
        cx - size, cy            -- Left
    }
    
    if mode == "line" then
        love.graphics.polygon("line", pts)
        
        -- Draw cell nucleus for "bio" feel
        local r, g, b, a = love.graphics.getColor()
        love.graphics.setColor(r, g, b, a * 0.5)
        love.graphics.circle("fill", cx, cy, size * 0.4)
        love.graphics.setColor(r, g, b, a)
    else
        love.graphics.polygon(mode, pts)
    end
end

return Duplicator
