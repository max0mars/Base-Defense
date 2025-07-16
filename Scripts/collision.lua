collision = {
    grid = {},
    emptyGrid = {},
    cellSize = 32,
    width = 0,
    height = 0
}

function collision:setGrid(cellSize, width, height) --sets grid values
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
    if hitbox:getX() < 0 or hitbox:getX() > self.width or hitbox:getY() < 0 or hitbox:getY() > self.height then
        return -- don't check out of bounds collisions
    end
    local xCell = math.floor(hitbox:getX() / self.cellSize) + 1
    local yCell = math.floor(hitbox:getY() / self.cellSize) + 1
    if self.grid[xCell] and self.grid[xCell][yCell] then
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
                    for j = i + 1, #cell do
                        if collision:checkCollision(cell[i], cell[j]) then
                            if cell[i].onCollision then
                                cell[i]:onCollision(cell[j])
                            end
                            if cell[j].onCollision then
                                cell[j]:onCollision(cell[i])
                            end
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
    if not a or not b then return false end
    if a.type == "circle" and b.type == "circle" then
        return self:circleCircle(a, b)
    elseif a.type == "rectangle" and b.type == "rectangle" then
        return self:rectRect(a, b)
    elseif a.type == "circle" and b.type == "rectangle" then
        return self:circleRect(a, b)
    elseif a.type == "rectangle" and b.type == "circle" then
        return self:circleRect(b, a)
    else
        error("Error with hitbox types: " .. a.type .. " and " .. b.type)
    end
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
    return math.abs(x1 - x2) * 2 < (w1/2 + w2/2) and math.abs(y1 - y2) * 2 < (h1/2 + h2/2)
end

-- Circle - Rectangle Collision check
-- Assumes centered at its x, y
function collision:circleRect(circle, rect)
    local circleX, circleY, circleR = circle:getX(), circle:getY(), circle:getRadius()
    local rectX, rectY, rectW, rectH = rect:getX(), rect:getY(), rect:getWidth(), rect:getHeight()
    local halfW = rectW / 2
    local halfH = rectH / 2

    local closestX = math.max(rectX - halfW, math.min(circleX, rectX + halfW))
    local closestY = math.max(rectY - halfH, math.min(circleY, rectY + halfH))

    local dx = closestX - circleX
    local dy = closestY - circleY

    return (dx * dx + dy * dy) < (circleR * circleR)
end

return collision