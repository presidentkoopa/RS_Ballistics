# RS_Ballistics

**The combat-effects generator for the UZDXREMA (DoomXR) mod family.** Data in
lumps turns into:
- real rounds in flight, with tracers, vapour trails, heat shimmer and near-miss whiz and crack
- muzzle flashes (every shot its own: sparks lean, spread and burn differently, powder burns redder or whiter), gunsmoke
  and a smoking, glowing barrel; point-blank powder burns, dust kicked off nearby walls, a shockwave of bent air, and
  gunshot tails
- spent casings and hulls, and chainsaw engine exhaust
- impacts by surface material: sparks, 3D chunks, dust, splinters, glints, splashes,
  marks and ricochets -- each round type with its own hit character
- room-filling smoke the guns, blasts, flames and rockets fill and the rounds tear; rockets and flames leave black soot (engine smoke volume)
- debris that bounces, collides with the whole level, patters as it lands and stays for the fight (engine collision and debris pool)
- lasting wall damage: bullet holes by material, gouges, craters, scorch rings, chainsaw cuts and flamethrower soot
  (engine surface damage)
- light from sparks, embers and tracers, and muzzle flashes that can throw shadows (engine effect lights)
- flamethrowers: a licking drawn-line core, flame that slides along what it hits,
  scorch and black smoke
- looks for plasma, rockets, the BFG, the railgun and the chainsaw
- two server rules: gameplay recoil for the guns that use it, and whether our rounds also leave vanilla decals

The same system covers everything from no effects at all to EXTREME, in VR. The
effects level (off, plain, normal, heavy, extreme) scales counts, lights, sizes,
smoke, shoves, shimmer, mark life, glow and tracers; `@extreme` profiles add what
only the top level shows. Effects are picked per player by level, style and menu
settings.

## Requirements

- **The UZDXREMA engine** (a private GZDoom 5.0 fork) at 8950092f88 or later.
  RS_Ballistics uses engine features plain GZDoom does not have: GPU particle
  definitions (`PARTICLEDEFS`, `SpawnParticles`, mesh particles, level collision,
  the debris pool), surface materials (`SURFACES`, `TexMan.GetSurface`), drawn-line
  looks (`SetDrawnLine*`), generated particle looks, heat shimmer
  (`SetHeatSource`), the smoke volume (`EmitSmoke` with soot, `CarveSmoke`,
  `PushEffectImpulse`), debris landing sounds (`landsound`), precaching
  (`+PRECACHEALWAYS`), surface damage (`PaintSurfaceDamage`, `DAMAGEDEFS`) and effect lights
  (`SpawnEffectLight`, PARTICLEDEFS `light` keys, `LF_CASTSHADOW`). It will not load on other engines.
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
| `SURFACES` | Which textures are metal, wood, glass, liquid or dirt. |
| `DAMAGEDEFS`, `damage/rsb` | Wall damage brushes: generated masks (soot, depth, heat, wet), four variants each. |
| `zscript/rsb` | The generator: parser, registry, bullets, impacts, flashes, barrel heat and exhaust, hotspots, casings, flamethrowers, recoil, previews, benchmarks. |
| `MENUDEF`, `CVARINFO`, `KEYCONF` | Options -> Ballistics & Effects: every look has a setting, "All effects on", Recoil under GAMEPLAY, Preview and Benchmarks rows. |
| `sounds`, `sprites`, `models` | Impact, ricochet, whiz, crack, casing, flame, debris landing and gunshot tail sounds; tracer, casing, flash, spark and smoke sprites; casing, rocket and debris models. |
| `tools` | Generators and importers: casings, chunks, wall damage brushes, sparks, the rocket voxel, debris sounds. |

A bad profile is refused and named with its lump and line; the rest still load.

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
