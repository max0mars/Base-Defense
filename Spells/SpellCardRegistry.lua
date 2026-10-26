-- Spells/SpellCardRegistry.lua
local Spell = require("Spells.Spell")

local SpellCardRegistry = {}

-- Fireball
SpellCardRegistry.Fireball = Spell.new({
    id = "spell_fireball",
    name = "Fireball",
    description = "Deals 60 damage in an area.",
    cost = 20,
    rarity = "Common",
    radius = 60,
    damage = 60,
    customExecute = function(self, x, y, game)
        local FireballVisual = require("Spells.FireballVisual")
        table.insert(game.animations, FireballVisual:new(x, y, self:getStat("radius"), self:getStat("damage"), game))
    end
})

-- Stun Burst
SpellCardRegistry.StunBurst = Spell.new({
    id = "spell_stunburst",
    name = "Stun Burst",
    description = "Stuns enemies in a small area.",
    cost = 15,
    rarity = "Uncommon",
    radius = 40,
    customExecute = function(self, x, y, game)
        -- Visual
        local StunBurstVisual = require("Graphics.Animations.StunBurstVisual")
        local r = self:getStat("radius")
        table.insert(game.animations, StunBurstVisual:new(x, y, r, 1.5))
        
        -- Sound
        if AUDIO then
            AUDIO:playSFX("lightning_01")
        end
        
        -- Stun status effect
        local Stun = require("Game.Effects.StatusEffects.Stun")
        local r2 = r * r
        for _, obj in ipairs(game.objects) do
            if obj:isType("enemy") and not obj.destroyed then
                local dx = obj.x - x
                local dy = obj.y - y
                if dx*dx + dy*dy <= r2 then
                    if obj.effectManager then
                        obj.effectManager:applyEffect(Stun:new({ duration = 2.0 }))
                    end
                end
            end
        end
    end
})

-- Acid Cloud
SpellCardRegistry.AcidCloud = Spell.new({
    id = "spell_acidcloud",
    name = "Acid Cloud",
    description = "Deals poison damage in an area.",
    cost = 30,
    rarity = "Rare",
    radius = 50,
    dps = 10,
    customExecute = function(self, x, y, game)
        -- Visual
        local AcidCloudVisual = require("Graphics.Animations.AcidCloudVisual")
        local r = self:getStat("radius")
        table.insert(game.animations, AcidCloudVisual:new(x, y, r, 5.0))
        
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

-- Zap
SpellCardRegistry.Zap = Spell.new({
    id = "spell_zap",
    name = "Zap",
    description = "Deals low damage and short stun.",
    cost = 10,
    rarity = "Common",
    radius = 25,
    damage = 40,
    customExecute = function(self, x, y, game)
        -- Visuals
        if game.spawnLightningBolt then
            game:spawnLightningBolt(x, y)
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
                        obj.effectManager:applyEffect(Stun:new({ duration = 0.2 }))
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

return SpellCardRegistry
