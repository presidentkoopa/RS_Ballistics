# STAGED -- smoke tuning: the numbers RS_Ballistics sends 13b

**For:** the build lane, ahead of the first 13c build. **Not applied.** The owner is testing,
and changes wait for their list.

**Every number below is a first guess, to tune in the headset.** "Live" is what the installed
pack (bb1c162) sends today.

## 0. How to read the numbers

These follow SMOKE_13B_IMPL_NOTES.md. One `EmitSmoke` ball of `radius` r and `amount` a:

- **How visible one fresh puff is:** τ = a × r / 60 through its centre, at absorption 1. The
  weight (1 − d²/r²)² integrates to 16/15 r along a line. The share of light that gets
  through is T = e^−τ:

  | τ | 0.1 | 0.2 | 0.35 | 0.5 | 1.0 | 2.0 |
  |---|---|---|---|---|---|---|
  | T (share of light through) | 0.90 | 0.82 | 0.70 | 0.61 | 0.37 | 0.14 |

- **How much it adds to a room:** its mass is M ≈ a × r³ (density × map units³).
- **Held fire:** the cloud's density is ΣM × keep / its volume. Across L units,
  T = e^(−density × L / 64). At dissipation 0.15/s, steady emission keeps
  (1 − e^−0.15t) / 0.15t of its mass: **0.66 after 6 s, 0.52 after 10 s**. The half-life is
  4.6 s.
- **The grid limit:** cells are 8 units at default quality. A radius under 6 u (MIN_RADIUS
  0.75 cells) is widened and thinned so the mass is kept. So a puff under ~8 u buys nothing,
  and most of today's per-shot radii (5-7) are too small to read.
- **The design rule this gives:**
  - How visible one puff is grows with a × r. How much haze builds grows with a × r³.
  - **Showpiece guns** (pistols, revolvers, shotguns): small dense puffs, each shot a
    visible ball.
  - **Full auto:** wide thin blooms. Each shot is faint, and the mass still builds a haze.

## 1. Muzzle smoke per gun: flash `smokevolume = radius, amount, heat, speed[, along]`

**How the code places it:** the centre sits `along + r/2` ahead of the muzzle. Velocity is
the barrel × speed. The amount is multiplied by the per-shot `vary smoke` wobble, by `surge`,
and by the player's "Flash smoke" (`rsb_flash_smoke`, default 1).

| Flash | Live | Live τ | **First guess** | τ (T), fresh | M |
|---|---|---|---|---|---|
| **pistol_9mm** (showpiece) | 6, 0.3, 0.4, 60 | 0.03 | **14, 1.3, 0.5, 90, 6** | 0.30 (0.74) | 3.6k |
| **pistol_45** (showpiece: fatter, slower) | 7, 0.4, 0.4, 60 | 0.05 | **16, 1.3, 0.5, 80, 6** | 0.35 (0.71) | 5.3k |
| revolver (the legacy flash has no key yet; add with its own flash) | -- | -- | **18, 1.5, 0.6, 70, 6** | 0.45 (0.64) | 8.7k |
| shotgun_m37 | 12, 0.9, 0.8, 140 | 0.18 | **20, 1.0, 0.8, 160, 8** | 0.33 (0.72) | 8.0k |
| shotgun_doom | 14, 1.1, 0.8, 120 | 0.26 | **22, 1.1, 0.8, 140, 8** | 0.40 (0.67) | 11.7k |
| shotgun_bullpup | 16, 1.4, 1.0, 110 | 0.37 | **24, 1.2, 1.0, 130, 8** | 0.48 (0.62) | 16.6k |
| **shotgun_ssg** (the train wreck) | 20, 1.8, 1.2, 160 | 0.60 | **32, 1.5, 1.2, 200, 12** | 0.80 (0.45) | 49k |
| chaingun_556 (full auto) | 5, 0.18, 0.4, 60 | 0.015 | **24, 0.4, 0.4, 60, 12** | 0.16 (0.85) | 5.5k |
| machinegun_762 (full auto) | 6, 0.3, 0.5, 60 | 0.03 | **26, 0.45, 0.5, 70, 12** | 0.20 (0.82) | 7.9k |
| smg (legacy, add with its own flash) | -- | -- | **16, 0.35, 0.4, 70, 6** | 0.09 (0.91) | 1.4k |
| rifle (legacy, add with its own flash) | -- | -- | **14, 0.8, 0.5, 100, 6** | 0.19 (0.83) | 2.2k |
| launcher_40mm (a low-pressure thump) | 12, 1.0, 0.6, 60 | 0.20 | **20, 1.2, 0.4, 50, 6** | 0.40 (0.67) | 9.6k |
| rocket_launcher | 18, 1.6, 1.6, 90 | 0.48 | **24, 1.4, 1.2, 90, 8** | 0.56 (0.57) | 19k |
| rocket_rpg (the backblast, 51.5 behind) | 24, 2.4, 1.6, 220, −51.5 | 0.96 | **36, 1.6, 1.6, 220, −51.5** | 0.96 (0.38) | 75k |
| plasma, bfg_9000, bfg_heavy | none | -- | **none** (energy burns no powder; the blast makes the smoke) | -- | -- |

