local StandardMainTurret = require("Buildings.MainTurrets.StandardMainTurret")
local Layout = require("Game.GUI.Layout")
local HitscanBullet = require("Bullets.HitscanBullet")
local BurnEffect = require("Game.Effects.StatusEffects.Burn")
local Chill = require("Game.Effects.StatusEffects.Chill")
local Utils = require("Classes.Utils")
local PlayerDeck = require("Game.Cards.PlayerDeck")
local Card = require("Game.Cards.Card")
local ExecutionType = require("Game.Cards.ExecutionType")
local InstantCard = require("Instants.Instant")

local MainLazer = setmetatable({}, { __index = StandardMainTurret })
MainLazer.__index = MainLazer

MainLazer.template = {
    id = "standard_main",
    name = "Heavy Laser",
    cardRarity = "main_weapon",
    size = 20,
    rotation = 0,

    fireRate = 0.5,
    range = 500,
    barrel = 26, -- pivot to emitter (the beam starts at the emitter crystal)
    color = {0.3, 0.3, 0.3, 1},
    types = { turret = true },
    shapePattern = {
        {0, 0}, {1, 0},
        {0, 1}, {1, 1}
    },
    firingArc = { direction = 0, minRange = 0, angle = math.pi },
    bulletName = "Heavy Laser",
    bulletColor = {0.3, 0.85, 1}, -- the charged coils' colour (MainLazer.CHARGE_COLOR)
    bulletSpeed = 400,
    damage = 60,
    pierce = 1,
    lifespan = 1,
    displayLifespan = 0.5,
    bulletW = 4, 
    bulletH = 4,
    damageType = "energy",
    bulletShape = "ray",
    hitEffects = {}
}

function MainLazer:new(config)
    local baseConfig = Utils.deepCopy(MainLazer.template)
    if config then
        for k, v in pairs(config) do baseConfig[k] = v end
    end
    baseConfig.bulletType = HitscanBullet
    
    local t = StandardMainTurret:new(baseConfig)
    setmetatable(t, { __index = self })
    
    t.electricFieldCooldown = 0
    t.zapBurstCount = 0
    t.zapDelayTimer = 0.3
    
    return t
end

function MainLazer:applyUpgrade(reward)
    if not reward or not reward.id then return end
    self.upgrades[reward.id] = true
    
    if reward.id == "low_power_operating" then
        if self.effectManager then
            self.effectManager:applyEffect({
                name = "Low Power Operating",
                isUpgrade = true,
                statModifiers = { damage = { mult = -0.2 }, fireRate = { mult = 0.5 } }
            })
        end
    elseif reward.id == "electric_field" then
        if self.effectManager then
            self.effectManager:applyEffect({ name = "Electric Field", isUpgrade = true })
        end
    end
    print("Main Turret Upgrade Applied: " .. reward.name)
end

function MainLazer:update(dt)
    StandardMainTurret.update(self, dt)
    if self.flashTime then
        self.flashTime = self.flashTime + dt
        if self.flashTime >= MainLazer.FLASH_TIME then self.flashTime = nil end
    end
    if self.recoilTime then
        self.recoilTime = self.recoilTime + dt
        if self.recoilTime >= MainLazer.RECOIL_TIME then self.recoilTime = nil end
    end
    if self.upgrades["electric_field"] then
        self:updateElectricField(dt)
    end
end

