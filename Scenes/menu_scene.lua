local menu_scene = {}
menu_scene.__index = menu_scene
local scene = require("Scenes.scene") -- Import the base scene class
local game = require("Game.Core.GameManager")
setmetatable(menu_scene, { __index = scene })

function menu_scene:load()
    love.mouse.setVisible(true)
    self.buttons = {
        -- Main Actions
        {
            x = (VIRTUAL_WIDTH - 240) / 2,
            y = 190,
            w = 240,
            h = 45,
            label = "PLAY GAME",
            type = "main",
            action = "play",
            color = {0.1, 0.45, 0.25, 1},
            hoverColor = {0.18, 0.7, 0.4, 1},
            borderColor = {0.3, 0.9, 0.5, 1}
        },
        {
            x = (VIRTUAL_WIDTH - 240) / 2,
            y = 245,
            w = 240,
            h = 45,
            label = "TUTORIAL",
            type = "main",
            action = "tutorial",
            color = {0.3, 0.2, 0.55, 1},
            hoverColor = {0.48, 0.32, 0.8, 1},
            borderColor = {0.7, 0.5, 1, 1}
        }
    }
    
    -- System Resolution settings
    local resOptions = {
        { width = 800, height = 600, label = "800x600" },
        { width = 1200, height = 900, label = "1200x900" },
        { width = 1600, height = 1200, label = "1600x1200" },
        { label = "Fullscreen", fullscreen = true }
    }
    
    local resW = 110
    local resH = 28
    local resSpacing = 12
    local resStartY = 350
    local totalResW = #resOptions * resW + (#resOptions - 1) * resSpacing
    local resStartX = (VIRTUAL_WIDTH - totalResW) / 2
    
    for i, res in ipairs(resOptions) do
        table.insert(self.buttons, {
            x = resStartX + (i - 1) * (resW + resSpacing),
            y = resStartY,
            w = resW,
            h = resH,
            label = res.label,
            type = "setting",
            action = "resolution",
            data = res,
            color = {0.15, 0.15, 0.18, 1},
            hoverColor = {0.28, 0.28, 0.32, 1},
            borderColor = {0.5, 0.5, 0.55, 1}
        })
    end

    self.confirmation = require("Game.GUI.ConfirmationUI"):new({inputHandler = {}})
    local AudioSlidersUI = require("Game.GUI.AudioSlidersUI")
    self.sliders = AudioSlidersUI:new({ x = (VIRTUAL_WIDTH - 240) / 2, y = 445, w = 240 })
end

function menu_scene:update(dt)
    self.confirmation:update(dt)
    if self.sliders then self.sliders:update(dt) end
end

function menu_scene:draw()
    -- Draw subtle tactical grid background
    love.graphics.setColor(0.15, 0.15, 0.18, 0.35)
    for gx = 0, VIRTUAL_WIDTH, 40 do
        love.graphics.line(gx, 0, gx, VIRTUAL_HEIGHT)
    end
    for gy = 0, VIRTUAL_HEIGHT, 40 do
        love.graphics.line(0, gy, VIRTUAL_WIDTH, gy)
    end

    -- Draw a glowing sci-fi title banner
    love.graphics.setColor(0.12, 0.25, 0.4, 0.15)
    love.graphics.rectangle("fill", 0, 65, VIRTUAL_WIDTH, 65)
    love.graphics.setColor(0.2, 0.45, 0.7, 0.5)
    love.graphics.line(0, 65, VIRTUAL_WIDTH, 65)
    love.graphics.line(0, 130, VIRTUAL_WIDTH, 130)
    
    -- Draw main title
    love.graphics.push()
    love.graphics.scale(2.5, 2.5)
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.printf("BASE DEFENSE", 1, 31, VIRTUAL_WIDTH / 2.5, "center")
    -- Text
    love.graphics.setColor(0.3, 0.7, 1, 1)
    love.graphics.printf("BASE DEFENSE", 0, 30, VIRTUAL_WIDTH / 2.5, "center")
    love.graphics.pop()
    
    -- Subtitle
    love.graphics.setColor(0.55, 0.6, 0.7, 1)
    love.graphics.printf("Protect the Core. Upgrade your Arsenal.", 0, 148, VIRTUAL_WIDTH, "center")
    
    -- Settings Section Divider
    love.graphics.setColor(0.4, 0.4, 0.45)
    love.graphics.printf("— SYSTEM CONFIGURATION —", 0, 318, VIRTUAL_WIDTH, "center")
    
    -- Draw all buttons
    local mx, my = love.mouse.getPosition()
    for _, btn in ipairs(self.buttons) do
        local isHovered = mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h
        
        -- Custom checks (like isTooBig for resolutions)
        local isTooBig = false
        if btn.action == "resolution" and btn.data.width then
            local dw, dh = love.window.getDesktopDimensions()
            isTooBig = btn.data.width > dw or btn.data.height > dh
        end
        
        -- Select color based on state
        local bgCol = btn.color
        local borderCol = btn.borderColor
        
        if isTooBig then
            bgCol = {0.4, 0.15, 0.15, 1}
            borderCol = {0.8, 0.3, 0.3, 1}
        elseif isHovered then
            bgCol = btn.hoverColor
        end
        
        -- Draw button background with rounded corners
        love.graphics.setColor(bgCol)
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 6, 6)
        
        -- Draw glowing border on hover
        love.graphics.setColor(borderCol)
        love.graphics.setLineWidth(isHovered and 2 or 1)
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 6, 6)
        love.graphics.setLineWidth(1)
        
        -- Draw button text
        love.graphics.setColor(1, 1, 1)
        local label = btn.label
        if isTooBig then label = label .. " (!)" end
        
        -- Center text vertically
        local textYOffset = btn.h / 2 - 6
        if btn.type == "main" then
            textYOffset = btn.h / 2 - 7
            -- For main buttons, draw bold shadow
            love.graphics.push()
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.printf(label, btn.x + 1, btn.y + textYOffset + 1, btn.w, "center")
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(label, btn.x, btn.y + textYOffset, btn.w, "center")
            love.graphics.pop()
        else
            love.graphics.printf(label, btn.x, btn.y + textYOffset, btn.w, "center")
        end
    end

    if self.sliders then self.sliders:draw() end
    self.confirmation:draw()
end

function menu_scene:mousepressed(x, y, button)
    if self.confirmation:mousepressed(x, y, button) then
        return true
    end

    if self.sliders and self.sliders:mousepressed(x, y, button) then
        return true
    end

    if button == 1 then
        -- AABB collision detection for buttons
        for _, btn in ipairs(self.buttons) do
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                -- Play sound feedback
                -- Sound removed per user request
                
                if btn.action == "play" then
                    game.testingMode = false
                    self.scene_manager.switch("game")
                elseif btn.action == "tutorial" then
                    self.scene_manager.switch("tutorial")
                elseif btn.action == "resolution" then
                    local res = btn.data
                    if res.fullscreen then
                        scalify:switchFullscreen()
                    else
                        scalify:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, res.width, res.height, {resizable = true, highdpi = true})
                    end
                end
                break
            end
        end
    end
end

function menu_scene:keypressed(key)
    if key == "return" then
        game.testingMode = false
        self.scene_manager.switch("game") -- Switch to the game scene when Enter is pressed
    elseif key == "t" then
        game.testingMode = true
        self.scene_manager.switch("game") -- Switch to the game scene in Testing Mode when 't' is pressed
    elseif key == "escape" then
        love.event.quit()
    end
end

function menu_scene:mousereleased(x, y, button)
    if self.sliders then
        self.sliders:mousereleased(x, y, button)
    end
end

return menu_scene