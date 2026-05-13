local MutationUI = {}
MutationUI.__index = MutationUI

function MutationUI:new(game)
    local obj = setmetatable({
        game = game,
        isActive = false,
        chosenOption = nil,
        selectionType = "enemy", -- "enemy" or "upgrade"
        
        -- Panel layout for single card centered
        panelW = 320,
        panelH = 380,
        startY = 130
    }, self)
    return obj
end

function MutationUI:activate(options, selectionType)
    self.isActive = true
    self.selectionType = selectionType or "enemy"
    
    if options and #options > 0 then
        local chosenIdx = love.math.random(1, #options)
        self.chosenOption = options[chosenIdx]
        
        local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
        EnemyRegistry:activateMutation(self.chosenOption)
    else
        self.chosenOption = nil
        self.isActive = false
        self.game:setState("preparing")
    end
end

function MutationUI:update(dt)
    if not self.isActive then return end
end

function MutationUI:draw()
    if not self.isActive or not self.chosenOption then return end
    
    -- Dark overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    
    love.graphics.setColor(1, 1, 1, 1)
    local title = self.selectionType == "enemy" and "NEW THREAT DETECTED" or "SWARM EVOLUTION"
    local subtitle = self.selectionType == "enemy" and "The swarm expands..." or "The swarm adapts..."
    
    love.graphics.printf(title, 0, 40, VIRTUAL_WIDTH, "center")
    love.graphics.printf(subtitle, 0, 70, VIRTUAL_WIDTH, "center")
    
    local x = (VIRTUAL_WIDTH - self.panelW) / 2
    local y = self.startY
    local data = self.chosenOption.data
    
    -- Panel background
    love.graphics.setColor(0.12, 0.12, 0.12, 1)
    love.graphics.rectangle("fill", x, y, self.panelW, self.panelH, 10)
    
    -- Neon Border
    local borderColor = self.selectionType == "enemy" and {1, 0.2, 0.2} or {0.8, 0.2, 1}
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, self.panelW, self.panelH, 10)
    
    -- Icon representation
    love.graphics.setColor(data.color or borderColor)
    local iconSize = 48
    love.graphics.rectangle("line", x + self.panelW/2 - iconSize/2, y + 40, iconSize, iconSize)
    love.graphics.rectangle("fill", x + self.panelW/2 - iconSize/2 + 10, y + 40 + 10, iconSize - 20, iconSize - 20)
    
    -- Name
    love.graphics.setColor(1, 1, 1, 1)
    local nameText = self.selectionType == "enemy" and (data.type or "Unknown") or (data.name or "Upgrade")
    love.graphics.printf(nameText:upper(), x, y + 110, self.panelW, "center")
    
    -- Description
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.printf(data.description or "", x + 20, y + 160, self.panelW - 40, "center")
    
    -- Target (for upgrades)
    if self.selectionType == "upgrade" and data.target then
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], 0.8)
        love.graphics.printf("TARGET: " .. data.target:upper(), x, y + 280, self.panelW, "center")
    end
    
    -- Status stamp
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], 1)
    love.graphics.printf("ADDED TO SWARM", x, y + 330, self.panelW, "center")
    
    -- Call to action prompt at screen bottom
    local pulse = (math.sin(love.timer.getTime() * 6) + 1) / 2
    love.graphics.setColor(1, 1, 1, 0.4 + 0.6 * pulse)
    love.graphics.printf("[ CLICK ANYWHERE TO CONTINUE ]", 0, VIRTUAL_HEIGHT - 60, VIRTUAL_WIDTH, "center")
    
    love.graphics.setLineWidth(1)
end

function MutationUI:mousepressed(x, y, button)
    if not self.isActive or button ~= 1 then return false end
    
    self.isActive = false
    self.game:setState("preparing")
    return true
end

return MutationUI
