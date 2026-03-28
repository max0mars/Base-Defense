collision = {
    num = 0,
    grid = {},
    emptyGrid = {},
    largeObjects = {},
    allObjects = {},
    cellSize = 32,
    width = 0,
    height = 0
}

function collision:setGrid(width, height, cellSize) --sets grid values
    self.width = width or 800
    self.height = height or 600
    self.cellSize = cellSize or 32
    self:resetGrid()
end

function collision:resetGrid() -- resets the grid
    self.grid = {}
    local xCells = math.ceil(self.width / self.cellSize)
    local yCells = math.ceil(self.height / self.cellSize)
    for x = 1, xCells do
        self.grid[x] = {}
        for y = 1, yCells do
            self.grid[x][y] = {}
        end
    end
end

-- adds an object to the grid based on its hitbox location
function collision:addToGrid(obj)
    if obj.destroyed then
        return -- Do not add destroyed objects to the grid
    end
    
    local hitbox = obj:getHitbox()
    if not hitbox then
        return -- No hitbox to check
    end
    table.insert(self.allObjects, obj)
    if obj.big then
        table.insert(self.largeObjects, obj) -- Store large objects separately
        return -- Do not add large objects to the grid
    end
    local x = hitbox:getX()
    local y = hitbox:getY()
    if x < 0 or x > self.width or y < 0 or y > self.height then
        return -- don't check out of bounds collisions
    end
    local xCell = math.floor(x / self.cellSize) + 1
    local yCell = math.floor(y / self.cellSize) + 1
    if xCell >= 1 and xCell <= #self.grid and yCell >= 1 and yCell <= #self.grid[xCell] then
        table.insert(self.grid[xCell][yCell], obj)
    end
end

-- checks all collisions in the grid
-- If an object has an onCollision method, it will be called with the other object as an argument
function collision:checkAllCollisions() 
    for x = 1, #self.grid do
        for y = 1, #self.grid[x] do
            local cell = self.grid[x][y]
            if #cell > 1 then
                for i = 1, #cell do
                    local obj1 = cell[i]
                    for j = i + 1, #cell do
                        local obj2 = cell[j]
                        if not obj1.destroyed and not obj2.destroyed and collision:checkCollision(obj1, obj2) then
                            if obj1.onCollision then
                                obj1:onCollision(obj2)
                            end
                            if obj2.onCollision then
                                obj2:onCollision(obj1)
                            end
                        end
                    end
                end
            end
        end
    end
    for _, obj in ipairs(self.largeObjects) do
        if not obj.destroyed then
            for x = 1, #self.grid do
                for y = 1, #self.grid[x] do
                    local cell = self.grid[x][y]
                    for _, other in ipairs(cell) do
                        if other ~= obj and not other.destroyed and collision:checkCollision(obj, other) then
                            if obj.onCollision then
                                obj:onCollision(other)
                            end
                            if other.onCollision then
                                other:onCollision(obj)
                            end
                        end
                    end
                end
            end
        end
    end
end

function collision:checkCollisionsByType(type1, type2)
    for x = 1, #self.grid do
        for y = 1, #self.grid[x] do
            local cell = self.grid[x][y]
            if #cell > 1 then
                for i = 1, #cell do
                    local obj1 = cell[i]
                    for j = i + 1, #cell do
                        local obj2 = cell[j]
                        if (obj1:isType(type1) and obj2:isType(type2)) or (obj1:isType(type2) and obj2:isType(type1)) then
                            if not obj1.destroyed and not obj2.destroyed and collision:checkCollision(obj1, obj2) then
                                if obj1.onCollision then
                                    obj1:onCollision(obj2)
                                end
                                if obj2.onCollision then
                                    obj2:onCollision(obj1)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    for _, obj in ipairs(self.largeObjects) do
        if not obj.destroyed then
            for x = 1, #self.grid do
                for y = 1, #self.grid[x] do
                    local cell = self.grid[x][y]
                    for _, other in ipairs(cell) do
                        if (obj:isType(type1) and other:isType(type2)) or (obj:isType(type2) and other:isType(type1)) then
                            if other ~= obj and not other.destroyed and collision:checkCollision(obj, other) then
                                if obj.onCollision then
                                    obj:onCollision(other)
                                end
                                if other.onCollision then
                                    other:onCollision(obj)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function collision:bruteforceByType(objects, type1, type2)
    objlist1 = {}
    objlist2 = {}
    for i = 1, #objects do
        if objects[i]:isType(type1) and not objects[i].destroyed then
            table.insert(objlist1, objects[i])
        elseif objects[i]:isType(type2) and not objects[i].destroyed then
            table.insert(objlist2, objects[i])
        end
    end
    for _, obj1 in ipairs(objlist1) do
        if not obj1.destroyed then
            for _, obj2 in ipairs(objlist2) do
                if not obj2.destroyed and not obj1.destroyed then 
                    if collision:checkCollision(obj1, obj2) then
                        collision.num = collision.num + 1
                        if obj1.onCollision then
                            obj1:onCollision(obj2)
                        end
                        if obj2.onCollision then
                            obj2:onCollision(obj1)
                        end
                    end
                end
            end
        end
    end
end
     

