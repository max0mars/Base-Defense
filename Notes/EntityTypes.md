# Entity Types

This document lists all the structural "types" attached to game objects and cards in the game. These types are used by the multi-type system for queries like `isType("type_name")` (e.g. to determine if a target is valid, or if status effects can be applied).

---

## 1. Buildings (`Buildings/`)

**Structural types:** `building`, `turret`, `passive`, `mainturret`

**Flavour types:**
* Damage type (added automatically from `damageType`): `ballistic`, `energy`, `explosive`, `fire`, `poison`, `ice`
* Firing style: `shotgun`, `lobber`
* Status effect: `toxic` (Chem Lab), `slow`, `stun`
* Role: `control` (anything that slows or stuns), `economy`

All buildings inherit the `building` type from `Building.lua`. Turrets and passives get their types from their entry in `TurretIndex.lua` / `PassiveIndex.lua`, which override the class defaults.

### Turrets (`Buildings/TurretIndex.lua`)
* **Sentry**: `turret`, `ballistic`
* **Blaster**: `turret`, `energy`
* **Auto Cannon**: `turret`, `ballistic`
* **Shotgun Turret**: `turret`, `ballistic`, `shotgun`
* **Heavy Gun**: `turret`, `ballistic`
* **Poison Turret**: `turret`, `poison`
* **Airburst Turret**: `turret`, `ballistic`
* **Flux Cannon**: `turret`, `energy`
* **Grenadier**: `turret`, `explosive`, `lobber`
* **Slush Cannon**: `turret`, `ice`, `slow`, `control`
* **GTR-55 Gator**: `turret`, `ballistic`
* **Missile Launcher**: `turret`, `explosive`
* **Plasma Scattershot**: `turret`, `energy`, `shotgun`
* **CSR-8 Sequence**: `turret`, `ballistic`
* **The Hook**: `turret`, `ballistic`, `stun`, `control`
* **Sniper Turret**: `turret`, `ballistic`
* **Mortar**: `turret`, `explosive`, `lobber`
* **PROJECT CHIMERA**: `turret`, `energy`

### Main Turrets (`Buildings/MainTurrets/`)
All main turrets inherit from `StandardMainTurret.lua`, which adds the `mainturret` type.
* **Heavy Laser** (`MainLazer.lua`): `mainturret`, `turret`, `energy`
* **Machine Gun** (`FastMainTurret.lua`): `mainturret`, `turret`, `ballistic`

### Passives (`Buildings/PassiveIndex.lua`)
* **Unstable Laser**: `passive`
* **Ammo Cache** (`Buff.lua`): `passive`
* **Recursive Rounds** (`ShardBullets.lua`): `passive`
* **Bank**: `passive`, `economy`
* **Chem Lab** (`ToxicTotem.lua`): `passive`, `toxic`
* **Conduit**: `passive`, `economy`
* **Frost Trap** (`FrostTrap.lua`): `passive`, `slow`, `control`
* **Explosive Bullets** (`ExplosiveTotem.lua`): `passive`, `explosive`

---

## 2. Instants (`Instants/`)

All instant cards inherit from `Instant.lua` and have the type `instant`.

---

## 3. Spells (`Spells/`)

All spell cards inherit from `Spell.lua` and have the type `spell`.

* **Spell deck:** at battle start, spells are split out of the run deck into their own
  piles (`spellDrawPile` / `spellDiscardPile`). Sending a wave discards the build hand
  and draws `spellHandSize` spells; finishing the wave returns them and draws the build hand.
  Cast spells go to the spell discard and reshuffle back in (not consumed).
* **Mana:** starts at `maxMana`, regenerates `manaRegenPerWave` after each wave (capped).
  There is no draw-a-card-for-mana action.
* **Hotkeys:** during a wave, number keys `1..N` select the N-th spell in hand (left to
  right) for targeting. The cast needs a fresh left click, so a button already held
  for turret fire never casts; after a cast, turret fire waits for the button to be released.

---

## 4. Enemies (`Enemies/`, `Game/Spawning/EnemyIndex.lua`)

All enemies inherit from `living_object.lua` (`living_object`) and `Enemy.lua` (`enemy`).

* **Faction colours:** `red`, `yellow`, `green`, `blue`
* **Roles:** `armour`, `sapper`, `spawner`, `support`, `duplicator`, `tank`

---

## 5. Other

* **Bullets:** `bullet`
* **Base:** `base`
