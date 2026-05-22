local Enemy = require("Enemies.Enemy")
local Beast = require("Enemies.Beast")
local BeastMaster = setmetatable({}, {__index = Enemy})
BeastMaster.__index = BeastMaster

local default = {
    speed = 20,
    maxHp = 350,
    damage = 25,
    reward = 120,
    size = 26,
    color = {0.5, 0.1, 0.5, 1},
    types = { beastmaster = true },
    -- Summoning defaults
    spawnInterval = 5,
    spawnCount = 3,
    maxBeasts = 6,
    bloodPackHeal = false
}

function BeastMaster:new(config)
    config = config or {}
    if not config.types then config.types = {} end
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    for key in pairs(default.types) do
        config.types[key] = true
    end
    
    local instance = Enemy:new(config)
    setmetatable(instance, BeastMaster)
    
    instance.activeBeasts = {}
    instance.spawnTimer = 3
    --instance.hasInitiallySpawned = false
    
    return instance
end

function BeastMaster:update(dt)
    if self.destroyed then return end
    
    -- Clean up dead beasts from tracking
    for i = #self.activeBeasts, 1, -1 do
        if self.activeBeasts[i].destroyed then
            table.remove(self.activeBeasts, i)
        end
    end
    
    -- if not self.hasInitiallySpawned then
    --     self.hasInitiallySpawned = true
    --     self:summonBeasts(true)
    -- else
        self.spawnTimer = self.spawnTimer + dt
        if self.spawnTimer >= self:getStat("spawnInterval") then
            self.spawnTimer = 0
            self:summonBeasts()
        end
    -- end
    
    Enemy.update(self, dt)
end

function BeastMaster:summonBeasts()
    local maxBeasts = self:getStat("maxBeasts")
    local spawnCount = self:getStat("spawnCount")
    
    
    local currentBeasts = #self.activeBeasts
    local availableSlots = maxBeasts - currentBeasts
    local amountToSpawn = math.min(spawnCount, availableSlots)
    
    -- Blood Pack mutation check
    if self.bloodPackHeal then
        for _, beast in ipairs(self.activeBeasts) do
            if not beast.destroyed then
                local oldHp = beast.hp
                beast.hp = math.min(beast:getStat("maxHp"), beast.hp + 20)
                local amountHealed = beast.hp - oldHp
                if amountHealed > 0 then
                    self.game:spawnDamageNumber(amountHealed, beast.x, beast.y, "heal")
                end
            end
        end
    end
    
    if amountToSpawn > 0 then
        -- Shout visual and audio effect
        if AUDIO then AUDIO:playSFX("whistle_01") end
        if self.game.spawnExpandingCircle then
            self.game:spawnExpandingCircle(self.x, self.y, self:getStat("size")/2, self:getStat("size")*4, self.color, 0.4)
        end
    end
    
    for i = 1, amountToSpawn do
        -- Spawn off-screen to the right (assuming base is roughly center and screen is 800+ wide)
        local screenW = love.graphics.getWidth()
        local rx = screenW + 50 + math.random() * 100
        -- Adjust if game doesn't use standard love.graphics.getWidth
        if self.game.base then
            rx = self.game.base.x + 800 + math.random() * 100
        end
        local ry = self.y + (math.random() - 0.5) * 80
        
        local beastInstance = Beast:new({
            game = self.game,
            x = rx,
            y = ry,
            master = self
        })
        
        table.insert(self.activeBeasts, beastInstance)
        self.game:addObject(beastInstance)
    end
end

function BeastMaster:died()
    -- Trigger enrage on all active beasts
    for _, beast in ipairs(self.activeBeasts) do
        if not beast.destroyed and beast.masterDied then
            beast:masterDied()
        end
    end
    
    -- Call base died
    Enemy.died(self)
end

function BeastMaster:draw()
    local r, g, b, a = unpack(self.color)
    local drawX = self.x
    local drawY = self.y
    local size = self:getStat("size")
    
    -- Empty state (Dim fill)
    love.graphics.setColor(r, g, b, 0.2)
    love.graphics.rectangle("fill", drawX - size/2, drawY - size/2, size, size)
    
    -- Health fill
    local maxHp = self:getStat("maxHp")
    local fillRatio = self.hp / maxHp
    
    local scissorY = (drawY - size/2) + size * (1 - fillRatio)
    local scissorH = size * fillRatio
    
    love.graphics.setScissor(math.floor(drawX - size/2), math.floor(scissorY), math.ceil(size), math.ceil(scissorH))
    love.graphics.setColor(r, g, b, 0.8)
    love.graphics.rectangle("fill", drawX - size/2, drawY - size/2, size, size)
    
    -- Bright horizontal line at health cap
    if fillRatio > 0 and fillRatio < 1 then
        love.graphics.setScissor(math.floor(drawX - size/2), math.floor(scissorY), math.ceil(size), 2)
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", drawX - size/2, drawY - size/2, size, size)
    end
    love.graphics.setScissor()
    
    -- Glowing borders
    for i = 3, 1, -1 do
        love.graphics.setColor(r, g, b, 0.1 * (4-i))
        love.graphics.setLineWidth(i * 3)
        love.graphics.rectangle("line", drawX - size/2, drawY - size/2, size, size)
    end
    
    -- Main border
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", drawX - size/2, drawY - size/2, size, size)
end

return BeastMaster
