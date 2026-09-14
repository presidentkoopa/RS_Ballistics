# STAGED -- #8 collision and #9 stay-debris: what RS_Ballistics' particles do

**For:** the build lane. **Not wired.**

**#8 final keys** (build lane, #8 COHERENT, building with 13c + IK):
- `collide = none | plane | level`. "field" below means `level`.
- Fading once deeper than 1-2 map units is built in, with no key.
- Mesh chunks on `level` keep #10's plane landing until #9.

**Wire only `collide = level` after the build's "done":** scratchpad collide_level_apply.py
(`--dry` to report). `restitution`, `friction`, `restlife` and `restfade` wait for #9: the
parser drops a whole definition with an unknown key.

**#9 hook:** no SpawnDebris native. A definition with `restitution` sends its SpawnParticles
bursts to the pool. `restlife` off means never rest; `restlife = 1.5` gives embers.

**Limits:** walls under 4 units leak (8-unit doors hold). 3D-floor sides, midtextures and
polyobjects aren't in the field.

**The owner's answers this follows:**
- **Answer 7:** resting debris stays 60 s, in a 16,384-piece pool, with sliders.
- **Answer 9:** a spark deeper in a wall than its radius fades instead of popping through.
- **Effects on,** high quality.
- **The colour rule:** a resting ember may glow only while it cools.

## 1. Every definition, by group (87 today)

| Group | Definitions | #8 collide | #9 rest | Restitution / friction | Rest life |
|---|---|---|---|---|---|
| **3D chunks: concrete** | chunk_concrete_chip1-8, slab1-3, rubble1-3 | field | yes | chips 0.25 / 0.6; slabs, rubble 0.15 / 0.8 | 60 s |
| **3D chunks: wood** | chunk_wood_splinter1-5, plank1-2, woodchip1-3 | field | yes | 0.35 / 0.5 (light, skittering) | 60 s |
| **3D chunks: metal** | chunk_metal_shard1-5, strip1 | field | yes | 0.3 / 0.35 | 60 s |
| **3D chunks: metal** | chunk_metal_nut1 | field | yes | 0.45 / 0.3 (bounces and rolls) | 60 s |
| **3D chunks: glass** | chunk_glass_shard1-5, sliver1-2 | field | yes | 0.2 / 0.25 (slides) | 45 s (small, many) |
| **3D chunks: dirt** | chunk_dirt_clod1-5 | field | yes | 0.05 / 0.9 (thud and stop) | 45 s |
| **3D chunks: dirt** | chunk_dirt_pebble1-3 | field | yes | 0.4 / 0.5 | 60 s |
| **Flat debris** (the older flat-card pieces) | debris_chip, debris_splinter, debris_clod, debris_shard | field | yes, shorter | 0.2 / 0.7 | 20 s |
| **Sparks** (bore and impact) | spark_streak, spark_photo, spark_star, spark_speck, spark_sparkler, spark_impact, spark_ricochet, spark_spray | field: bounce, and fade when deep in a wall | no | 0.35 / 0.15 (skitter, then die on their life) | -- |
| **Embers** (hot beads) | spark_ember, ember_metal | field | yes, briefly: glowing on the floor as they cool | 0.2 / 0.6 | 1.5 s, then fade |
| **Energy** | arc, plasma_glow(_small), bfg_glow(_heavy), bfg_wave, rail_mote, rocket_motor | none (in the air, light only) | no | -- | -- |
| **Fire** | flame_puff, flame_tip, flame_lick, fireball, muzzle_plume(_dirty) | keep today's plane (flames lick the surface they land on); no field | no | -- | -- |
| **Dust and soot off a surface** | dust_concrete, dust_wood, dust_dirt, soot_puff, smoke_flame | keep today's plane (dust settles on the floor it came off); no field -- a deliberate soft reading of "dust doesn't collide": a plane test is free, and dust sinking through the floor shows | no | -- | -- |
| **Smoke and vapour in the air** | smoke_gun, smoke_rocket, smoke_port, smoke_barrel, smoke_barrel_soot, smoke_soot_gun, bullet_vapour, casing_wisp | none (room smoke is 13b's volume) | no | -- | -- |

**Casings** are RSB_LocalEjecta actors today, not particles, capped at 300 (`rsb_casing_max`).
They move into the debris pool when single-surface casing meshes exist (≤ 64 triangles, one
atlased skin: the #10 casing survey). Parked.

## 2. The pool: what a fight spends

From RSBDEFS today: chip, splinter and clod bursts are 9-10 pieces, times the impact's count
scale, with `vary count` about ±50% a hit (the average holds). Glass throws 14.

| Source (into concrete) | Pieces | How |
|---|---|---|
| a pistol round | about 8 a hit | chips_concrete 9 × 0.9 |
| buckshot, 7 pellets | about 28 a shot | 9 × 0.45 each |
| a Super Shotgun blast, 20 pellets | about 110 a shot | buckshot_magnum 9 × 0.6 each |
| the chaingun | about 63 a second | 9 × 0.8 a hit, at vanilla's 8.75 shots a second: about 3,800 in a minute of held fire |
| a rocket or a BFG blast | about 16 | chips 9 + slabs 4 + rubble 3 (metal: 6 shards) |

**Steady state** is the spawn rate × the rest life. A chaingun held for a whole minute keeps
about 3,800 resting pieces, 23% of 16,384. Two heavy guns at once is about half the pool.
Enemy impacts (later) add to this.

**When it fills,** the pool recycles the oldest resting pieces first, so a long fight thins
out the far past, not the present. The ~110 pieces a Super Shotgun blast throws are the
biggest single spend. If recycling ever shows, the fix is data: lower the count scale for
chips (not the pool), or shorten flat-debris rest life.

## 3. What I'll need from the #8 and #9 "done"

- **Keys:** the final collide value for the field, plus restitution, friction and restlife
  names and ranges.
- **Casing entry:** whether `SpawnDebris` replaces the spawn for resting chunks (bursts would
  name a debris definition), or whether a definition's `restlife` makes `SpawnParticles` hand
  it to the pool.
- **Groups:** whether a definition can say "never rest" (sparks) and "rest briefly, then fade"
  (embers).
