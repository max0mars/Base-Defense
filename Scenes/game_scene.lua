local game_scene = {
    
}
game_scene.__index = game_scene
local scene = require("Scenes.scene") -- Import the base scene class
setmetatable(game_scene, { __index = scene })

local game = require("Game.Core.GameManager") -- Import the game module

function game_scene:load()
    game:load()
    game.time_mul = 1 -- game starts at normal speed
    self.gameover = false
    if AUDIO then AUDIO:playMusic() end
end

function game_scene:mousepressed(x, y, button)
    if self.gameover then
        if button == 1 then
            local btnW = 140
            local btnH = 45
            local btnX = VIRTUAL_WIDTH / 2 - btnW / 2
            local btnY = VIRTUAL_HEIGHT / 2 + 80
            if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + btnH then
                love.event.quit()
            end
        end
        return
    end
    game.inputHandler:mousepressed(x, y, button) -- Route through InputHandler
end

function game_scene:mousereleased(x, y, button)
    if game.inputHandler.mousereleased then
        game.inputHandler:mousereleased(x, y, button)
    end
end

function game_scene:update(dt)
    if game:isState("gameover") and not self.gameover then
        self.gameover = true
        love.mouse.setVisible(true)
    end

    local effectiveDt = dt * game.time_mul
    
    -- Freeze game if paused or a modal menu is active
    if paused == 1 or 
       (game.rewardSystem and game.rewardSystem.isActive) or 
       (game.specialUpgradeManager and game.specialUpgradeManager.isActive) or
       (game.gui.mutation and game.gui.mutation.isActive) or
       (game.gui.confirmation and game.gui.confirmation.active) then
        effectiveDt = 0
    end
    
    game:update(effectiveDt)
end

function game_scene:draw()
    if self.gameover then
        love.graphics.setColor(0, 0, 0, 0.85) -- Dark overlay
        love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
        
        -- Game Over Title
        love.graphics.setColor(1, 0.2, 0.2)
        love.graphics.push()
        love.graphics.scale(2, 2)
        love.graphics.printf("GAME OVER", 0, VIRTUAL_HEIGHT / 4 - 30, VIRTUAL_WIDTH / 2, "center")
        love.graphics.pop()
        
        -- Stats
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Wave Reached: " .. tostring(game.wave or 1), 0, VIRTUAL_HEIGHT / 2 - 10, VIRTUAL_WIDTH, "center")
        love.graphics.printf("Final Score: " .. tostring(game.xp or 0), 0, VIRTUAL_HEIGHT / 2 + 20, VIRTUAL_WIDTH, "center")
        
        -- Quit Button
        local mx, my = love.mouse.getPosition()
        local btnW = 140
        local btnH = 45
        local btnX = VIRTUAL_WIDTH / 2 - btnW / 2
        local btnY = VIRTUAL_HEIGHT / 2 + 80
        local isHovered = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
        
        love.graphics.setColor(isHovered and {0.8, 0.2, 0.2, 1} or {0.5, 0.1, 0.1, 1})
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 8, 8)
        love.graphics.setColor(1, 0.5, 0.5, 1)
        love.graphics.setLineWidth(isHovered and 2 or 1)
        love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 8, 8)
        love.graphics.setLineWidth(1)
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Quit Game", btnX, btnY + 15, btnW, "center")
        return
    end
    game:draw()
    if paused == 1 then
        love.graphics.setColor(0, 0, 0, 0.5) -- Semi-transparent black for pause overlay
        love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
        love.graphics.setColor(1, 1, 1) -- Reset color for text
        love.graphics.printf("Game Paused", 0, VIRTUAL_HEIGHT / 2 - 20, VIRTUAL_WIDTH, "center")
    end
    love.graphics.setColor(1, 1, 1, 1)
    -- love.graphics.print("Tokens: " .. game.tokens, 10, 10)
    -- --love.graphics.print("Time Multiplier: " .. string.format("%.1f", time_mul) .. "x", 10, 30)
    -- love.graphics.print("Wave: " .. game.wave, 10, 30)
    -- --love.graphics.print("Game State: " .. game.state, 10, 70)
    -- --love.graphics.print("Wave State: " .. game.WaveSpawner.waveState, 200, 10)
    -- --love.graphics.print("Selected Turret: " .. (game.inputHandler.selectedTurret and game.inputHandler.selectedTurret.id or "None"), 200, 30)
    -- --love.graphics.print("Spawn Rate: " .. game.WaveSpawner.spawnRate, 200, 50)
    -- love.graphics.print("Debug: " .. tostring(game.debugMode or false), 10, 50)
end

function game_scene:keypressed(key)
    if key == "p" then
        paused = paused == 1 and 0 or 1 -- Toggle pause
    elseif key == "+" or key == "=" then
        game.time_mul = math.min(game.time_mul + 0.5, 5) -- Increase time multiplier up to 5x
    elseif key == "-" then
        game.time_mul = math.max(game.time_mul - 0.5, 0) -- Decrease time multiplier down to 0x
    elseif key == "escape" then
        game.gui.confirmation:activate(
            "Do you want to quit?",
            function() love.event.quit() end,
            function() end
        )
    else 
        game.inputHandler:keypressed(key) -- Route through InputHandler
    end
end

return game_scene