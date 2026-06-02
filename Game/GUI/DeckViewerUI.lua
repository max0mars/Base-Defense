local DeckViewerUI = {}
DeckViewerUI.__index = DeckViewerUI

local ExecutionType = require("Game.Cards.ExecutionType")

function DeckViewerUI:new(game)
    local obj = setmetatable({
        game = game,
        isActive = false,
        pileType = "",
        cards = {},
        scrollOffset = 0,
        closeButton = { x = VIRTUAL_WIDTH - 80, y = 40, w = 40, h = 40 }
    }, self)
    return obj
end

function DeckViewerUI:open(pileType, cards, sourceBtn)
    self.isActive = true
    self.pileType = pileType
    self.cards = {}
    
    if sourceBtn then
        self.closeButton.x = sourceBtn.x + sourceBtn.w / 2 - 20
        self.closeButton.y = sourceBtn.y + sourceBtn.h / 2 - 20
    else
        self.closeButton = { x = VIRTUAL_WIDTH - 80, y = 40, w = 40, h = 40 }
    end
    
    -- Create a shallow copy to sort without affecting the real pile
    for _, c in ipairs(cards) do
        table.insert(self.cards, c)
    end
    
    -- Sort by cost (ascending), then name (alphabetical)
    table.sort(self.cards, function(a, b)
        local costA = a.getCost and a:getCost() or a.cost or 0
        local costB = b.getCost and b:getCost() or b.cost or 0
        if costA ~= costB then
            return costA < costB
        end
        return (a.name or "") < (b.name or "")
    end)
    
    self.scrollOffset = 0
end

function DeckViewerUI:close()
    self.isActive = false
    self.cards = {}
end

function DeckViewerUI:update(dt)
end

function DeckViewerUI:draw()
    if not self.isActive then return end
    
    -- Dark overlay background
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    
    local title = self.pileType == "DrawPile" and "DRAW PILE" or "DISCARD PILE"
    local font = love.graphics.getFont()
    
    love.graphics.setColor(0.9, 0.9, 1.0, 1)
    love.graphics.printf(title .. " (" .. #self.cards .. " Cards)", 0, 30, VIRTUAL_WIDTH, "center")
    
    -- Close button
    local cb = self.closeButton
    local mx, my = love.mouse.getPosition()
    local hoverClose = mx >= cb.x and mx <= cb.x + cb.w and my >= cb.y and my <= cb.y + cb.h
    love.graphics.setColor(hoverClose and {1, 0.3, 0.3, 1} or {0.6, 0.2, 0.2, 1})
    love.graphics.rectangle("fill", cb.x, cb.y, cb.w, cb.h, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("X", cb.x, cb.y + 10, cb.w, "center")
    
    -- Draw grid of cards
    local cols = 6
    local cardW = 100
    local cardH = 140
    local spacingX = 20
    local spacingY = 20
    local startX = (VIRTUAL_WIDTH - (cols * cardW + (cols - 1) * spacingX)) / 2
    local startY = 100
    
    for i, card in ipairs(self.cards) do
        local col = ((i - 1) % cols)
        local row = math.floor((i - 1) / cols)
        
        local cx = startX + col * (cardW + spacingX)
        local cy = startY + row * (cardH + spacingY) - self.scrollOffset
        
        -- Draw Card Background
        local rcolors = {
            common = {0.5, 0.5, 0.5}, uncommon = {0.2, 0.8, 0.2},
            rare = {0.2, 0.5, 1.0}, epic = {0.7, 0.3, 0.9}, legendary = {1.0, 0.7, 0.1}
        }
        local rarity = card.payload and card.payload.rarity or card.rarity or "common"
        local rCol = rcolors[rarity:lower()] or rcolors.common
        
        love.graphics.setColor(rCol[1]*0.2, rCol[2]*0.2, rCol[3]*0.2, 0.95)
        love.graphics.rectangle("fill", cx, cy, cardW, cardH, 5)
        
        -- Border
        love.graphics.setColor(rCol[1]*0.8, rCol[2]*0.8, rCol[3]*0.8, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", cx, cy, cardW, cardH, 5)
        love.graphics.setLineWidth(1)
        
        -- Text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(card.name, cx + 5, cy + 10, cardW - 10, "center")
        
        -- Type
        local typeStr = "Place"
        if card.executionType == ExecutionType.Global or card.executionType == "Global" then typeStr = "Global"
        elseif card.executionType == ExecutionType.Targeted or card.executionType == "Targeted" then typeStr = "Target" end
        
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.printf(typeStr, cx + 5, cy + 40, cardW - 10, "center")
        
        -- Cost
        local cost = card.getCost and card:getCost() or card.cost or 0
        love.graphics.setColor(0.9, 0.9, 0.2, 1)
        love.graphics.printf(cost .. " Tk", cx, cy + cardH - 20, cardW, "center")
    end
end

function DeckViewerUI:mousepressed(x, y, button)
    if not self.isActive then return false end
    
    if button == 1 then
        local cb = self.closeButton
        if x >= cb.x and x <= cb.x + cb.w and y >= cb.y and y <= cb.y + cb.h then
            self:close()
        end
    end
    
    return true -- Block all clicks when active
end

return DeckViewerUI
