# Base-Defense Codebase Guide

This is a Love2D-based tower defense game written in Lua. Understanding the architecture and patterns will help you contribute effectively.

## Architecture Overview

**Scene System**: Uses a scene manager pattern ([Scenes/scene_manager.lua](Scenes/scene_manager.lua)) to handle game states:

- Main entry point [main.lua](main.lua) delegates all Love2D callbacks to scene_manager
- Scenes: `menu_scene` and `game_scene` implement the core game loop
- Switch scenes via `scene_manager.switch(name)`

**Object Hierarchy**: All game entities inherit from base classes:

```lua
object (Classes/object.lua)
├── living_object (adds HP/damage)
│   └── Enemy (basic enemy behavior)
└── building (Buildings/Building.lua)
    └── Turret (shooting mechanics)
```

**Game Manager Pattern**: [Game/GameManager.lua](Game/GameManager.lua) is the central coordinator:

- Manages all game objects in `self.objects` table
- Handles score, XP, money, waves
- Integrates collision system, reward system, wave spawning
- Use `game:addObject(obj)` to register any new game entity

## Critical Development Patterns

**Object Creation**: Always use the constructor pattern with config tables:

```lua
-- Good: unified object creation
local enemy = Enemy:new({x = 100, y = 200, game = gameRef})

-- Required: All objects need game reference for cross-system communication
config.game = game  -- Essential for most objects
```

**Collision System**: Uses a spatial grid ([Physics/collisionSystem_brute.lua](Physics/collisionSystem_brute.lua)):

- Grid auto-configured in GameManager:load()
- Objects need `hitbox = true` in config and `tag` property for collision detection
- Collision handled via `obj:onCollision(other)` method

**Building Placement**: Buildings use a slot-based grid system:

- Base has `buildGrid` with slots
- Building position calculated from slot number in `building:getXY()`
- Buildings must specify type: "unit", "turret", or "passive"

## Important Conventions

**Coordinate System**: All drawing uses centered coordinates (x,y = center), documented in [Documentation.txt](Documentation.txt)

**Shape Definitions**: Standardized shape system:

- `size` = radius for circles, side length for squares
- Rectangle shapes use `w` and `h` properties
- Circle shapes are deprecated per object.lua

**ID System**: Auto-incrementing unique IDs via `newID()` in [Classes/object.lua](Classes/object.lua)

**Destruction Pattern**: Objects use `destroyed` flag + `died()` method, not immediate deletion

## Key Integration Points

**Love2D Callbacks**: Only [main.lua](main.lua) handles Love2D events - scenes receive them via scene_manager delegation

**Time Control**: Game supports time multiplier in game_scene (`time_mul` variable affects update deltatime)

**Resource Management**: GameManager tracks score/XP/money, RewardSystem handles rewards, WaveSpawner manages enemy waves

## Running the Game

- Standard Love2D project: `love .` from project root
- Console enabled via [conf.lua](conf.lua) for debugging
- Window: 800x600, non-resizable
- ESC key quits, P key pauses (in game scene)

## File Organization Logic

- `/Classes/`: Base object inheritance hierarchy
- `/Game/`: Core game systems (manager, base, rewards, waves)
- `/Buildings/`: All placeable structures and their behaviors
- `/Enemies/`: Enemy types and AI
- `/Physics/`: Collision detection and hitbox systems
- `/Scenes/`: Game state management (menu, gameplay)
- `/Bullets/`, `/Effects/`: Combat mechanics and visual effects

When adding new features, follow the existing inheritance patterns and ensure proper integration with GameManager's object registry system.
