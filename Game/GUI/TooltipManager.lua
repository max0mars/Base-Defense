local TooltipManager = {}
TooltipManager.__index = TooltipManager

function TooltipManager:new(game)
    local obj = setmetatable({
        game = game,
        hoveredBuilding = nil,
        hoverTooltip = nil,
        rarityProbs = nil
    }, self)
    return obj
end

function TooltipManager:update(dt)
    self.hoveredBuilding = self.game.inputHandler.hoveredBuilding
    self.hoverTooltip = self.game.base.hoverTooltip
end

function TooltipManager:draw()
    local game = self.game
    
    -- Draw slot unlock tooltip
    if self.hoverTooltip then
        self:drawSimpleTooltip(self.hoverTooltip.x, self.hoverTooltip.y, self.hoverTooltip.text, self.hoverTooltip.cost or 0)
    end
    
    -- Draw building effects/buff tooltips
    if self.hoveredBuilding and self.hoveredBuilding.showEffects and self.hoveredBuilding.effectManager then
        local tipX, tipY = self.hoveredBuilding.x, self.hoveredBuilding.y
        if self.hoveredBuilding.getCenterPosition then
            tipX, tipY = self.hoveredBuilding:getCenterPosition()
        end
        self.hoveredBuilding.effectManager:drawTooltip(tipX, tipY)
    end
    
    -- Draw startup and preparation messages
    if game:isState("preparing") then
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.printf("Press Enter to Start Wave ", 0, VIRTUAL_HEIGHT / 2 - 20, VIRTUAL_WIDTH, "center")
    end

    -- Draw rarity probabilities tooltip
    if self.rarityProbs then
        local mx, my = love.mouse.getPosition()
        self:drawRarityTooltip(mx + 15, my + 15, self.rarityProbs)
    end
end

function TooltipManager:drawSimpleTooltip(x, y, text, cost)
    love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
    local font = love.graphics.getFont()
    local tw = font:getWidth(text)
    local th = font:getHeight()
    love.graphics.rectangle("fill", x, y, tw + 10, th + 10)
    
    if self.game.tokens >= cost then
        love.graphics.setColor(0, 1, 0, 1)
    else
        love.graphics.setColor(1, 0, 0, 1)
    end
    love.graphics.print(text, x + 5, y + 5)
    love.graphics.setColor(1, 1, 1, 1)
end

function TooltipManager:drawRarityTooltip(x, y, probs)
    local padding = 12
    local lineHeight = 22
    local width = 160
    local height = (#probs * lineHeight) + padding * 2
    
    -- Draw shadow/background
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", x, y, width, height, 6)
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.rectangle("line", x, y, width, height, 6)
    
    for i, p in ipairs(probs) do
        love.graphics.setColor(p.color)
        local text = string.format("%s: %.0f%%", p.rarity, p.percent)
        love.graphics.print(text, x + padding, y + padding + (i-1) * lineHeight)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return TooltipManager
