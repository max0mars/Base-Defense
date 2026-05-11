local MutationUI = {}
MutationUI.__index = MutationUI

function MutationUI:new(game)
    local obj = setmetatable({
        game = game,
        isActive = false,
        options = {},
        selectedIndex = nil,
        selectionType = "enemy", -- "enemy" or "upgrade"
        
        -- Panel layout
        panelW = 280,
        panelH = 350,
        spacing = 40,
        startY = 120
    }, self)
    return obj
end

function MutationUI:activate(options, selectionType)
    self.isActive = true
    self.options = options
    self.selectedIndex = nil
    self.selectionType = selectionType or "enemy"
end

function MutationUI:update(dt)
    if not self.isActive then return end
    
    local mx, my = love.mouse.getPosition()
    self.selectedIndex = nil
    
    local totalW = (#self.options * self.panelW) + ((#self.options - 1) * self.spacing)
    local startX = (VIRTUAL_WIDTH - totalW) / 2
    
    for i, opt in ipairs(self.options) do
        local x = startX + (i - 1) * (self.panelW + self.spacing)
        local y = self.startY
        
        if mx >= x and mx <= x + self.panelW and my >= y and my <= y + self.panelH then
            self.selectedIndex = i
            break
        end
    end
end

function MutationUI:draw()
    if not self.isActive then return end
    
    -- Dark overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    
    love.graphics.setColor(1, 1, 1, 1)
    local title = self.selectionType == "enemy" and "NEW ENEMY DETECTED" or "SWARM EVOLUTION"
    local subtitle = self.selectionType == "enemy" and "Choose the next evolution of the swarm" or "Select a genetic upgrade for the active forces"
    
    love.graphics.printf(title, 0, 40, VIRTUAL_WIDTH, "center")
    love.graphics.printf(subtitle, 0, 70, VIRTUAL_WIDTH, "center")
    
    local totalW = (#self.options * self.panelW) + ((#self.options - 1) * self.spacing)
    local startX = (VIRTUAL_WIDTH - totalW) / 2
    
    for i, opt in ipairs(self.options) do
        local x = startX + (i - 1) * (self.panelW + self.spacing)
        local y = self.startY
        local isHovered = (self.selectedIndex == i)
        local data = opt.data
        
        -- Panel background
        if isHovered then
            love.graphics.setColor(0.15, 0.15, 0.15, 1)
        else
            love.graphics.setColor(0.1, 0.1, 0.1, 1)
        end
        love.graphics.rectangle("fill", x, y, self.panelW, self.panelH, 8)
        
        -- Neon Border
        local borderColor = self.selectionType == "enemy" and {1, 0.2, 0.2} or {0.8, 0.2, 1} -- Red for enemy, Purple for upgrade
        if isHovered then
            love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], 1)
            love.graphics.setLineWidth(3)
        else
            love.graphics.setColor(borderColor[1] * 0.5, borderColor[2] * 0.5, borderColor[3] * 0.5, 1)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", x, y, self.panelW, self.panelH, 8)
        
        -- Icon representation
        love.graphics.setColor(data.color or borderColor)
        local iconSize = 40
        love.graphics.rectangle("line", x + self.panelW/2 - iconSize/2, y + 40, iconSize, iconSize)
        love.graphics.rectangle("fill", x + self.panelW/2 - iconSize/2 + 10, y + 40 + 10, iconSize - 20, iconSize - 20)
        
        -- Name
        love.graphics.setColor(1, 1, 1, 1)
        local nameText = self.selectionType == "enemy" and (data.type or "Unknown") or (data.name or "Upgrade")
        love.graphics.printf(nameText:upper(), x, y + 100, self.panelW, "center")
        
        -- Description
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.printf(data.description or "", x + 20, y + 140, self.panelW - 40, "center")
        
        -- Target (for upgrades)
        if self.selectionType == "upgrade" and data.target then
            love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], 0.8)
            love.graphics.printf("TARGET: " .. data.target:upper(), x, y + 260, self.panelW, "center")
        end

        -- Call to action
        if isHovered then
            love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], 1)
            local actionText = self.selectionType == "enemy" and "ADD TO SWARM" or "MUTATE ENEMY"
            love.graphics.printf(actionText, x, y + 310, self.panelW, "center")
        end
    end
    
    love.graphics.setLineWidth(1)
end

function MutationUI:mousepressed(x, y, button)
    if not self.isActive or button ~= 1 then return false end
    
    if self.selectedIndex then
        local option = self.options[self.selectedIndex]
        local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
        EnemyRegistry:activateMutation(option)
        
        self.isActive = false
        self.game:setState("preparing")
        return true
    end
    
    return false
end

return MutationUI
