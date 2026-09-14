# STAGED -- ballistics for enemies, and effects by distance (discussion, nothing built)

**From:** the owner's question, 2026-09-14. "Assume I had a mod to replace hitscanning enemies with projectiles. How do
we get THEM to have ballistics, too? And can we set a radius around the player where, outside of it, enemies do not get
ballistic effects, for performance concerns?" The owner: "we will cap and optimize later."

## 1. Enemies with ballistics

RS_Ballistics rounds are already real projectiles (`RSB_Bullet`): a `round` profile gives ballistics (speed, size, damage),
and its round look gives the trail, per-material impacts and the near-miss whiz or crack. Three ways in:

1. **A mod fires our round.** An enemy spawns `RSB_Bullet` (or a subclass) and names a round profile, for example
   `zombieman_9mm`. Today `RSB_Bullet.Launch(shot, PlayerInfo shooter, hand, profile)` expects a player's hand, so it needs
   a sibling: `RSB_Bullet.LaunchFrom(Actor shooter, String roundProfile)`. Small job on this lane's side.
2. **A mod keeps its own projectile** and calls our pieces:
   - `RSB_Flash.Fire(profile, muzzle, aim, beamSlot, carrierVel)` for the enemy's muzzle flash
   - `RSB_Wake.Lay` per tic for the trail
   - `RSB_Impact.Land` where it hits

   `RSB_Service` lets a mod that doesn't require RS_Ballistics reach these softly.
3. **No gameplay change:** keep enemies hitscan, give their puffs our impact looks (as `RSB_HitPuff` does), and draw a
   look-only tracer from the muzzle to the hit. It looks ballistic without changing damage or dodging.

**Netplay:** enemy projectiles are playsim actors on every machine, so flight and damage must be identical everywhere
(RSB_Bullet already is: ballistics come only from the base profile). Only looks vary per machine.

Enemy impacts were already "later" on the owner's roadmap.

## 2. Effects by distance (performance)

Safe for netplay as long as it only skips LOOKS, never movement, damage or hits. Proposed as bands, not a hard edge:

| Distance from the viewer | Enemy effects |
|---|---|
| near (under ~1,000 units) | full |
| mid | half the particles, no lights, no room smoke, no debris |
| far (over ~3,000 units) | the impact sound only |

- **Own guns:** the player's own guns are always full.
- **Room smoke queue:** far-away `EmitSmoke` still counts against the engine's 128-a-tic queue even though the smoke box
  can't draw it (build lane, 13b notes), so the bands protect that queue too.
- **Behind the player:** an optional cull skips effects there, but in VR the head turns fast and it pops in. A wide cone
  at most.
- **Settings:** an "Enemy effects distance" slider (a user cvar, looks only), plus an optional cap on full-effect enemy
  hits per tic, nearest first, for slaughter maps.
- **Where it lives:** in RSB_Impact / RSB_Flash / RSB_Bullet's look paths (a distance from the local view to the effect,
  which is fine for presentation), alongside the budget governor (ENGINE_SUPPORT_LIST #4) when caps are designed.
