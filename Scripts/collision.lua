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

function collision:updateGrid()
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
    self.grid = self:createGrid(width, height, self.cellSize)
end

function collision:addToGrid(hitbox)
    if(not hitbox or not hitbox.x or not hitbox.y) then
        error("Hitbox must have x and y properties")
    end
    if hitbox.x < 0 or hitbox.x > self.width or hitbox.y < 0 or hitbox.y > self.height then
        return
    end
    if(hitbox.type == 'circle') then
        local xCell = math.floor(hitbox.x / self.cellSize) + 1
        local yCell = math.floor(hitbox.y / self.cellSize) + 1
        if self.grid[xCell] and self.grid[xCell][yCell] then
            table.insert(self.grid[xCell][yCell], hitbox)
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
                            print("Collision detected between " .. cell[i].entity .. " and " .. cell[j].entity)
                        end
                    end
                end
            end
        end
    end
end

function collision:checkCollision(a, b)
    if a.type == "circle" and b.type == "circle" then
        return circleCircle(a, b)
    elseif a.type == "square" and b.type == "square" then
        return rectRect(a, b)
    elseif a.type == "circle" and b.type == "square" then
        return circleRect(a, b)
    elseif a.type == "square" and b.type == "circle" then
        return circleRect(b, a)
    elseif a.type == "triangle" and b.type == "triangle" then
        return triangleTriangle(a, b)
    elseif a.type == "triangle" and b.type == "square" then
        return triangleRect(a, b)
    elseif a.type == "square" and b.type == "triangle" then
        return triangleRect(b, a)
    elseif a.type == "triangle" and b.type == "circle" then
        return triangleCircle(a, b)
    elseif a.type == "circle" and b.type == "triangle" then
        return triangleCircle(b, a)
    else
        error("Error with hitbox types: " .. a.type .. " and " .. b.type)
    end
end

return collision