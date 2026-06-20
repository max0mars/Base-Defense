local living_object = require("Classes.living_object")
local Navigators = require("Physics.Navigators")
local Enemy = setmetatable({}, {__index = living_object})
Enemy.__index = Enemy

local Stats = {
    name = "Basic",
    reward = 25,
    size = 20, -- Default size for basic enemies
    shape = "rectangle", -- Default shape for basic enemies
    color = {1, 0, 0, 1}, -- Default color for basic enemies
    hitbox = true, -- Enemies have hitboxes by default
    types = { enemy = true }, -- Using Multi-Type system
    effectManager = true, -- Enemies have a effectManager by default
    splitOnDeathChance = 0,
}   

local function getBaseStats(config)
    local isTesting = config.game and config.game.testingMode
    local index = isTesting and require("Game.Spawning.TestingEnemyIndex") or require("Game.Spawning.EnemyIndex")
    local name = config.name or Stats.name or "Basic"
    local normalizedName = name:lower():gsub("%s+", "")
    for _, entry in ipairs(index) do
        local entryId = entry.id:lower():gsub("%s+", "")
        local entryType = entry.type:lower():gsub("%s+", "")
        if entryId == normalizedName or entryType == normalizedName then
            return entry
        end
    end
    -- Fallback to Basic
    for _, entry in ipairs(index) do
        if entry.id == "Basic" then
            return entry
        end
    end
    return nil
end

function Enemy:new(config)
    config = config or {}
    local customTypes = config.types
    config.types = {}
    if customTypes then
        for k, v in pairs(customTypes) do
            config.types[k] = v
        end
    end
    
    local base = getBaseStats(config)
    if base then
        config.maxHp = config.maxHp or base.maxHp
        config.damage = config.damage or base.damage
        config.speed = config.speed or base.speed
        config.color = config.color or base.color
        config.shape = config.shape or base.shape
        config.size = config.size or base.size
        config.isFlying = (config.isFlying == nil and base.isFlying) or config.isFlying
        if base.affinities and not config.affinities then
            config.affinities = {}
            for k, v in pairs(base.affinities) do
                config.affinities[k] = v
            end
        end
        if base.types then
            for k, v in pairs(base.types) do
                config.types[k] = config.types[k] or v
            end
        end
    end

    for key, value in pairs(Stats) do
        if key ~= "types" then
            config[key] = config[key] or value -- Use default values if not provided
        end
    end
    
    for key in pairs(Stats.types) do
        config.types[key] = true
    end
    
    local isSpecialized = false
    for k in pairs(config.types) do
        if k ~= "enemy" then
            isSpecialized = true
            break
        end
    end
    if not isSpecialized then
        config.types.basic = true
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
    obj:getTargetPos()
    
    local navType = config.navigator or "GridNavigator"
    obj.navigator = Navigators[navType]:new(obj, obj.game)
    
    
    obj.shield = 0
    obj.maxShield = 50 -- Default reference for shield visuals
    
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
    
    self.effectManager:update(dt) -- Update status effects
    
    if self:getStat("stunned", 0) > 0 then
        return
    end
    
    self.w = self:getStat("size")
    self.h = self:getStat("size")
    self:getTargetPos()
    
    if self.navigator then
        self.navigator:update(dt)
    end
    
    if self.x < self.target then
        self.game.base:takeDamage(self:getStat("damage"), "normal", self.x, self.y, self) -- Damage the base if the enemy reaches it
        self:died() -- Destroy the enemy if it reaches the base
    end
end

