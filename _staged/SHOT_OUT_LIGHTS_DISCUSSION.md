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

---

# Worked out with the glow lane, 2026-09-18 (owner: "work together", theory only)

## Settled

**The glow mods cannot supply the fixture-to-room link.** GlowInTheDark places no dynamic lights at
all -- its lanes are per-sector surface emission, no radius, no source. Darkness, Fog, Sweeps and
Bloom only READ light. The only real light in the family is the flashlight, on the player. So option
(1) in the crux above is dead and the link must come from the hit.

**Two rules recover most of the accuracy with no authored data:**
- **Side, not line.** A lamp texture is on one SIDE of a line, and that side belongs to one sector --
  the room you see it from. `RSB_Materials.Probe` already resolves the exact side and part on every
  hit, so this is free today.
- **A share per fixture, counted at map load.** Tally `light`-material surfaces per sector once; each
  break takes its share of that room's drop budget. "Shoot the lights out", not "shoot a lamp, room
  goes black". One integer per sector. NOTE a light SURFACE is not a FIXTURE (one lamp is often
  several sidedefs, a strip light is one fixture over many), so either group contiguous same-texture
  sides at load, or tally surfaces and make the budget tunable. Ship the second.

**First slice, needing nothing from anyone:** lamps that are ACTORS carry their own dynamic light.
Make those shootable and the light dies with the actor -- no sector maths, no table, no engine ask,
correct in co-op for free. Proves the look before anything touches level state.

## The one engine item

Doom's light specials recompute a sector's light every tic, so a written value is gone next tic. And
**script cannot reach them at all**: `class Lighting : SectorEffect native { }` is EMPTY, with
`m_MaxLight`/`m_MinLight` only in C++ (`src/playsim/mapthinkers/a_lights.cpp`). So "lower the base
levels" was never available.

**Ask: a per-sector light TRIM that every special is computed through.** One value per sector,
applied after the special decides, so a strobe keeps strobing and simply dims. Additive, default
zero, every existing map identical until something sets it. Named for what it does -- the next
callers are a power cut, a dimmer, an EMP, a boss phase. It also makes specialled and unspecialled
rooms the SAME code path, which removes "half of Doom's lit rooms are exempt".

Two riders from the glow lane, both right:
1. **The trim must be READABLE from script,** not only writable, or every mod that reacts to a room's
   light still sees the old number and lights a shot-out room as though nothing happened.
2. **Say whether the smoke sees it.** 13d's light grid takes its ambient from the sector light per
   column; if the trim is applied only to surfaces at draw, a shot-out room's haze stays bright --
   and the haze is usually the biggest thing in frame.

## Where the state lives -- checked, and it decides the interface

**Event handler fields are NOT saved.** `StaticEventHandler : Object native play`, and `src/events.cpp`
serializes nothing. So a dead-fixture registry kept on the handler is gone on load. It has to live on
a **Thinker**, which IS serialized with the level -- and once it does, a savegame restores the dark
room AND the tally together.

That settles the glow lane's load question in their favour: **a query, not an event replay.** Given a
sector, what share of its fixtures are dead. Called on WorldLoaded it rebuilds their reaction in one
pass, with no replayed glass-break sounds and no "was this a replay" flag anywhere.

`already broken` in the payload means the registry is PER SURFACE, not just a count per sector. That
is the real cost on the ballistics side and it is accepted.

## The break notification payload (agreed with the glow lane)

Named for what happened, not for who listens; a shot-out screen, a burst pipe or a broken vent uses
the same hook.

