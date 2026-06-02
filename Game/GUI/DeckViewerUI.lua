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
    self.deckPage = 1
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
    
    local mx, my = love.mouse.getPosition()
    
    local title = self.pileType == "DrawPile" and "DRAW PILE" or "DISCARD PILE"
    local font = love.graphics.getFont()
    
    love.graphics.setColor(0.9, 0.9, 1.0, 1)
    love.graphics.printf(title .. " (" .. #self.cards .. " Cards)", 0, 30, VIRTUAL_WIDTH, "center")
    

    
    -- Draw grid of cards
    local cols = 4
    local cardW = 200
    local cardH = 280
    local spacingX = 40
    local spacingY = 20
    local startX = (VIRTUAL_WIDTH - (cols * cardW + (cols - 1) * spacingX)) / 2
    local startY = 80
    
    local maxPerPage = 8
    local totalPages = math.max(1, math.ceil(#self.cards / maxPerPage))
    self.deckPage = self.deckPage or 1
    if self.deckPage > totalPages then self.deckPage = totalPages end
    if self.deckPage < 1 then self.deckPage = 1 end
    
    local startIndex = (self.deckPage - 1) * maxPerPage + 1
    local endIndex = math.min(self.deckPage * maxPerPage, #self.cards)
    
    for i = startIndex, endIndex do
        local displayIndex = i - startIndex
        local card = self.cards[i]
        local col = (displayIndex % cols)
        local row = math.floor(displayIndex / cols)
        
        local cx = startX + col * (cardW + spacingX)
        local cy = startY + row * (cardH + spacingY)
        
        if card.getCardDraw and card:getCardDraw() then
            local isHovered = mx >= cx and mx <= cx + cardW and my >= cy and my <= cy + cardH
            card:getCardDraw():draw(cx, cy, cardW, cardH, isHovered)
        end
    end
    
    self.prevPageBtn = { x = 120, y = VIRTUAL_HEIGHT - 90, w = 120, h = 40, label = "Prev Page" }
    self.nextPageBtn = { x = VIRTUAL_WIDTH - 240, y = VIRTUAL_HEIGHT - 90, w = 120, h = 40, label = "Next Page" }
    
    if self.deckPage > 1 then
        local isHovered = mx >= self.prevPageBtn.x and mx <= self.prevPageBtn.x + self.prevPageBtn.w and my >= self.prevPageBtn.y and my <= self.prevPageBtn.y + self.prevPageBtn.h
        love.graphics.setColor(isHovered and {0.4, 0.6, 0.9, 1} or {0.3, 0.5, 0.8, 1})
        love.graphics.rectangle("fill", self.prevPageBtn.x, self.prevPageBtn.y, self.prevPageBtn.w, self.prevPageBtn.h, 5)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(self.prevPageBtn.label, self.prevPageBtn.x, self.prevPageBtn.y + 12, self.prevPageBtn.w, "center")
    end
    
    if self.deckPage < totalPages then
        local isHovered = mx >= self.nextPageBtn.x and mx <= self.nextPageBtn.x + self.nextPageBtn.w and my >= self.nextPageBtn.y and my <= self.nextPageBtn.y + self.nextPageBtn.h
        love.graphics.setColor(isHovered and {0.4, 0.6, 0.9, 1} or {0.3, 0.5, 0.8, 1})
        love.graphics.rectangle("fill", self.nextPageBtn.x, self.nextPageBtn.y, self.nextPageBtn.w, self.nextPageBtn.h, 5)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(self.nextPageBtn.label, self.nextPageBtn.x, self.nextPageBtn.y + 12, self.nextPageBtn.w, "center")
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Page " .. self.deckPage .. " / " .. totalPages, 0, VIRTUAL_HEIGHT - 75, VIRTUAL_WIDTH, "center")
    
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.printf("Click anywhere else to close", 0, VIRTUAL_HEIGHT - 45, VIRTUAL_WIDTH, "center")
end

function DeckViewerUI:mousepressed(x, y, button)
    if not self.isActive then return false end
    
    if button == 1 then
        if self.deckPage and self.deckPage > 1 and self.prevPageBtn then
            local btn = self.prevPageBtn
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                self.deckPage = self.deckPage - 1
                return true
            end
        end
        
        if self.deckPage and self.nextPageBtn then
            local totalPages = math.max(1, math.ceil(#self.cards / 8))
            if self.deckPage < totalPages then
                local btn = self.nextPageBtn
                if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                    self.deckPage = self.deckPage + 1
                    return true
                end
            end
        end
        
        -- Click anywhere else closes the viewer
        self:close()
    end
    
    return true -- Block all clicks when active
end

return DeckViewerUI
