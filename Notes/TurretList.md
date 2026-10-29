# Turret List

Source of truth is `Buildings/TurretIndex.lua`; these notes mirror it.
Cost is in tokens (3 per wave by default). DPS is single-target, before upgrades
and buffs. Burst turrets include the burst delay in their cycle time.

## Common

### Sentry
- **Cost**: 1
- **Damage**: 11 (physical)
- **Range**: 420
- **Fire Rate**: 0.7
- **DPS**: 7.7
- **Description**: Balanced range and damage.

### Blaster
- **Cost**: 1
- **Damage**: 6 per bolt (energy), 3-bolt burst (0.1s apart)
- **Range**: 340
- **Fire Rate**: 0.63
- **DPS**: ~10.1 (18 per 1.79s cycle)
- **Description**: Fires energy bolts, effective against armor.

### Auto Cannon
- **Cost**: 1
- **Damage**: 5 (physical)
- **Range**: 190
- **Fire Rate**: 3.2
- **DPS**: 16.0
- **Description**: High fire rate, low damage, short range.

### Shotgun Turret
- **Cost**: 1
- **Damage**: 6 per pellet (physical), 8 pellets, 15 degree spread
- **Range**: 150 (100 degree arc)
- **Fire Rate**: 0.55
- **DPS**: 26.4 if every pellet hits (about half do at max range)
- **Description**: Shreds close-range targets.

### Heavy Gun
- **Cost**: 1
- **Damage**: 54 (physical)
- **Range**: 450
- **Fire Rate**: 0.15
- **DPS**: 8.1
- **Description**: Long range, high damage.

## Uncommon

### Icicle Ballista
- **Cost**: 1
- **Damage**: 26 (ice), up to +60% as chill nears freezing, +100% vs frozen
- **Range**: 420
- **Fire Rate**: 0.35
- **DPS**: 9.1 | 18.2 vs frozen
- **Description**: Heavy icicles that hit harder the more chilled the target is.

### Poison Turret
- **Cost**: 2
- **Damage**: 9 direct + poison 8/s for 4s (up to 4 stacks)
- **Range**: 300
- **Fire Rate**: 0.4
- **DPS**: 3.6 direct | ~16.4 including poison (41 per dart)
- **Description**: Fires toxic darts that damage over time.

### Airburst Turret
- **Cost**: 1
- **Damage**: 23 (physical) direct, or bursts at 60% of range into 5 shrapnel of 23 each (30 degree cone each side)
- **Range**: 300
- **Fire Rate**: 0.4
- **DPS**: 9.2 per hit | 46 if all shrapnel connects
- **Description**: Fires shells that explode mid-air into shrapnel.

### Flux Cannon
- **Cost**: 2
- **Damage**: 54 (energy)
- **Range**: 340
- **Fire Rate**: 0.33
- **DPS**: 17.8
- **Description**: Energy damage that ignores heavy armor.

### Grenadier
- **Cost**: 1
- **Damage**: 7 per grenade explosion (explosive, 60 radius, falls off to 25% at the edge), 3-grenade burst (0.2s apart), 0.7s fuse. Grenades never hit directly.
- **Range**: 200 - 380
- **Fire Rate**: 0.3
- **DPS**: ~5.6 to everything in the blast (21 per 3.73s cycle)
- **Description**: Lobs grenades that explode after a short delay.

### Slush Cannon
- **Cost**: 1
- **Damage**: 23 (ice) + 2 chill
- **Range**: 340
- **Fire Rate**: 0.396
- **DPS**: 9.1
- **Description**: Fires heavy clumps of slush that chill enemies.

## Rare

### Glacial Monolith
- **Cost**: 2
- **Damage**: None. One wave every 3s, 2 chill to every enemy the wave passes (18 degree ring inside a 28 degree arc, expands at 120 px/s)
- **Range**: 380
- **Fire Rate**: 0.33 waves/s
- **Description**: Area chill support; slowly builds chill on everything in its arc.

### Ice Shard Gunner
- **Cost**: 1
- **Damage**: 5 (ice) + 0.5 chill per hit
- **Range**: 350
- **Fire Rate**: 2.3
- **DPS**: 11.5 (freezes a lone target in ~5s)
- **Description**: Rapidly fires ice shards that chill enemies.

### GTR-55 Gator
- **Cost**: 2
- **Damage**: 54 (physical), pierce 3
- **Range**: 380
- **Fire Rate**: 0.55
- **DPS**: 29.7 per target (up to 3 in a line)
- **Description**: Hard hitting rounds go right through enemies.

### Missile Launcher
- **Cost**: 2
- **Damage**: 50 explosion (explosive, 40 radius) on impact. No separate direct-hit damage.
- **Range**: 340
- **Fire Rate**: 0.4
- **DPS**: 20.0
- **Description**: Slow (200 speed) missiles that explode on the first enemy they hit.

### Plasma Scattershot
- **Cost**: 2
- **Damage**: 11 per bolt (energy), 10 bolts, no pierce
- **Range**: 150
- **Fire Rate**: 1.6, 15 shots per magazine, 4s reload
- **DPS**: 176 while firing | ~129 sustained (both if every bolt hits)
- **Description**: Fires plasma rounds at high speed but has limited ammo. Reloads slowly.

### CSR-8 Sequence
- **Cost**: 2
- **Damage**: 18 (physical)
- **Range**: 340
- **Fire Rate**: 0.4, ramping to 4.8 (x12) over 8s locked on one target. Loses half its charge when it switches target.
- **DPS**: 7.2 | 86.4 fully ramped
- **Description**: Shoots faster the longer it stays locked onto a target.

### The Hook
- **Cost**: 1
- **Damage**: 72 (physical) + 1s stun
- **Range**: 270
- **Fire Rate**: 0.25
- **DPS**: 18.0
- **Description**: Fires a heavy shot that stuns enemies in their tracks.

## Epic

### Frost Cannon
- **Cost**: 1
- **Damage**: 12 per pellet (ice) + 0.5 chill, 6 pellets, 9.2 degree spread
- **Range**: 420
- **Fire Rate**: 0.8
- **DPS**: 57.6 if every pellet hits (~17 at max range)
- **Description**: Long range, tight spread shotgun. Its pellets chill enemies.

### Cryo Beam
- **Cost**: 1
- **Damage**: 6.25 per tick (ice), 4 ticks/s
- **Range**: 380
- **DPS**: 25.0 (freezes its target in 3s, then retargets after 0.3s)
- **Description**: Locks a freezing beam onto one enemy until it freezes, then moves to the next target.

### Sniper Turret
- **Cost**: 2
- **Damage**: 225 (physical, hitscan)
- **Range**: 225 - 550 (90 degree arc)
- **Fire Rate**: 0.1
- **DPS**: 22.5
- **Description**: High damage, long range.

### Mortar
- **Cost**: 2
- **Damage**: 90 explosion (explosive, 80 radius, falls off to 25% at the edge). Explodes on landing only.
- **Range**: 255 - 380
- **Fire Rate**: 0.115
- **DPS**: 10.35 to everything in the blast
- **Description**: KABOOM!

## Legendary

### PROJECT CHIMERA (Chain Laser)
- **Cost**: 3
- **Damage**: 27 (energy), then bounces to the nearest unhit enemy up to 5 times. Each bounce deals 10% less of the first hit: 90%, 80%, 70%, 60%, 50%.
- **Range**: 380
- **Fire Rate**: 0.5
- **DPS**: 13.5 single target | ~61 across a group (121.5 per shot)
- **Description**: No one is safe
