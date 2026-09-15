# STAGED -- the surface pass: what new surfaces do when shot (nothing built yet)

**Owner, 2026-09-15:** "talk to me about expanding what happens when a texture is shot. i'd like to see more debris
spawn. example, shooting lights or electricity or tech things would have a specific effect, then dirt would or wood
or something else". Picked: **tech, electrical and pipes; lights and screens; brick, marble and tile.** Debris:
**keep the counts, add new kinds** (each surface throws its own pieces).

**Parked by the owner:** shot-out lights (flicker, dimming, a room going dark -- a gameplay idea for a meetup with the
glow lanes; never touch their mods), gore and flesh (maybe never: existing gore mods, or our own later), liquids (a
later pass). Lights and screens get the **pop and sparks only**.

Paused 2026-09-15 by the owner's pause (relayed by the build lane) before any file changed. Resume from here.

## 1. Surfaces (SURFACES.txt; appended blocks -- a later rule wins, so they take their textures back from metal and glass)

Read from the IWADs in the build folder (doom.wad is Doom 1: 287 walls, 107 flats; doom2.wad: 428 walls, 147 flats);
floors checked by eye on rendered sheets.

| Surface | Walls | Flats |
|---|---|---|
| `tech` | COMP2, COMPBLUE, COMPOHSO, COMPSPAN, COMPTILE, TEKWALL*, TEKGREN*, TEKBRON*, SPACEW*, MIDSPACE, SW?BRCOM, SW?COMM, SW?COMP, SW?TEK, SW?BLUE | COMP01 |
| `screen` | COMPSTA1, COMPSTA2, COMPTALL, COMPUTE*, COMPWERD, PLANET1, EXITSIGN, SW?EXIT | CONS1_1, CONS1_5, CONS1_7 |
| `light` | LITE2, LITE3, LITE4, LITE5, LITE96, LITEBLU*, LITEMET, LITERED, LITESTON, TEKLITE, TEKLITE2, BRICKLIT | TLITE6_1, TLITE6_4, TLITE6_5, TLITE6_6, FLOOR1_7, FLAT2, FLAT17, FLAT22, CEIL1_2, CEIL1_3, CEIL3_4, CEIL3_6, GRNLITE1 |
| `pipe` | PIPE1, PIPE2, PIPE4, PIPE6, PIPES, PIPEWAL*, BROWNPIP, SW?PIPE | -- |
| `brick` | BRICK*, BIGBRIK*, BRNBIG*, BRNSMAL*, BRNPOIS*, ZZWOLF*, SW?BRIK | FLAT8, RROCK14 |
| `marble` | MARBLE*, MARBFAC*, MARBFACE, MARBGRAY, MARBLOD1, GSTONE*, GSTFONT*, GSTGARG, GSTLION, GSTSATYR, GSTVINE*, SW?MARB, SW?GSTON, SW?GARG, SW?LION, SW?SATYR | DEM1_*, FLOOR7_2, GATE1, GATE2, GATE3 |
| `tile` | -- (none named tile in Doom 1/2) | FLAT20, FLAT5, FLOOR5_*, FLAT9, FLAT18 -- check in the headset |

Lava-crack floors (RROCK01/02/05-08, SLIME09-12) and the liquids stay with the liquids pass.

## 2. What each surface does when shot (counts as today's; kinds are new)

| Surface | Bursts | Light | Sound | Damage | Debris (new kinds) |
|---|---|---|---|---|---|
| tech | sparks off the panel (spark_metal), 2-3 white-blue electric arcs (rsb_arc), a smoke wisp | 60, 1.6, 3 tics, 170 200 255 | `rsb/impact/electric` (new) | hole_punch, soot 0.3 | circuit board bits, wire bits |
| screen | screen glass (glint_glass), a spark burst, one arc | 50, 1.4, 2, 150 220 200 | `rsb/glass` | crack | glass, board bits |
| light | the pop: bulb glass, a spark spray | 90, 2.2, 2, 255 245 220 (the pop only; no flicker) | `rsb/glass` | crack | bulb-glass shards |
| pipe | metal hit (spark_metal, shards) + a hotspot `pipe_steam`: a hissing steam jet for about 1.5 s | -- | `rsb/impact/metal`, the hotspot loops the hiss | hole_punch | metal shards |
| brick | brick chunks, red-brown dust | -- | `rsb/impact/concrete` | hole_chip | brick chunks (landing: rubble) |
| marble | white chips, fine white dust | -- | `rsb/impact/concrete` | hole_chip, less soot | marble chips (landing: marble clatter) |
| tile | tile shards, fine dust | -- | `rsb/impact/concrete` | crack, small | tile shards (landing: tile clatter) |

