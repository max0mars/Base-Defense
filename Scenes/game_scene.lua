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
    if AUDIO and not AUDIO:isPlayingMusic() then AUDIO:playMusic() end
    local AudioSlidersUI = require("Game.GUI.AudioSlidersUI")
    self.sliders = AudioSlidersUI:new({ x = (VIRTUAL_WIDTH - 200) / 2, y = VIRTUAL_HEIGHT / 2 + 40, w = 200 })
end

function game_scene:mousepressed(x, y, button)
    if self.gameover then
        if button == 1 then
            local btnW = 130
            local btnH = 45
            local btnY = VIRTUAL_HEIGHT / 2 + 80
            local retryX = VIRTUAL_WIDTH / 2 - 140
            local quitX = VIRTUAL_WIDTH / 2 + 10
            
            if x >= retryX and x <= retryX + btnW and y >= btnY and y <= btnY + btnH then
                paused = 0
                self:load()
            elseif x >= quitX and x <= quitX + btnW and y >= btnY and y <= btnY + btnH then
                love.event.quit()
            end
        end
        return
    end
    if paused == 1 then
        if self.sliders and self.sliders:mousepressed(x, y, button) then
            return
        end
        return
    end
    game.inputHandler:mousepressed(x, y, button) -- Route through InputHandler
end

function game_scene:mousereleased(x, y, button)
    if paused == 1 then
        if self.sliders then self.sliders:mousereleased(x, y, button) end
        return
    end
    if game.inputHandler.mousereleased then
        game.inputHandler:mousereleased(x, y, button)
    end
end

function game_scene:update(dt)
    if paused == 1 and self.sliders then
        self.sliders:update(dt)
    end
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
        
        -- Retry and Quit Buttons
        local mx, my = love.mouse.getPosition()
        local btnW = 130
        local btnH = 45
        local btnY = VIRTUAL_HEIGHT / 2 + 80
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
        return
    end
    game:draw()
    if paused == 1 then
        love.graphics.setColor(0, 0, 0, 0.5) -- Semi-transparent black for pause overlay
        love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
        love.graphics.setColor(1, 1, 1) -- Reset color for text
        love.graphics.printf("Game Paused", 0, VIRTUAL_HEIGHT / 2 - 20, VIRTUAL_WIDTH, "center")
        if self.sliders then self.sliders:draw() end
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
        if game.gui.confirmation.active then
            game.gui.confirmation.active = false
            if game.gui.confirmation.onCancel then game.gui.confirmation.onCancel() end
        else
            game.gui.confirmation:activate(
                "Do you want to quit?",
                function() love.event.quit() end,
                function() end
            )
        end
    else 
        game.inputHandler:keypressed(key) -- Route through InputHandler
    end
end

return game_scene