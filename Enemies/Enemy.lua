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
    if obj.effectManager then
        obj.effectManager:recalculateStats()
    end
    setmetatable(obj, { __index = self })
    obj.target = obj.game.base.x + obj.game.base.w / 2 + (obj.size or obj.w / 2)
    
    local navType = config.navigator or "GridNavigator"
    obj.navigator = Navigators[navType]:new(obj, obj.game)
    
    
    return obj
end

function Enemy:_createGlowCanvas()
    local padding = 12
    local cw = self.w + padding * 2
    local ch = self.h + padding * 2
    
    -- Create canvas and render the glowing outline
    self.canvas = love.graphics.newCanvas(cw, ch)
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear(0, 0, 0, 0)
    
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
        
    end
    
    if self.x < self.target then
        self.game.base:takeDamage(self:getStat("damage"), "normal", self.x, self.y) -- Damage the base if the enemy reaches it
        self:died() -- Destroy the enemy if it reaches the base
    end
    self.effectManager:update(dt) -- Update status effects
end

function Enemy:getFuturePosition(time)
    local speed = self:getStat("speed")
    local distToTravel = speed * time
    if distToTravel <= 0 then return self.x, self.y end

    local nav = self.navigator
    -- If it's a DirectNavigator or no path
    if not nav or not nav.path or #nav.path == 0 then
        -- Direct horizontal movement towards target
        local dx = self.target - self.x
        local d = math.abs(dx)
        if d > 0 then
            local dir = dx / d
            if distToTravel >= d then
                return self.target, self.y
            else
                return self.x + dir * distToTravel, self.y
            end
        else
            return self.x, self.y
        end
    end

    local currentX, currentY = self.x, self.y
    local remainingDist = distToTravel

    -- Current target (already has offset applied in Navigator:calculateNodeTarget)
    local tx, ty = nav.tx, nav.ty
    if tx and ty then
        local dx = tx - currentX
        local dy = ty - currentY
        local d = math.sqrt(dx*dx + dy*dy)
        if d > 0 then
            if remainingDist <= d then
                return currentX + (dx/d) * remainingDist, currentY + (dy/d) * remainingDist
            end
            remainingDist = remainingDist - d
            currentX, currentY = tx, ty
        end
    end

    -- Future nodes
    for i = (nav.currentNodeIndex or 1) + 1, #nav.path do
        local prevNode = nav.path[i-1]
        local currNode = nav.path[i]
        
        -- World position of node center
        local bx = self.game.battlefieldGrid.x + (currNode.x - 1) * self.game.battlefieldGrid.cellSize + self.game.battlefieldGrid.cellSize / 2
        local by = self.game.battlefieldGrid.y + (currNode.y - 1) * self.game.battlefieldGrid.cellSize + self.game.battlefieldGrid.cellSize / 2
        
        -- Apply perpendicular offset (replicates GridNavigator:calculateNodeTarget logic)
        if nav.perpendicularOffset then
             local pdx = currNode.x - prevNode.x
             local pdy = currNode.y - prevNode.y
             local mag = math.sqrt(pdx*pdx + pdy*pdy)
             if mag > 0 then
                 local px = -pdy / mag
                 local py = pdx / mag
                 bx = bx + px * nav.perpendicularOffset
                 by = by + py * nav.perpendicularOffset
             end
        end
        
        local dx = bx - currentX
        local dy = by - currentY
        local d = math.sqrt(dx*dx + dy*dy)
        
        if d > 0 then
            if remainingDist <= d then
                return currentX + (dx/d) * remainingDist, currentY + (dy/d) * remainingDist
            end
            remainingDist = remainingDist - d
            currentX, currentY = bx, by
        end
    end

    -- Return the final path node position (reaches the base)
    return currentX, currentY
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

function Enemy:drawHealthBar()
    -- Health is now drawn as a fill effect inside the enemy sprite
end

function Enemy:draw()
    local r, g, b, a = unpack(self.color or {1, 0, 0, 1})
    local drawX = self.x - self.w/2
    local drawY = self.y - self.h/2
    
    -- 1. Draw "Empty" Base State (Dim fill)
    love.graphics.setColor(r, g, b, 0.15)
    love.graphics.rectangle("fill", drawX, drawY, self.w, self.h)
    
    -- 2. Calculate Scissor Box for Health Fill (Draining effect)
    local fillRatio = self.hp / self:getStat("maxHp")
    -- Fill drops from top to bottom. The filled portion starts at the bottom.
    local scissorY = drawY + self.h * (1 - fillRatio)
    local scissorH = self.h * fillRatio
    
    -- 3. Draw "Health" Fill (Bright fill restricted by scissor)
    -- We use math.floor to prevent sub-pixel jittering with setScissor
    love.graphics.setScissor(math.floor(drawX), math.floor(scissorY), math.floor(self.w), math.ceil(scissorH))
    love.graphics.setColor(r, g, b, 0.7) -- Bright inner color
    love.graphics.rectangle("fill", drawX, drawY, self.w, self.h)
    love.graphics.setScissor() -- Reset scissor immediately
    
    -- 4. Draw Glow Layers (Outside scissor)
    for i = 6, 1, -1 do
        local alpha = 0.05 * (1 - i/7)
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.setLineWidth(i * 3)
        love.graphics.rectangle("line", drawX, drawY, self.w, self.h)
    end
    
    -- 5. Draw Main Neon Border (Last to ensure crisp edges)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", drawX, drawY, self.w, self.h)
    
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
                
                love.graphics.line(prevX, prevY, wx, wy)
                prevX, prevY = wx, wy
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(1)
    end
end

return Enemy