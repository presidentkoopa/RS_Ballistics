# RS_Ballistics

**The combat-effects generator for the UZDXREMA (DoomXR) mod family.** Data in
lumps turns into:
- real rounds in flight as **3D models** -- one mesh at eight sizes, so a buckshot pellet is a stub and a
  .30-06 tracer is a long fat streak, each round turning to face its own flight -- with vapour trails, heat
  shimmer, flight lights and near-miss whiz and crack
- muzzle flashes (every shot its own: sparks lean, spread and burn differently, powder burns redder or whiter), gunsmoke
  and a smoking, glowing barrel; point-blank powder burns, dust kicked off nearby walls, a shockwave of bent air, and
  gunshot tails
- spent casings and hulls, and chainsaw engine exhaust
- impacts by surface material: sparks, 3D chunks, dust, splinters, glints, splashes,
  marks and ricochets -- each round type with its own hit character; tech panels short out in arcs,
  screens crack and arc, lights pop, pipes vent steam, brick, marble and tile break into their own pieces
- room-filling smoke the guns, blasts, flames and rockets fill and the rounds tear; rockets and flames leave black soot (engine smoke volume)
- debris that bounces, collides with the whole level, patters as it lands and stays for the fight (engine collision and debris pool)
- lasting wall damage: bullet holes by material, gouges, craters, scorch rings, chainsaw cuts and flamethrower soot
  (engine surface damage)
- light from sparks, embers and tracers, and muzzle flashes that can throw shadows (engine effect lights)
- volumetric flashes and blasts: every gun's flash and every rocket, plasma and BFG blast as real glowing gas with depth
  that lights the haze, each gun its own shape (engine emissive volumes; the flat flame card and cone are the fallback)
- flamethrowers: a licking drawn-line core, flame that slides along what it hits,
  scorch and black smoke
- looks for plasma, rockets, the BFG, the railgun and the chainsaw
- enemy fire: monsters' hitscans fly as real rounds with our tracers, cracks and hits, or stay instant and are
  dressed in our looks; far fights draw lighter
- **recoil computed from real physics, not typed**: every gun's kick comes from bullet weight, muzzle
  velocity, powder charge and the loaded gun's weight, through free-recoil arithmetic. An MG42 and a Kar98k
  fire the same cartridge out of a 25 lb gun and a 9 lb gun and the file says so -- identical impulse,
  three times apart in energy. Guns with no cartridge (a BFG, a chainsaw, a spray can) state a kick instead,
  and stating it is a decision rather than an omission
- **fire that rides what it was set alight on**: a burning man burns while he runs and carries his own
  light with him, rather than leaving a scorch mark where he was standing
- **cold**, which is not warm fire: frost vapour that SINKS, ice that falls rather than burning out, a pale
  mark, and the one impact in the package that bends no air because there is no heat to shimmer
- **a jet that is not fire at all**: an inert aerosol -- no light, no heat, no scorch, no sound -- and the
  same jet ignited when something lights it
- three server rules: gameplay recoil for the guns that use it, whether our rounds also leave vanilla decals, and
  enemy hitscans as rounds

The same system covers everything from no effects at all to EXTREME, in VR. The
effects level (off, plain, normal, heavy, extreme) scales counts, lights, sizes,
smoke, shoves, shimmer, mark life, glow and tracers; `@extreme` profiles add what
only the top level shows. Effects are picked per player by level, style and menu
settings.

## Coverage

**1251 profiles. Every gun in every set has its own.**

| set | guns | what they name |
|---|---|---|
| Vanilla and Vanilla+ | 50 | the unprefixed house names -- these guns *are* the baseline. Their loads are inferred from named real-world equivalents (an Ithaca 37, a Beretta, a Tec-9) |
| WW2 and Brutal Wolfenstein | 50 | `ww2_*`, eleven real cartridges shared between the two sets |
| Blood | 12 | `bl_*` -- a flare that sticks and burns, a thrown lighter, a spray can with two jets |
| Bloom | 10 | `bm_*`, composed from Blood's cards and sharing them on purpose |
| HacX | 9 | `hx_*` -- a taser that arcs, a cryo gun that freezes |
| Aliens | 8 | `ae_*`, including a caseless 10mm that throws no brass at all |
| Cola | 8 | `cl_*` |
| Robocop | 8 | `rc_*` -- a compensated machine pistol, an anti-materiel cannon |

