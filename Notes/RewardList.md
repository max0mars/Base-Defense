Reward Index Tracking
Sorted by Rarity

Common
- Sentry [Buildings.Turrets.Sentry]: Balanced range and damage.
- Auto Cannon [Buildings.Turrets.AutoCannon]: High fire rate, low damage, short range.
- Shotgun Turret [Buildings.Turrets.ShotgunTurret]: Shreds close-range targets.
- Heavy Gun [Buildings.Turrets.HeavyGun]: Long range, high damage.
- Flare Gun [Buildings.Turrets.Turret]: Fires flares that apply 1 burn on hit.

Uncommon
- Oil Gun [Buildings.Turrets.Turret]: Oils and slows enemies. Burn ignites the oil for 5 extra burn (oiling a burning enemy ignites it at once).
- Ice Market [Buildings.Passives.IceMarket]: Gain $5 every time a frozen enemy dies.
- Icicle Ballista [Buildings.Turrets.Turret]: Fires heavy icicles that deal more damage the more chilled the target is, and the most to frozen enemies.
- Airburst Turret [Buildings.Turrets.AirburstTurret]: Fires shells that explode mid-air into shrapnel.
- Ammo Cache [Buildings.Passives.Buff]: Increase nearby turret damage by 20%
- Recursive Rounds [Buildings.Passives.ShardBullets]: Bullets will now split on inpact.
- Flux Cannon [Buildings.Turrets.FluxCannon]: Energy damage that ignores heavy armor.
- Bank [Buildings.Passives.Bank]: Generates 1 Token per wave if adjacent slots are occupied.
- Grenadier [Buildings.Turrets.Grenadier]: Lobs grenades that explode after a short delay.
- Slush Cannon [Buildings.Turrets.SlushCannon]: Fires heavy clumps of slush. Each hit applies 2 stacks of chill.

Rare
- Flamethrower [Buildings.Turrets.Turret]: Rapidly sprays slow bursts of flame. Each hit applies 1 burn.
- Cinder Mortar [Buildings.Turrets.Turret]: Lobs a spread of cinders. The first enemy over each takes fire damage and 3 burn.
- Thermite Launcher [Buildings.Turrets.Turret]: Sticks thermite charges that apply 3 burn a second for 5 seconds; charges stack.
- Cold Tactics [Buildings.Passives.ColdTactics]: Nearby turrets deal more damage the closer the enemy hit is to freezing, up to +50%. Frozen enemies take +50%.
- Glacial Monolith [Buildings.Turrets.GlacialMonolith]: Deals no damage. Sends slow freezing waves through its arc that apply 2 stacks of chill.
- Ice Shard Gunner [Buildings.Turrets.Turret]: Rapidly fires ice shards. Each hit adds half a stack of chill.
- Chem Lab [Buildings.Passives.ToxicTotem]: Spreads deadly toxins. Highly contagious.
  - Gives its diagonal neighbours Toxic Rounds: hits apply Toxic (10s, 2 poison damage per
    second, -15% speed, one stack; reapplying refreshes it). An enemy that dies while Toxic
    bursts into 4 shards that deal no damage but apply Toxic, so it chains without limit.
- GTR-55 Gator [Buildings.Turrets.Gator]: Hard hitting rounds go right through enemies.
- Unstable Laser [main_upgrade]: Gives adjacent energy turrets a 25% chance to apply 3 burn.
- Missile Launcher [Buildings.Turrets.MissileLauncher]: Wouldn't want to get in the way of one of these.
- Plasma Scattershot [Buildings.Turrets.PlasmaScattershot]: Fires plamsa rounds at high speed but has limited ammo. Reloads slowly.
- CSR-8 Sequence [Buildings.Turrets.SequenceTurret]: Shoots faster the longer it stays locked onto a target.
- The Hook [Buildings.Turrets.HookTurret]: Fires a heavy shot that stuns enemies in their tracks.

Epic
- Inferno Tower [Buildings.Turrets.InfernoTower]: Fire beam that ramps up to 5x damage over 5 seconds on one target. No burn.
- Frost Cannon [Buildings.Turrets.Turret]: Long range, tight spread shotgun. Each pellet applies half a stack of chill.
- Cryo Beam [Buildings.Turrets.CryoBeam]: Locks a freezing beam onto one enemy. Freezes it in about 3 seconds, then moves to the next target.
- Sniper Turret [Buildings.Turrets.Sniper]: High damage, long range.
- Mortar [Buildings.Turrets.Mortar]: KABOOM!
- Explosive Bullets [Buildings.Passives.ExplosiveTotem]: Adds a little extra something to nearby turrets.
- Low Power Ops [main_upgrade]: Your big lazer shoots much faster but does a little less damage.

Legendary
- PROJECT STARFALL [Buildings.Turrets.MeteorTurret]: Calls meteors onto its target (fire damage, no burn); the crater left behind applies burn.
- PROJECT STORMBREAKER [main_upgrade]: zzzZap!
- PROJECT CHIMERA [Buildings.Turrets.ChainLaser]: No one is safe

Fire synergy (burn, see Game/Effects/StatusEffects/Burn.lua)
- Burn: stacks share one pool per enemy. 1-9 stacks = 10 dps, 10-19 = 20 dps, 20+ = 30 dps.
  Stacks lost per second = 0.5 + 0.04 * stacks^2 (DECAY_BASE / DECAY_SCALE / DECAY_POWER).
- Spells: Embers (uncommon, 2 burn every 0.5s in an area for 5s), Blazing Flames (rare, 10 burn,
  then 5s of double burn damage and double decay in the area).
- Instants: Incendiary Rounds (uncommon, physical turret hits apply 2 burn), Fan the Flames
  (uncommon, fire turrets +10% fire rate), Cheap Accelerants (rare, fire damage incl. burn x2 for the wave).
- Artifacts: Fuel Tank (+1 stack per burn application), Persistent Flames (burn decays 30% slower),
  Combustion (a killed burning enemy's stacks move to the nearest enemy).