The Double Barrel's profile stays in the pack unused (the gun left the arsenal).

## 2. Impact dust per material: impact `smokevolume = radius, amount, heat`

**How the code places it:** the centre is `surface + normal × r/2`, velocity `normal × 20`.

**Live** (pistol_9mm, pistol_45, chaingun_556, machinegun_762, buckshot, buckshot_magnum):
concrete 6, 0.12, 0; wood 6, 0.1, 0; dirt 6, 0.18, 0. That's τ 0.01 and M 26: invisible.

**First guess, a base per material.** Dust has no heat: it hangs and drifts up only slowly.

| Material | Base (a pistol round) | τ (T) | M |
|---|---|---|---|
| stone / concrete (default variant) | **14, 0.8, 0** | 0.19 (0.83) | 2.2k |
| wood | **12, 0.5, 0** | 0.10 (0.90) | 0.9k |
| dirt | **16, 0.9, 0** | 0.24 (0.79) | 3.7k |
| metal, glass, liquid | **none** (sparks, glints, splashes; no dust) | -- | -- |
| flesh | later, with enemy impacts | -- | -- |

**Per family, the amount × the base** (the radius stays):

| Family | Amount × | Notes |
|---|---|---|
| pistol_9mm | 1.0 | |
| pistol_45 | 1.15 | |
| chaingun_556 | 0.8 | |
| machinegun_762 | 1.0 | |
| buckshot | 0.35 a pellet | 7 pellets make ~2.5 pistol hits of dust over the pattern |
| buckshot_magnum | 0.3 a pellet | 20 pellets make ~6 |
| rifle | 1.1 | family has no key yet |
| magnum | 1.2 | family has no key yet |
| pistol, bullet | 0.8 | families have no key yet |

## 3. Blasts: impact `smokevolume` + `push = radius, strength (u/s)`

> **LIVE BUG.** The impact `push` strengths are 1.5-2.4 today. They go straight to
> `PushEffectImpulse` as u/s, so blasts shove nothing. The flash pushes were converted to u/s
> in 60c12b3; the impact ones were missed. The fix is data only: the numbers below, on every
> material variant.

| Impact (all its material variants) | Live | **First guess** | τ (T), fresh | M |
|---|---|---|---|---|
| rocket | 48, 3.0, 1.2; push 160, **1.5** | **64, 1.8, 3.0; push 256, 650** | 1.9 (0.15) | 472k |
| rocket_rpg | 56, 3.6, 1.4; push 190, **1.8** | **80, 1.8, 3.5; push 320, 800** | 2.4 (0.09) | 922k |
| bfg (lit ozone, not soot) | 40, 1.2, 1.5; push 200, **2.0** | **72, 0.8, 2.5; push 384, 900** | 0.96 (0.38) | 299k |
| bfg_heavy | 52, 1.6, 1.8; push 260, **2.4** | **96, 1.0, 3.0; push 448, 1100** | 1.6 (0.20) | 885k |
| plasma | 8, 0.2, 0.5 | **12, 0.35, 1.0**; no push | 0.07 (0.93) | 0.6k |
| unmaker_melt_pool | 20, 1.0, 1.0 | **24, 0.9, 1.2** | 0.36 (0.70) | 12k |
| unmaker_melt | 12, 0.4, 0.8 | **14, 0.5, 1.0** | 0.12 (0.89) | 1.4k |

**Heat 3 lifts a blast** at up to ~240 u/s, cooling over about a second. It billows, banks
at the ceiling, and eye level clears first. The 13b notes' recipe range is 64-128 / 1.5-3 /
heat 3-6 / push 192-384 at 500-900; these sit at its low end on purpose.

**No carve at a blast's centre.** The same-tic order of emit and carve kernels would decide
whether it eats the blast's own cloud. The push clears the old smoke instead.

**Muzzle pushes** (flash `push = radius, strength[, along]`, already u/s):

