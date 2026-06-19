# Entity Types

This document lists all the structural "types" attached to game objects and cards in the game. These types are used by the multi-type system for queries like `isType("type_name")` (e.g. to determine if a target is valid, or if status effects can be applied).

---

## 1. Buildings (`Buildings/`)

**All possible types in this group:**
* `building`, `turret`, `blocker`, `passive`, `mainturret`, `mainLazer`, `energy`, `legendary`, `explosive`, `lobber`, `stun`, `shotgun`, `poison`, `slow`, `hitscan`, `economy`, `totem`, `toxic`, `shard`, `slotted`

All buildings inherit the `building` type from the base class `Building.lua`. Additionally, sub-classes and specific building definitions add other types.

### Base Classes
* **`Building.lua`**: `building`
* **`Turrets/Turret.lua`**: `turret` (and `building`)
* **`Blockers/Blocker.lua`**: `blocker` (and `building`)
* **`Buffs/Buff.lua`**: `passive` (and `building`)

### Turrets (`Buildings/Turrets/`)
* **Airburst Turret** (`AirburstTurret.lua`): `turret`
* **Auto Cannon** (`AutoCannon.lua`): `turret`
* **Blaster** (`Blaster.lua`): `turret`, `energy`
* **Chain Laser** (`ChainLaser.lua`): `turret`, `legendary`, `energy`
* **Flux Cannon** (`FluxCannon.lua`): `turret`, `energy`
* **Gator** (`Gator.lua`): `turret`
* **Grenadier** (`Grenadier.lua`): `turret`, `explosive`, `lobber`
* **Heavy Gun** (`HeavyGun.lua`): `turret`
* **Hook Turret** (`HookTurret.lua`): `turret`, `stun`
* **Missile Launcher** (`MissileLauncher.lua`): `turret`, `explosive`
* **Mortar** (`Mortar.lua`): `turret`, `lobber`, `explosive`
* **Plasma Scattershot** (`PlasmaScattershot.lua`): `turret`, `energy`, `shotgun`
* **Poison Turret** (`PoisonTurret.lua`): `turret`, `poison`
* **Sentry** (`Sentry.lua`): `turret`
* **Sequence Turret** (`SequenceTurret.lua`): `turret`
* **Shotgun Turret** (`ShotgunTurret.lua`): `turret`, `shotgun`
* **Slush Cannon** (`SlushCannon.lua`): `turret`, `slow`
* **Sniper** (`Sniper.lua`): `turret`, `hitscan`

### Main Turrets (`Buildings/MainTurrets/`)
All main turrets inherit from `StandardMainTurret.lua`, which automatically adds the `mainturret` type.
* **Standard Main Turret** (`StandardMainTurret.lua`): `mainturret`, `turret`
* **Machine Gun** (`FastMainTurret.lua`): `mainturret`, `turret`
* **Main Lazer** (`MainLazer.lua`): `mainturret`, `turret`, `mainLazer`, `energy`

### Buffs / Totems (`Buildings/Passives/`)
* **Bank** (`Bank.lua`): `building`, `economy`, `passive`
* **Explosive Totem** (`ExplosiveTotem.lua`): `passive`, `totem`, `explosive`
* **Industrial Battery** (`IndustrialBattery.lua`): `building`, `passive`
* **Poison Totem** (`PoisonTotem.lua`): `passive`, `totem`, `poison`
* **Range Buff** (`RangeBuff.lua`): `passive`
* **Shard Bullets** (`ShardBullets.lua`): `passive`, `totem`, `shard`
* **Toxic Totem** (`ToxicTotem.lua`): `passive`, `totem`, `toxic`
* **Unstable Laser** (`UnstableLaser.lua`): `building`, `passive`

### Blockers (`Buildings/Blockers/`)
* **Small Box** (`SmallBox.lua`): `blocker`
* **Small Fence** (`SmallFence.lua`): `blocker`
* **Slotted Blocker** (`SlottedBlocker.lua`): `blocker`, `slotted`
* **Frost Trap / Slow Blocker** (`SlowBlocker.lua`): `blocker`, `slow`

---

## 2. Instants (`Instants/`)

**All possible types in this group:**
* `instant`

All instant cards inherit from `Instant.lua` and have the type `instant`.
* **Base Class** (`Instant.lua`): `instant`
* **Overclock** (`InstantCardRegistry.lua`): `instant`
* **Range Finder** (`InstantCardRegistry.lua`): `instant`
* **Frenzy** (`InstantCardRegistry.lua`): `instant`
* **Emergency Repairs** (`InstantCardRegistry.lua`): `instant`
* **Hasty Defenses** (`InstantCardRegistry.lua`): `instant`

---

## 3. Spells (`Spells/`)

**All possible types in this group:**
* `spell`

All spell cards inherit from `Spell.lua` and have the type `spell`.
* **Base Class** (`Spell.lua`): `spell`
* **Fireball** (`SpellCardRegistry.lua`): `spell`
* **Stun Burst** (`SpellCardRegistry.lua`): `spell`
* **Acid Cloud** (`SpellCardRegistry.lua`): `spell`
* **Judgment** (`SpellCardRegistry.lua`): `spell`

---

## 4. Enemies (`Enemies/`)

**All possible types in this group:**
* `living_object`, `enemy`, `basic`, `armored`, `beast`, `beastmaster`, `carrier`, `tank`, `duplicator`, `bio`, `flyer`, `guardian`, `speeder`

All enemies inherit from `living_object.lua` (adding `living_object` type) and `Enemy.lua` (adding `enemy` type). If an enemy has no specialized type, it is marked as `basic`.

* **Base Class** (`living_object.lua`): `living_object`
* **Enemy Base Class** (`Enemy.lua`): `enemy` (automatically adds `basic` if no other types besides `enemy` are specified)
* **Armored** (`Armored.lua`): `armored`, `enemy`, `living_object`
* **Beast** (`Beast.lua`): `beast`, `enemy`, `living_object`
* **Beast Master** (`BeastMaster.lua`): `beastmaster`, `enemy`, `living_object`
* **Carrier** (`Carrier.lua`): `carrier`, `tank`, `enemy`, `living_object`
* **Duplicator** (`Duplicator.lua`): `duplicator`, `bio`, `enemy`, `living_object`
* **Flyer** (`Flyer.lua`): `flyer`, `enemy`, `living_object`
* **Guardian** (`Guardian.lua`): `guardian`, `enemy`, `living_object`
* **Speeder** (`Speeder.lua`): `speeder`, `enemy`, `living_object`
* **Speeder Group** (`SpeederGroup.lua`): Spawns multiple `speeder` enemies (`speeder`, `enemy`, `living_object`)
* **Tank** (`Tank.lua`): `tank`, `enemy`, `living_object`
