local game_over_scene = {}
game_over_scene.__index = game_over_scene

local scene = require("Scenes.scene") -- Import the base scene class
setmetatable(game_over_scene, { __index = scene })

local game = require("Game.Core.GameManager")

function game_over_scene:load()
    love.mouse.setVisible(true)
    self.damageHistoryList = game.base:getProcessedDamageHistory()
    self.damageHistoryPage = 1
    self.itemsPerPage = 16
end

function game_over_scene:draw()
    game:draw()
    love.graphics.setColor(0, 0, 0, 0.85) -- Dark overlay
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    
    -- Game Over Title
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.push()
    love.graphics.scale(2, 2)
    love.graphics.printf("GAME OVER", 0, VIRTUAL_HEIGHT / 8 - 20, VIRTUAL_WIDTH / 2, "center")
    love.graphics.pop()
    
    -- Stats
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Wave Reached: " .. tostring(game.wave or 1), 0, VIRTUAL_HEIGHT / 4 + 15, VIRTUAL_WIDTH, "center")
    
    -- Grid rendering
    if self.damageHistoryList and #self.damageHistoryList > 0 then
        love.graphics.setColor(0, 0.85, 1.0, 1)
        love.graphics.printf("Damage History", 0, VIRTUAL_HEIGHT / 4 + 40, VIRTUAL_WIDTH, "center")
        
        local totalPages = math.ceil(#self.damageHistoryList / self.itemsPerPage)
        
        local cols = 8
        local rows = 2
        local cellW = 80
        local cellH = 90
        local startX = VIRTUAL_WIDTH / 2 - (cols * cellW) / 2
        local startY = VIRTUAL_HEIGHT / 4 + 70
        
        local startIndex = (self.damageHistoryPage - 1) * self.itemsPerPage + 1
        local endIndex = math.min(startIndex + self.itemsPerPage - 1, #self.damageHistoryList)
        
        for i = startIndex, endIndex do
            local item = self.damageHistoryList[i]
            local localIdx = i - startIndex
            local col = localIdx % cols
            local row = math.floor(localIdx / cols)
            
            local cx = startX + col * cellW + cellW / 2
            local cy = startY + row * cellH + cellH / 2
            
            -- Draw subtle box
            love.graphics.setColor(0, 0.85, 1.0, 0.2)
            love.graphics.rectangle("line", startX + col * cellW, startY + row * cellH, cellW, cellH, 4)
            
            -- Draw Level
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.printf("Level: " .. tostring(item.level), startX + col * cellW, startY + row * cellH + 5, cellW, "center")
            
            -- Draw Sprite
            local drawW = item.w or 20
            local drawH = item.h or 20
            
            local enemyFileName = item.name
            if enemyFileName == "Basic" then enemyFileName = "Enemy" end
            local success, enemyClass = pcall(require, "Enemies." .. enemyFileName)
            
            if success and enemyClass then
                local mockEnemy = {
                    x = cx,
                    y = cy,
                    w = drawW,
                    h = drawH,
                    hp = 1,
                    maxHp = 1,
                    shield = 0,
                    maxShield = 0,
                    color = item.color or {1, 0, 0, 1},
                    game = game,
                    getStat = function(self, stat)
                        if stat == "maxHp" then return self.maxHp end
                        if stat == "size" then return self.w end
                        return 0
                    end
                }
                setmetatable(mockEnemy, { __index = enemyClass })
                mockEnemy:draw()
            else
                -- Fallback
                if item.color then
                    love.graphics.setColor(unpack(item.color))
                else
                    love.graphics.setColor(1, 0, 0, 1)
                end
                
                if item.shape == "circle" then
                    love.graphics.circle("fill", cx, cy, drawW / 2)
                else
                    love.graphics.rectangle("fill", cx - drawW/2, cy - drawH/2, drawW, drawH)
                end
            end
            
            -- Draw Damage
            love.graphics.setColor(1, 0.4, 0.4, 1)
            love.graphics.printf("Dmg: " .. tostring(math.floor(item.damage)), startX + col * cellW, startY + row * cellH + cellH - 20, cellW, "center")
        end
        
        -- Pagination Controls
        if totalPages > 1 then
            local mx, my = love.mouse.getPosition()
            local leftArrowX, leftArrowY = startX - 40, startY + (rows * cellH) / 2 - 15
            local rightArrowX, rightArrowY = startX + cols * cellW + 10, startY + (rows * cellH) / 2 - 15
            
            local hoverLeft = mx >= leftArrowX and mx <= leftArrowX + 30 and my >= leftArrowY and my <= leftArrowY + 30
            local hoverRight = mx >= rightArrowX and mx <= rightArrowX + 30 and my >= rightArrowY and my <= rightArrowY + 30
            
            -- Left Arrow
            love.graphics.setColor(hoverLeft and {0, 0.85, 1.0, 1} or {0, 0.5, 0.6, 1})
            love.graphics.rectangle("fill", leftArrowX, leftArrowY, 30, 30, 4)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf("<", leftArrowX, leftArrowY + 8, 30, "center")
            
            -- Right Arrow
            love.graphics.setColor(hoverRight and {0, 0.85, 1.0, 1} or {0, 0.5, 0.6, 1})
            love.graphics.rectangle("fill", rightArrowX, rightArrowY, 30, 30, 4)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(">", rightArrowX, rightArrowY + 8, 30, "center")
            
            -- Page Text
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.printf("Page " .. self.damageHistoryPage .. " / " .. totalPages, 0, startY + rows * cellH + 10, VIRTUAL_WIDTH, "center")
        end
    end
    
    -- Retry and Quit Buttons
    local mx, my = love.mouse.getPosition()
    local btnW = 130
    local btnH = 45
    local btnY = VIRTUAL_HEIGHT / 2 + 150
    local retryX = VIRTUAL_WIDTH / 2 - 140
    local quitX = VIRTUAL_WIDTH / 2 + 10
    
    local isRetryHovered = mx >= retryX and mx <= retryX + btnW and my >= btnY and my <= btnY + btnH
    local isQuitHovered = mx >= quitX and mx <= quitX + btnW and my >= btnY and my <= btnY + btnH
    
    -- Draw Retry Button (Green themed)
    love.graphics.setColor(isRetryHovered and {0.2, 0.8, 0.2, 1} or {0.1, 0.5, 0.1, 1})
    love.graphics.rectangle("fill", retryX, btnY, btnW, btnH, 8, 8)
    love.graphics.setColor(0.5, 1, 0.5, 1)
    love.graphics.setLineWidth(isRetryHovered and 2 or 1)
    love.graphics.rectangle("line", retryX, btnY, btnW, btnH, 8, 8)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Retry", retryX, btnY + 15, btnW, "center")
    
    -- Draw Quit Button (Red themed)
    love.graphics.setColor(isQuitHovered and {0.8, 0.2, 0.2, 1} or {0.5, 0.1, 0.1, 1})
    love.graphics.rectangle("fill", quitX, btnY, btnW, btnH, 8, 8)
    love.graphics.setColor(1, 0.5, 0.5, 1)
    love.graphics.setLineWidth(isQuitHovered and 2 or 1)
    love.graphics.rectangle("line", quitX, btnY, btnW, btnH, 8, 8)
    love.graphics.setLineWidth(1)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Quit Game", quitX, btnY + 15, btnW, "center")
end

function game_over_scene:mousepressed(x, y, button)
    if button == 1 then
        local btnW = 130
        local btnH = 45
        local btnY = VIRTUAL_HEIGHT / 2 + 150
        local retryX = VIRTUAL_WIDTH / 2 - 140
        local quitX = VIRTUAL_WIDTH / 2 + 10
        
        if x >= retryX and x <= retryX + btnW and y >= btnY and y <= btnY + btnH then
            paused = 0
            self.scene_manager.switch("game")
        elseif x >= quitX and x <= quitX + btnW and y >= btnY and y <= btnY + btnH then
            love.event.quit()
        end
        
        if self.damageHistoryList and #self.damageHistoryList > 0 then
            local totalPages = math.ceil(#self.damageHistoryList / self.itemsPerPage)
            if totalPages > 1 then
                local cols = 8
                local rows = 2
                local cellW = 80
                local cellH = 90
                local startX = VIRTUAL_WIDTH / 2 - (cols * cellW) / 2
                local startY = VIRTUAL_HEIGHT / 4 + 70
                
                local leftArrowX, leftArrowY = startX - 40, startY + (rows * cellH) / 2 - 15
                local rightArrowX, rightArrowY = startX + cols * cellW + 10, startY + (rows * cellH) / 2 - 15
                
                if x >= leftArrowX and x <= leftArrowX + 30 and y >= leftArrowY and y <= leftArrowY + 30 then
                    self.damageHistoryPage = math.max(1, self.damageHistoryPage - 1)
                elseif x >= rightArrowX and x <= rightArrowX + 30 and y >= rightArrowY and y <= rightArrowY + 30 then
                    self.damageHistoryPage = math.min(totalPages, self.damageHistoryPage + 1)
                end
            end
        end
    end
end

return game_over_scene