- **Profiles:** `<family>.tech|screen|light|pipe|brick|marble|tile` for every bullet family (bullet, pistol, pistol_9mm,
  pistol_45, magnum, rifle, chaingun_556, machinegun_762, buckshot, buckshot_magnum), derived by a script from each
  family's stone and `.metal` / `.glass` variants: same `scale`, `vary`, damage radius; bursts swapped for the surface's.
  Blasts, energy and saws fall back to their base profile for now.
- **Extreme:** the roster generator's `family()` rules apply their `*` rule to every material variant: review the
  regenerated diff so stone-only additions (dust jets, concrete frags) do not land on the new surfaces.
- **Enemy rounds** use pistol_9mm / buckshot / chaingun_556 impacts, so they get the new surfaces for free.

## 3. New debris shapes (tools/gen_chunks.py, fixed seeds, the white skin tinted by the definition's colour)

| Shape | Build | Colour | Landing sound |
|---|---|---|---|
| tech/board1-3 | a thin notched plate, ~3 x 2 cm | 40 90 50 (green) | chips, pitched high |
| tech/wire1-2 | a thin strip bent twice (like `strip`, narrower) | 180 110 60 (copper) | chips, quiet |
| light/bulb1-3 | a thin curved shard off a sphere cap | clear, 225 230 235 | glass |
| brick/chunk1-4 | a chipped block, ~4 x 2 x 1.5 cm | 150 80 62 | rubble |
| marble/chip1-4 | a flat sharp chip | 225 222 212 | marble clatter |
| tile/shard1-4 | a flat thin piece with one straight edge | 205 208 212 | tile clatter |

PARTICLEDEFS definitions as the metal shard's (collide level, restitution, restlife, landsound).

## 4. Sounds found (permitted pools; import like tools/import_debris_sounds.py, with ASSETS.md SHA-1s)

| Group | Files (length, mean loudness) |
|---|---|
| `rsb/impact/electric` | RS_Main ch/ELECTRO8.wav (0.61 s, -15.8 dB), ch/PZAPHIT.ogg (0.40 s, -11.7), ch/DSDEVZAP.ogg (1.25 s, -11.8), ch/ELECTRO7.ogg (1.40 s, -12.2); ART SOURCE hbgore/SPARKS1.ogg (1.44 s, -16.8) |
| steam hiss (pipe hotspot loop) | ART SOURCE COMBAT/WEAPONS/Flamethrower/FlamerHiss2.wav (0.90 s, -16.2), FlamerHiss1.ogg (1.33 s, -25.0); FT_lighthiss.ogg too quiet (-36) |
| `rsb/debris/tile` | ART SOURCE footstep/tilea/tile2_step1-4 (0.42 s, -34), Doomguy Footsteps DSTILE01-06 (0.16 s, -23.6) |
| `rsb/debris/marble` | ART SOURCE footstep/tileb/marble_step1-8 (0.70 s, -31) |

## 5. The queue when the owner resumes

1. **#15 emissive volumes** (build lane done pending): Engine docs/EMISSIVE_VOLUMES_15_IMPL_NOTES.md "Hand-off" -- a
   VOLUMEDEFS lump (`emissive <name>`, class gun / biggun / blast told honestly), `volume = <def>` and `vary volume` on
   flash and impact profiles, cached handles, `EmissiveVolumeEnabled` per shot with today's cone and flame as the
   fallback, the menu mirror (All effects on: 3 / 0 / 0 / 1 / 1 / 32 / 2), a `rsb_bench_flashvolumes` bench. Owner: size
   for the look; the VR optimize pass comes later.
2. **The compressed particle atlas** (after #15): pack the generated books (tools/gen_flipbooks.py: RBVS smoke puff,
   RBVF fireball, 64 frames at 512, in the scratchpad) and name them in PARTICLEDEFS.
3. **Sensory impulses** (flash blindness, ringing ears; after the atlas): call `ExposureImpulse` / `HearingImpulse`
   from RSB_Flash for the big guns once the keys arrive.
4. **This surface pass.**
5. **Slow-mo** (the owner's word: after the major ballistics work): refresh SLOWMO_PLAN.md for the systems added
   since 09-12; the ballistics lane makes the RS_SlowMo mod.
