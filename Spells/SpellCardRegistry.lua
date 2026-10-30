-- Spells/SpellCardRegistry.lua
local Spell = require("Spells.Spell")

local SpellCardRegistry = {}

-- Fireball
SpellCardRegistry.Fireball = Spell.new({
    id = "spell_fireball",
    name = "Fireball",
    description = "Deals 60 damage in an area.",
    icons = { "fire" },
    cost = 20,
    rarity = "Common",
    radius = 60,
    damage = 60,
    customExecute = function(self, x, y, game)
        local FireballVisual = require("Spells.FireballVisual")
        table.insert(game.animations, FireballVisual:new(x, y, self:getStat("radius"), self:getStat("damage"), game))
    end
})

-- Stun Gas: a short-lived cloud that stuns every enemy in it, including any
-- that walk in before it clears
SpellCardRegistry.StunBurst = Spell.new({
    id = "spell_stunburst",
    name = "Stun Gas",
    description = "Releases a cloud of stunning gas that stuns enemies in it, and any that walk in before it clears.",
    cost = 15,
    rarity = "Uncommon",
    radius = 40,
    customExecute = function(self, x, y, game)
        -- Visual
        local GasCloudVisual = require("Graphics.Animations.GasCloudVisual")
        local r = self:getStat("radius")
        table.insert(game.animations, GasCloudVisual:new(x, y, r, 1.5, { color = {0.98, 0.92, 0.45}, growTime = 0.2 }))
        
        -- Sound
        if AUDIO then
            AUDIO:playSFX("lightning_01")
        end
        
        -- The cloud stuns the enemies caught in it now, and any that walk in later
        local StunGasEffect = require("Spells.StunGasEffect")
        local cloud = StunGasEffect:new({
            x = x,
            y = y,
            radius = r,
            stunDuration = 2.0,
            duration = 1.5,
            game = game
        })
        cloud:stunEnemiesInside()
        if game.enemyEffectManager then
            game.enemyEffectManager:applyEffect(cloud)
        end
    end
})

-- Acid Cloud: a lingering cloud of poison gas
SpellCardRegistry.AcidCloud = Spell.new({
    id = "spell_acidcloud",
    name = "Acid Cloud",
    description = "Leaves a lingering cloud of poison gas that deals poison damage to enemies inside.",
    icons = { "poison" },
    cost = 30,
    rarity = "Rare",
    radius = 50,
    dps = 20,
    customExecute = function(self, x, y, game)
        -- Visual
        local GasCloudVisual = require("Graphics.Animations.GasCloudVisual")
        local r = self:getStat("radius")
        table.insert(game.animations, GasCloudVisual:new(x, y, r, 5.0, { color = {0.45, 0.8, 0.3}, growTime = 0.6, wisps = true }))
        
        -- Register custom duration effect on the global enemyEffectManager
        if game.enemyEffectManager then
            local AcidCloudEffect = require("Spells.AcidCloudEffect")
            game.enemyEffectManager:applyEffect(AcidCloudEffect:new({
                x = x,
                y = y,
                radius = r,
                dps = self:getStat("dps"),
                duration = 5.0,
                game = game
            }))
        end
    end
})

-- Judgment (Global Spell)
SpellCardRegistry.Judgment = Spell.new({
    id = "spell_judgment",
    name = "Judgment",
    description = "Deal 800 damage split evenly between all active enemies.",
    icons = { "trueDamage" },
    cost = 50,
    rarity = "Epic",
    radius = 0,
    damage = 800,
    isGlobalSpell = true,
    customExecute = function(self, x, y, game)
        local activeEnemies = {}
        for _, obj in ipairs(game.objects) do
            if obj:isType("enemy") and not obj.destroyed then
                table.insert(activeEnemies, obj)
            end
        end
        
        local numEnemies = #activeEnemies
        if numEnemies > 0 then
            local damagePerEnemy = self:getStat("damage") / numEnemies
            for _, enemy in ipairs(activeEnemies) do
                -- Apply damage
                enemy:takeDamage(damagePerEnemy, "trueDamage")
                -- Spawn lightning bolt visual
                if game.spawnLightningBolt then
                    game:spawnLightningBolt(enemy.x, enemy.y)
                end
                -- Play electric sfx
                if AUDIO then
                    AUDIO:playSFX("lightning_01")
                end
            end
        end
    end
})

