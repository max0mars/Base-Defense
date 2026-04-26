local menu_scene = {}
menu_scene.__index = menu_scene
local scene = require("Scenes.scene") -- Import the base scene class
setmetatable(menu_scene, { __index = scene })

function menu_scene:load()
    -- Define resolution options
    self.resolutions = {
        { width = 800, height = 600, label = "800x600" },
        { width = 1280, height = 720, label = "1280x720" },
        { width = 1600, height = 900, label = "1600x900" },
        { width = 1920, height = 1080, label = "1920x1080" },
        { label = "Toggle Fullscreen", fullscreen = true }
    }
    
    self.buttons = {}
    
    local buttonWidth = 200
    local buttonHeight = 30
    local spacing = 15
    local startY = 250
    -- Center buttons horizontally based on the virtual resolution
    local startX = (VIRTUAL_WIDTH - buttonWidth) / 2
    
    for i, res in ipairs(self.resolutions) do
        table.insert(self.buttons, {
            x = startX,
            y = startY + (i - 1) * (buttonHeight + spacing),
            w = buttonWidth,
            h = buttonHeight,
            data = res
        })
    end
end

function menu_scene:draw()
    love.graphics.setColor(1, 1, 1) -- Set color to white
    
    -- Draw title and instructions using virtual coordinates
    love.graphics.printf("Welcome to the Base Defense Game!", 0, 100, VIRTUAL_WIDTH, "center")
    love.graphics.printf("Press 'Enter' to Start", 0, 150, VIRTUAL_WIDTH, "center")
    love.graphics.printf("Press 'T' for Tests", 0, 180, VIRTUAL_WIDTH, "center")
    
    -- Draw resolution buttons
    for _, btn in ipairs(self.buttons) do
        -- Draw button background
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)
        
        -- Draw button border
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
        
        -- Draw button label
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(btn.data.label, btn.x, btn.y + (btn.h / 2) - 6, btn.w, "center")
    end
end

function menu_scene:mousepressed(x, y, button)
    if button == 1 then
        -- AABB collision detection for buttons
        for _, btn in ipairs(self.buttons) do
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                if btn.data.fullscreen then
                    scalify:switchFullscreen()
                else
                    -- Resize window using scalify
                    scalify:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, btn.data.width, btn.data.height, {resizable = true, highdpi = true})
                end
                break
            end
        end
    end
end

function menu_scene:keypressed(key)
    if key == "return" then
        self.scene_manager.switch("game") -- Switch to the game scene when Enter is pressed
    elseif key == "t" then
        self.scene_manager.switch("test") -- Switch to the test scene when 't' is pressed
    end
end

return menu_scene