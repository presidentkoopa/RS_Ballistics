# RS_Ballistics

**The combat-effects generator for the UZDXREMA (DoomXR) mod family.** It turns
data into:
- rounds in flight
- muzzle flashes, smoke and sparks
- casings
- impacts by material

The goal is everything from no effects at all up to F.E.A.R., Trepang2, Selaco
and Max Payne-level spectacle, in VR.

## Status

- **M1 done:** profiles (`RSBDEFS`), the parser that refuses a bad profile by
  lump and line, the registry, the service, `rsb_log`.
- **M2 done:** styles, bursts, materials, impacts by surface, the profile-driven
  bullet, flash and casings, near-miss whiz, and the customization menu with
  Preview.
- **In this batch:**
  - **Flamethrowers:** `flame` profiles, `RSB_Flame.Stream / StopStream / Pilot`, a
    Preview button and a menu page.
  - **Casings:** local by default (`shared: false`) for netplay.
  - **Profiles:** six more gun profiles.
- **Next:** the reload system's call sites (main lane), then the engine's
  particle stage 2 (textured, lit smoke; heat shimmer).

The owner-approved direction is that the heavy machinery (particles, smoke volume,
surface damage, materials, the world clock) moves into the engine, GPU-driven.
This package keeps the content: recipes, looks, presets, menus. Until each
engine piece lands, the ZScript here is the working prototype and the spec.

## Load order

1. `RS_Ballistics`
2. `RS_VR_Reload`
3. `RS_VR_Weapons`

## Build

```
powershell -File build.ps1
```

`build.ps1` lints the menu, packs `RS_Ballistics.pk3` from an allowlist, verifies
the entries, and runs the shared compile check with the reload system.
In the owner's setup, builds are run by the main lane.

## Rules this package keeps

- **Netplay:** cosmetic effects never use playsim RNG (a local hash instead), and
  anything that changes the game is keyed by its owner, never `consoleplayer`.
- **Assets:** only from the owner's licensed pools. Nothing copied from other
  games or mods.
- **Errors:** a bad profile is refused and named, never silently defaulted.

## Docs

The design documents live in `E:\DOOMWork\Engine docs\`:
- `RS_BALLISTICS_PLAN.md`: this package
- `ENGINE_SUPPORT_LIST.md`: the engine list and where everything lives
- `COMBAT_SPECTACLE_PLAN.md`: the combat spectacle plan
- `SLOWMO_PLAN.md`: slow-mo
- `SELACO_STUDY.md`: the Selaco study
