-- Spells/SpellCardRegistry.lua
local Spell = require("Spells.Spell")

local SpellCardRegistry = {}

-- Fireball
SpellCardRegistry.Fireball = Spell.new({
    id = "spell_fireball",
    name = "Fireball",
    description = "Deals 80 damage in a area.",
    cost = 25,
    rarity = "Common",
    radius = 60,
    damage = 80,
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
    cost = 25,
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
    cost = 50,
    rarity = "Rare",
    radius = 80,
    dps = 15,
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
    description = "Deal 1000 damage split evenly between all active enemies.",
    cost = 50,
    rarity = "Epic",
    radius = 0,
    damage = 1000,
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
    description = "Deals 20 damage in a very small area.",
    cost = 0,
    rarity = "Common",
    radius = 25,
    damage = 20,
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

        -- Damage
        local r = self:getStat("radius")
        local r2 = r * r
        local dmg = self:getStat("damage")
        for _, obj in ipairs(game.objects) do
            if obj:isType("enemy") and not obj.destroyed then
                local dx = obj.x - x
                local dy = obj.y - y
                if dx*dx + dy*dy <= r2 then
                    obj:takeDamage(dmg, "energy")
                end
            end
        end
    end
})

return SpellCardRegistry
