# RS_Ballistics

**The combat-effects generator for the UZDXREMA (DoomXR) mod family.** Data in
lumps turns into:
- real rounds in flight, with tracers and near-miss whiz and crack
- muzzle flashes, gunsmoke and sparks
- spent casings and hulls
- impacts by surface material: sparks, chips, dust, splinters, glints, splashes,
  marks and ricochets
- flamethrowers: a licking drawn-line core, flame that slides along what it hits,
  scorch and black smoke
- looks for plasma, rockets, the BFG, the railgun and the chainsaw

The same system covers everything from no effects at all to heavy spectacle, in
VR. Effects are picked per player by style, effects tier and menu settings.

## Requirements

- **The UZDXREMA engine** (a private GZDoom 5.0 fork) at 463098530b or later.
  RS_Ballistics uses engine features plain GZDoom does not have: GPU particle
  definitions (`PARTICLEDEFS`, `SpawnParticles`), surface materials (`SURFACES`,
  `TexMan.GetSurface`) and drawn-line looks (`SetDrawnLine*`). It will not load on
  other engines.
- Mods that fire its rounds (RS_VR_Reload, RS_VR_Weapons) require it and load
  after it.

## Load order

1. `RS_Ballistics`
2. `RS_VR_Reload`
3. `RS_VR_Weapons`

## What is in the package

| Lump / folder | What it holds |
|---|---|
| `RSBDEFS` | Profiles: styles, bursts, impacts, rounds (ballistics + looks), wakes, flashes, flames, ejecta. Any loaded mod may ship its own; a later profile with the same name wins. |
| `PARTICLEDEFS` | GPU particle definitions: flame puffs, smoke, dust. |
| `SURFACES` | Which textures are metal, wood, glass, liquid or dirt. |
| `zscript/rsb` | The generator: parser, registry, bullet, impacts, flashes, casings, flamethrowers, previews, benchmarks. |
| `MENUDEF`, `CVARINFO` | Options → RS Ballistics: every look has a setting, plus Preview and Benchmarks rows. |
| `sounds`, `sprites` | Impact, ricochet, whiz, crack, casing and flame sounds; tracer, casing, flash and smoke sprites. |

A bad profile is refused and named with its lump and line; the rest still load.

## Netplay

- What the game knows about a round (speed, size, damage) comes only from its
  `ballistics` profile, identical on every machine, with no player setting.
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

## Assets

Every sound and sprite here comes from the owner's permitted asset pools: the
RS_Main asset folders and the owner's ART SOURCE library. Each file was matched by
hash against those pools on 2026-09-14. Nothing is taken from other released mods.

## Design docs

The design documents live in the owner's `Engine docs` folder, not in this
repository: `RS_BALLISTICS_PLAN.md`, `ENGINE_SUPPORT_LIST.md`,
`GPU_PARTICLES_STAGE2_PLAN.md`, `FLAME_ENGINE_PLAN.md`, `SURFACE_MATERIALS_PLAN.md`.
