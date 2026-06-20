local StandardMainTurret = require("Buildings.MainTurrets.StandardMainTurret")
local Utils = require("Classes.Utils")
local PlayerDeck = require("Game.Cards.PlayerDeck")
local Card = require("Game.Cards.Card")
local ExecutionType = require("Game.Cards.ExecutionType")
local InstantCard = require("Instants.instant")

local FastMainTurret = setmetatable({}, { __index = StandardMainTurret })
FastMainTurret.__index = FastMainTurret

FastMainTurret.template = {
    id = "fast_main",
    name = "Machine Gun",
    cardRarity = "main_weapon",
    size = 20,
    rotation = 0,

    fireRate = 8, -- fast fire rate
    range = 450,
    barrel = 20,
    color = {0.6, 0.6, 0.6, 1},
    types = { turret = true},
    shapePattern = {
        {0, 0}, {1, 0},
        {0, 1}, {1, 1}
    },
    firingArc = { direction = 0, minRange = 0, angle = math.pi },
    
    -- Normal bullet properties
    bulletName = "Standard Bullet",
    bulletColor = {1, 0.8, 0.2},
    bulletSpeed = 700,
    damage = 4,
    pierce = 1,
    spread = math.rad(5),
    lifespan = 1.5,
    --displayLifespan = 0.5,
    bulletW = 3, 
    bulletH = 3,
    damageType = "normal",
    --bulletShape = "circle",
    hitEffects = {},
    sfx = "gunshot_01"
}

function FastMainTurret:new(config)
    local baseConfig = Utils.deepCopy(FastMainTurret.template)
    if config then
        for k, v in pairs(config) do baseConfig[k] = v end
    end
    
    local t = StandardMainTurret:new(baseConfig)
    setmetatable(t, { __index = self })
    
    return t
end

function FastMainTurret:draw()
    local cx, cy = self:getCenterPosition()
    local r, g, b = unpack(self.color or {0.6, 0.6, 0.6, 1})
    
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", cx - self.size, cy - self.size, self.size*2, self.size*2)
    
    local mx, my = require("Game.GUI.Layout").mouseToField()
    local angle = math.atan2(my - cy, mx - cx)
    
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(angle)
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.rectangle("fill", 0, -self.size/6, self.barrel, self.size/3)
    love.graphics.pop()
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function FastMainTurret:drawFiringArc(alpha)
    local cx, cy = self:getCenterPosition()
    local range = self:getStat("range")
    love.graphics.setColor(1, 1, 1, alpha or 0.2)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", cx, cy, range)
    love.graphics.setColor(1, 1, 1, (alpha or 0.2) * 0.3)
    love.graphics.circle("fill", cx, cy, range)
    love.graphics.setColor(1, 1, 1, 1)
end

function FastMainTurret:getFirePoint()
    local cx, cy = self:getCenterPosition()
    local mx, my = require("Game.GUI.Layout").mouseToField()
    local angle = math.atan2(my - cy, mx - cx)
    return cx + math.cos(angle) * self.barrel, cy + math.sin(angle) * self.barrel
end

function FastMainTurret:fire(args)
    if AUDIO and self:getStat("sfx") then 
        AUDIO:playSFX(self:getStat("sfx")) 
    end
    StandardMainTurret.fire(self, args)
end

function FastMainTurret.getStartingDeck()
    local deck = PlayerDeck:new()
    StandardMainTurret.addCard(deck, "autoCannon", 2)
    StandardMainTurret.addCard(deck, "heavygun", 2)
    StandardMainTurret.addCard(deck, "inst_overclock_1", 2)
    StandardMainTurret.addCard(deck, "inst_range_1", 2)
    StandardMainTurret.addCard(deck, "inst_frenzy_1", 1)
    
    deck:addCard(InstantCard.new({
        id = "stabilizing_shots",
        name = "Stabilizing Shots",
        description = "Reduces the Machine Gun's spread.",
        cost = 1,
        rarity = "uncommon",
        isConsume = true,
        executionType = InstantCard.ExecutionType.Targeted,
        statModifiers = { spread = { mult = -0.60 } },
        requiredType = "mainturret"
    }))
    
    return deck
end

function FastMainTurret.getUniqueCards()
    return {
        uncommon = {
            -- {
            --     id = "stabilizing_shots",
            --     name = "Stabilizing Shots",
            --     description = "Reduces the Machine Gun's spread by 50%.",
            --     type = "effect",
            --     iconCategory = "upgrade",
            --     cost = 1,
            --     payload = {
            --         requiredType = "mainturret",
            --         effect = {
            --             name = "Stabilizing Shots",
            --             statModifiers = { spread = { mult = -0.80 } }
            --         }
            --     },
            --     isEligible = function(game)
            --         return true
            --     end
            -- }
        }
    }
end

return FastMainTurret