-- Handles checkings collisions between two objects
-- Based on shapes of objects, it will call the appropriate collision function
function collision:checkCollision(obj1, obj2)
    local a = obj1:getHitbox()
    local b = obj2:getHitbox()
    if not a or not b then
        return false
    end
    return self:rectRect(a, b) -- only rectangle-rectangle collision implemented
    -- if a.type == "circle" and b.type == "circle" then
    --     return self:circleCircle(a, b)
    -- elseif a.type == "rectangle" and b.type == "rectangle" then
    --     return self:rectRect(a, b)
    -- elseif a.type == "circle" and b.type == "rectangle" then
    --     return self:circleRect(a, b)
    -- elseif a.type == "rectangle" and b.type == "circle" then
    --     return self:circleRect(b, a)
    -- elseif a.type == 'ray' and b.type == 'rectangle' then
    --     return self:rayRect(a, b)
    -- elseif a.type == 'ray' and b.type == 'circle' then
    --     return self:rayCircle(a, b)
    -- else
    --     error("Error with hitbox types: " .. a.type .. " and " .. b.type)
    -- end
end

-- Circle - Circle Collision check
function collision:circleCircle(a, b)
    local dx = a:getX() - b:getX()
    local dy = a:getY() - b:getY()
    local distance = dx * dx + dy * dy
    return distance < (a:getSize() + b:getSize()) * (a:getSize() + b:getSize()) -- Assuming size is radius for circles
end

-- Rectangle - Rectangle Collision check
-- Assumes centered at their x, y
function collision:rectRect(a, b)
    local x1, y1, w1, h1 = a:getX(), a:getY(), a:getWidth(), a:getHeight()
    local x2, y2, w2, h2 = b:getX(), b:getY(), b:getWidth(), b:getHeight()
    if not (x1 and y1 and w1 and h1 and x2 and y2 and w2 and h2) then
        error("One of the objects is missing width or height for rectangle collision")
    end
    return math.abs(x1 - x2) < (w1/2 + w2/2) and math.abs(y1 - y2) < (h1/2 + h2/2)
end

-- Circle - Rectangle Collision check
-- Assumes centered at its x, y
function collision:circleRect(circle, rect)
    local circleX, circleY, circleR = circle:getX(), circle:getY(), circle:getSize()
    local rectX, rectY, rectW, rectH = rect:getX(), rect:getY(), rect:getWidth(), rect:getHeight()
    local halfW = rectW / 2
    local halfH = rectH / 2

    local closestX = math.max(rectX - halfW, math.min(circleX, rectX + halfW))
    local closestY = math.max(rectY - halfH, math.min(circleY, rectY + halfH))

    local dx = closestX - circleX
    local dy = closestY - circleY

    return (dx * dx + dy * dy) < (circleR * circleR)
end

function collision:rayCircle(a, b)
    local x1, y1 = a.x1, a.y1
    local x2, y2 = a.x2, a.y2
    local cx, cy, r = b:getX(), b:getY(), b:getSize()

    local dx = x2 - x1
    local dy = y2 - y1

    local fx = x1 - cx
    local fy = y1 - cy

    local a = dx*dx + dy*dy
    local b = 2 * (fx*dx + fy*dy)
    local c = fx*fx + fy*fy - r*r

    local discriminant = b*b - 4*a*c
    if discriminant < 0 then
    return false
    end

    discriminant = math.sqrt(discriminant)

    local t1 = (-b - discriminant) / (2*a)
    local t2 = (-b + discriminant) / (2*a)

    -- Check if it hits within the segment
    if t1 >= 0 and t1 <= 1 then return true end
    if t2 >= 0 and t2 <= 1 then return true end

    return false
end

function collision:rayRect(a, b)
    local x1, y1 = a.x1, a.y1
    local x2, y2 = a.x2, a.y2
    
    local hitbox = b:getHitbox()
    if not hitbox then return false end
    
    local rx, ry, rw, rh = hitbox:getX(), hitbox:getY(), hitbox:getWidth(), hitbox:getHeight()

    local dx = x2 - x1
    local dy = y2 - y1

    local tmin = 0
    local tmax = 1

    -- X-axis intersection
    if math.abs(dx) < 0.0001 then
        if x1 < rx - rw/2 or x1 > rx + rw/2 then return false end
    else
        local t1 = (rx - rw/2 - x1) / dx
        local t2 = (rx + rw/2 - x1) / dx
        if t1 > t2 then t1, t2 = t2, t1 end
        tmin = math.max(tmin, t1)
        tmax = math.min(tmax, t2)
    end

    -- Y-axis intersection
    if math.abs(dy) < 0.0001 then
        if y1 < ry - rh/2 or y1 > ry + rh/2 then return false end
    else
        local t1 = (ry - rh/2 - y1) / dy
        local t2 = (ry + rh/2 - y1) / dy
        if t1 > t2 then t1, t2 = t2, t1 end
        tmin = math.max(tmin, t1)
        tmax = math.min(tmax, t2)
    end

    if tmin > tmax or tmax < 0 or tmin > 1 then
        return false
    end

    -- Return true and the entry point t
    return true, tmin
end

function collision:checkCollisionsRay(obj, ray, typeName)
    local collisions = {}
    for _, other in ipairs(self.allObjects) do
        if other:isType(typeName) and not other.destroyed and collision:checkCollision(ray, other) then
            obj:onCollision(other) -- Call onCollision method if it exists
        end
    end
end

return collision