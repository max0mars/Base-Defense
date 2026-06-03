local StandardMainTurret = require("Buildings.MainTurrets.StandardMainTurret")
local Layout = require("Game.GUI.Layout")
local HitscanBullet = require("Bullets.HitscanBullet")
local BurnEffect = require("Game.Effects.StatusEffects.Burn")
local Utils = require("Classes.Utils")
local PlayerDeck = require("Game.Cards.PlayerDeck")
local Card = require("Game.Cards.Card")
local ExecutionType = require("Game.Cards.ExecutionType")
local Sentry = require("Buildings.Turrets.Sentry")
local Blaster = require("Buildings.Turrets.Blaster")
local AutoCannon = require("Buildings.Turrets.AutoCannon")
local ShotgunTurret = require("Buildings.Turrets.ShotgunTurret")
local HeavyGun = require("Buildings.Turrets.HeavyGun")
local InstantCardRegistry = require("Instants.InstantCardRegistry")
local InstantCard = require("Instants.instant")

local MainLazer = setmetatable({}, { __index = StandardMainTurret })
MainLazer.__index = MainLazer

MainLazer.template = {
    id = "standard_main",
    name = "Heavy Laser",
    cardRarity = "main_weapon",
    size = 20,
    rotation = 0,
    turnSpeed = math.huge,
    fireRate = 0.5,
    range = 500,
    barrel = 20,
    color = {0.3, 0.3, 0.3, 1},
    types = { turret = true, mainLazer = true, energy = true },
    shapePattern = {
        {0, 0}, {1, 0},
        {0, 1}, {1, 1}
    },
    firingArc = { direction = 0, minRange = 0, angle = math.pi },
    bulletName = "Heavy Laser",
    bulletColor = {0, 0, 1},
    bulletSpeed = 400,
    damage = 45,
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
                statModifiers = { damage = { mult = -0.2 }, fireRate = { mult = 0.5 } }
            })
        end
    elseif reward.id == "unstable_laser" then
        local burn = BurnEffect:new({
            name = "burn",
            duration_burn = 3.2,
            dps_burn = 10,
            maxStacks = 5,
            chance = 0.25
        })
        self:addHitEffect(burn)
        if self.effectManager then
            self.effectManager:applyEffect({ name = "+Burn Chance" })
        end
    elseif reward.id == "electric_field" then
        if self.effectManager then
            self.effectManager:applyEffect({ name = "Electric Field" })
        end
    end
    print("Main Turret Upgrade Applied: " .. reward.name)
end

function MainLazer:update(dt)
    StandardMainTurret.update(self, dt)
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
            target:takeDamage(self:getStat("damage"), "energy", target.x, target.y)
            if self.game.spawnLightningBolt then self.game:spawnLightningBolt(target.x, target.y) end
            if self.game.spawnParticleExplosion then self.game:spawnParticleExplosion({0.4, 0.7, 1, 1}, 5, target.x, target.y) end
            
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
     StandardMainTurret.fire(self, args)
end

function MainLazer:getFirePoint()
    local cx, cy = self:getCenterPosition()
    local mx, my = Layout.mouseToField()
    local angle = math.atan2(my - cy, mx - cx)
    return cx + math.cos(angle) * 20, cy + math.sin(angle) * 20
end