function Enemy:takeDamage(amount, damageType, hitX, hitY, damageTags)
    if not amount or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
        return 0
    end
    
    local combinedTags = {}
    if damageTags then
        for _, tag in ipairs(damageTags) do
            table.insert(combinedTags, tag)
        end
    end
    table.insert(combinedTags, damageType)

    local damageMult = 1
    if self.affinities then
        for _, tag in ipairs(combinedTags) do
            if self.affinities[tag] then
                damageMult = damageMult * self.affinities[tag]
            end
        end
    end

    amount = amount * damageMult

    -- Effectiveness vs this enemy's affinities (damage-type matchup), for feedback.
    local effectiveness = nil
    if damageMult < 1 then
        effectiveness = "resist"
    elseif damageMult > 1 then
        effectiveness = "weak"
    end

    -- Apply Damage Reduction (from Guardian Aura or other effects)
    local reduction = self:getStat("damageReductionMultiplier", 1)
    amount = amount * reduction

    if amount > 1 then
        self.game:spawnDamageNumber(amount, hitX or self.x, hitY or self.y, damageType, effectiveness)
    end

    -- 1. Check if shield exists
    if self.shield > 0 then
        local oldShield = self.shield
        self.shield = self.shield - amount
        if self.shield <= 0 then
            self.shield = 0
            if oldShield > 0 then
                self.game:spawnArmorBreak(self.x, self.y)
            end
        end
        -- Explicitly return to nullify remaining damage from this attack
        return amount
    end

    -- 2. Apply damage to HP if no shield
    if amount >= self.hp then
        self.hp = 0
    else
        self.hp = self.hp - amount
    end

    if self.hp <= 0 then
        self:died()
    end

    return amount
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
    if self.isDead then return end
    self.isDead = true
    
    if self.effectManager then
        self.effectManager:triggerEvent("onDeath", self)
    end
    
    if AUDIO then AUDIO:playSFX("explosion_01") end
    
    if self.splitOnDeathChance and self.splitOnDeathChance > 0 and math.random() <= self.splitOnDeathChance then
        local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
        local offsets = {
            {x = -12, y = -12},
            {x = 12, y = 12}
        }
        for i = 1, 2 do
            local spawnConfig = {
                game = self.game,
                x = self.x + offsets[i].x,
                y = self.y + offsets[i].y,
                name = self.name
            }
            local basicClass = require("Enemies.Enemy")
            local childInstance = basicClass:new(spawnConfig)
            EnemyRegistry:applyActiveMutations(childInstance)
            self.game:addObject(childInstance)
        end
    end
    
    self.game:EnemyDied(self) -- tell game manager I dead
    self:destroy() -- Call the destroy method from the base living_object
end

function Enemy:getTargetPos()
    local factor = 0.5
    if self.shape == "dart" then
        factor = 7 / 15
    elseif self.shape == "octagon" then
        factor = 0.6
    elseif self.shape == "arrow" then
        factor = 0.8
    end
    self.target = self.game.base.x + self.game.base.w / 2 + (self.w * factor)
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

function Enemy:drawCustomShape(mode, cx, cy)
    if self.shape == "dart" then
        local scale = self:getStat("size", 15) / 15
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.scale(scale, scale)
        love.graphics.polygon(mode, -7, 0, 7, -4, 4, 0, 7, 4)
        love.graphics.pop()
    elseif self.shape == "tank" then
        local scale = self:getStat("size", 22) / 22
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.scale(scale, scale)
        local pts = {
            -11, -10, 11, -10, 11, -7, 9, -7, 9, 7, 11, 7,
            11, 10, -11, 10, -11, 7, -9, 7, -9, -7, -11, -7
        }
        love.graphics.polygon(mode, pts)
        love.graphics.pop()
    elseif self.shape == "octagon" then
        local size = self:getStat("size", 20)
        local function getOctagonPoints(x, y, s)
            local pts = {}
            for i = 0, 7 do
                local angle = i * (math.pi / 4) + (math.pi / 8)
                table.insert(pts, x + math.cos(angle) * s)
                table.insert(pts, y + math.sin(angle) * s)
            end
            return pts
        end
        local points = getOctagonPoints(cx, cy, size * 0.6)
        love.graphics.polygon(mode, points)
    elseif self.shape == "cross" then
        local thickness = self.w * 0.35
        -- Vertical Bar
        love.graphics.rectangle(mode, cx - thickness/2, cy - self.h/2, thickness, self.h)
        -- Horizontal Bar
        love.graphics.rectangle(mode, cx - self.w/2, cy - thickness/2, self.w, thickness)
    elseif self.shape == "diamond" then
        local size = self.w / 2
        local pts = {
            cx, cy - size,           -- Top
            cx + size, cy,           -- Right
            cx, cy + size,           -- Bottom
            cx - size, cy            -- Left
        }
        love.graphics.polygon(mode, pts)
    else
        love.graphics.rectangle(mode, cx - self.w/2, cy - self.h/2, self.w, self.h)
    end
