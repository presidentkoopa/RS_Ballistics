# STAGED -- #11: the sounds debris makes

**For:** the build lane. **Not wired;** engine #11 comes after #9.

**How #11 plays them** (COLLISION_DEBRIS_MESH_PLAN.md, "Landing sounds"):
- **Once per group:** one positional sound for a group's predicted first landing, on a local
  timer.
- **Through the normal sound path,** with pitch from the client RNG.
- **Never** on a playsim actor.

So a definition (or a burst) names ONE landing sound, and the group's size picks a variant.

**Sources:** RS_Main's library (fair game) and what RS_Ballistics already packs. Every
candidate is listed by path. Nothing is picked by ear yet. Before a final pick, each candidate
gets measured: duration, loudness and brightness. The pick goes by that and by the owner's ear.

## 1. The starting set

| Landing sound | Used by | Candidates (to measure) | Notes |
|---|---|---|---|
| `rsb/debris/brass_small` | 9mm / .45 / 5.56 casings (once they are debris) | RS_Ballistics `rsb/casing/small` (already packed, 9 files) | the tinkle we already have |
| `rsb/debris/brass_rifle` | 7.62, rifle and chaingun casings | RS_Main `combatfx/casings/DSRIFLC1-3.ogg`, `CHGNCAS1-3`; RS_Ballistics `rsb/casing/medium` | a heavier ring |
| `rsb/debris/hull` | shotgun hulls | RS_Ballistics `rsb/casing/shell` (packed); RS_Main `combatfx/casings/DSSHELL1-7` | a dull plastic tap |
| `rsb/debris/chips` | concrete chips, flat chips | RS_Main `combatfx/impact/impact0-9` (check which are grit, not a bullet crack); `ch/BOUNCE2.lmp` | a light patter; many small, quiet |
| `rsb/debris/rubble` | slabs, rubble (blasts) | RS_Main `ch/ROCKHIT1.wav`, `ch/DSMOTHUD.ogg` | a heavy stone thud, a little rattle |
| `rsb/debris/metal` | metal shards, strip | RS_Main `combatfx/magdrops/DSAOUNC1-6`, `DSBOUNC1-6` (magazine drops: real metal clatter) | pitched up for small shards |
| `rsb/debris/nut` | the hex nut | the same magdrops, pitched high, short | a bright ting and a roll |
| `rsb/debris/glass` | glass shards and slivers | RS_Ballistics `sounds/rsb/glass/glsfal.ogg`, `dsbottle.ogg`; RS_Main `combatfx/ice/ice_shatter.ogg` | a tinkle; `winbrea` is too big, keep it for the window itself |
| `rsb/debris/wood` | splinters, planks, wood chips | no good match yet: RS_Main has no wood clatter. Fallback: RS_Ballistics `rsb/impact/wood` pitched up and quiet | ask the owner for a wood-knock source |
| `rsb/debris/dirt` | clods and pebbles | RS_Main `ch/DSMOTHUD.ogg` (soft, quiet); `rs_grenade/GBOUNCE`, `rs_gh_weapon/gh_grenade/GRNBNCE` (also in `gh_handgrenade`) | clods thud, pebbles tick |
| (none) | sparks | -- | sparks don't land audibly; an ember hiss is optional (RS_Ballistics `rsb/sparks`, very quiet) |

## 2. Size and count

- **A group's size** scales the volume: a single chip is barely heard, a rocket's rubble is a
  thud. Past about 12 pieces it's one bigger variant, not louder.
- **Variety:** each landing sound is a `$random` of 3 or more files with `$limit` 2-4, as the
  casing sounds already are, and the client RNG varies the pitch.
- **Distance:** normal attenuation. Debris is quiet beyond a room.

## 3. Order, once #11 is in

1. **Wire the packed sounds:** brass, hulls, glass.
2. **Measure and pick** from the RS_Main candidates: chips, rubble, metal, dirt.
3. **Find a wood source** with the owner.
4. **Headset check, menu only:** empty a magazine into a concrete wall. Chips patter; casings
   tinkle on the floor; a rocket's rubble thuds; glass tinkles; nothing buzzes or stacks into
   noise.