Plus the Modern/Breach guns, which live in their own package and name `glock17`, `mk18`, `mp5` and
their suppressed twins.

Nothing is wearing another set's clothes. Where a gun *does* share a profile it is stated with its
reason -- two tesla weapons should look the same, Cola's revolver is literally Vanilla+'s -- and
`tools/check_set_coverage.py` tells **borrowed** from **shared on purpose** from **its own**.

## What a gun gets, and what it must say

A gun names profiles on its sheet: `flashprofile`, `recoilprofile`, `roundprofile`, `ejectaprofile`.
Two rules matter more than the rest:

- **A stated absence is a decision; a missing key is a mistake.** `recoilprofile = "none"` means no
  kick. *Deleting* the line means the house default -- a real kick nobody chose. `none` exists for
  every kind a gun can name (`flash`, `recoil`, `ejecta`, `trail`), and each is short-circuited in
  code before the registry is consulted, so naming it never logs an error. A `none` that logs is not
  a `none`.
- **The look never decides the gameplay.** `damage = none`, `speed = none`, `radius = none` and
  `kick = none` all mean the same thing: this profile is being named for how it LOOKS, and the value
  belongs to the weapon. Without those hatches a cartridge came to decide a gun's damage and a look
  profile came to decide where its bullets went.

## Requirements

- **The UZDXREMA engine** (a private GZDoom 5.0 fork) at cf3dba0d6f or later.
  RS_Ballistics uses engine features plain GZDoom does not have: GPU particle
  definitions (`PARTICLEDEFS`, `SpawnParticles`, mesh particles, level collision,
  the debris pool), surface materials (`SURFACES`, `TexMan.GetSurface`), drawn-line
  looks (`SetDrawnLine*`), generated particle looks, heat shimmer
  (`SetHeatSource`), the smoke volume (`EmitSmoke` with soot, `CarveSmoke`,
  `PushEffectImpulse`), debris landing sounds (`landsound`), precaching
  (`+PRECACHEALWAYS`), surface damage (`PaintSurfaceDamage`, `DAMAGEDEFS`) and effect lights
  (`SpawnEffectLight`, PARTICLEDEFS `light` keys, `LF_CASTSHADOW`) emissive volumes (`VOLUMEDEFS`,
  `SpawnEmissiveVolume`) and the compressed particle atlas (BC7 DDS flipbooks). It will not load on other engines.
- Mods that fire its rounds or call its hooks (RS_VR_Reload, RS_VR_Weapons) require
  it and load after it.

## Load order

1. `RS_Ballistics`
2. `RS_VR_Reload`
3. `RS_VR_Weapons`

(The owner's full order has more mods around these; RS_Ballistics always loads
before the two that use it.)

## What is in the package