-- Lightning: strikes the highest-HP enemies in the area, each at most once.
-- Strikes beyond the number of enemies in range are wasted.
SpellCardRegistry.Lightning = Spell.new({
    id = "spell_lightning",
    name = "Lightning",
    description = "Strikes the 3 highest HP enemies in an area for 300 damage each.",
    icons = { "energy" },
    cost = 35,
    rarity = "Rare",
    radius = 100,
    damage = 300,
    strikes = 3,
    customExecute = function(self, x, y, game)
        local r = self:getStat("radius")
        local r2 = r * r
        if game.spawnCircleFade then
            game:spawnCircleFade(x, y, r, {0.2, 0.8, 1, 0.5}, 0.25)
        end

        local inRange = {}
        for _, obj in ipairs(game.objects) do
            if obj:isType("enemy") and not obj.destroyed then
                local dx = obj.x - x
                local dy = obj.y - y
                if dx * dx + dy * dy <= r2 then
                    table.insert(inRange, obj)
                end
            end
        end
        table.sort(inRange, function(a, b) return a.hp > b.hp end)

        local dmg = self:getStat("damage")
        for i = 1, math.min(self:getStat("strikes"), #inRange) do
            local enemy = inRange[i]
            -- Single target: no "aoe" tag
            enemy:takeDamage(dmg, "energy", enemy.x, enemy.y)
            if game.spawnLightningBolt then
                game:spawnLightningBolt(enemy.x, enemy.y)
            end
            if game.spawnParticleExplosion then
                game:spawnParticleExplosion({0.2, 0.8, 1, 1}, 10, enemy.x, enemy.y, 0.3, 10)
            end
        end
        if AUDIO then
            AUDIO:playSFX("lightning_01")
        end
    end
})

-- Zap
SpellCardRegistry.Zap = Spell.new({
    id = "spell_zap",
    name = "Zap",
    description = "Deals low damage and short stun.",
    icons = { "energy" },
    cost = 10,
    rarity = "Common",
    radius = 25,
    damage = 40,
    customExecute = function(self, x, y, game)
        -- Visuals
        if game.spawnLightningBolt then
            game:spawnLightningBolt(x, y, { scale = 0.5 })
        end
        if game.spawnParticleExplosion then
            game:spawnParticleExplosion({0.2, 0.8, 1, 1}, 8, x, y, 0.3, 10)
        end
        if game.spawnCircleFade then
            game:spawnCircleFade(x, y, self:getStat("radius"), {0.2, 0.8, 1, 1}, 0.2)
        end

        -- Sound
        if AUDIO then
            AUDIO:playSFX("lightning_01")
        end

        -- Damage & Stun
        local r = self:getStat("radius")
        local r2 = r * r
        local dmg = self:getStat("damage")
        local Stun = require("Game.Effects.StatusEffects.Stun")
        for _, obj in ipairs(game.objects) do
            if obj:isType("enemy") and not obj.destroyed then
                local dx = obj.x - x
                local dy = obj.y - y
                if dx*dx + dy*dy <= r2 then
                    obj:takeDamage(dmg, "energy", nil, nil, { "aoe" })
                    if obj.effectManager then
                        obj.effectManager:applyEffect(Stun:new({ duration = 1.0 }))
                    end
                end
            end
        end
    end
})

-- -----------------------------------------------------------------------------
-- Ice synergy spells (chill / freeze, see Chill.lua)
-- -----------------------------------------------------------------------------

-- Blizzard: Acid Cloud-style lingering area that slows and chills
SpellCardRegistry.Blizzard = Spell.new({
    id = "spell_blizzard",
    name = "Blizzard",
    description = "Creates a blizzard that deals ice damage over time and slows and chills enemies inside.",
    icons = { "ice" },
    cost = 30,
    rarity = "Uncommon",
    radius = 75,
    dps = 5,
    customExecute = function(self, x, y, game)
        local AcidCloudVisual = require("Graphics.Animations.AcidCloudVisual")
        local r = self:getStat("radius")
        table.insert(game.animations, AcidCloudVisual:new(x, y, r, 5.0, {0.55, 0.85, 1}))

        if game.enemyEffectManager then
            local BlizzardEffect = require("Spells.BlizzardEffect")
            game.enemyEffectManager:applyEffect(BlizzardEffect:new({
                x = x,
                y = y,
                radius = r,
                dps = self:getStat("dps"),
                chillPerSecond = 0.5,
                slow = 0.2,
                duration = 5.0,
                game = game
            }))
        end
    end
})

-- Flash Freeze: instantly freezes every chilled enemy in the area
SpellCardRegistry.FlashFreeze = Spell.new({
    id = "spell_flashfreeze",
    name = "Flash Freeze",
    description = "Instantly freezes every chilled enemy in an area.",
    icons = { "ice" },
    cost = 25,
    rarity = "Rare",
    radius = 60,
    customExecute = function(self, x, y, game)
        local Chill = require("Game.Effects.StatusEffects.Chill")
        local r = self:getStat("radius")
        if game.spawnExpandingCircle then
            game:spawnExpandingCircle(x, y, 4, r, {0.75, 0.95, 1, 0.6}, 0.35)
        end
        if AUDIO then
            AUDIO:playSFX("lightning_01")
        end

        -- Any amount of chill qualifies; thawing enemies have no chill and stay immune.
        local r2 = r * r
        for _, obj in ipairs(game.objects) do
            if obj:isType("enemy") and not obj.destroyed then
                local dx = obj.x - x
                local dy = obj.y - y
                if dx * dx + dy * dy <= r2 and Chill.getStacks(obj) > 0 then
                    Chill.freeze(obj)
                end
            end
        end
    end
})

-- Overchill (Global): all chill applied is doubled for 5 seconds
SpellCardRegistry.Overchill = Spell.new({
    id = "spell_overchill",
    name = "Overchill",
    description = "For 5 seconds, all chill applied is doubled.",
    icons = { "ice" },
    cost = 25,
    rarity = "Rare",
    radius = 0,
    isGlobalSpell = true,
    customExecute = function(self, x, y, game)
        local em = game.enemyEffectManager
        if not em then return end
        -- Recasting refreshes the duration instead of stacking the multiplier.
        local existing = em:getEffect("overchill")
        if existing then
            existing.duration = 5.0
        else
            em:applyEffect({ name = "overchill", displayName = "Overchill", duration = 5.0, chillMultiplier = 2 })
        end
        if game.spawnFloatingText then
            game:spawnFloatingText("OVERCHILL", x, y, {0.55, 0.85, 1, 1})
        end
    end
})

-- -----------------------------------------------------------------------------
-- Fire synergy spells (burn, see Burn.lua)
-- -----------------------------------------------------------------------------

-- Embers: hot coals that keep applying burn to enemies in the area
SpellCardRegistry.Embers = Spell.new({
    id = "spell_embers",
    name = "Embers",
    description = "Spreads hot coals over an area for 5 seconds. Enemies in it gain 2 burn every half second.",
    cost = 25,
    rarity = "Uncommon",
    radius = 60,
    customExecute = function(self, x, y, game)
        local FireZoneEffect = require("Spells.FireZoneEffect")
        FireZoneEffect.spawn(game, {
            name = "embers",
            x = x, y = y,
            radius = self:getStat("radius"),
            duration = 5,
            tickInterval = 0.5,
            stacksPerTick = 2,
        }, "coals")
        if game.spawnParticleExplosion then
            game:spawnParticleExplosion({1, 0.5, 0.1, 1}, 12, x, y, 0.4, 16)
        end
    end
})

-- Blazing Flames: burst of burn, then a zone where burn hits harder but burns out faster
SpellCardRegistry.BlazingFlames = Spell.new({
    id = "spell_blazingflames",
    name = "Blazing Flames",
    description = "Applies 10 burn to enemies in an area. For 5 seconds, burn deals double damage there but also decays twice as fast.",
    cost = 30,
    rarity = "Rare",
    radius = 70,
    customExecute = function(self, x, y, game)
        local Burn = require("Game.Effects.StatusEffects.Burn")
        local FireZoneEffect = require("Spells.FireZoneEffect")
        local r = self:getStat("radius")
        local r2 = r * r
        for _, obj in ipairs(game.objects) do
            if obj:isType("enemy") and not obj.destroyed then
                local dx, dy = obj.x - x, obj.y - y
                if dx * dx + dy * dy <= r2 then
                    Burn.apply(obj, 10)
                end
            end
        end
        FireZoneEffect.spawn(game, {
            name = "blazing_flames",
            x = x, y = y,
            radius = r,
            duration = 5,
            burnDamageMult = 2,
            burnDecayMult = 2,
        }, "blaze")
        if game.spawnExpandingCircle then
            game:spawnExpandingCircle(x, y, 4, r, {1, 0.55, 0.1, 0.7}, 0.3)
        end
        if AUDIO then
            AUDIO:playSFX("explosion_02")
        end
    end
})

return SpellCardRegistry
