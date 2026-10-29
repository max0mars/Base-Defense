local StandardMainTurret = require("Buildings.MainTurrets.StandardMainTurret")
local Utils = require("Classes.Utils")
local PlayerDeck = require("Game.Cards.PlayerDeck")
local Card = require("Game.Cards.Card")
local ExecutionType = require("Game.Cards.ExecutionType")
local InstantCard = require("Instants.Instant")
local Layout = require("Game.GUI.Layout")

local FastMainTurret = setmetatable({}, { __index = StandardMainTurret })
FastMainTurret.__index = FastMainTurret

FastMainTurret.template = {
    id = "fast_main",
    name = "Machine Gun",
    cardRarity = "main_weapon",
    size = 20,
    rotation = 0,

    fireRate = 6, -- fast fire rate
    range = 450,
    barrel = 27, -- pivot to muzzle (bullets leave from the muzzle brake)
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
    damageType = "physical",
    --bulletShape = "circle",
    hitEffects = {},
    sfx = "gunshot_01"
}

-- Sprite: a decagon base under a rotating head, with a machine gun barrel
-- (vented cooling shroud, thin barrel, muzzle brake) that kicks back on each
-- shot behind a short muzzle flash.
FastMainTurret.FLASH_TIME = 0.06 -- seconds a muzzle flash lasts
FastMainTurret.RECOIL = 2.5 -- px the barrel kicks back
FastMainTurret.RECOIL_TIME = 0.08 -- seconds it takes to return

function FastMainTurret:new(config)
    local baseConfig = Utils.deepCopy(FastMainTurret.template)
    if config then
        for k, v in pairs(config) do baseConfig[k] = v end
    end
    
    local t = StandardMainTurret:new(baseConfig)
    setmetatable(t, { __index = self })
    
    return t
end

function FastMainTurret:applyUpgrade(reward)
    if not reward or not reward.id then return end
    self.upgrades[reward.id] = true

    -- Counterpart to the Heavy Laser's Low Power Ops
    if reward.id == "heavy_rounds" and self.effectManager then
        self.effectManager:applyEffect({
            name = "Heavy Rounds",
            statModifiers = { damage = { mult = 0.5 }, fireRate = { mult = -0.2 } }
        })
    end
    print("Main Turret Upgrade Applied: " .. reward.name)
end

function FastMainTurret:update(dt)
    StandardMainTurret.update(self, dt)
    if self.flashTime then
        self.flashTime = self.flashTime + dt
        if self.flashTime >= FastMainTurret.FLASH_TIME then self.flashTime = nil end
    end
    if self.recoilTime then
        self.recoilTime = self.recoilTime + dt
        if self.recoilTime >= FastMainTurret.RECOIL_TIME then self.recoilTime = nil end
    end
end

local function decagon(cx, cy, radius)
    local pts = {}
    for i = 0, 9 do
        local a = i * math.pi / 5 + math.pi / 10
        table.insert(pts, cx + math.cos(a) * radius)
        table.insert(pts, cy + math.sin(a) * radius)
    end
    return pts
end

--- Draws `shape(mode)` as a part: a dim fill, an optional soft glow, then the
--- outline. The small head and barrel parts skip the glow so the bloom pass
--- doesn't wash their details out.
local function part(color, fillAlpha, width, shape, glow)
    local r, g, b = color[1], color[2], color[3]
    if fillAlpha > 0 then
        love.graphics.setColor(r, g, b, fillAlpha)
        shape("fill")
    end
    if glow then
        love.graphics.setColor(r, g, b, 0.3)
        love.graphics.setLineWidth(width * 2.2)
        shape("line")
    end
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(width)
    shape("line")
end

