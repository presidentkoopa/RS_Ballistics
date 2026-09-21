# Star Wars — the ballistics plan

**Answer to `STAR_WARS_BRIEF.md`. Owner's go: plan, then build.**

The line designed against: *"beautiful lovely beams … but remember it is star wars, not john wick."*
And straight after: *"ballistics should still add weight and recoil here and there. i need some
feedback at least."*

---

## The two questions

**1. Does anything need an engine capability? No.**

- The blade is already a hand-following model (three additive shells) on the weapons side.
- A blaster bolt is the round-in-flight model this package already flies (`btracer.obj`), with new
  coloured skins and new MODELDEF frames. Coloured flight lights, glide and self-drawn beams exist.
- The swing smear is a drawn-line trail laid tip-to-tip each tic. Trails have 64 slots.
- Wall contact uses `RSB_Materials.FromTrace` + `RSB_Impact.LandOn`, which are public today.

**2. Six bolt looks, three colours.**

| look | what it is | who fires it |
|---|---|---|
| **blaster bolt** | short saturated streak, white-hot core, coloured halo, lights the walls it passes — pistol, rifle and heavy sizes | most of them |
| **sniper bolt** | the longest, thinnest, fastest bolt | Wardusted SniperRifle |
| **bowcaster quarrel** | a fat green bolt, slower, hits hard | both Bowcasters |
| **ion bolt** | blue-white with arcs crawling on it; shorts out what it hits | Xim Ion Blaster |
| **disruptor** | no bolt — an instant beam muzzle-to-hit, white core, red edge; the target flakes to ash | DisruptorRifle |
| **concussion** | a heavy pulse; a ring of bent air where it lands, and a thump | ConcussionRifle |

Colours are **the films'** (owner, 2026-09-21): hand blasters fire **red** on both sides, **blue** is the
clone army (the Z-6, the rotary) and ion, and the bowcaster keeps the **green** the games gave it.

*Correction:* an earlier draft called "red Empire, green Rebel" the owner's rule. It came from the brief,
unquoted, and the films do not do it.

---

## Gun by gun

| gun | look | colour | kick |
|---|---|---|---|
| **Wardusted** | | | |
| DL44Blaster | blaster, pistol | red | a sharp snap, fast back |
| E11Blaster | blaster, rifle | red | light and quick |
| DarkBlaster | blaster, heavy | red | heavier |
| DLT19 | blaster, heavy | red | small per shot, builds with the rate |
| E22Blaster | blaster, rifle | red | twin-barrel shove |
| Z6RotaryBlaster | blaster, heavy | blue | tiny per shot, wanders as it spins |
| Bowcaster | quarrel | green | a real shove |
| ConcussionRifle | concussion | — | the thump of the set |
| DisruptorRifle | disruptor | red | a hard crack |
| SniperRifle | sniper | red | a hard crack |
| DarkAssaultCannon | heavy charge | red | the heaviest, settles slowly |
| RebelThermalDetonator, ProximityMines | energy blast | — | none (thrown) |
| **Xim** | | | |
| Pistol (blaster) | blaster, pistol | red | snap |
| Shotgun (Blaster Rifle) | blaster, rifle | red | light |
| SSG (Ion Blaster) | ion | blue | sharp |
| Chaingun (Heavy Blaster) | blaster, heavy | red | builds |
| Rocket (Bowcaster) | quarrel | green | shove |
| Plasma (Rotary Blaster) | blaster, heavy | blue | wanders |
| BFG (Thermal Detonators) | energy blast, big | — | none |

**No brass on any of them** (`ejectaprofile = "none"`). **No powder smoke** at the muzzle: a blaster
flash is a coloured snap of light and a whiff of ozone. **Never zero kick**: every kick is stated,
because there is no cartridge to derive one from. Pistols snap and come back fast; heavy guns settle
slowly.

## What a bolt does when it lands

Sparks, a scorch and smoke off the burnt spot, a flash of its own colour lighting the wall. On
flesh: a cauterised sizzle, steam and char, no blood spray. The smoke is the hit burning, not powder,
so it stays.

## What the enemies fire (Xim)

Xim's troopers use the package's shared enemy rounds, which fly as bullets. `--enemies` writes
`_staged/RSBDEFS.xim_enemies`: it gives `enemy_round`, `enemy_pellet` and `enemy_heavy` red bolt
looks (frames J, I, K), bolt impacts and a streak light. **Look only**: speed and damage stay the
house's. It ships as `RSBDEFS.txt` inside the Xim REMA pack, which loads after RS_Ballistics, so the
override exists only while Xim is played.

---

## The lightsaber — eight colours

| effect | what it is | the call on the weapons side |
|---|---|---|
| **deflect** | the bolt snaps off the blade: blade-coloured flare, white sparks, arcs | `"saber_deflect_" .. colour` where `deflect_energy` / `deflect_bullet` are named today |
| **cut** | a strike through a monster: cauterised, coloured flash, steam, char | `RSB_Impact.At(...)` from `Cut()` on each hit |
| **wall** | the blade melting into a wall: a glowing groove that drags with the blade and cools — the blast-door shot | trace the blade line; on a hit `RSB_Impact.LandOn(owner, RSB_Materials.FromTrace(d, dir), "saber_wall_" .. colour, dir)` |
| **smear** | the swing leaves a fading ribbon of light | while the tip is fast: `RSB_Trail.Lay("saber_smear_" .. colour, owner, lastTip, tip)` |
| **clash** | blade on blade | `"saber_clash_" .. colour` |

`colour` is lower-case from the saber's own table: blue, green, red, purple, yellow, orange, cyan,
white. **The hum's pitch rising with the swing is already built** on the weapons side.

---

## Built by this lane

`tools/gen_starwars_profiles.py`, generated like every other set, verified through a real boot,
light → extreme. Names are `sw_<gun>` for flashes and recoil, `sw_bolt_<colour>_<size>` for rounds,
`saber_<effect>_<colour>` for the saber. The sheet lines come out of `--sheet`, not a message.
