local living_object = require("Classes.living_object")
local Navigators = require("Physics.Navigators")
local Enemy = setmetatable({}, {__index = living_object})
Enemy.__index = Enemy

local Stats = {
    speed = 25,
    damage = 10,
    reward = 25,
    armour = 0,
    size = 20, -- Default size for basic enemies
    shape = "rectangle", -- Default shape for basic enemies
    color = {1, 0, 0, 1}, -- Default color for basic enemies
    hp = 100, -- Default health for basic enemies
    maxHp = 100, -- Maximum health for basic enemies
    hitbox = true, -- Enemies have hitboxes by default
    types = { enemy = true }, -- Using Multi-Type system
    effectManager = true, -- Enemies have a effectManager by default
}   

function Enemy:new(config)
    config = config or {}
    for key, value in pairs(Stats) do
        config[key] = config[key] or value -- Use default values if not provided
    end
    
    if not config.types then config.types = {} end
    for key in pairs(Stats.types) do
        config.types[key] = true
    end
    
    config.w = config.w or config.size
    config.h = config.h or config.size
    local obj = living_object:new(config)
    -- Override default parent to point to enemy manager
    if obj.effectManager and obj.game.enemyEffectManager then
        obj.effectManager.parent = obj.game.enemyEffectManager
    end
    setmetatable(obj, { __index = self })
    obj.target = obj.game.base.x + obj.game.base.w / 2 + (obj.size or obj.w / 2)
    
    local navType = config.navigator or "GridNavigator"
    obj.navigator = Navigators[navType]:new(obj, obj.game)
    
    -- Hybrid Separation Initial State
    obj.currentSeparationStrength = 0 -- 0=Line, 1=Spread
    
    obj:_createGlowCanvas()
    
    return obj
end

function Enemy:_createGlowCanvas()
    local padding = 12
    local cw = self.w + padding * 2
    local ch = self.h + padding * 2
    
    -- Create canvas and render the glowing outline
    self.canvas = love.graphics.newCanvas(cw, ch)
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear()
    
    local r, g, b, a = unpack(self.color or {1, 0, 0, 1})
    
    -- Draw glow layers (static)
    for i = 6, 1, -1 do
        local alpha = 0.05 * (1 - i/7)
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.setLineWidth(i * 3)
        love.graphics.rectangle("line", padding, padding, self.w, self.h)
    end
    
    -- Main crisp outline
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", padding, padding, self.w, self.h)
    
    love.graphics.setCanvas()
    self.canvasPadding = padding
end

function Enemy:update(dt)
    if self.destroyed then return end
    
    if self.navigator then
        self.navigator:update(dt)
        
        -- Adaptive Separation Engine (Lerp currentSeparationStrength)
        if self.game.useHybridSeparation and self.navigator.path then
            local targetNode = self.navigator.path[self.navigator.currentNodeIndex]
            local targetStrength = 0
            
            if targetNode and targetNode.isOpenZone then
                targetStrength = 1
            elseif targetNode and targetNode.isCorridor then
                targetStrength = 0
            end
            
            -- Smooth transition over 0.5s (lerp)
            local lerpSpeed = 2 -- Matches 0.5s transition (1 / 0.5)
            if self.currentSeparationStrength < targetStrength then
                self.currentSeparationStrength = math.min(targetStrength, self.currentSeparationStrength + lerpSpeed * dt)
            elseif self.currentSeparationStrength > targetStrength then
                self.currentSeparationStrength = math.max(targetStrength, self.currentSeparationStrength - lerpSpeed * dt)
            end
        end
    end
    
    if self.x < self.target then
        self.game.base:takeDamage(self:getStat("damage")) -- Damage the base if the enemy reaches it
        self:died() -- Destroy the enemy if it reaches the base
    end
    self.effectManager:update(dt) -- Update status effects
end

function Enemy:recalculatePath()
    if self.navigator and self.navigator.recalculate then
        self.navigator:recalculate()
    end
end

function Enemy:getVelocity()
    local currentSpeed = self:getStat("speed")
    return -currentSpeed, 0 -- Enemies move left by default
end

function Enemy:onCollision(obj)
    if obj:isType('base') then
        obj:takeDamage(self:getStat("damage"))
        self:died() -- Destroy enemy on collision with base
    end
end

function Enemy:died()
    self.game:EnemyDied(self) -- tell game manager I dead
    self:destroy() -- Call the destroy method from the base living_object
end

function Enemy:getTargetPos()
    self.target = self.game.base.x + self.game.base.w / 2 + (self.size or self.w / 2)
end

function Enemy:checkBaseCollision()
    if self.x <= self.target then
        return true
    end
    return false
end

function Enemy:draw()
    -- Draw the pre-rendered glowing canvas
    if self.canvas then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.canvas, self.x - self.w/2 - self.canvasPadding, self.y - self.h/2 - self.canvasPadding)
    end
    
    if self.game.debugMode and self.navigator and self.navigator.path then
        love.graphics.setColor(0, 1, 0, 0.5) -- Green transparent line for path
        love.graphics.setLineWidth(2)
        local path = self.navigator.path
        local startIdx = math.max(1, self.navigator.currentNodeIndex - 1)
        
        if startIdx <= #path then
            local prevX, prevY = self.x, self.y
            for i = self.navigator.currentNodeIndex, #path do
                local node = path[i]
                -- World position of node center
                local wx = self.game.battlefieldGrid.x + (node.x - 1) * self.game.battlefieldGrid.cellSize + self.game.battlefieldGrid.cellSize / 2
                local wy = self.game.battlefieldGrid.y + (node.y - 1) * self.game.battlefieldGrid.cellSize + self.game.battlefieldGrid.cellSize / 2
                
                -- Offset perpendicular to segment is NOT drawn in the path line (the line is the raw path)
                -- but the FIRST point should start from the enemy's world position
                love.graphics.line(prevX, prevY, wx, wy)
                prevX, prevY = wx, wy
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(1)
    end
end

return Enemy