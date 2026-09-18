# Liquids — what they would actually mean in our stack

**A discussion, not a plan. Owner opened it 2026-09-18. Ballistics lane.**

## The useful surprise: we already own most of it

"Liquids" sounds like a new system. It mostly is not. The lasting surface damage the engine already
paints for us (`r_damage`, DAMAGEDEFS brushes) has **four channels: soot, hole depth, heat, and WET**.
A wet patch is already a thing the renderer draws on a wall. And every impact profile already has a
`.liquid` material variant, so shooting standing water already throws a splash.

So the question is not "can we do liquids" but "which four or five specific things are missing", and
they turn out to be small and separable.

## The five things people mean by "liquids"

**1. A splash in the air.** Done. `splash_liquid` bursts, per-material. Nothing needed.

**2. A wet patch where something landed.** Done in the engine, unused by us. We paint soot, holes and
heat today; we have never once painted `wet`. A blood spray or a shot into a pipe should.

**3. Blood that is RED.** *This is the one real engine gap.* A paint carries soot/depth/heat/wet —
four amounts, no colour. Wet darkens and glosses a surface, which is right for water and wrong for
blood. **Ask: a tint on a paint.** One colour per paint, multiplied into the wet channel's look. That
is small, it is general (rust, oil, slime, alien ichor, scorch colour by material all want it), and it
is the difference between "liquids" and "water only".

**4. Pooling, running, dripping.** The genuinely new behaviour, and the only part that is a system:
   - **A pool spreads.** One paint is a fixed circle. A pool wants radius growing over a second or two
     and then stopping. **Ask: a paint whose radius animates**, or a script-side series of paints
     (cheap, ugly, floods the 128-a-tic queue). I would rather ask for the first.
   - **Blood runs DOWN a wall.** A circle never reads as blood on a wall; the drip does. That is a
     paint that extends along gravity over time — a streak whose length grows and whose head is
     darker. **Ask: a directional streak brush with a growing length.** This is the single most
     recognisable liquid behaviour and we cannot fake it with round stamps.
   - **Hits in one place ACCUMULATE.** Ten rounds into one spot should make one bigger wet mark, not
     ten identical ones fighting. Soot already adds up per the DAMAGEDEFS comment; wet should too.

**5. It should dry.** Wet never fades today — a known gap, and it is in the slow-mo notes as one of
the values still on the wrong clock. A pool of water on a hot floor and a pool of blood should both
fade, over minutes, and blood should darken as it dries rather than vanish. **Ask: a decay rate per
channel**, which also finally gives heat somewhere honest to live.

## What is ours and what is the engine's

| | Ours (data, this week) | Engine |
|---|---|---|
| Splash in the air | burst definitions, per material | — |
| Wet patch | add `wet` to the damage key on liquid/flesh hits | — |
| Colour | choose it per material | **a tint on a paint** |
| Pool spreading | choose the size and time | **an animating radius** |
| Runs and drips | choose where and how fast | **a directional streak brush** |
| Accumulation | — | **wet adds up like soot** |
| Drying | choose the rate | **per-channel decay** |

Five engine asks, all in one subsystem, all additive and default-off — a paint with no tint, no
growth and no decay behaves exactly as today. If we are opening that record anyway, opening it once
for all five is the cheaper shape.

## What I would NOT do

- **No fluid simulation.** Nobody is asking for water that flows around geometry, and it would cost
  more than everything else in this package put together.
- **No slippery floors, no liquid that changes movement.** The moment a liquid affects how the player
  moves it stops being presentation, has to replicate exactly, and becomes a gameplay argument. If
  that is ever wanted it should be its own decision, not smuggled in with the look.
- **No blood for its own sake.** Gore is parked separately by the owner. This is the surface half —
  what a liquid does once it has landed — and it serves water, oil, coolant and slime as readily as
  blood.

## Netplay

All of it is presentation: paints are queued by the engine and nothing reads them back. Same rule as
every other look — no playsim random, nothing keyed to consoleplayer. Drying on a world or real clock
is a choice; world, so a pool does not dry while time is stopped.

## The honest summary

Water: we could improve it with data alone, today. **Blood: we cannot do it properly without a tint on
a paint** — everything else is polish on top of that one field.