| field | type | why |
|---|---|---|
| `kind` | Name | `light`, `screen`, `glass`, `pipe` -- from the materials, not an engine enum |
| `sector` | Sector | the side's OWN sector: the room that just lost its light. Never the line's front sector |
| `deadShare` | double 0..1 | share of that room's fixtures out AFTER this break. "The room lost its last light" is the moment emergency lighting belongs, and only the ballistics tally knows it |
| `tookShare` | double 0..1 | what this one break took, for proportional reactions |
| `where` | Vector3 | the hit, for something at the fixture rather than across the room |
| `line`, `side`, `part` | Line, int, int | wall identity (part 0 upper, 1 middle, 2 lower) -- dedupe and placement |
| `plane` | int | for a flat: which plane, with `sector` above |
| `alreadyBroken` | bool | a second round into a dead lamp, so nobody restages the reaction |
| `instigator` | Actor (may be null) | no use today; a power cut, an EMP and a boss phase will |
| `damageType` | Name | same |

Nothing cut. Every field is cheap and the two speculative ones cost nothing to carry.

## The floor, via a Service

`class Service abstract` exists (`wadsrc/static/zscript/engine/service.zs`), so neither mod has to be
loaded for the other to compile and a missing answer means "no darkness mod, use the raw number".

The glow lane publishes **the surviving fraction of a given light level under the player's current
Darkness settings, CURVE ONLY** (0-255 in, 0..1 out) -- deliberately excluding the distance and height
terms, which depend on where the player stands and would make a floor true in the doorway and false
in the room. So the floor is "with the curve alone, this room still survives at X", and the menu row
says a Darkness preset deepens it further with range and height.

## Their reaction, and its honest limit

On "this room has lost its last light" they would switch the sector's glow lanes to an emergency
colour at raised intensity -- amber or red down the wall, the floor lane up, so the room reads as lit
by something that is not the ceiling any more. Per sector, needs nothing new. They CANNOT make it
throb: GitD's pulse is level-wide, and per-sector pulse is explicitly NOT being asked for.

## Status

Theory. Nothing built by either lane. The engine item is logged with the build lane and not scoped.

## The owner settled the shape, 2026-09-18 (still theory, not commissioned)

> "lights come from sector levels, whcih can be lowered by shooting textures flagged as 'lights'. we
> can find them in the doomwad and ensure they 'go dark' with the sector. lamps would be dynamic
> lights, which we can sprite edit to 'shoot out' and snuff the dynamiuc light"

Two paths, exactly as designed: flagged TEXTURES lower the sector; lamp ACTORS lose their dynamic
light and take a shot-out sprite.

## TWO SETS, NOT ONE -- the thing that would have been a bug

The `light` material in SURFACES.txt has shipped for weeks and already covers every vanilla fixture
(and the Doom 2 ones). But it is tuned for the LOOK and is deliberately generous -- its flats include
FLOOR1_7, FLAT2, FLAT17, FLAT22, CEIL1_2, CEIL1_3, CEIL3_4, CEIL3_6, several of which are ordinary
ceilings and floors that merely read as bright. **If the fixture tally used that list, a room's own
ceiling would count as a lamp and shooting the floor would dim the room.**

- **`light` MATERIAL** -- broad, unchanged, already shipping. Governs the pop, the bulb glass, the
  spark spray, the blink. A lit ceiling tile deserves all of those.
- **FIXTURE set** -- strict, new, and the ONLY thing the per-sector tally and the sector trim read:
  LITE2, LITE3, LITE4, LITE5, LITE96, LITEBLU1-4, LITERED, TEKLITE, TEKLITE2, BRICKLIT, GRNLITE1 and
  the four TLITE6 ceiling panels. Excluding LITEMET and LITESTON (lit trim, not lamps -- a strip of
  trim should pop and spark without darkening anything) and every ordinary ceiling and floor flat.

Anything can be a lit-looking surface; only a lamp is a fixture.

## Brightmaps: the warning does not apply to Doom

