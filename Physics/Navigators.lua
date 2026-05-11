local Navigator = {}
Navigator.__index = Navigator

function Navigator:new(enemy, game)
    local obj = setmetatable({}, self)
    obj.enemy = enemy
    obj.game = game
    return obj
end

function Navigator:update(dt)
    -- Abstract method
end

---------------------------
-- DirectNavigator (Flying/Ghost units)
---------------------------
local DirectNavigator = setmetatable({}, Navigator)
DirectNavigator.__index = DirectNavigator

function DirectNavigator:new(enemy, game)
    local obj = Navigator.new(self, enemy, game)
    return obj
end

function DirectNavigator:update(dt)
    local enemy = self.enemy
    -- Simply straight to the target
    local dx = enemy.target - enemy.x
    local dy = 0
    local dist = math.abs(dx)
    
    local currentSpeed = enemy:getStat("speed")
    if dist > 0 then
        enemy.x = enemy.x + (dx / dist) * currentSpeed * dt
    end
end

---------------------------
-- GridNavigator (Ground units)
---------------------------
local GridNavigator = setmetatable({}, Navigator)
GridNavigator.__index = GridNavigator

local Pathfinder = require("Physics.Pathfinder")

function GridNavigator:new(enemy, game)
    local obj = Navigator.new(self, enemy, game)
    obj.path = nil
    obj.currentNodeIndex = 1
    obj.needsRecalculation = true
    
    -- Swarming offset (perpendicular to movement)
    obj.perpendicularOffset = (math.random() - 0.5) * 12
    obj.tx, obj.ty = nil, nil
    return obj
end

function GridNavigator:recalculate()
    self.needsRecalculation = true
    self.tx, self.ty = nil, nil
end

function GridNavigator:calculateNodeTarget()
    local game = self.game
    local enemy = self.enemy
    
    if not self.path or self.currentNodeIndex > #self.path then return end
    
    local prevNode = self.path[self.currentNodeIndex - 1]
    local currNode = self.path[self.currentNodeIndex]
    
    -- Base grid coordinates for the target node
    local bx = game.battlefieldGrid.x + (currNode.x - 1) * game.battlefieldGrid.cellSize + game.battlefieldGrid.cellSize / 2
    local by = game.battlefieldGrid.y + (currNode.y - 1) * game.battlefieldGrid.cellSize + game.battlefieldGrid.cellSize / 2
    
    if prevNode then
        -- Calculate perpendicular offset based on segment direction
        local dx = currNode.x - prevNode.x
        local dy = currNode.y - prevNode.y
        local mag = math.sqrt(dx*dx + dy*dy)
        if mag > 0 then
            -- Perpendicular vector (-dy, dx)
            local px = -dy / mag
            local py = dx / mag
            bx = bx + px * self.perpendicularOffset
            by = by + py * self.perpendicularOffset
        end
    end
    
    self.tx, self.ty = bx, by
end

function GridNavigator:update(dt)
    local enemy = self.enemy
    local game = self.game

    if self.needsRecalculation then
        local startX = math.floor((enemy.x - game.battlefieldGrid.x + 0.5) / game.battlefieldGrid.cellSize) + 1
        local startY = math.floor((enemy.y - game.battlefieldGrid.y + 0.5) / game.battlefieldGrid.cellSize) + 1
        
        local targetX = enemy.target
        local baseCellX = math.floor((targetX - game.battlefieldGrid.x + 0.5) / game.battlefieldGrid.cellSize) + 1
        
        self.path = Pathfinder.findGroundPath(startX, startY, baseCellX, game, enemy)
        self.currentNodeIndex = 2 -- Skip starting node
        self.needsRecalculation = false
        self:calculateNodeTarget()
    end

    local currentSpeed = enemy:getStat("speed")
    
    if self.path and self.currentNodeIndex <= #self.path and self.tx then
        local dx = self.tx - enemy.x
        local dy = self.ty - enemy.y
        local dist = math.sqrt(dx*dx + dy*dy)
        
        if dist < 5 then
            self.currentNodeIndex = self.currentNodeIndex + 1
            if self.currentNodeIndex <= #self.path then
                self:calculateNodeTarget()
            end
        else
            local vx = (dx / dist)
            local vy = (dy / dist)
            
            -- Hybrid Separation Logic
            if game.useHybridSeparation and enemy.currentSeparationStrength and enemy.currentSeparationStrength > 0 then
                local sepX, sepY = 0, 0
                local neighborRadius = 200
                local r2 = neighborRadius * neighborRadius
                
                for _, other in ipairs(game.objects) do
                    if other ~= enemy and other:isType("enemy") and not other.destroyed then
                        local sx = enemy.x - other.x
                        local sy = enemy.y - other.y
                        local d2 = sx*sx + sy*sy
                        
                        if d2 < r2 and d2 > 0 then
                            local d = math.sqrt(d2)
                            -- Inverse square law: push harder when closer
                            local force = 1 / d2 
                            sepX = sepX + (sx / d) * force
                            sepY = sepY + (sy / d) * force
                        end
                    end
                end
                
                -- Scale separation by current strength and combine with movement
                vx = vx + sepX * 100 * enemy.currentSeparationStrength
                vy = vy + sepY * 100 * enemy.currentSeparationStrength
                
                -- Repurifying movement vector
                local newMag = math.sqrt(vx*vx + vy*vy)
                if newMag > 0 then
                    vx, vy = vx/newMag, vy/newMag
                end
            end

            local nextX = enemy.x + vx * currentSpeed * dt
            local nextY = enemy.y + vy * currentSpeed * dt
            
            local function checkCollision(nx, ny)
                local cx = math.floor((nx - game.battlefieldGrid.x + 0.5) / game.battlefieldGrid.cellSize) + 1
                local cy = math.floor((ny - game.battlefieldGrid.y + 0.5) / game.battlefieldGrid.cellSize) + 1
                if cx >= 1 and cx <= game.battlefieldGrid.width and cy >= 1 and cy <= game.battlefieldGrid.height then
                    return Pathfinder.isBlocked(cx, cy, game, enemy)
                end
                return false
            end
            
            if checkCollision(enemy.x, enemy.y) then
                -- If already inside a block, allow movement to escape
                enemy.x = nextX
                enemy.y = nextY
            elseif not checkCollision(nextX, nextY) then
                enemy.x = nextX
                enemy.y = nextY
            else
                -- Try sliding along the wall
                if not checkCollision(nextX, enemy.y) then
                    enemy.x = nextX
                elseif not checkCollision(enemy.x, nextY) then
                    enemy.y = nextY
                end
            end
        end
    else
        -- Fallback to direct navigation or if no path found (blocked)
        local dx = enemy.target - enemy.x
        local dist = math.abs(dx)
        if dist > 0 then
            enemy.x = enemy.x + (dx / dist) * currentSpeed * dt
        end
    end
end

return {
    Navigator = Navigator,
    DirectNavigator = DirectNavigator,
    GridNavigator = GridNavigator
}