function MainLazer:draw()
    local cx, cy = self:getCenterPosition()
    local r, g, b = unpack(self.color or {0.3, 0.3, 0.3, 1})
    
    if self.showArc and self.upgrades["electric_field"] then
        self:drawFiringArc(0.3)
    end
    
    local function drawBase(radius)
        local pts = {}
        for i = 0, 15 do
            local rad = (i % 2 == 0) and radius or (radius * 0.6)
            local angle = i * (math.pi * 2 / 16)
            table.insert(pts, cx + math.cos(angle) * rad)
            table.insert(pts, cy + math.sin(angle) * rad)
        end
        love.graphics.polygon("line", pts)
    end

    love.graphics.setColor(r, g, b, 0.4)
    love.graphics.setLineWidth(4)
    drawBase(self.size * 1.1)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(2)
    drawBase(self.size * 1.1)

    local mx, my = Layout.mouseToField()
    local angle = math.atan2(my - cy, mx - cx)
    
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(angle)
    
    local function drawTeslaCoil()
        local currentFireRate = self:getStat("fireRate")
        local reloadProgress = 1 - math.max(0, self.cooldown / (1 / currentFireRate))
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
        love.graphics.line(0, 0, 20, 0)
        for i = 1, 3 do
            local x = i * 5
            local threshold = i * 0.25
            if reloadProgress >= threshold then love.graphics.setColor(0.4, 0.7, 1, 1)
            else love.graphics.setColor(0.3, 0.3, 0.3, 1) end
            love.graphics.ellipse("line", x, 0, 1.5, 4)
        end
        if reloadProgress >= 1 then love.graphics.setColor(0.4, 0.7, 1, 1)
        else love.graphics.setColor(0.3, 0.3, 0.3, 1) end
        love.graphics.circle("line", 20, 0, 3.5)
    end
    
    local currentFireRate = self:getStat("fireRate")
    local reloadProgress = 1 - math.max(0, self.cooldown / (1 / currentFireRate))
    
    if not self.upgrades["electric_field"] and reloadProgress > 0.25 then
        love.graphics.setColor(0, 0.5, 1, 0.3 * reloadProgress)
        love.graphics.setLineWidth(5)
        drawTeslaCoil()
    end
    
    if not self.upgrades["electric_field"] then
        love.graphics.setLineWidth(2)
        drawTeslaCoil()
        if reloadProgress >= 1 then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.circle("fill", 20, 0, 1.5)
        end
    else
        for i = 1, 3 do
            local ringRadius = 7 + i * 5
            local threshold = i / 3
            local isCharged = reloadProgress >= threshold
            if isCharged then
                love.graphics.setColor(0.4, 0.7, 1, 0.8)
                love.graphics.setLineWidth(2)
            else
                love.graphics.setColor(0.2, 0.2, 0.3, 0.5)
                love.graphics.setLineWidth(1)
            end
            love.graphics.circle("line", 0, 0, ringRadius)
            if isCharged then
                love.graphics.setColor(0.4, 0.7, 1, 0.15)
                love.graphics.circle("fill", 0, 0, ringRadius)
            end
        end
        local pulse = (math.sin(love.timer.getTime() * 10) + 1) / 2
        love.graphics.setColor(0.4, 0.7, 1, 0.5 + 0.5 * pulse * reloadProgress)
        love.graphics.circle("fill", 0, 0, 4 + 2 * pulse)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 0, 0, 3)
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
    local RewardIndex = require("Game.Rewards.NormalRewardIndex")
    
    local function findRewardById(id)
        for _, rarityList in pairs(RewardIndex) do
            if type(rarityList) == "table" then
                for _, item in ipairs(rarityList) do
                    if item.id == id then
                        return item
                    end
                end
            end
        end
        return nil
    end

    local function addBuildingCard(id, quantity, rarity)
        local reward = findRewardById(id)
        if reward then
            deck:addCard(Card:new({
                id = reward.id, 
                name = reward.name, 
                description = reward.description,
                executionType = ExecutionType.Placement, 
                quantity = quantity,
                payload = { buildingClass = reward.building, config = {}, rarity = rarity }
            }))
        end
    end

    addBuildingCard("sentry", 2, "common")
    addBuildingCard("blaster", 4, "common")

    
    deck:addCard(Card:new({
        id = "unstable_laser",
        name = "Unstable Laser",
        description = "Gives your big lazer a 20% chance to burn enemies.",
        executionType = ExecutionType.Targeted,
        quantity = 1,
        payload = { isMainUpgrade = true, rarity = "uncommon" }
    }))
    
    local function addInstantCard(id, quantity)
        for _, instant in pairs(InstantCardRegistry) do
            if type(instant) == "table" and instant.id == id then
                instant.quantity = quantity
                deck:addCard(instant)
                return
            end
        end
    end
    
    addInstantCard("inst_overclock_1", 4)
    addInstantCard("inst_range_1", 2)
    addInstantCard("inst_frenzy_1", 1)
    
    local energySurge = InstantCard.new({
        id = "inst_energy_surge_1",
        name = "Energy Surge",
        description = "All energy turrets gain +20% damage.",
        cost = 2,
        rarity = "rare",
        executionType = InstantCard.ExecutionType.Global,
        customExecute = function(gameObj)
            local buff = {
                name = "energy_surge_damage",
                displayName = "Energy Surge",
                statModifiers = { damage = { mult = 0.20 } }
            }
            if gameObj and gameObj.objects then
                for _, obj in ipairs(gameObj.objects) do
                    if obj.isType and obj:isType("turret") and obj:isType("energy") then
                        if obj.effectManager then
                            obj.effectManager:applyEffect(buff)
                        end
                    end
                end
            end
        end
    })
    energySurge.quantity = 1
    deck:addCard(energySurge)
    
    return deck
end

function MainLazer.getUniqueCards()
    return {
        rare = {
            {
                id = "unstable_laser",
                name = "Unstable Laser",
                description = "Gives your big lazer a 20% chance to burn enemies.",
                type = "main_upgrade",
                iconCategory = "upgrade",
                cost = 2,
                isEligible = function(game)
                    local mt = game.base and game.base.mainLazer
                    return mt and mt.id == "standard_main" and not mt.upgrades["unstable_laser"]
                end
            },
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
            }
        },
        legendary = {
            {
                id = "electric_field",
                name = "PROJECT STORMBREAKER",
                description = "zzzZap!",
                type = "main_upgrade",
                iconCategory = "upgrade",
                cost = 4,
                isEligible = function(game)
                    local mt = game.base and game.base.mainLazer
                    return mt and not mt.upgrades["electric_field"]
                end
            }
        }
    }
end

return MainLazer