function MainLazer:updateElectricField(dt)
    if not self.upgrades["electric_field"] then return end
    if self.electricFieldCooldown > 0 then
        self.electricFieldCooldown = self.electricFieldCooldown - dt
        return
    end
    if not self.game:isState("wave") then return end

    local cx, cy = self:getCenterPosition()
    local zapRange = self:getStat("range")
    local r2 = zapRange * zapRange
    
    local potentialTargets = {}
    for _, obj in ipairs(self.game.objects) do
        if obj:isType("enemy") and not obj.destroyed then
            local dx, dy = obj.x - cx, obj.y - cy
            if dx*dx + dy*dy <= r2 then
                table.insert(potentialTargets, obj)
            end
        end
    end

    if #potentialTargets > 0 then
        if self.zapBurstCount == 0 then
            self.zapDelayTimer = self.zapDelayTimer - dt
        else
            self.zapDelayTimer = 0
        end
        
        if self.zapDelayTimer <= 0 then
            local target = potentialTargets[love.math.random(1, #potentialTargets)]
            if AUDIO then AUDIO:playSFX("lightning_01") end
            self:applyHitEffects(target)
            local damage = self:getStat("damage") * Chill.getDamageMultiplier(target, self:getDamageVsChill())
            target:takeDamage(damage, "energy", target.x, target.y, nil, self)
            if self.game.spawnLightningBolt then self.game:spawnLightningBolt(target.x, target.y) end
            if self.game.spawnParticleExplosion then
                local c = MainLazer.CHARGE_COLOR
                self.game:spawnParticleExplosion({ c[1], c[2], c[3], 1 }, 5, target.x, target.y)
            end
            
            self.zapBurstCount = self.zapBurstCount + 1
            if self.zapBurstCount < 3 then
                self.electricFieldCooldown = 0.1 
            else
                self.zapBurstCount = 0
                self.electricFieldCooldown = 1 / self:getStat("fireRate")
                self.zapDelayTimer = 0.3
            end
        end
    else
        self.zapBurstCount = 0
        self.zapDelayTimer = 0.3
    end
end

function MainLazer:PlayerClick(tX, tY)
    if self.upgrades["electric_field"] then return false end
    return StandardMainTurret.PlayerClick(self, tX, tY)
end

function MainLazer:fire(args)
     args = args or {}
     if not args.angle then
         local fX, fY = self:getFirePoint()
         args.angle = math.atan2(args.targetY - fY, args.targetX - fX)
     end
     args.displayLifespan = args.displayLifespan or self:getStat("displayLifespan")
     args.color = args.color or self:getStat("bulletColor")
     if AUDIO then AUDIO:playSFX("laser_01") end
     self.flashTime, self.recoilTime = 0, 0
     StandardMainTurret.fire(self, args)
end

function MainLazer:getFirePoint()
    local cx, cy = self:getCenterPosition()
    local mx, my = Layout.mouseToField()
    local angle = math.atan2(my - cy, mx - cx)
    return cx + math.cos(angle) * self.barrel, cy + math.sin(angle) * self.barrel
end

-- Sprite: a hexagonal base with charge lights, a sleek rotating head with a
-- glowing core, and twin emitter rails wrapped in three energy coils that light
-- up one after another as it recharges. The beam is the charged coils' colour.
-- Firing flares the emitter and kicks the head back; the coils then go dark.
MainLazer.CHARGE_COLOR = { 0.3, 0.85, 1 }
MainLazer.HULL_COLOR = { 0.34, 0.39, 0.47 }
MainLazer.FLASH_TIME = 0.14 -- seconds the emitter flares after a shot
MainLazer.RECOIL = 2
MainLazer.RECOIL_TIME = 0.12
local COIL_X = { 10.5, 15.5, 20.5 } -- along the rails (local, rotated coordinates)

--- How far the next shot has charged, 0 to 1.
function MainLazer:getCharge()
    local fireRate = self:getStat("fireRate")
    if fireRate <= 0 then return 0 end
    return math.max(0, math.min(1, 1 - self.cooldown * fireRate))
end

local function hexagon(cx, cy, radius, turn)
    local pts = {}
    for i = 0, 5 do
        local a = i * math.pi / 3 + (turn or 0)
        table.insert(pts, cx + math.cos(a) * radius)
        table.insert(pts, cy + math.sin(a) * radius)
    end
    return pts
end

--- Colour between the hull and the charge colour, `t` of the way.
local function chargeTint(t)
    local h, c = MainLazer.HULL_COLOR, MainLazer.CHARGE_COLOR
    return h[1] + (c[1] - h[1]) * t, h[2] + (c[2] - h[2]) * t, h[3] + (c[3] - h[3]) * t
end

--- Opaque dark backing, a faint tint, then the outline.
local function plate(r, g, b, width, shape)
    love.graphics.setColor(0.03, 0.04, 0.06, 1)
    shape("fill")
    love.graphics.setColor(r, g, b, 0.18)
    shape("fill")
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(width)
    shape("line")
end

function MainLazer:draw()
    local cx, cy = self:getCenterPosition()
    local hull, glow = MainLazer.HULL_COLOR, MainLazer.CHARGE_COLOR
    local charge = self:getCharge()
    local field = self.upgrades["electric_field"]

    if self.showArc and field then
        self:drawFiringArc(0.3)
    end

    -- Base: an outer hexagon (with a soft glow), an inner one turned against it,
    -- and six lights that come on as it charges
    local radius = self.size * 1.08
    local outer = hexagon(cx, cy, radius, math.pi / 6)
    love.graphics.setColor(hull[1], hull[2], hull[3], 0.12)
    love.graphics.polygon("fill", outer)
    love.graphics.setColor(hull[1], hull[2], hull[3], 0.35)
    love.graphics.setLineWidth(4.5)
    love.graphics.polygon("line", outer)
    love.graphics.setColor(hull[1], hull[2], hull[3], 1)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", outer)
    love.graphics.setColor(hull[1], hull[2], hull[3], 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line", hexagon(cx, cy, radius * 0.72, 0))
    for i = 0, 5 do
        local a = i * math.pi / 3 + math.pi / 6
        local lit = math.max(0, math.min(1, charge * 6 - i))
        love.graphics.setColor(chargeTint(lit))
        love.graphics.circle("fill", cx + math.cos(a) * radius * 0.86, cy + math.sin(a) * radius * 0.86, 1.3)
    end

    local mx, my = Layout.mouseToField()
    local angle = math.atan2(my - cy, mx - cx)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(angle)

    if field then
        -- Electric Field: no emitter; three rings charge around the core instead
        for i = 1, 3 do
            local lit = math.max(0, math.min(1, charge * 3 - (i - 1)))
            local r, g, b = chargeTint(lit)
            love.graphics.setColor(r, g, b, 0.35 + 0.55 * lit)
            love.graphics.setLineWidth(1 + lit)
            love.graphics.circle("line", 0, 0, 7 + i * 5)
            if lit >= 1 then
                love.graphics.setColor(glow[1], glow[2], glow[3], 0.12)
                love.graphics.circle("fill", 0, 0, 7 + i * 5)
            end
        end
        local pulse = (math.sin(love.timer.getTime() * 10) + 1) / 2
        love.graphics.setColor(glow[1], glow[2], glow[3], 0.5 + 0.5 * pulse * charge)
        love.graphics.circle("fill", 0, 0, 4 + 2 * pulse)
    else
        local kick = self.recoilTime and -MainLazer.RECOIL * (1 - self.recoilTime / MainLazer.RECOIL_TIME) or 0
        love.graphics.translate(kick, 0)
        local tip = self.barrel

        -- Twin rails out to the emitter
        for _, ry in ipairs({ -4, 4 }) do
            plate(hull[1], hull[2], hull[3], 1.2, function(mode)
                love.graphics.polygon(mode, 4, ry - 1.4, tip - 2, ry - 0.8, tip - 2, ry + 0.8, 4, ry + 1.4)
            end)
        end
        -- Energy running down the gap between the rails, further as it charges
        love.graphics.setColor(glow[1], glow[2], glow[3], 0.15 + 0.6 * charge)
        love.graphics.setLineWidth(1)
        love.graphics.line(6, 0, 6 + (tip - 8) * charge, 0)

        -- Coils: rings around the rails, lit in turn as the charge builds
        for i, x in ipairs(COIL_X) do
            local lit = math.max(0, math.min(1, charge * 3 - (i - 1)))
            local r, g, b = chargeTint(lit)
            -- (no extra glow pass: the bloom adds it, and wider lines run the coils together)
            love.graphics.setColor(r, g, b, 0.75 + 0.25 * lit)
            love.graphics.setLineWidth(1.1 + 0.3 * lit)
            love.graphics.ellipse("line", x, 0, 1.2, 5.8)
        end

        -- Emitter: a crystal at the tip that lights once fully charged
        local ready = charge >= 1
        local er, eg, eb = chargeTint(ready and 1 or charge * 0.5)
        local crystal = { tip - 3, 0, tip, -2.6, tip + 2.5, 0, tip, 2.6 }
        love.graphics.setColor(0.03, 0.04, 0.06, 1)
        love.graphics.polygon("fill", crystal)
        love.graphics.setColor(er, eg, eb, ready and 0.8 or 0.3)
        love.graphics.polygon("fill", crystal)
        love.graphics.setColor(er, eg, eb, 1)
        love.graphics.setLineWidth(1.2)
        love.graphics.polygon("line", crystal)
        if ready then
            local pulse = (math.sin(love.timer.getTime() * 8) + 1) / 2
            love.graphics.setColor(1, 1, 1, 0.6 + 0.4 * pulse)
            love.graphics.circle("fill", tip, 0, 0.9 + 0.4 * pulse)
        end
        if self.flashTime then
            local fade = 1 - self.flashTime / MainLazer.FLASH_TIME
            love.graphics.setColor(glow[1], glow[2], glow[3], 0.5 * fade)
            love.graphics.circle("fill", tip + 1, 0, 3 + 6 * (1 - fade))
            love.graphics.setColor(1, 1, 1, fade)
            love.graphics.circle("fill", tip + 1, 0, 2.2 * fade + 0.6)
        end

        -- Head: a tapered housing over the rails' roots, with vent lines and a
        -- core window that glows with the charge
        plate(hull[1], hull[2], hull[3], 2, function(mode)
            love.graphics.polygon(mode, -9, -5, -6, -8, 4, -8, 8, -4, 8, 4, 4, 8, -6, 8, -9, 5)
        end)
        love.graphics.setColor(hull[1], hull[2], hull[3], 0.7)
        love.graphics.setLineWidth(1)
        love.graphics.line(-6, -5.5, 3, -5.5)
        love.graphics.line(-6, 5.5, 3, 5.5)
        local r, g, b = chargeTint(0.35 + 0.65 * charge)
        love.graphics.setColor(r, g, b, 0.25 + 0.5 * charge)
        love.graphics.circle("fill", -1, 0, 3.2)
        love.graphics.setColor(r, g, b, 1)
        love.graphics.setLineWidth(1.2)
        love.graphics.circle("line", -1, 0, 3.2)
    end

    love.graphics.pop()
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function MainLazer:drawFiringArc(a1, a2, a3)
    local alpha = (type(a1) == "number" and a1 <= 1 and a1) or a3 or 0.2
    local cx, cy = self:getCenterPosition()
    local range = self:getStat("range")
    if self.upgrades["electric_field"] then
        love.graphics.setColor(0.4, 0.7, 1, alpha)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", cx, cy, range)
        love.graphics.setColor(0.4, 0.7, 1, alpha * 0.15)
        love.graphics.circle("fill", cx, cy, range)
    else
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", cx, cy, range)
        love.graphics.setColor(1, 1, 1, alpha * 0.3)
        love.graphics.circle("fill", cx, cy, range)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function MainLazer.getStartingDeck()
    local deck = PlayerDeck:new()
    
    StandardMainTurret.addCard(deck, "sentry", 2, "common")
    StandardMainTurret.addCard(deck, "blaster", 2, "common")
    StandardMainTurret.addCard(deck, "fluxCannon", 1)
    
    StandardMainTurret.addCard(deck, "inst_overclock_1", 2)
    StandardMainTurret.addCard(deck, "inst_range_1", 2)
    StandardMainTurret.addCard(deck, "inst_frenzy_1", 1)
    StandardMainTurret.addCard(deck, "spell_fireball", 1)
    StandardMainTurret.addCard(deck, "spell_zap", 1)

    
    local energySurge = InstantCard.new({
        id = "inst_energy_surge_1",
        name = "Energy Surge",
        description = "All energy turrets gain +20% damage.",
        cost = 2,
        rarity = "rare",
        executionType = InstantCard.ExecutionType.Group,
        statModifiers = { damage = { mult = 0.20 } },
        targetTypes = { energy = true }
    })
    energySurge.quantity = 1
    deck:addCard(energySurge)

    deck:addCard(Card:new({
        id = "industrialBattery",
        name = "Industrial Battery",
        description = "Increases all Energy damage by 20% when adjacent to the Main Turret.",
        executionType = ExecutionType.Placement,
        cost = 2,
        quantity = 1,
        payload = {
            buildingClass = require("Buildings.Passives.IndustrialBattery"),
            config = {},
            rarity = "rare",
            iconCategory = "buff",
            affectedSlots = {{-1, 0}, {0, 1}, {0, -1}, {1, 0}}
        }
    }))
    
    return deck
end

function MainLazer.getUniqueCards()
    return {
        rare = {
            {
                id = "low_power_operating",
                name = "Low Power Ops",
                description = "Your big lazer shoots much faster but does a little less damage.",
                type = "main_upgrade",
                iconCategory = "upgrade",
                cost = 2,
                isEligible = function(game)
                    local mt = game.base and game.base.mainLazer
                    return mt and mt.id == "standard_main" and not mt.upgrades["low_power_operating"]
                end
            },
            {
                id = "industrialBattery",
                name = "Industrial Battery",
                description = "Increases all Energy damage by 50% when adjacent to the Main Turret.",
                type = "building",
                building = require("Buildings.Passives.IndustrialBattery"),
                iconCategory = "buff",
                cost = 2,
                affectedSlots = {{-1, 0}, {0, 1}, {0, -1}, {1, 0}}
            }
        },
        legendary = {
            {
                id = "electric_field",
                name = "PROJECT STORMBREAKER",
                description = "zzzZap!",
                type = "main_upgrade",
                iconCategory = "upgrade",
                cost = 3,
                isEligible = function(game)
                    local mt = game.base and game.base.mainLazer
                    return mt and not mt.upgrades["electric_field"]
                end
            }
        }
    }
end

return MainLazer
