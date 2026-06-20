local new_game_scene = {}
new_game_scene.__index = new_game_scene
local scene = require("Scenes.scene")

setmetatable(new_game_scene, { __index = scene })

local SettingsPanel = require("Game.GUI.SettingsPanel")
local CardDraw = require("Game.Cards.CardDraw")
local Cursor = require("Game.GUI.Cursor")
local DeckViewerUI = require("Game.GUI.DeckViewerUI")

function new_game_scene:load()
    self.settings = SettingsPanel:new({
        title = "SETTINGS",
        bottomButtons = {
            { label = "CLOSE", action = "back", color = {0.3, 0.2, 0.22, 1}, hoverColor = {0.5, 0.32, 0.34, 1}, borderColor = {0.9, 0.55, 0.55, 1} },
            { label = "MAIN MENU", action = "exit", color = {0.6, 0.2, 0.2, 1}, hoverColor = {0.8, 0.3, 0.3, 1}, borderColor = {0.9, 0.4, 0.4, 1} }
        }
    })
    self.deckViewer = DeckViewerUI:new(nil)
    self.isSettingsOpen = false

    -- Define available main turrets
    self.turrets = {
        {
            id = "MainLazer",
            name = "Heavy Laser",
            description = "Fires strong laser shots at a slow rates.",
            cost = 0,
            rarity = "main_weapon",
            type = "building",
            iconCategory = "turret",
            damageBars = 4,
            rangeBars = 5,
            firerateBars = 2
        },
        {
            id = "FastMainTurret",
            name = "Machine Gun",
            description = "Fires rapid bullets at enemies. Not very accurate.",
            cost = 0,
            rarity = "main_weapon",
            type = "building",
            iconCategory = "turret",
            damageBars = 1,
            rangeBars = 4,
            firerateBars = 5
        }
    }
    self.currentIndex = 1

    self:updateCard()

    -- Button Dimensions
    self.btnW = 200
    self.btnH = 50
    self.viewDeckBtnY = VIRTUAL_HEIGHT / 2 + CardDraw.HEIGHT / 2 + 20
    self.startBtnY = self.viewDeckBtnY + self.btnH + 15
end

function new_game_scene:updateCard()
    local turretData = self.turrets[self.currentIndex]
    self.card = CardDraw.new(0, 0, turretData)
end

function new_game_scene:update(dt)
    if self.isSettingsOpen then
        self.settings:update(dt)
        return
    end

    if self.deckViewer.isActive then
        self.deckViewer:update(dt)
        return
    end
end

function new_game_scene:draw()
    if self.isSettingsOpen then
        self.settings:draw()
        return
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Select Your Base", 0, 80, VIRTUAL_WIDTH, "center")

    -- Center Card
    local cx = VIRTUAL_WIDTH / 2
    local cy = VIRTUAL_HEIGHT / 2
    local cardX = cx - CardDraw.WIDTH / 2
    local cardY = cy - CardDraw.HEIGHT / 2

    self.card:draw(cardX, cardY, CardDraw.WIDTH, CardDraw.HEIGHT, false)

    local mx, my = love.mouse.getPosition()
    Cursor.wantHand = false

    -- Draw Arrows
    local arrowSize = 30
    local leftArrowX = cardX - 60
    local rightArrowX = cardX + CardDraw.WIDTH + 60
    local arrowY = cy

    local hoverLeft = math.abs(mx - leftArrowX) < arrowSize and math.abs(my - arrowY) < arrowSize
    local hoverRight = math.abs(mx - rightArrowX) < arrowSize and math.abs(my - arrowY) < arrowSize

    if hoverLeft or hoverRight then Cursor.wantHand = true end

    -- Left Arrow
    love.graphics.setColor(hoverLeft and {0.8, 0.8, 0.8, 1} or {0.5, 0.5, 0.5, 1})
    love.graphics.polygon("fill", leftArrowX + arrowSize/2, arrowY - arrowSize/2, leftArrowX - arrowSize/2, arrowY, leftArrowX + arrowSize/2, arrowY + arrowSize/2)

    -- Right Arrow
    love.graphics.setColor(hoverRight and {0.8, 0.8, 0.8, 1} or {0.5, 0.5, 0.5, 1})
    love.graphics.polygon("fill", rightArrowX - arrowSize/2, arrowY - arrowSize/2, rightArrowX + arrowSize/2, arrowY, rightArrowX - arrowSize/2, arrowY + arrowSize/2)

    -- Draw Buttons
    local function drawButton(label, y)
        local btnX = cx - self.btnW / 2
        local hover = mx >= btnX and mx <= btnX + self.btnW and my >= y and my <= y + self.btnH
        if hover then Cursor.wantHand = true end
        
        love.graphics.setColor(hover and {0.3, 0.3, 0.3, 1} or {0.2, 0.2, 0.2, 1})
        love.graphics.rectangle("fill", btnX, y, self.btnW, self.btnH, 5)
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.rectangle("line", btnX, y, self.btnW, self.btnH, 5)
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(label, btnX, y + self.btnH / 2 - 7, self.btnW, "center")
        
        return hover
    end

    self.hoverViewDeck = drawButton("View Deck", self.viewDeckBtnY)
    self.hoverStart = drawButton("Start Game", self.startBtnY)

    if self.deckViewer.isActive then
        self.deckViewer:draw()
    end

    -- Instead of relying on global OS cursor here directly, it's generally best to use the Cursor component if game_scene/menu_scene do so, but love.mouse.setCursor is common.
    -- Menu_scene sets wantHand in update and calls setCursor. We will do it here.
    love.mouse.setCursor(Cursor.wantHand and love.mouse.getSystemCursor("hand") or love.mouse.getSystemCursor("arrow"))
