# Shooting out lights — what it would take

**A discussion, not a plan. Owner opened it 2026-09-18. Ballistics lane.**

**Lane note up front:** RS_Darkness and the other glow mods are not mine to read, analyse or redesign,
and I have not. Everything below is either the ballistics half or a question for whoever owns the
lighting side. Where I say "the lighting mod", I mean *they decide*, not *I assume*.

## The crux, said first

**A wall texture that looks like a light is not a light source.** Doom lights a room with a sector
light level, and the lamp texture is decoration. Our surface pass already recognises a `light`
material and already does the pop — bulb glass, a spark spray, one bright blink. What it cannot do is
know **which light was hit and what that light was lighting**, because in a vanilla map that
relationship does not exist anywhere.

So the whole feature reduces to one question: **where does the fixture-to-darkness link come from?**

Three answers, and it is not my call which:

1. **The lighting mod already knows.** If it places a dynamic light on light textures or on lamp
   actors, then *it* holds the link, and all it needs from us is "this fixture was destroyed, here".
   Cleanest by far, and the only one with no map work.
2. **Dim the sector the fixture is in, by a fixed amount.** Works on every map with no data at all,
   and is crude: shoot a lamp on a wall between two rooms and the wrong room darkens.
3. **A table.** Per-map or per-texture data saying what lights what. Accurate, and nobody is going to
   author it for hundreds of maps.

My read: (1) if the lighting mod can, (2) as the fallback for maps where it cannot, never (3).

## What happens when one breaks

- **The sector gets darker.** Level state.
- **Its dynamic light goes out** — and should *die* rather than snap: a filament flickers and drops
  over a few tics. Presentation, following the state.
- **The texture changes to a broken one.** Level state.
- **It stays broken.** No relighting.

## Netplay — and this is why it is not a ballistics feature

Everything RS_Ballistics has built for a year is presentation: client-side, look-only, safe to skip on
one machine and not another. **This is the opposite.** A sector's light level and a changed texture are
level state: they go in savegames, they must match on every machine, and in co-op one player shooting
a lamp darkens it for everyone.

The concrete consequence: **the break must NOT ride on our impact path.** Our impact looks run
client-side and are deliberately allowed to differ between machines (view culling, distance LOD, the
effects dial). If breaking the light happened there, two players would disagree about whether a room
is dark. The break has to be decided in the playsim, at the moment the round lands, on every machine
alike — and the pretty part (glass, sparks, the dying flicker) hangs off it as usual.

Cost is negligible: a sector light change is nothing, a texture swap is nothing. **The risk is not
performance, it is playability** — a map that goes pitch black is unplayable, and Doom's monsters do
not care about light, so darkness only ever hurts the player. Whatever gets built wants a floor on how
dark a room may go and a switch to turn the whole thing off.

## What ballistics supplies, and what I would want the interface to be

Ours, and we could build it tomorrow:
- the hit that reads as *breaking a fixture* rather than chipping a wall — bulb glass, the spark
  spray, the pop, a scorch on the mount (most of this exists in `impact bullet.light` today);
- telling a fixture from a wall, using the surface pass we already have;
- the flicker-and-die of whatever light was there, which is a look.

The interface I would argue for, in the engine's house style — **named for what it does, not for who
asked**: a general *"a thing in the world broke, here, of this kind"* notification that any mod can
listen to, not a Darkness-specific call. The same hook then serves a shot-out screen, a burst pipe, a
broken vent, a shattered window. If the engine has to know it is a light, the abstraction is wrong.

## What I need before writing anything

1. **Who owns it** — name the lane, and I hand them the ballistics half.
2. **Answer to the crux:** can the lighting mod supply the fixture-to-light link (1), or do we accept
   dimming the sector (2)?
3. **Whether the owner wants it to be gameplay at all** — because that is what it is. Presentation is
   free and reversible; this is neither.
