# Base Defense

A tower defense game built with [LOVE 2D](https://love2d.org/) in Lua. Defend your base from waves of increasingly difficult enemies by strategically placing turrets, blockers, and buff totems on a grid-based battlefield.

## Gameplay

- **Wave-based combat** with escalating difficulty and enemy variety
- **Grid-based building** - place turrets, blockers, and buff totems on your base
- **Player-controlled main turret** for manual targeting with hitscan laser
- **Reward system** between waves - spend money on randomized building cards with luck-based rarity scaling
- **Buff totems** that grant effects (explosive, poison, splitting) to adjacent turrets
- **Status effects** including poison DoT, explosions, armor piercing, and projectile splitting

## Turrets

| Turret | Description |
|--------|-------------|
| Main Turret | Player-controlled hitscan laser (2x2) |
| Sentry | Balanced standard turret |
| Heavy Gun | High damage, slow fire rate |
| Auto Cannon | High fire rate, low damage per shot |
| Sniper | Long-range hitscan |
| Poison Turret | Applies poison DoT on hit |
| Lobber | Parabolic arc projectiles with explosions |
| Splitter | Bullets split into multiple projectiles |

## Enemies

| Enemy | Description |
|-------|-------------|
| Basic | Balanced stats (25 speed, 100 HP) |
| Speeder | Fast with low HP (120 speed, 25 HP) - Wave 3+ |
| Tank | Slow with high HP (10 speed, 2000 HP) - Wave 5+ |

## Buildings

- **Blockers** - Destructible terrain (SmallBox, SmallFence, SlottedBlocker)
- **Buff Totems** - Passive enhancements for adjacent turrets (Explosive, Poison, Shard Bullets, Damage)

## How to Play

1. **Preparation phase** - Review your base and plan placement
2. **Wave phase** - Enemies spawn and march toward your base; turrets fire automatically
3. **Reward phase** - Spend money on building cards, upgrade luck for better rewards
4. Repeat until your base falls

**Controls:**
- Mouse to aim the main turret and interact with UI
- Space to view turret firing arcs

## Running

Requires [LOVE 2D](https://love2d.org/) (love 11.x+).

```bash
love .
```

## Project Structure

```
Base-Defense/
├── main.lua                 # Entry point
├── conf.lua                 # LOVE configuration (1920x1080)
├── Buildings/
│   ├── Turrets/             # 8 turret types + base class
│   ├── Blockers/            # Destructible terrain
│   └── Buffs/               # Passive buff totems
├── Enemies/                 # Enemy types + base class
├── Bullets/                 # Projectile types (standard, hitscan, lobber)
├── Game/
│   ├── Core/                # GameManager, Base, BattlefieldGrid
│   ├── Spawning/            # WaveSpawner, WaveDirector, EnemyRegistry
│   ├── Rewards/             # Reward system and card pools
│   ├── GUI/                 # UI components and tooltips
│   ├── Input/               # Input handling
│   ├── Inventory/           # Player inventory
│   └── Effects/             # Status effects and independent effects
├── Scenes/                  # Scene management (menu, game, test)
├── Classes/                 # Base object classes and utilities
├── Physics/                 # Collision detection and pathfinding
└── Graphics/                # Animations and visual effects
```