end

function new_game_scene:mousepressed(x, y, button)
    if self.isSettingsOpen then
        local action = self.settings:mousepressed(x, y, button)
        if action == "back" then self.isSettingsOpen = false end
        if action == "exit" then self.scene_manager.switch("menu") end
        return
    end

    if self.deckViewer.isActive then
        self.deckViewer:mousepressed(x, y, button)
        return
    end

    if button == 1 then
        local cx = VIRTUAL_WIDTH / 2
        local cy = VIRTUAL_HEIGHT / 2
        local cardX = cx - CardDraw.WIDTH / 2
        local arrowSize = 30
        local leftArrowX = cardX - 60
        local rightArrowX = cardX + CardDraw.WIDTH + 60
        
        -- Left Arrow
        if math.abs(x - leftArrowX) < arrowSize and math.abs(y - cy) < arrowSize then
            self.currentIndex = self.currentIndex - 1
            if self.currentIndex < 1 then self.currentIndex = #self.turrets end
            self:updateCard()
        end
        
        -- Right Arrow
        if math.abs(x - rightArrowX) < arrowSize and math.abs(y - cy) < arrowSize then
            self.currentIndex = self.currentIndex + 1
            if self.currentIndex > #self.turrets then self.currentIndex = 1 end
            self:updateCard()
        end

        -- View Deck Button
        if self.hoverViewDeck then
            local turretModule = require("Buildings.MainTurrets." .. self.turrets[self.currentIndex].id)
            if turretModule.getStartingDeck then
                local deck = turretModule.getStartingDeck()
                local unrolledCards = {}
                for _, c in ipairs(deck.cards) do
                    for i = 1, (c.quantity or 1) do
                        table.insert(unrolledCards, c)
                    end
                end
                
                local btnX = cx - self.btnW / 2
                self.deckViewer:open("Starting Deck", unrolledCards, { x = btnX, y = self.viewDeckBtnY, w = self.btnW, h = self.btnH })
            end
        end

        -- Start Game Button
        if self.hoverStart then
            _G.PersistentState.selectedMainTurret = self.turrets[self.currentIndex].id
            
            -- Set up starting deck and inject unique cards
            local turretModule = require("Buildings.MainTurrets." .. _G.PersistentState.selectedMainTurret)
            if turretModule.getStartingDeck then
                _G.PersistentState.deck = turretModule.getStartingDeck()
            end
            if turretModule.getUniqueCards then
                local RewardIndex = require("Game.Rewards.NormalRewardIndex")
                local SpellCardRegistry = require("Spells.SpellCardRegistry")
                local InstantCardRegistry = require("Instants.InstantCardRegistry")
                RewardIndex.injectCards(turretModule.getUniqueCards())
                RewardIndex.injectSpells(SpellCardRegistry)
                RewardIndex.injectInstants(InstantCardRegistry)
            else
                local RewardIndex = require("Game.Rewards.NormalRewardIndex")
                local SpellCardRegistry = require("Spells.SpellCardRegistry")
                local InstantCardRegistry = require("Instants.InstantCardRegistry")
                RewardIndex.injectSpells(SpellCardRegistry)
                RewardIndex.injectInstants(InstantCardRegistry)
            end
            self.scene_manager.switch("game")
        end
    end
end

function new_game_scene:keypressed(key)
    if self.isSettingsOpen then
        if key == "escape" then self.isSettingsOpen = false end
        return
    end

    if key == "escape" then
        self.isSettingsOpen = true
    end
end

return new_game_scene