| Lump / folder | What it holds |
|---|---|
| `RSBDEFS` | Profiles: styles, bursts, impacts, rounds (ballistics + looks), wakes, flashes (incl. `sparkvary`, exhaust, charge), flames, trails, hotspots, ejecta, recoil. `<profile>@extreme` and the other level variants. Any loaded mod may ship its own; a later profile with the same name wins. |
| `PARTICLEDEFS` | GPU particle definitions: flame, smoke, dust, the textured spark library, 3D debris chunks (mesh), debris keys. |
| `SURFACES` | Which textures are metal, wood, glass, liquid, dirt, brick, marble, tile, pipe, tech, screen or light. |
| `textures` | Volumetric flipbooks for the engine's compressed particle atlas: RBVF, a raymarched fireball cooling to smoke (64 BC7 frames at 512, generated by `tools/gen_flipbooks.py`), drawn by the rocket and RPG blasts. |
| `DAMAGEDEFS`, `damage/rsb` | Wall damage brushes: generated masks (soot, depth, heat, wet), four variants each. |
| `VOLUMEDEFS` | Volumetric flash and blast looks (`emissive` blocks, class gun / biggun / blast), named by flash and impact profiles with `volume`. |
| `zscript/rsb` | The generator: parser, registry, bullets, impacts, flashes, barrel heat and exhaust, hotspots, casings, flamethrowers, recoil, previews, benchmarks. |
| `MENUDEF`, `CVARINFO`, `KEYCONF` | Options -> Ballistics & Effects: every look has a setting, "All effects on", Recoil under GAMEPLAY, Preview and Benchmarks rows. |
| `sounds`, `sprites`, `models` | Impact, ricochet, whiz, crack, casing, flame, debris landing and gunshot tail sounds; tracer, casing, flash, spark and smoke sprites; casing, rocket and debris models. |
| `tools` | Generators and importers (casings, chunks, wall damage brushes, sparks, the rocket voxel, debris sounds, the surface pass), the per-set profile generators, `cartridges.py` (the one canonical load table), `gun_weights.py` (every weight this package holds, with its provenance) and the checkers below. |

A bad profile is refused and named with its lump and line; the rest still load.

## Checks

Every one of these exists because something shipped broken while looking fine.

| tool | what it refuses |
|---|---|
| `tools/boot_verify.ps1` | packs to scratch, boots in the owner's load order and **fails on any refused profile**. A boot test can report GREEN with twelve profiles dead -- the level still runs. |
| `tools/model_lint.py` | a round naming a model frame with no MODELDEF block, no sprite lump, or no block on *both* round classes. MODELDEF binds to one class and **not its children**, so a subclass draws nothing, silently. Run by `build.ps1`. |
| `tools/check_set_coverage.py` | reads the **installed pk3**, not the source, and reports tuned / borrowed / shared-on-purpose / house / broken per set. |
| `tools/trace_set_wiring.py` | follows every gun to the leaves -- flash to tail sound, ejecta to casing sound, round to whiz and every material's impact sound. |
| the generators | refuse to write a sound name `SNDINFO` does not declare. A dead sound name is silent and looks exactly like a working one. |

Each guard has been deliberately broken to watch it fire. A guard nobody has exercised is a guess.

## Netplay

- What the game knows about a round (speed, size, damage) comes only from its
  `ballistics` profile, identical on every machine, with no player setting.
- Gameplay recoil is decided in the weapon's own action on every machine, from the
  map clock, the shot count, crouching and the owner's speed; `sv_rsb_recoil` is a
  server switch; recoil profiles have no local variants.
- Vanilla decals on our rounds are a server rule too (`sv_rsb_decals`, off): decals are playsim
  thinkers, so no player's own wall damage setting decides them.
- Every look is presentation for the machine that draws it: no playsim RNG (hashes
  instead), nothing a netgame compares, never read back by gameplay.
- Anything tied to a player is keyed by its owner, never `consoleplayer`.
- **Nothing here moves the camera.** `RSB_Recoil.View` and `ViewJolt` return the kick the *drawn gun*
  carries and the only consumer applies it to the prop's hand offset. In VR the camera is the headset,
  so a jolt we compute fights the player's inner ear -- the engine's own `A_Recoil` carries the same
  warning. Recoil is a torque spent on things you look AT, never the thing you look THROUGH.

## What other mods can ask it

`RSB_Service` publishes what a shot does, so no lane has to be handed a stale table:

```
GetDouble("recoil.impulse", "ww2_mg42")     lb-s out of the muzzle -- what pushes an arm
GetDouble("recoil.energy",  "ww2_mg42")     ft-lb -- what stops it
GetDouble("recoil.vg",      "ww2_mg42")     fps the gun itself goes backwards
GetDouble("recoil.climb",   "ww2_mg42")     degrees up per shot
GetDouble("cartridge.roundlb", "ww2_762tok")  what ONE loaded round weighs
GetString("profiles") / GetInt("count", kind) / GetInt("has", name, 0,0,null,'kind')
```