end

function Enemy:draw()
    if self.shape == "arrow" then
        local r, g, b, a = unpack(self.color or {1, 0.5, 0, 1})
        local drawX = self.x
        local drawY = self.y
        local size = self:getStat("size")
        
        -- Calculate rotation (pointing towards target)
        local angle = 0
        if self.navigator and (self.navigator.tx or self.tx) then
            local targetX = self.navigator.tx or self.tx
            local targetY = self.navigator.ty or self.ty
            angle = math.atan2(targetY - self.y, targetX - self.x)
        else
            angle = math.pi -- Default facing left
        end

        local function getArrowPoints(cx, cy, s, ang)
            local points = {
                {cx + math.cos(ang) * s, cy + math.sin(ang) * s}, -- Tip
                {cx + math.cos(ang + 2.5) * s, cy + math.sin(ang + 2.5) * s}, -- Back-right
                {cx + math.cos(ang + math.pi) * (s * 0.4), cy + math.sin(ang + math.pi) * (s * 0.4)}, -- Indented back
                {cx + math.cos(ang - 2.5) * s, cy + math.sin(ang - 2.5) * s} -- Back-left
            }
            local flat = {}
            for _, p in ipairs(points) do
                table.insert(flat, p[1])
                table.insert(flat, p[2])
            end
            return flat
        end

        local arrowPoints = getArrowPoints(drawX, drawY, size * 0.8, angle)

        -- 1. Draw "Empty" Base State (Dim fill)
        love.graphics.setColor(r, g, b, 0.15)
        love.graphics.polygon("fill", arrowPoints)
        
        -- 2. Calculate Scissor Box for Health Fill (Draining effect)
        local maxHp = self:getStat("maxHp")
        local fillRatio = self.hp / maxHp
        
        local minY, maxY = arrowPoints[2], arrowPoints[2]
        for i = 4, #arrowPoints, 2 do
            local y = arrowPoints[i]
            if y < minY then minY = y end
            if y > maxY then maxY = y end
        end
        local actualH = maxY - minY
        
        local scissorY = minY + actualH * (1 - fillRatio)
        local scissorH = actualH * fillRatio
        
        -- 3. Draw "Health" Fill (Bright fill restricted by scissor)
        SetGameScissor(math.floor(self.x - size), math.floor(scissorY), math.ceil(size * 2), math.ceil(scissorH))
        love.graphics.setColor(r, g, b, 0.7)
        love.graphics.polygon("fill", arrowPoints)
        
        if fillRatio > 0 and fillRatio < 1 then
            SetGameScissor(math.floor(self.x - size), math.floor(scissorY), math.ceil(size * 2), 2)
            love.graphics.setColor(r, g, b, 1)
            love.graphics.polygon("fill", arrowPoints)
            SetGameScissor()
        end
        
        SetGameScissor()
        
        -- Layer 3: Shield Fill
        if self.maxShield > 0 and self.shield > 0 then
            local shieldRatio = self.shield / self.maxShield
            local sScissorY = minY + actualH * (1 - shieldRatio)
            local sScissorH = actualH * shieldRatio
            
            SetGameScissor(math.floor(self.x - size), math.floor(sScissorY), math.ceil(size * 2), math.ceil(sScissorH))
            love.graphics.setColor(0.6, 0.6, 0.6, 1) -- Flat Grey
            love.graphics.polygon("fill", arrowPoints)
            SetGameScissor()
        end
        
        -- 4. Glow Layers
        for i = 4, 1, -1 do
            local alpha = 0.05 * (1 - i/5)
            love.graphics.setColor(r, g, b, alpha)
            love.graphics.setLineWidth(i * 3)
            love.graphics.polygon("line", arrowPoints)
        end
        
        -- 5. Main Neon Border
        love.graphics.setColor(r, g, b, 1)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", arrowPoints)
        
        -- Draw debug path if debugMode
        if self.game.debugMode and self.navigator and self.navigator.path then
            love.graphics.setColor(0, 1, 0, 0.5)
            love.graphics.setLineWidth(2)
            local path = self.navigator.path
            local prevX, prevY = self.x, self.y
            for i = self.navigator.currentNodeIndex, #path do
                local node = path[i]
                local wx = self.game.battlefieldGrid.x + (node.x - 1) * self.game.battlefieldGrid.cellSize + self.game.battlefieldGrid.cellSize / 2
                local wy = self.game.battlefieldGrid.y + (node.y - 1) * self.game.battlefieldGrid.cellSize + self.game.battlefieldGrid.cellSize / 2
                love.graphics.line(prevX, prevY, wx, wy)
                prevX, prevY = wx, wy
            end
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setLineWidth(1)
        end
        return
    end

    local r, g, b, a = unpack(self.color or {1, 0, 0, 1})
    local drawX = self.x - self.w/2
    local drawY = self.y - self.h/2
    local cx, cy = self.x, self.y
    
    -- 1. Layer 1 (Empty Base): Dim fill
    love.graphics.setColor(r, g, b, 0.2)
    self:drawCustomShape("fill", cx, cy)
    
    -- 2. Layer 2 (Normal HP Fill): Bright glow fill with bottom-up scissor
    local maxHp = self:getStat("maxHp")
    local fillRatio = self.hp / maxHp
    
    -- Calculate scissor
    local scissorY = drawY + self.h * (1 - fillRatio)
    local scissorH = self.h * fillRatio
    
    SetGameScissor(math.floor(drawX), math.floor(scissorY), math.floor(self.w), math.ceil(scissorH))
    love.graphics.setColor(r, g, b, 0.7)
    self:drawCustomShape("fill", cx, cy)
    
    -- Add a bright horizontal line at the health level "cap"
    if fillRatio > 0 and fillRatio < 1 then
        SetGameScissor(math.floor(drawX), math.floor(scissorY), math.floor(self.w), 2)
        love.graphics.setColor(r, g, b, 1)
        self:drawCustomShape("fill", cx, cy)
        SetGameScissor()
    end
    
    SetGameScissor()
    
    -- 3. Layer 3 (Shield Fill): Flat Grey fill with bottom-up scissor
    if self.maxShield > 0 and self.shield > 0 then
        local shieldRatio = self.shield / self.maxShield
        local sScissorY = drawY + self.h * (1 - shieldRatio)
        local sScissorH = self.h * shieldRatio
        
        SetGameScissor(math.floor(drawX), math.floor(sScissorY), math.floor(self.w), math.ceil(sScissorH))
        love.graphics.setColor(0.6, 0.6, 0.6, 1) -- Flat Grey
        self:drawCustomShape("fill", cx, cy)
        SetGameScissor()
    end
    
    -- 4. Layer 4 (Neon Border): Thick neon outer outline and glow
    -- Glow Layers
    for i = 6, 1, -1 do
        local alpha = 0.05 * (1 - i/7)
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.setLineWidth(i * 3)
        self:drawCustomShape("line", cx, cy)
    end
    
    -- Main crisp outline
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(2)
    self:drawCustomShape("line", cx, cy)
    
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