The glow lane checked brightmaps.pk3: ZERO matches for LITE*/TLITE*. So the vanilla fixtures are lit
by sector light like any other surface and "they go dark with the sector" is ALREADY TRUE. The
engine ask I expected (suppress a surface's brightmap) does not exist for Doom; it returns only if a
PWAD brightmaps its own light textures. Known limitation, not a surprise.

What is left is the broken LOOK, which is art. **Generate it rather than draw sixteen variants:** the
package already generates debris shapes and damage brushes from a seed, and a shot-out lamp is a
darkened base plus a blown-out overlay composited per texture. Deterministic and owned outright.

## Actor lamps already carry their light

lights.pk3 gives a dynamic light to TechLamp, TechLamp2, BlueTorch, GreenTorch, RedTorch, the three
Short torches, Candelabra, Column, BurningBarrel and HeadCandles. Kill the actor and the light goes
with it -- no level state at all. Making a decoration shootable is gameplay and is neither lane's.

## The Service, as the glow lane will publish it

`RSD_DarknessService`, play scope, no state, safe every tic, via
`virtual play double GetDouble(String request, string, int, double, Object, Name)`:
- `"active"` -> 1.0 if darkness is really on. **Ask this first** and cache per level; with 0.0 the raw
  sector number is the truth.
- `"surviving"`, doubleArg = a light level 0-255 -> the fraction 0..1 surviving the curve (mode,
  pre-gain, curve, min light, post-gain), NO distance or height term. `effective = level * returned`.
- `"floorlight"`, doubleArg = the minimum EFFECTIVE light to guarantee -> the raw sector level needed,
  or **-1 when the curve cannot reach it at any level (Blackout)**, which means DO NOT DIM AT ALL
  here -- not "clamp to zero".
- A missing RS_Darkness means `ServiceIterator.Find` returns nothing: use the raw number. An unknown
  request returns 0.0, and 0.0 from `"surviving"` is "no answer", never "black" (they return an
  epsilon for a real black).

The spatial terms are excluded on purpose: a floor built on where the player stands is true in the
doorway and false three steps into the room -- it would pass a test and fail in play.

## Ceiling panels: grid them, and let the HIT pick the cell (design closed)

A wall fixture is one sidedef among many, but a ceiling light panel usually IS the ceiling -- one
flat covering the whole sector. Under a naive share-per-fixture that room goes from fully lit to its
floor on ONE shot: the same collapse we split the lists to avoid, arriving from the other side.

A plain count of "one fixture per 256x256 of lit ceiling" still has a hole: nothing says which chunk
a shot killed, so four rounds into one corner would darken the whole room. The payload already
carries the hit position, so use it.

**A flat fixture's identity is (sector, plane, cellX, cellY)** -- the hit snapped to a 256-unit world
grid. Each cell dies once; a second round into the same cell arrives with `alreadyBroken` true, so
dedupe is free. "Shoot the lights out" becomes literally true: the player has to walk their fire
across the panel.

**The tally N** is the panel's extent in cells from the sector's BOUNDING BOX, clamped to 1..12. The
clamp stops a vast outdoor sector needing two hundred rounds, and a bounding box is geometry, so the
number is identical on every machine -- which is what co-op needs. It overestimates an L-shaped room,
costing a shot or two and nothing else.

**A wall fixture stays (line, side, part).** Two different identity shapes, both exact, both dedupe.

`deadShare` is an honest fraction of the CLAMPED tally, so the glow lane's emergency threshold means
what it says. That threshold is a number on their side, not exactly 1 -- the last fixture in an
awkward corner should not gate the effect.

## Status at close of the design conversation

Shape settled by the owner, design closed between the ballistics and glow lanes, NOTHING BUILT and
not commissioned. Outstanding when it becomes work:
1. The engine item -- a per-sector light TRIM every special computes through, readable from script,
   and a decision on whether the smoke's ambient sees it. With the build lane, not scoped.
2. Ballistics: the fixture list, the per-sector tally, the per-surface dead registry ON A THINKER
   (not an event handler -- those are not serialized), the break notification, the query for load,
   the floor via `RSD_DarknessService`, and generated broken-lamp textures.
3. Glow lane: the Service, and the emergency-lighting reaction with its threshold.
4. Gameplay, neither lane: making lamp actors shootable.