**Zero means no data, not no recoil.** Twenty-six profiles have no cartridge and state nothing rather
than an invented load; a consumer reading zero as "this gun does not kick" stops moving for every
energy weapon in the game. `climb` is stated for all of them. An unknown *name* also returns zero, so
check with `GetInt("has", ...)` when a name is built at runtime.

Round mass times the magazine is why a PPSh with 71 rounds in the drum is a seventh heavier than an
empty one, and gets lighter and kickier as it empties -- one number, no second system.

## Build

```
powershell -File build.ps1
```

`build.ps1` lints the menu, packs `RS_Ballistics.pk3` from an allowlist, verifies
the entries and runs a compile check against the reload system. It expects the
owner's `E:\DOOMWork` layout (the shared tools folder and the engine build).

## Assets and credits

- **Sounds and sprites** come from the owner's permitted asset pools: the RS_Main
  asset folders and the owner's ART SOURCE library, matched by hash on 2026-09-14.
  `ASSETS.md` lists each effect sprite's, debris sound's and gunshot tail's source.
- **Generated by this package, owned outright:** the debris sprites (chips,
  splinters, clods, glass shards), and the 9mm, .45 and .357 casings and the
  12-gauge shell (`tools/gen_casings.py`), and the 3D debris chunks
  (`tools/gen_chunks.py`: concrete, wood, metal, glass and dirt), and the wall
  damage brushes (`tools/gen_brushes.py`).
- **The rocket in flight** (`models/rocket/rocket.kvx`) is RS_Main's
  `voxels/MISLA.kvx`, copied unchanged (`tools/import_rocket_voxel.py`); the same file is in
  the DXR engine's own static resources, and neither records its author.
- **Force Unleashed**, Ermac's (iAmErmac) VR mod, under the MIT License
  (`licenses/force_unleashed_MIT.txt`): the rifle casing
  (`models/casings/casing_rifle.md3`) is its chaingun belt round with the bullet cut
  off and rescaled to a real case. Force Unleashed's own README credits Brutal Doom
  and Sketchfab authors for its assets.

## Design docs

The engine design documents live in the owner's `Engine docs` folder, not in this
repository: `RS_BALLISTICS_PLAN.md`, `ENGINE_SUPPORT_LIST.md`,
`GPU_PARTICLES_STAGE2_PLAN.md`, `FLAME_ENGINE_PLAN.md`, `SURFACE_MATERIALS_PLAN.md`,
`SMOKE_VOLUME_PLAN.md`, `COLLISION_DEBRIS_MESH_PLAN.md`, `SURFACE_DAMAGE_PLAN.md`,
`WALL_DAMAGE_ART_PLAN.md`. This package's own plans are in `_staged/`: collision and
debris, debris sounds, smoke tuning, recoil, enemy ballistics.

Cross-lane papers in `Engine docs`: `PROPOSAL_GUN_WEIGHT_AND_RECOIL.md` (weight as a real property,
kick computed at the shot), `GUN_WEIGHTS_HANDOVER.md` (66 gun weights with their provenance, and the
empty-weight conversion), `RECOIL_TO_BODY_FINDINGS.md` (co-signed with the Body IK lane),
`CROSSPLATFORM_COOP_RULE.md`. `THE_BALLISTICS_LANE.md` beside this file is the lane's own account,
failures included.

---

## Making a profile

*How a gun gets its ballistics in this package. Every rule here was paid for once — the cost is in
the margin, because a rule without its reason is a rule somebody deletes.*

---

### 1. What a gun names

A gun's WMSHEET row names up to four profiles:

