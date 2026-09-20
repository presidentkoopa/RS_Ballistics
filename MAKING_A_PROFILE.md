# Making a profile

*How a gun gets its ballistics in this package. Every rule here was paid for once — the cost is in
the margin, because a rule without its reason is a rule somebody deletes.*

---

## 1. What a gun names

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

## 2. The kick is derived, never chosen

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

### Five things that are easy to get wrong

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

## 3. Generators own their blocks

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

## 4. Absence is a statement

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

## 5. `@extreme`

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

## 6. Proving it

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

## 7. The shape behind all of it

Every rule on this page is the same defect wearing different clothes:

> **A thing that is missing looks exactly like a thing that is fine.**

A dead sound name is silent. A refused profile is a name that does not exist while looking like one
that does. An unnamed key takes the house recipe. A model bound to a parent class draws nothing on the
child. An erased `roundmass` parses perfectly. A checker blind to a whole package reports zero
problems.

Write the thing down, then write the check that refuses its absence.

---

*Ballistics lane. See also `README.md` (what the package does), `THE_BALLISTICS_LANE.md` (what it got
wrong and what caught it), and `Engine docs/PROPOSAL_GUN_WEIGHT_AND_RECOIL.md`.*