function FastMainTurret:draw()
    local cx, cy = self:getCenterPosition()
    local color = self.color or { 0.6, 0.6, 0.6, 1 }
    -- Steel tones, dark enough that the bloom pass leaves their details readable
    local headColor = { 0.45, 0.5, 0.56 }
    local barrelColor = { 0.36, 0.4, 0.46 } -- darker than the base, so it stands out over it

    -- Base: a decagon with an inner ring and bolts
    local radius = self.size * 1.05
    local outer = decagon(cx, cy, radius)
    part(color, 0.1, 2, function(mode) love.graphics.polygon(mode, outer) end, true)
    local inner = decagon(cx, cy, radius * 0.7)
    love.graphics.setColor(color[1], color[2], color[3], 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line", inner)
    for i = 0, 9, 2 do
        local a = i * math.pi / 5 + math.pi / 10
        love.graphics.circle("fill", cx + math.cos(a) * radius * 0.85, cy + math.sin(a) * radius * 0.85, 1.1)
    end

    local mx, my = Layout.mouseToField()
    local angle = math.atan2(my - cy, mx - cx)
    local kick = self.recoilTime and -FastMainTurret.RECOIL * (1 - self.recoilTime / FastMainTurret.RECOIL_TIME) or 0
    local muzzle = self.barrel

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(angle)

    -- Barrel (under the head): vented shroud, barrel, muzzle brake
    love.graphics.push()
    love.graphics.translate(kick, 0)
    -- Each piece is backed with an opaque dark fill so the base's lines don't show through
    local function barrelPiece(width, shape)
        love.graphics.setColor(0.04, 0.05, 0.06, 1)
        shape("fill")
        part(barrelColor, 0.25, width, shape)
    end
    barrelPiece(1.5, function(mode) love.graphics.rectangle(mode, 5, -3.5, 12, 7, 1, 1) end)
    love.graphics.setColor(barrelColor[1], barrelColor[2], barrelColor[3], 0.9)
    love.graphics.setLineWidth(1)
    for _, vx in ipairs({ 8, 11, 14 }) do
        love.graphics.rectangle("line", vx - 0.8, -1.4, 1.6, 2.8)
    end
    barrelPiece(1.3, function(mode) love.graphics.rectangle(mode, 17, -1.4, muzzle - 20, 2.8) end)
    barrelPiece(1.5, function(mode) love.graphics.rectangle(mode, muzzle - 3, -2.6, 3, 5.2, 0.6, 0.6) end)
    if self.flashTime then self:drawMuzzleFlash(muzzle) end
    love.graphics.pop()

    -- Head: receiver with an ammo box on its side, a feed cover and a pivot
    part(headColor, 0.14, 1.5, function(mode) love.graphics.rectangle(mode, -6, 6, 8, 4.5, 1, 1) end)
    love.graphics.setColor(0.04, 0.05, 0.06, 1) -- opaque, so the barrel's end doesn't show through
    love.graphics.rectangle("fill", -9, -7, 16, 14, 3, 3)
    part(headColor, 0.2, 2, function(mode) love.graphics.rectangle(mode, -9, -7, 16, 14, 3, 3) end)
    love.graphics.setColor(headColor[1], headColor[2], headColor[3], 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.line(-5, -7, -5, 7)
    love.graphics.line(-5, -3, 7, -3)
    love.graphics.setColor(headColor[1], headColor[2], headColor[3], 1)
    love.graphics.circle("line", -1, 2, 2.2)

    love.graphics.pop()
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

--- A star of flame at the muzzle (local, rotated coordinates): an outer flare
--- in the bullet colour around a white-hot core, fading over FLASH_TIME.
function FastMainTurret:drawMuzzleFlash(x)
    local fade = 1 - self.flashTime / FastMainTurret.FLASH_TIME
    local s = (self.flashScale or 1) * (0.7 + 0.3 * fade)
    local flip = self.flashFlip or 1
    local c = self:getStat("bulletColor") or { 1, 0.8, 0.2 }
    -- Triangles (fills must be convex): a long forward spike and two side
    -- spikes, the longer one on a random side
    local up, down = flip > 0 and 5 or 3.5, flip > 0 and 3.5 or 5
    local function flame(k)
        love.graphics.polygon("fill", x, -2.5 * k, x + 11 * k, 0, x, 2.5 * k)
        love.graphics.polygon("fill", x, -1.5 * k, x + 4 * k, -up * k, x + 5 * k, -0.5 * k)
        love.graphics.polygon("fill", x, 1.5 * k, x + 4 * k, down * k, x + 5 * k, 0.5 * k)
    end
    love.graphics.setColor(c[1], c[2], c[3], 0.18 * fade)
    love.graphics.circle("fill", x + 3 * s, 0, 6 * s)
    love.graphics.setColor(c[1], c[2], c[3], 0.9 * fade)
    flame(s)
    love.graphics.setColor(1, 0.97, 0.85, fade)
    flame(s * 0.55)
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
    local mx, my = Layout.mouseToField()
    local angle = math.atan2(my - cy, mx - cx)
    return cx + math.cos(angle) * self.barrel, cy + math.sin(angle) * self.barrel
end

function FastMainTurret:fire(args)
    if AUDIO and self:getStat("sfx") then 
        AUDIO:playSFX(self:getStat("sfx")) 
    end
    -- Each shot gets its own flash (size and which way the side flames lean)
    self.flashTime = 0
    self.flashScale = 0.85 + math.random() * 0.35
    self.flashFlip = math.random() < 0.5 and -1 or 1
    self.recoilTime = 0
    StandardMainTurret.fire(self, args)
end

function FastMainTurret.getStartingDeck()
    local deck = PlayerDeck:new()
    StandardMainTurret.addCard(deck, "autoCannon", 2)
    StandardMainTurret.addCard(deck, "heavygun", 2)
    StandardMainTurret.addCard(deck, "grenadier", 1)
    StandardMainTurret.addCard(deck, "inst_overclock_1", 2)
    StandardMainTurret.addCard(deck, "inst_range_1", 2)
    StandardMainTurret.addCard(deck, "inst_frenzy_1", 1)
    StandardMainTurret.addCard(deck, "spell_stunburst", 1)
    StandardMainTurret.addCard(deck, "spell_acidcloud", 1)
    
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
        rare = {
            {
                id = "heavy_rounds",
                name = "Heavy Rounds",
                description = "Your machine gun shoots slower but hits much harder.",
                type = "main_upgrade",
                iconCategory = "upgrade",
                cost = 2,
                isEligible = function(game)
                    local mt = game.base and game.base.mainLazer
                    return mt and mt.id == "fast_main" and not mt.upgrades["heavy_rounds"]
                end
            }
        },
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