```
gun "BW_Kar98"
  flashprofile         = "ww2_kar98k"     the muzzle: light, cone, bursts, flame, smoke, tail
  recoilprofile        = "ww2_kar98k"     the kick, and where the rounds go
  ejectaprofile        = "ww2_kar98k"     the brass
  roundprofile         = "ww2_792"        the round in flight, and what it does when it lands
  baseweight           = 8.60             the EMPTY gun, in pounds
```

A `round` is a pairing:

```
round ww2_792
  ballistics = ww2_792      speed, radius, damage, roundmass   — the same on every machine
  roundlook  = ww2_792      model, wake, whiz, impact family, trail — local, per player
end
```

That split is load-bearing. **Ballistics is what the game knows; a roundlook is what a player sees.**
A look profile must never decide where a bullet goes — it did once, and a cartridge once decided a
weapon's damage, which is why `damage = none`, `speed = none`, `radius = none` and `kick = none` all
exist.

**Flame guns name nothing on the sheet.** `WM_FlameGun.FlameProfile()` is a virtual, so the *decision*
lives in code and the *names* stay data. The spray can needs that: which jet comes out depends on
whether a lit lighter is in front of the nozzle, and a sheet key can only ever state one name.

---

### 2. The kick is derived, never chosen

Four real figures in, one number out:

```
Vg      = (bullet_grains × muzzle_fps + 4700 × charge_grains) / (7000 × loaded_lb)    fps
energy  = loaded_lb × Vg² / 64.348                                                    ft-lb
impulse = loaded_lb × Vg / 32.174                                                     lb·s
climb   = Vg × 0.148 × ACTION[action]                        capped at 4.2 degrees
```

`ACTION` — how much of the gun's rearward velocity reaches your aim rather than the floor or a bipod:

| bolt | break | pump | revolver | semi | auto | belt | harness |
|---|---|---|---|---|---|---|---|
| 1.55 | 1.50 | 1.45 | 1.20 | 1.15 | 0.85 | 0.45 | 0.25 |

Shared by every generator. Never fork it — the whole point is that all eleven sets sit on one scale.

#### Five things that are easy to get wrong

**Loaded weight, not empty.** A full magazine is a fifth of a Glock. Using empty weights once put a
Glock *above an Ithaca 37* on climb, which is how the mistake was found.
`loaded = baseweight + capacity × roundmass / 7000`. The sheet's `baseweight` is the **empty** gun.

**Impulse is a cartridge fact; energy and Vg are gun facts.** Weight cancels out of impulse. The MG42
and the Kar98k fire the same 7.92×57 out of a 25 lb gun and a 9 lb gun: **identical impulse 3.173,
energy 18.2 against 6.3**. Any model of weight or body reaction has to survive that pair — it is the
one that feels wrong in both directions if you key off energy.

**Muzzle velocity is not a property of a cartridge.** Barrel length changes it. This package holds
**29 distinct loads across 13 cartridges** — 5.56 runs 3020 fps out of a rotary and 2560 out of a
G36C; 9×19 runs 1250 from an MP40 and 1050 subsonic. Flattening them onto the cartridge to tidy a
table would change sixteen guns' kick for nothing.

**The authored weight is recoverable.** `impulse × 32.174 / vg` returns the weight a stated climb was
written at — the Kar98k comes back 8.90 lb against a table that says 8.90. That is how live-weight
kick scales with no new data, and why it is *identical at a full magazine* and only grows as the gun
empties.

**A gun with no cartridge states its kick.** A BFG, a chainsaw, a spray can, a flamethrower. Inventing
a load so the arithmetic will run is false precision, and stating a number is a decision rather than
an omission.

---

### 3. Generators own their blocks

Profiles are generated, not hand-written. `tools/gen_*_profiles.py` per set, and:

> **A generator owns its blocks. Any line it does not emit, it deletes.**

`roundmass` was written into eleven WW2 cartridges by a one-off script. Every re-run of the generator
erased it again — **ten of eighteen gone, silent for four commits**. The profile still parsed, the
boot still went green, the coverage checker still read every gun as tuned, because *a missing optional
key is indistinguishable from a key nobody wanted*. Only a gun firing in a live level noticed.

