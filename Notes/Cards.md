# Card System Documentation

In the **Base-Defense** engine, "Cards" represent the core method by which players interact with the game. They are used to place buildings, upgrade units, and cast global spells.

## Execution Types

Cards are categorized by their `ExecutionType` (defined in `Game.Cards.ExecutionType`), which determines how the game handles their execution:

### 1. Placement
- **Purpose:** Used for placing physical structures (such as turrets, walls, or generators) onto the game grid.
- **Behavior:** The card's payload contains a `buildingClass`. When played, the game instantiates this class at the targeted grid location.

### 2. Global
- **Purpose:** Applies a game-wide buff or effect that applies to all relevant entities or overall player stats.
- **Behavior:** Does not require a specific map target. When played, it registers an effect with the `playerEffectManager` and applies it to the entire game state.

### 3. Targeted
- **Purpose:** Applies a specific buff, upgrade, or effect to a single entity on the board (e.g., buffing a specific sniper turret).
- **Behavior:** Requires the player to target a valid entity on the map. If the target is invalid (like empty grass or the wrong unit type), the execution fails.

---

## Core Classes

### `Card` (`Game.Cards.Card`)
The standard base class primarily used for `Placement` and simple `Global` effects. 
- It holds a `payload` containing the necessary configuration (like the class to build).
- It dynamically calculates its token cost by looking itself up in various Reward Indices.

### `Instant` (`Instants.Instant`)
Represents "Spells" or direct-action upgrades. `Instants` heavily utilize the `Targeted` execution type.
- Contains specific `isValidTarget(targetEntity)` logic to prevent invalid plays (e.g., ensuring a turret-specific buff cannot be placed on a wall).
- Uses `statModifiers` to apply buffs via an entity's `effectManager`.
- Supports a `customExecute` callback for highly specific or unique behaviors that don't fit the standard stat buff mold.

### `PlayerDeck` (`Game.Cards.PlayerDeck`)
Manages the player's collection of cards. It handles the logic for drawing cards into the hand, consuming them upon successful execution, and refunding the cost if a placement is cancelled or fails.

---

## Card Icons

Synergy icons sit in the bottom left of a card's description box (`Game.Cards.CardIcons`), always in this order:
0. **Target:** `mainTurret`, added automatically to cards that can only target the Main Turret (`type = "main_upgrade"` or `requiredType = "mainturret"`)
1. **Firing types:** `projectile`, `hitscan`, `shotgun`, `lobber`, `beam` (a card can have more than one, e.g. a shotgun shows `projectile` + `shotgun`)
2. **Damage types:** `physical`, `energy`, `explosive`, `fire`, `poison`, `ice`, `trueDamage`
3. **Resources:** `token`, `mana`, `money`

**Automatic:** a turret with a `bulletId` and `damageType` derives its icons: `hitscan` for a hitscan bullet, `lobber` if its `types` include `lobber`, otherwise `projectile`; plus `shotgun` for the `shotgun` type or `pelletCount > 1`; then its damage type.

**Manual — add these when you make a new card:** any other card needs an explicit `icons = { ... }` field on its definition (order doesn't matter, it's sorted):
- Turrets without a bullet (beams, waves), e.g. Cryo Beam `{ "beam", "ice" }`
- Spells (`Spells/SpellCardRegistry.lua`), instants (`Instants/InstantCardRegistry.lua`), passives (`Buildings/PassiveIndex.lua`)
- Main turret cards and upgrades (`Buildings/MainTurrets/*`); for a deck `Card:new`, put `icons` in `payload.config`

Show the types the card cares about (Unstable Laser buffs energy turrets with burn: `{ "energy", "fire" }`). Cards with nothing type-specific (Ammo Cache, Overclock) get no icons. A new icon name needs a glyph, a colour and hover text (`CardIcons.INFO`) in `CardIcons.lua`. Hovering an icon in the deck view shows that text.
