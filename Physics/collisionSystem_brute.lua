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

function collision:checkCollisionsTagged(tag1, tag2)
    for x = 1, #self.grid do
        for y = 1, #self.grid[x] do
            local cell = self.grid[x][y]
            if #cell > 1 then
                for i = 1, #cell do
                    local obj1 = cell[i]
                    for j = i + 1, #cell do
                        local obj2 = cell[j]
                        if obj1.tag == tag1 and obj2.tag == tag2 or obj1.tag == tag2 and obj2.tag == tag1 then
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
                        if obj.tag == tag1 and other.tag == tag2 or obj.tag == tag2 and other.tag == tag1 then
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

function collision:bruteforceTagged(objects, tag1, tag2)
    objtag1 = {}
    objtag2 = {}
    for i = 1, #objects do
        if objects[i].tag == tag1 and not objects[i].destroyed then
            table.insert(objtag1, objects[i])
        elseif objects[i].tag == tag2 and not objects[i].destroyed then
            table.insert(objtag2, objects[i])
        end
    end
    for _, obj1 in ipairs(objtag1) do
        for _, obj2 in ipairs(objtag2) do
            if obj2.tag == tag2 and not obj2.destroyed then -- only finds collisions if tag2 created after tag1
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
     

-- Handles checkings collisions between two objects
-- Based on shapes of objects, it will call the appropriate collision function
function collision:checkCollision(obj1, obj2)
    local a = obj1:getHitbox()
    local b = obj2:getHitbox()
    if not a or not b then
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
    local rx, ry, rw, rh = b:getX(), b:getY(), b:getWidth(), b:getHeight()

    local dx = x2 - x1
    local dy = y2 - y1

    local tmin = -math.huge
    local tmax = math.huge

    local function test(p, d, min, max)
    if math.abs(d) < 0.0001 then
        if p < min or p > max then return false, nil, nil end
        return true, -math.huge, math.huge
    else
        local t1 = (min - p) / d
        local t2 = (max - p) / d
        if t1 > t2 then t1, t2 = t2, t1 end
        return true, t1, t2
    end
    end

    local hitX, t1x, t2x = test(x1, dx, rx - w/2, rx + w/2)
    if not hitX then return false end

    local hitY, t1y, t2y = test(y1, dy, ry - h/2, ry + h/2)
    if not hitY then return false end

    tmin = math.max(t1x, t1y)
    tmax = math.min(t2x, t2y)

    if tmax < 0 or tmin > tmax or tmin > 1 then return false end

    return true
end

function collision:checkCollisionsRay(obj, ray, tag)
    local collisions = {}
    for _, other in ipairs(self.allObjects) do
        if other.tag == tag and not other.destroyed and collision:checkCollision(ray, other) then
            obj:onCollision(other) -- Call onCollision method if it exists
        end
    end
end

return collision