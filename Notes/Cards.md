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