| Flash | Live | **First guess** | Why |
|---|---|---|---|
| shotgun_ssg | 64, 260 | **96, 320** | one blast shoves the room's haze (Hard Boiled) |
| shotgun_bullpup | 52, 220 | **72, 260** | |
| shotgun_m37 | none | **48, 180** | |
| shotgun_doom | none | **56, 200** | |
| rocket_launcher | 56, 240 | **64, 260** | |
| rocket_rpg | 80, 380, −51.5 | **112, 450, −51.5** | the backblast clears the air behind you |
| bfg_9000 | 96, 320 | **keep** | |
| bfg_heavy | 128, 420 | **keep** | |

## 4. Flames: flame `smokevolume = radius, amount, heat`

The code emits it at the landing point every `landingtics`, with velocity (0, 0, 30).

| Flame | Live | **First guess** | M a second |
|---|---|---|---|
| incinerator (landing every 2 tics) | 16, 0.5, 1.0 | **16, 0.5, 1.5** | 36k |
| napalm (every tic) | 16, 0.5, 1.0 | **20, 0.25, 1.5** | 70k |

Napalm gets the same mass, wider and thinner: a burning pool's haze, not a ball.

**Later (a new flame key):** a thin capsule along the jet each tic,
`EmitSmoke(nozzle, 8, 0.05, 1.5, dir × 200, tip)`, M ≈ 640 a tic. That's heat haze along the
stream.

## 5. Sustained cuts and burns: hotspot `smokevolume = radius, amount`

These emit every 6 tics, × the spot's heat, with heat 0.5 × hot.

| Hotspot | Live | **First guess** | M at full heat |
|---|---|---|---|
| unmaker_burn (all variants) | 10, 0.6 | **16, 0.8** | 3.3k |
| saw_cut_stone (+ _heavy) | 9, 0.35 | **14, 0.6** | 1.6k: stone dust off the cut |
| saw_cut_wood (+ _heavy) | 9, 0.35 | **12, 0.45** | 0.8k |

**The chainsaw exhaust comes later.** It needs the engine port's position from the weapon
card: `EmitSmoke(port, 8, 0.3, 0.6, back × 40)` every 4 tics idling, every 2 revving.

## 6. Round tunnels: roundlook `carve = radius, amount`

The code carves once per tic of flight, along that tic's travel (340-900 u).

**Live:** every bullet 2.5, 0.5. That's under the 6 u minimum: by my reading of MakeShape's
(r/rEff)² capsule scale, it's widened to 6 u and thinned to ~0.09. Nearly invisible.
Plasma 3, 0.6. Rocket 6, 0.8. BFG 10 and 12, 1.0.

| Round look | **First guess** | Why |
|---|---|---|
| pistol_9mm | **6, 0.85** | the showpiece: a clean tunnel that reads in slow motion |
| pistol_45 | **7, 0.85** | |
| revolver_357 | **7, 0.9** | |
| rifle_762 | **6, 0.8** | |
| rifle_556 | **5, 0.7** | |
| smg_9mm, smg_45, default | **4, 0.4** | a hint; its own haze survives |
| chaingun_556, machinegun_762 | **4, 0.35** and **5, 0.4** | |
| tracer_556, tracer_762 | **6, 0.7** and **7, 0.75** | every 4th/5th round cuts a visible line through the gun's own haze |
| buckshot, buckshot_magnum | **4, 0.35** and **4, 0.4** a pellet | a fan of tunnels that strips the haze in a cone |
| plasma_ball, plasma_carbine | **8, 0.7** and **6, 0.6** | |
| rocket, rocket_rpg | **10, 0.9** | |
| rocket_rpg_boost | **8, 0.7** | |
| bfg_ball, bfg_heavy | **20, 1.0** and **28, 1.0** | |

**Later (a new roundlook key `smoketrail = radius, amount, heat`):** a capsule emit per tic of a
rocket's flight, 8, 0.35, 0.8. M ≈ a × 1.05 r² × length, about 470 a tic at 20 u/tic: a
thin trail that hangs.

## 7. `SetSmokeLook` (live, on WorldLoaded): keep it

`SetSmokeLook(Color(255, 140, 138, 134), 1.0, 0.8, 0.4, 0.15, 1.0)`

| Value | Live | Why |
|---|---|---|
| tint | 140, 138, 134 | A neutral, slightly warm grey. Smokeless-powder smoke and concrete dust are pale grey. The colour rule: smoke is lit, never glows, and a level has one look. |
| absorption | 1.0 | The unit every amount above is sized against: density 1 through 64 units dims what's behind to e^−1 ≈ 0.37, about a third. Tune amounts, not absorption, so the numbers stay readable. For quick global thickness, use the player's density scale (13c) or `rsb_flash_smoke`. |
| scatter | 0.8 | Most of the light smoke removes comes back scattered from the room's light, so it reads grey-lit, not black. If smoke looks black in lit rooms, raise it. |
| ambient | 0.4 | A floor, so smoke in a dark corner still shows its shape. **The white-out risk is here:** if smoke glows in a dark Doom room, lower ambient to 0.25 before anything else. |
| dissipation | 0.15 /s | A half-life of 4.6 s: thick haze is gone in ~30 s, and a held chaingun's haze fades within ~15 s of stopping. Doom fights need sightlines, so the haze must not outlive the fight. "Smoke fade speed" multiplies it. |
| buoyancy | 1.0 | Heat 1 rises at up to ~80 u/s. Cool dust drifts up very slowly. Blasts bank at the ceiling, and eye level clears first. |

