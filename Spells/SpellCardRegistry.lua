-- Spells/SpellCardRegistry.lua
local Spell = require("Spells.Spell")

local SpellCardRegistry = {}

-- Fireball
SpellCardRegistry.Fireball = Spell.new({
    id = "spell_fireball",
    name = "Fireball",
    description = "Deal 80 damage in a 60-radius.",
    cost = 1,
    rarity = "Common",
    radius = 60,
    customExecute = function(x, y, game)
        local FireballVisual = require("Graphics.Animations.FireballVisual")
        table.insert(game.animations, FireballVisual:new(x, y, 60, 80, game))
    end
})

-- Stun Burst
SpellCardRegistry.StunBurst = Spell.new({
    id = "spell_stunburst",
    name = "Stun Burst",
    description = "Stuns enemies in a 70-radius for 3.0s.",
    cost = 2,
    rarity = "Uncommon",
    radius = 70,
    customExecute = function(x, y, game)
        -- Visual
        local StunBurstVisual = require("Graphics.Animations.StunBurstVisual")
        table.insert(game.animations, StunBurstVisual:new(x, y, 70, 1.5))
        
        -- Sound
        if AUDIO then
            AUDIO:playSFX("lightning_01")
        end
        
        -- Stun status effect
        local Stun = require("Game.Effects.StatusEffects.Stun")
        local r2 = 70 * 70
        for _, obj in ipairs(game.objects) do
            if obj:isType("enemy") and not obj.destroyed then
                local dx = obj.x - x
                local dy = obj.y - y
                if dx*dx + dy*dy <= r2 then
                    if obj.effectManager then
                        obj.effectManager:applyEffect(Stun:new({ duration = 3.0 }))
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
    description = "Deals 25 DPS to enemies in an 80-radius for 5.0s.",
    cost = 2,
    rarity = "Rare",
    radius = 80,
    customExecute = function(x, y, game)
        -- Visual
        local AcidCloudVisual = require("Graphics.Animations.AcidCloudVisual")
        table.insert(game.animations, AcidCloudVisual:new(x, y, 80, 5.0))
        
        -- Register custom duration effect on the global enemyEffectManager
        if game.enemyEffectManager then
            local AcidCloudEffect = require("Spells.AcidCloudEffect")
            game.enemyEffectManager:applyEffect(AcidCloudEffect:new({
                x = x,
                y = y,
                radius = 80,
                dps = 25,
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
    cost = 2,
    rarity = "Rare",
    radius = 0,
    isGlobalSpell = true,
    customExecute = function(x, y, game)
        local activeEnemies = {}
        for _, obj in ipairs(game.objects) do
            if obj:isType("enemy") and not obj.destroyed then
                table.insert(activeEnemies, obj)
            end
        end
        
        local numEnemies = #activeEnemies
        if numEnemies > 0 then
            local damagePerEnemy = 1000 / numEnemies
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

return SpellCardRegistry
