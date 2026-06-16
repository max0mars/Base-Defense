# Base-Defense (feat. Deckbuilding) - Agent Instructions

This document provides an overview of the codebase architecture, core systems, and development conventions for AI agents working on this project. It is designed to prevent code reinvention and ensure adherence to existing structural patterns.

## 1. Project Environment
* **Engine:** LÖVE (Love2D)
* **Language:** Lua
* **Build System:** `makelove` (configured via `makelove.toml`)
* **Screen Scaling:** Handled by the external library `Libraries/scalify.lua`

## 2. Core Architecture
* **Object-Oriented Programming (OOP):** The project implements a custom OOP structure located in `Classes/`.
  * `Classes/object.lua`: The foundational base class for the system.
  * `Classes/living_object.lua`: Extends `object.lua`; used for entities that possess health or vitality properties.
* **Scene Management:** The game's state machine operates on scenes (`Scenes/scene_manager.lua`). Distinct states (Menu, Game, Game Over, Preparation, Tutorial, Test) are implemented as individual scenes inheriting from the base `Scenes/scene.lua`.

## 3. Gameplay Systems

### Entities & Objects
Do not reinvent entity logic. Extend the existing base classes:
* **Buildings (`Buildings/Building.lua`):** Base class for all structures. Sub-categories exist for `MainTurrets/`, `Turrets/`, `Blockers/`, and `Buffs/`.
* **Enemies (`Enemies/Enemy.lua`):** Base class for all adversaries (e.g., Tank, Speeder, Flyer, Carrier).
* **Bullets (`Bullets/Bullet.lua`):** Base class for projectiles. Specialized behaviors already exist (e.g., Hitscan, Airburst, Lobber, Missile).

### Deckbuilding & Cards
* **Core Logic:** Housed in `Game/Cards/`. Relies on `Card.lua`, `PlayerDeck.lua`, and `CardDraw.lua` for core deck mechanics.
* **Instants:** One-time use cards and immediate effects are categorized in `Instants/` and managed by `InstantCardRegistry.lua` and `Instant.lua`.

### Game Loop, Grid, and Physics
* **Game Core:** `Game/Core/GameManager.lua` manages the active gameplay state.
* **Grid System:** Placement and spatial layout are handled by `Game/Core/BattlefieldGrid.lua`.
* **Physics & Collision:** The project uses a custom physics/collision framework, NOT LÖVE's built-in `love.physics` (Box2D). Refer exclusively to `Physics/collisionSystem_brute.lua` and `Physics/hitbox.lua`.
* **Pathfinding:** Enemy pathing is handled via custom logic in `Physics/Pathfinder.lua` and `Physics/Navigators.lua`.

### Progression Systems
* **Waves & Spawning:** Controlled by `Game/Spawning/WaveDirector.lua` and `Game/Spawning/WaveSpawner.lua`. Available enemies must be registered in the appropriate registries (e.g., `EnemyRegistry.lua`, `NormalEnemyIndex.lua`).
* **Rewards:** Post-wave/gameplay rewards are handled by `Game/Rewards/RewardSystem.lua` and `RewardPool.lua`.

### Effects & Statuses
* **Status Effects:** Centralized and processed by `Game/Effects/EffectManager.lua`. Specific debuffs (Burn, Poison, Slow, Stun, Toxic) are modularized within `Game/Effects/StatusEffects/`.

## 4. UI & Audio Integration
* **GUI (`Game/GUI/`):** A bespoke GUI framework manages user interfaces (`GUIManager.lua`, `Layout.lua`). All visual elements (HandUI, Menus, Sliders) use this framework. Do not use raw Love2D text/drawing functions for UI elements if a GUI component is more appropriate. 
* **Tooltips:** Centralized in `Game/GUI/TooltipManager.lua`.
* **Audio (`Audio/`):** Audio playback is abstracted through `AudioManager.lua`, which delegates to `MusicManager.lua` and `SFXManager.lua`. Agents must use these managers for sound playback instead of directly invoking `love.audio`.

## 5. Agent Development Directives
* **Inheritance is Mandatory:** When creating a new turret, enemy, bullet, or scene, you must inherit from the respective base class in the codebase.
* **Registry Updates Required:** Many systems (Enemies, Instants, Rewards) utilize registries or indices. Ensure any newly created content is appended to the relevant registry files.
* **Consult Notes First:** Read the documentation in the `Notes/` directory (`Cards.md`, `DamageTypes.md`, `EnemyList.md`, `RewardList.md`, `TurretList.md`) to understand the intended design patterns, established damage typings, and existing content lists before generating new entities.
* **Respect the Physics Framework:** Do not attempt to implement Box2D or external physics libraries. Strictly adhere to the custom `Physics/` collision and hitbox modules.