**Wind:** none.

**One engine limit shows here:** one tint a level can't make flame and rocket smoke black while
gunsmoke stays pale. A later ask: an optional per-emit darkness (soot) value on EmitSmoke.

## 8. Budget: 128 events a tic per kind

The per-tic event counts, with the first-guess numbers:

| Case | Emits a tic | Carves a tic | Pushes a tic | What it looks like |
|---|---|---|---|---|
| **Chaingun held 10 s** (vanilla rate, a shot every 4 tics: 87 shots) | ≤ 2 (flash + impact) | ≤ 3 (a round flies 1-3 tics) | 0 | At the gun: 87 × 5.5k × 0.52 ≈ 250k in a ~128³ cloud, density 0.12, **T ≈ 0.79 across 128 u**. At the wall: 87 × 1.8k × 0.52 ≈ 80k hugging it (96×96×48), **T ≈ 0.76 across 96 u**, a chewed pillar in its dust. |
| **Rocket barrage** (10 rockets in ~6 s) | ≤ 2 | ≤ 9 (rockets in flight) | ≤ 2 | 4.7M × 0.66 ≈ 3.1M. A 512×512×128 room: density 0.09, **T ≈ 0.48 across 512 u**. A 256×256×128 room: density 0.37, **T ≈ 0.23 across 256 u**. **The one white-out candidate:** check it first; the fallback is rocket amount 1.8 → 1.2. |
| **Flamethrower held 10 s** (napalm) | 1 a stream (2 with the later jet key; dual-wield doubles) | 0 | 0 | 700k × 0.52 ≈ 360k banks at the ceiling (a 256×256×48 layer): **T ≈ 0.62 across 256 u up there**, eye level mostly clear. |
| **One Super Shotgun blast** (the arsenal's worst single tic) | 21 | 20 | 1 | 7 blasts in 10 s leave **T ≈ 0.84 across 128 u**. |
| **Pistol magazine** (15 shots in 6 s) | ≤ 2 | ≤ 2 | 0 | Each shot a visible puff (T 0.74) that drifts off. The haze left is faint (T ≈ 0.94 across 96 u): the pistol's look is the shot, not the fog. |

**Nothing needs merging today.** Every case is far under 128. Four netplay players firing
Super Shotguns in the same tic is 84 emits and 80 carves.

**What is already merged:**
- Sustained hits merge into hotspots: one emit a spot every 6 tics, not one a hit.
- Flames emit once per landing cadence, not once per flame puff.
- The BFG's 40 rays emit nothing.

**The merge rule to add** (RSB side, deterministic, no RNG, no view):
- **The counter:** RS_Ballistics counts its own calls per tic per kind.
- **Past 96 in a tic:** a shotgun blast's pellet impacts merge into one capsule emit between
  its farthest landing points (summed mass, radius +4). Its pellet carves merge into one carve
  along the blast axis (radius 12).
- **Past 120:** the smallest-mass emits drop first.

It matters for 8-player netplay and for enemy impacts later (slaughter maps).

## 9. Asks for the build lane

1. **Carve thinning:** does MakeShape's thinning of a radius under MIN_RADIUS scale a carve's
   amount the same way it scales an emit's? The tunnel numbers in §6 assume yes.
2. **Events far away:** are emits far outside the eye's box dropped before they count against
   128? Slaughter maps.
3. **Soot, later:** an optional per-emit darkness (soot) on EmitSmoke, so flames and rockets
   can make black smoke under one level tint.

## 10. First-look check, once 13c draws

1. **Empty a Pistolet magazine:** each shot a visible puff that drifts forward and up, gone in
   a few seconds.
2. **Hold the chaingun 10 s:** a haze gathers around the gun and at the wall. The far wall
   stays visible.
3. **One rocket:** a near-opaque cloud billows up and banks at the ceiling. The room clears in
   ~20-30 s.
4. **Fire through haze:** a round leaves a tunnel.
5. **If it's a white-out:** lower the density scale (13c) or `rsb_flash_smoke` first, then
   ambient. If it's blank: check `r_smoke`, and look for the per-map "dropped" console line.
