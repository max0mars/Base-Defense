Damage types and their colours are defined in Classes/DamageTypes.lua.

Damage Types (exactly one per hit, validated on takeDamage):
- ballistic  - default for turrets, bullets and enemies hitting the base
- energy     - Blaster, Flux Cannon, Plasma Scattershot, Chimera, Main Lazer, Zap
- explosive  - Grenadier, Missile Launcher, Mortar, and every explosion
- fire       - Burn ticks, Fireball
- poison     - Poison Turret, Poison and Toxic ticks, Toxic shards, Acid Cloud
- ice        - Slush Cannon
- trueDamage - Judgment; ignores affinities entirely

A turret's damage type is also added to its building types (Turret.lua), so
isType("energy") / targetTypes = { energy = true } match energy turrets.

Damage Tags (any number per hit, passed as takeDamage's damageTags):
- projectile - default on every bullet
- hitscan    - default on hitscan bullets (Sniper)
- aoe        - explosions, Fireball, Acid Cloud, Zap
- dot        - Burn, Poison and Toxic ticks, Acid Cloud
- toxic      - Toxic ticks and shards (poison damage, coloured purple)

Tags can't be a core damage type. Enemy affinities and "<tag>_damage" stat
modifiers match both the damage type and the tags. A tag listed in
DamageTypes.colors (toxic) overrides the hit's damage-number colour.
