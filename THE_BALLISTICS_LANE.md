# The ballistics lane

*The owner asked for a write-up about how badass this lane is. Here it is, with the failures in it,
because a record that only lists wins is a record nobody can use.*

---

## What it is

**1203 profiles.** Every gun in every set — Vanilla, Vanilla+, Modern, WW2, Brutal Wolfenstein,
Aliens, Cola, Blood — has its own flash, its own kick, its own brass, its own round in flight, and
its own mark on the wall. Nothing fires in borrowed clothes any more.

**Nothing in it is a number somebody liked the look of.** Every kick in the package is computed from
four real figures — bullet grains, muzzle velocity, powder charge, gun weight:

```
Vg   = (grains × fps + 4700 × charge) / (7000 × lb)
climb = Vg × 0.148 × ACTION[how the gun is held]
```

The MG42 and the Kar98k fire the same 7.92×57 out of a 25 lb gun and a 9 lb gun. The file says so out
loud now: identical impulse, **3.173 lb·s on both**, and 18.2 against 6.3 ft-lb of energy. That one
pair is why weight and load had to be split, and it reproduces itself out of the data rather than out
of anyone's arithmetic.

**The bullet is a model, not a sprite.** One mesh, eight sizes picked by frame — a buckshot pellet is
a 10-unit stub, a 7.62 tracer is the mesh at full size. A new calibre is a MODELDEF block and no code.

**A fire can ride the man it was set on.** A hotspot was always a *place* — right for a saw, wrong
for a fire. Now a flare in someone burns while he runs and carries his own light with him.

**A spray can fires nothing at all.** An inert jet: no light, no heat, no scorch, no sound. Almost
every key the flame system has is *absent* rather than turned down, because everything the flame
system does is about fire.

---

## Why any of it can be believed

This is the actual answer to "how badass", and it is not the feature list.

**Proved both ways, or it is a guess.** Every guard in this package has been deliberately broken to
watch it fire. The round lint: four failure modes, each planted in a complete copy of the tree. The
boot verifier: one bogus key planted, *"GREEN … 1173 profiles, 8 refused"*, thrown with all eight
named. A guard nobody has exercised is a guess with good intentions.

**Read the shipped file, not the source.** The coverage checker opens the installed `.pk3`, because
once a fix sat in source while the owner played the broken build for an hour.

**Refuse to write rather than write something dead.** The generators will not emit a sound name
`SNDINFO` does not declare — that rule exists because a dead sound shipped twice. It stopped three
invented tail names this week without a person in the loop.

**Prove it in a running game.** Impulse, round mass and the whole computed-kick formula were each
proved by a throwaway pk3 that ran them in a real level and was then deleted. An override that is
never called looks exactly like one that answers correctly.

---

## What it got wrong, and what caught it

| went wrong | caught by |
|---|---|
| Twelve profiles refused, boot still **GREEN** | nothing — which is why `boot_verify.ps1` exists now |
| A weight table reporting 1 estimate in 66 | reading its own output before sending it |
| A patch script run twice, field defined twice | the compile |
| `.` matches `\r`, stripping CR from 21 lines | counting the bytes instead of trusting the diff |
| Importing a generator **ran** it, reverting 11 rounds | the profile count not moving |
| Printing a key, then a note contradicting it | the weapons lane's lint |
| Zeroing a `none` block | the parser: *a casing of zero size is broken, not absent* |

Every one is the same shape, and it is the shape this whole package is built against:

> **A thing that is missing looks exactly like a thing that is fine.**

Seven or eight times now. Dead sound names. A checker blind to a whole package. A melee gun vanishing
from a report the moment it was fixed. An unpacked commit leaving a weapon dead for an hour. *MESH
UNREADABLE* reading as clean. Every tool in `tools/` exists because of one of them.

---

## The rule it holds hardest

**Say what is not there, and why.** `damage = none`, `kick = none`, `speed = none`, and now `recoil
none`, `ejecta none`, `trail none`. A stated absence is a decision. An omitted key is indistinguishable
from a mistake — and worse, falls back to a house recipe nobody chose.

There is deliberately **no `round none`**, and the reason is written where someone will look for it.
A kick and a casing are things a shot *may* have; the round *is* the shot. Symmetry is not a reason to
define something that would mean nothing.

---

*Ballistics lane, 2026-09-19.*
