local Pathfinder = {
    safetyMargin = 0.5 -- Safety margin as a percentage of cellSize (0.0 to 0.5)
}

-- Min-Heap for A* Open Set
local Heap = {}
Heap.__index = Heap

function Heap.new(compare)
    return setmetatable({ data = {}, compare = compare or function(a, b) return a < b end }, Heap)
end

function Heap:push(val)
    table.insert(self.data, val)
    local i = #self.data
    while i > 1 do
        local parent = math.floor(i / 2)
        if self.compare(self.data[i], self.data[parent]) then
            self.data[i], self.data[parent] = self.data[parent], self.data[i]
            i = parent
        else
            break
        end
    end
end

function Heap:pop()
    local top = self.data[1]
    self.data[1] = self.data[#self.data]
    table.remove(self.data)
    local i = 1
    while true do
        local left = i * 2
        local right = i * 2 + 1
        local smallest = i
        if left <= #self.data and self.compare(self.data[left], self.data[smallest]) then
            smallest = left
        end
        if right <= #self.data and self.compare(self.data[right], self.data[smallest]) then
            smallest = right
        end
        if smallest == i then break end
        self.data[i], self.data[smallest] = self.data[smallest], self.data[i]
        i = smallest
    end
    return top
end

function Heap:empty()
    return #self.data == 0
end

-- UTILS --

function Pathfinder.isBlocked(nx, ny, game, entity)
    local bfGrid = game.battlefieldGrid
    local baseGrid = game.base.buildGrid
    local bfSlot = (ny - 1) * bfGrid.width + nx
    
    local building = bfGrid.buildings[bfSlot]
    if building then
        -- Flying units ignore blockers
        if entity and entity.isFlying and building:isType("blocker") then
            -- Walkable for flyers
        else
            return true
        end
    end
    
    local px = bfGrid.x + (nx - 1) * bfGrid.cellSize
    local py = bfGrid.y + (ny - 1) * bfGrid.cellSize
    if px >= baseGrid.x and px < baseGrid.x + baseGrid.width * baseGrid.cellSize and
       py >= baseGrid.y and py < baseGrid.y + baseGrid.height * baseGrid.cellSize then
        local baseGridX = math.floor((px - baseGrid.x + 0.5) / baseGrid.cellSize) + 1
        local baseGridY = math.floor((py - baseGrid.y + 0.5) / baseGrid.cellSize) + 1
        local baseSlot = (baseGridY - 1) * baseGrid.width + baseGridX
        if baseGrid.buildings[baseSlot] then return true end
    end
    return false
end


local function hasLineOfSight(x1, y1, x2, y2, game)
    local bfGrid = game.battlefieldGrid
    local cellSize = bfGrid.cellSize
    
    local wx1, wy1 = bfGrid.x + (x1-1)*cellSize + cellSize/2, bfGrid.y + (y1-1)*cellSize + cellSize/2
    local wx2, wy2 = bfGrid.x + (x2-1)*cellSize + cellSize/2, bfGrid.y + (y2-1)*cellSize + cellSize/2
    
    local dx, dy = wx2 - wx1, wy2 - wy1
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist == 0 then return true end
    
    local steps = math.ceil(dist / (cellSize / 2))
    local ux, uy = dx/dist, dy/dist
    local margin = cellSize * (Pathfinder.safetyMargin or 0.2)
    local px, py = -uy * margin, ux * margin
    
    for i = 0, steps do
        local t = i / steps
        local cx, cy = wx1 + dx*t, wy1 + dy*t
        
        -- Sample center and buffered sides
        local checkPoints = {{cx,cy}, {cx+px, cy+py}, {cx-px, cy-py}}
        for _, cp in ipairs(checkPoints) do
            local gx = math.floor((cp[1] - bfGrid.x + 0.5) / cellSize) + 1
            local gy = math.floor((cp[2] - bfGrid.y + 0.5) / cellSize) + 1
            
            -- BOUNDARY FIX: If a point is outside the screen, it's NOT blocked.
            -- Only return false if it's INSIDE the grid AND isBlocked.
            if gx >= 1 and gx <= bfGrid.width and gy >= 1 and gy <= bfGrid.height then
                if Pathfinder.isBlocked(gx, gy, game) then
                    return false
                end
            end
        end
    end
    return true
end

function Pathfinder.simplifyPath(path, game)
    if not path or #path <= 2 then return path end
    local initialCount = #path
    
    local simple = {path[1]}
    local curr = 1
    
    while curr < #path do
        -- Greedily look as far forward as possible to skip intermediate "stepping stone" nodes
        local bestNext = curr + 1
        for next = #path, curr + 2, -1 do
            if hasLineOfSight(path[curr].x, path[curr].y, path[next].x, path[next].y, game) then
                bestNext = next
                break
            end
        end
        table.insert(simple, path[bestNext])
        curr = bestNext
    end
    
    print(string.format("[Pathfinder] Optimized: %d -> %d", initialCount, #simple))
    return simple
end

-- CORE PATHING --

function Pathfinder.findGroundPath(startX, startY, goalX, game, entity)
    local openSet = Heap.new(function(a, b) return a.f < b.f end)
    local startNode = {x = startX, y = startY, g = 0, f = math.abs(startX - goalX)}
    openSet:push(startNode)
    
    local cameFrom = {}
    local gScore = {[startX .. "," .. startY] = 0}
    
    while not openSet:empty() do
        local current = openSet:pop()
        
        if current.x == goalX then
            local path = {}
            local temp = current
            while temp do
                local node = {x = temp.x, y = temp.y}
                
                -- Analyze spatial context (Open Zone vs Corridor)
                local walkableCount = 0
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        if not (dx == 0 and dy == 0) then
                            local nx, ny = node.x + dx, node.y + dy
                            if nx >= 1 and nx <= game.battlefieldGrid.width and 
                               ny >= 1 and ny <= game.battlefieldGrid.height and 
                               not Pathfinder.isBlocked(nx, ny, game, entity) then
                                walkableCount = walkableCount + 1
                            end
                        end
                    end
                end
                
                if walkableCount > 7 then
                    node.isOpenZone = true
                elseif walkableCount <= 4 then
                    node.isCorridor = true
                end

                table.insert(path, 1, node)
                temp = cameFrom[temp.x .. "," .. temp.y]
            end
            return Pathfinder.simplifyPath(path, game)
        end
        
        local dirs = {{0,-1},{0,1},{-1,0},{1,0}}
        for _, d in ipairs(dirs) do
            local nx, ny = current.x + d[1], current.y + d[2]
            if nx >= 1 and nx <= game.battlefieldGrid.width and ny >= 1 and ny <= game.battlefieldGrid.height and not Pathfinder.isBlocked(nx, ny, game, entity) then
                local tentative_g = gScore[current.x .. "," .. current.y] + 1
                local key = nx .. "," .. ny
                if not gScore[key] or tentative_g < gScore[key] then
                    cameFrom[key] = current
                    gScore[key] = tentative_g
                    local f = tentative_g + math.abs(nx - goalX)
                    openSet:push({x = nx, y = ny, g = tentative_g, f = f})
                end
            end
        end
    end
    return nil
end

function Pathfinder.getDirectPath(startX, startY, goalX, goalY)
    return {{x = startX, y = startY}, {x = goalX, y = goalY}}
end

return Pathfinder
