# Tooltip System — Needs a Revamp (deferred)

**Status:** Outdated. Planned for a full future revamp; until then, only make minimal
per-building text fixes rather than patching the system piecemeal.

## Known problems
- **Text drifts from behaviour.** Tooltip strings are hand-written per building and can
  disagree with the card description and the real effect (e.g. the Bank tooltip said
  "+1 Energy per turn" while the card said Tokens and the payout ignored adjacency).
- **Several sources of truth.** Tooltip text comes from per-building
  `getTooltipStrings()` overrides (Bank, Conduit, IndustrialBattery, UnstableLaser),
  `EffectManager:getTooltipStrings()` (stat modifiers), and `TooltipManager` /
  `InfoColumn`, with no shared format.
- **Duplicated type guessing by ID.** `TooltipManager.lua` and `Rewards/Reward.lua`
  both classify cards by searching the ID string (`"buff"`, `"Cache"`, `"bank"`,
  `"Rounds"`...) instead of using `types` / `iconCategory`.
- **Hidden modifiers are opt-in.** Only modifiers tagged `hidden = true` are skipped;
  anything else (including internal/shadow stats) shows up unless remembered.

## Revamp goals (ideas)
- Generate tooltip text from the same data that drives behaviour (stats, effects, rules).
- One classification path based on `types` / `iconCategory`, not ID strings.
- One formatter for stat modifiers, abilities and building rules.
