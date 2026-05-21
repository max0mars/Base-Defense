local EnemySpawnUI = {}
EnemySpawnUI.__index = EnemySpawnUI

function EnemySpawnUI:new(game)
    local obj = setmetatable({}, self)
    obj.game = game
    obj.isActive = false
    obj.enemies = {
        "Armored", "Carrier", "Flyer", "Guardian", "Speeder", "Tank", "Duplicator"
    }
    obj.spawnCounts = {}
    for _, e in ipairs(obj.enemies) do
        obj.spawnCounts[e] = 0
    end
    obj.w = 300
    obj.h = 330
    obj.x = (VIRTUAL_WIDTH - obj.w) / 2
    obj.y = (VIRTUAL_HEIGHT - obj.h) / 2
    return obj
end

function EnemySpawnUI:update(dt)
end

function EnemySpawnUI:draw()
    if not self.isActive or not self.game.testingMode then return end
    
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h)
    
    love.graphics.printf("Testing Mode - Spawn Enemies", self.x, self.y + 10, self.w, "center")
    
    local startY = self.y + 50
    for i, e in ipairs(self.enemies) do
        local ey = startY + (i - 1) * 30
        love.graphics.print(e, self.x + 20, ey)
        
        -- Draw minus
        love.graphics.rectangle("line", self.x + 180, ey, 20, 20)
        love.graphics.printf("-", self.x + 180, ey + 2, 20, "center")
        
        -- Draw count
        love.graphics.printf(tostring(self.spawnCounts[e]), self.x + 200, ey + 2, 40, "center")
        
        -- Draw plus
        love.graphics.rectangle("line", self.x + 240, ey, 20, 20)
        love.graphics.printf("+", self.x + 240, ey + 2, 20, "center")
    end
    
    love.graphics.printf("Press Enter to send wave, e to close", self.x, self.y + self.h - 30, self.w, "center")
end

function EnemySpawnUI:mousepressed(x, y, button)
    if not self.isActive or not self.game.testingMode then return false end
    
    if button == 1 then
        local startY = self.y + 50
        for i, e in ipairs(self.enemies) do
            local ey = startY + (i - 1) * 30
            -- Check minus button
            if x >= self.x + 180 and x <= self.x + 200 and y >= ey and y <= ey + 20 then
                self.spawnCounts[e] = math.max(0, self.spawnCounts[e] - 1)
                return true
            end
            -- Check plus button
            if x >= self.x + 240 and x <= self.x + 260 and y >= ey and y <= ey + 20 then
                self.spawnCounts[e] = self.spawnCounts[e] + 1
                return true
            end
        end
    end
    
    return true -- Consume input if clicking inside or outside
end

return EnemySpawnUI