So: never hand-edit a generated block. Teach the generator.

Four more rules with the same shape:

- **`tools/cartridges.py` holds the only copy** of what a round weighs. A second copy is how the
  first one gets lost.
- **Guard `main()`.** Importing a generator *runs* it — one import to borrow a function rewrote
  RSBDEFS and reverted eleven roundlooks mid-edit.
- **Refuse to write** rather than emit something dead: a sound name `SNDINFO` does not declare, or a
  bounded value past its ceiling (soot is 0..1, a lick's strengths 0..2). The parser refuses the whole
  profile, correctly — five died on a green boot before the ceilings existed.
- **`[ \t]+`, never `\s+`**, when matching a profile header. `\s` matches a newline, so `end` swallows
  the header after it: six of ninety recoil profiles survived one such scan, and the tool then
  reported 84 guns as needing work that was already done.

---

### 4. Absence is a statement

```
recoilprofile = "none"      no kick at all — stated
(key omitted)               the HOUSE RECIPE: a real flash and a real kick on a pitchfork
```

Those are not the same thing, and the second is the trap. Melee (slot 1) and thrown (slot 9) weapons
must **state** `none`; so must a caseless gun's `ejectaprofile`. `none` exists for `flash`, `recoil`,
`ejecta` and `trail`, and for the keys `damage`, `speed`, `radius` and `kick`.

Each `none` is short-circuited in code *before* the registry is consulted — **a `none` that logs is not
a `none`.** Naming one used to write an error every map, which is how you teach people to ignore the
log.

There is deliberately **no `round none`**. A kick and a casing are things a shot *may* have; the round
*is* the shot. A gun that fires nothing of ours simply names no roundprofile.

---

### 5. `@extreme`

The effects dial (off / plain / normal / heavy / extreme) scales everything globally. An `@extreme`
variant adds what only the top setting shows.

> **More, never longer.** Brightness, thickness, count, radius, reach rise. Every duration is left
> exactly alone.

A flash that outlives its own shot stops reading as a flash — that was tried once and seen
immediately. The flare's fire at extreme throws 20 bursts a second instead of 14 with a bigger light
and a wider mark, and burns for the same fifteen seconds.

**Recoil never gets one.** It decides where bullets go, and the effects dial is a per-player look
setting — a kick that followed it would be two people in the same game disagreeing about where a
bullet went.

---

### 6. Proving it

**A name resolving proves nothing.** Every check below exists because something shipped broken while
looking fine, and every guard has been deliberately broken to watch it fire.

| tool | what it refuses |
|---|---|
| `tools/boot_verify.ps1` | any refused profile — a boot test can report GREEN with twelve profiles dead |
| `tools/model_lint.py` | a model frame with no MODELDEF block, no sprite lump, or missing on a subclass |
| `tools/cartridge_lint.py` | a gun naming a cartridge with no round mass — checked both directions |
| `tools/check_set_coverage.py` | reads the **installed pk3**; tuned / borrowed / shared-on-purpose / broken |
| `tools/name_the_guns.py` | guns not naming a profile that already exists |
| `rsb_shotreport` | prints what actually **drew** this map, counted where effects happen |
| the generators | a sound name `SNDINFO` does not declare |

The first three run inside `build.ps1`, so the pack cannot be built past them.

---

### 7. The shape behind all of it

Every rule on this page is the same defect wearing different clothes:

> **A thing that is missing looks exactly like a thing that is fine.**

A dead sound name is silent. A refused profile is a name that does not exist while looking like one
that does. An unnamed key takes the house recipe. A model bound to a parent class draws nothing on the
child. An erased `roundmass` parses perfectly. A checker blind to a whole package reports zero
problems.

Write the thing down, then write the check that refuses its absence.

---

*See also `THE_BALLISTICS_LANE.md` (what this lane got wrong and what caught it) and
`Engine docs/PROPOSAL_GUN_WEIGHT_AND_RECOIL.md`.*
