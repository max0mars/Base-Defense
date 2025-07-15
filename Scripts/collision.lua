collision = {
    grid = {},
    cellSize = 32,
    width = 0,
    height = 0
}

function collision:initialize(cellSize, width, height)
    self.width = width or 800
    self.height = height or 600
    self.cellSize = cellSize or 32
    self:updateGrid()
end

function collision:refreshGrid()
    local xCells = math.ceil(self.width / self.cellSize)
    local yCells = math.ceil(self.height / self.cellSize)
    for x = 1, xCells do
        self.grid[x] = {}
        for y = 1, yCells do
            self.grid[x][y] = {}
        end
    end
end

function collision:setGridSize(width, height)
    self.width = width
    self.height = height
    self.grid = self:refreshGrid()
end

function collision:addToGrid(hitbox)
    if hitbox:getX() < 0 or hitbox:getX() > self.width or hitbox:getY() < 0 or hitbox:getY() > self.height then
        return
    end
    if(hitbox.type == 'circle') then
        local xCell = math.floor(hitbox:getX() / self.cellSize) + 1
        local yCell = math.floor(hitbox:getY() / self.cellSize) + 1
        if self.grid[xCell] and self.grid[xCell][yCell] then
            table.insert(self.grid[xCell][yCell], hitbox)
        end
    end
end

function collision:checkAllCollisions()
    for x = 1, #self.grid do
        for y = 1, #self.grid[x] do
            local cell = self.grid[x][y]
            if #cell > 1 then
                for i = 1, #cell do
                    for j = i + 1, #cell do
                        if collision:checkCollision(cell[i], cell[j]) then
                            -- Handle collision between cell[i] and cell[j]
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
end

function collision:checkCollision(a, b)
    if a.type == "circle" and b.type == "circle" then
        return self:circleCircle(a, b)
    elseif a.type == "square" and b.type == "square" then
        return self:rectRect(a, b)
    elseif a.type == "circle" and b.type == "square" then
        return self:circleRect(a, b)
    elseif a.type == "square" and b.type == "circle" then
        return self:circleRect(b, a)
    elseif a.type == "triangle" and b.type == "triangle" then
        return self:triangleTriangle(a, b)
    elseif a.type == "triangle" and b.type == "square" then
        return self:triangleRect(a, b)
    elseif a.type == "square" and b.type == "triangle" then
        return self:triangleRect(b, a)
    elseif a.type == "triangle" and b.type == "circle" then
        return self:triangleCircle(a, b)
    elseif a.type == "circle" and b.type == "triangle" then
        return self:triangleCircle(b, a)
    else
        error("Error with hitbox types: " .. a.type .. " and " .. b.type)
    end
end

function collision:circleCircle(a, b)
    local dx = a:getX() - b:getX()
    local dy = a:getY() - b:getY()
    local distance = dx * dx + dy * dy
    return distance < (a:getSize() + b:getSize()) * (a:getSize() + b:getSize()) -- Assuming size is radius for circles
end

function collision:rectRect(a, b)
    local x1, y1, size1 = a:getX(), a:getY(), a:getSize()
    local x2, y2, size2 = b:getX(), b:getY(), b:getSize()
    return math.abs(x1 - x2) * 2 < (size1 + size2)
    and math.abs(y1 - y2) * 2 < (size1 + size2)
end

function collision:

return collision