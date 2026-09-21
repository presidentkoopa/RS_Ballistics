# Star Wars — the brief

**From the weapons lane, 2026-09-21, for the ballistics lane.** Left here because this lane was not
running when the owner asked for it. It is a request for a plan, not a build.

The owner's words: *"spin it through ballistics as well, tell it i expect STAR WARS ... this should
be a great experiment in bolt / blast / pulse / laser weaponry."*

This is the first time the package has energy weapons as a **whole set** rather than one plasma gun
at the end of a rifle list, and he is excited about it. It is yours to make look and sound like the
films.

---

## Two mods, 22 guns, no bullets anywhere

**Wardusted** (Wardust's Rogue Rebel) — its own DECORATE classes:

    DL44Blaster  E11Blaster  DarkBlaster  DLT19  E22Blaster  Z6RotaryBlaster
    Bowcaster  ConcussionRifle  DisruptorRifle  SniperRifle  DarkAssaultCannon
    RebelThermalDetonator  ProximityMines  Lightsaber

**Xim's Star Wars Doom** — DeHackEd, on Doom's own slots:

    Pistol = blaster         Shotgun = Blaster Rifle      SSG = Ion Blaster
    Chaingun = Heavy Blaster Rocket = Bowcaster           Plasma = Rotary Blaster
    BFG = Thermal Detonators Chainsaw = Lightsaber

## What "Star Wars" rules out

So nothing borrowed from the gun sets leaks in:

- **No brass, no casings, no ejecta of any kind.** Every one of these states `ejecta none`.
- **No muzzle smoke of the powder kind.** A blaster leaves a hot glow and maybe ozone, not soot.
- **No bullets.** A bolt is a *visible* streak of coloured light, slow enough to see — red for the
  Empire, green or blue for the Rebels — and it **arrives**, it does not hitscan. The owner wants to
  watch it fly.
- **No physical reload.** He ruled it: energy weapons, no magazines to handle.

## The one line to design against

The owner, 2026-09-21: *"make sure the ballistics are beautiful lovely beams lol maybe for the blaster
shit too!! but remember it is star wars, not john wick."*

**STAR WARS, NOT JOHN WICK.** Every instinct this package has built over a year is John Wick —
brass, powder smoke, muzzle flash petals, tracers every fifth round, a cartridge's arithmetic. Every
one of those is wrong here. A blaster bolt is a **beautiful beam**: a short, saturated, glowing
streak with a hot white core and a coloured halo, travelling slowly enough to track with your eye,
lighting the walls it passes, and ending in a flash-and-scorch rather than a bullet puff. The
lightsaber blade (see below) is already built as three nested additive shells — white core, bright
colour, dim halo — and a bolt wants the same anatomy, short and flying.

If a profile you are about to write would look right on an MP40, it is the wrong profile.

## What it does NOT rule out: weight and recoil

The owner, straight after: *"ballistics should still add weight and recoil here and there. i need
some feedback at least."*

**An energy weapon with no kick feels like a toy, and in a headset it feels like nothing at all.**
Ruling out powder does not rule out a shove. So every one of these gets a real `recoil` profile and a
real weight — just a different character from a cartridge gun:

- **Lighter per shot, but present.** A blaster bolt is a pulse, not an explosion in a chamber, so the
  climb is small and sharp rather than a heavy shove. But not zero: zero is the one wrong answer.
- **Weight is the other half of feedback, and it varies hugely here.** A DL-44 is a sidearm; a Z-6
  rotary cannon and a DLT-19 are heavy crew weapons; the Dark Assault Cannon is enormous. Weight
  already drives the live recoil arithmetic (`RSB_Recoil` kicks by the gun's live weight), so a heavy
  cannon should feel heavy in the hand and settle slowly, and a pistol should snap and recover fast.
- **The Z-6 and the rotaries SPIN UP.** That is weight you feel building while the barrels wind, not
  a per-shot kick — the same shape as the flamethrower's steady push rather than a jump.
- **The concussion rifle and the heavy stuff should THUMP.** They are the energy weapons that are
  allowed to hit hard, and the difference from a blaster should be obvious.

No brass and no soot, but a gun you can feel. That is the brief in one line.

## The sounds exist

Wardusted's `WARDUSTs_ROGUEREBEL_WEAPONSONLY_2023_04_11.pk3` carries 269 of them, including a **full
36-sound lightsaber set** under `Sounds/LIGHTSABER/`:

| | |
|---|---|
| ignition | `DSSABREI` |
| hum | `DSSABREU` |
| swings | `DSSABRE1` – `DSSABRE9` |
| flesh hits | `LSABHIT1` – `LSABHIT7` |
| wall hits | `LSABHTW1` – `LSABHTW3` |
| spins | `SBRSPN0` – `SBRSPN3` |

Blasters: `Sounds/Blaster Pistol/DL44.mp3`, `CONCUSS1/5/6`, `ATSTfire`, more at the root. Xim
reskins Doom's own `DS*` slots. Name what you use; do not invent a sound SNDINFO cannot resolve.

## The centrepiece: a lightsaber, on our engine

The owner: *"i expect to be able to throw like the shieldsaw and deflect attacks like the
shieldsaw."* `RS_ShieldSaw` already throws (`throwSpeed`) and deflects (`deflectOn` / `deflectAim`),
so the throw and the deflect are the shieldsaw's and the weapons lane builds on it.

**What is yours:**

**The blade.** In Jedi Academy the blade is not a model — it is drawn in code as a glowing beam off
the emitter. So it is entirely ballistics'. And it is the one thing nothing in the package does yet:
**a beam that stays lit and follows the hand every frame**, rather than a shot that fires and fades.
The `cl_particlegun` trail and the engine's `vol_beam` are most of the way there — a hard white core,
a coloured glow round it, light on the walls it passes. Plus **ignition**: the blade extends out of
the emitter and retracts, it does not pop.

**The swing.** Hand speed is already measured (the throw service). A fast swing should smear the
blade and lift the hum pitch — the single thing that makes a VR lightsaber feel real.

**The deflect and the clash.** A bolt striking the blade flashes and goes back the way it came. You
already have `deflect`, `deflect_energy` and `deflect_bullet` — a saber deflect is the energy one
made spectacular.

## What the weapons lane needs first — a plan

1. **Can the current trail/beam path draw a persistent beam that follows a moving hand every frame,
   or does that need an engine capability?** If it needs one, name it. The owner would rather build
   the capability once than contort around its absence.
2. **The bolt family:** how many distinct bolt looks this wants, and which gun gets which.

## Settled on the weapons side

Models: *Vince Crusty and Elin's VR Fully Modeled Weapons Pack*, textured from the owner's own Jedi
Academy install, already packed as `SW_Models_Wardusted.pk3` and `SW_Models_Xim.pk3` in
`D:\SteamLibrary\steamapps\Common\DooM VR\__Games\Wardusted\`. The saber is `saber/saber_w.md3` —
**the hilt only, 16 units**, which is exactly right, because the blade is yours.

JKXR's own per-weapon tuning (`weapons_vr.cfg` in `E:\StarWarsWork\JKXR\build\pk3\z_vr_assets_jka.pk3`)
is the source for placement: scale, offsets and rotation per JKA weapon id, set by that project's
author in a headset.
