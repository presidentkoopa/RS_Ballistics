# STAGED -- gameplay recoil: RS_Ballistics' half (proposal, nothing built)

**For:** the build lane's review, then the owner. **From:** the ballistics lane, 2026-09-14.

**Owner, verbatim:** "i do want gameplay recoil but as a toggle, so it can be turned off for
purists" (VR_BODY_IK_RETURN_PLAN.md §4b).

**Ownership (from §4b):**
- **Ballistics lane, with WM_Gun:** the per-archetype profiles and the gameplay effect.
- **IK lane:** the arm's visual response.
- **RS_VR_Reload:** the prop's jolt.

**Scope:** the Vanilla set only (the eight pickup pairs). Vanilla+ archetypes wait for the owner.
All numbers are **first guesses, to tune in the headset.**

---

## 1. What recoil is in VR

The player's hand can't be pushed, so gameplay recoil moves **where the rounds go**, not the
hand.
- **Climb:** each shot adds a kick, a small upward climb plus a sideways drift. The next rounds
  leave the gun turned by the kick so far.
- **Recovery:** the kick recovers once the trigger rests.
- **Holding the trigger:** walks the rounds up and sideways. The player sees it in the tracers
  and impacts, and pulls the gun down, which a VR hand can do.
- **The first shot of a run** is always dead on.

**Two parts, two cvars:**

| | Cvar | Kind | Default | What it does |
|---|---|---|---|---|
| **Gameplay recoil** | `sv_rsb_recoil` | server bool: one rule for the whole game, never per player | **on** (the owner asked for it; purists switch it off). The owner's call. | The climb, drift and bloom above. Off: rounds fly down the hand's line as today. |
| **Visual kick** | `rsb_recoil_view` | user float 0-2 | 1 | The per-shot jolt the arm (IK) and the prop (RS_VR_Reload) show. Render only. |

> **A rule the visual side must keep:** while gameplay recoil is on, the rendered gun ALWAYS
> points where the rounds will go. It carries the current gameplay kick whatever the visual
> slider says; the slider scales only the extra per-shot jolt. Otherwise the model lies about
> the aim.
>
> A laser sight must follow the same kicked line: flagged for the laser's owner. The laser LOOK
> is protected and unchanged; only its direction follows the gun.

## 2. Netplay

- **Where it's decided:** in WM_TryFire, the weapon's own action, which runs on every machine.
- **Inputs:**
  - the map clock (`level.maptime`)
  - the shot count of the held run
  - `player.crouchfactor` and the owner's velocity (bracing)
- **Keyed to** the gun actor and its owner, never `consoleplayer`.
- **No RNG at all:** drift is a fixed pattern by shot number, so it's learnable and identical
  everywhere. Scatter keeps WM_Gun's named `WMSpread` RNG, as today.
- **Profiles resolve by base name only:** never a `~style` or `@tier` variant, because those
  follow local settings.
- **State lives on the WM_Gun actor**, so it's saved. Recovery runs on the map clock, so slow
  motion is consistent.
- **Bracing** uses only networked state until hand input is networked: crouching and standing
  still. A two-hand grip on the foregrip comes later.

## 3. The profile: RSBDEFS `recoil` (a new kind)

```
recoil <name>
  climb   = degrees up a shot
  drift   = degrees, period in shots   # yaw += degrees x sin(2 pi x shot / period): a fixed left-right walk
  recover = degrees a second, delay tics   # recovery starts `delay` tics after the last shot
  max     = pitch degrees, yaw degrees     # the kick's cap
  bloom   = extra spread degrees per degree of kick
  brace   = crouched multiplier, standing-still multiplier
  view    = back units, rise degrees, roll degrees, tics   # the visual jolt: render only, x rsb_recoil_view
end
```

A gun names its profile with `WM_Gun.RecoilProfile "name"`. Unset means no recoil.

## 4. Per-archetype numbers

**Assumed fire rates:** the pistols are semi-auto (3-5 shots a second in a headset). The pumps
are about one shot every 0.4-0.8 s. The chaingun is vanilla's 8.75 a second.

| Profile (gun) | climb | drift (deg, period) | recover (deg/s, delay) | max (pitch, yaw) | bloom | brace (crouch, still) | view (back, rise, roll, tics) | What it plays like |
|---|---|---|---|---|---|---|---|---|
| `pistol_9mm` (Pistolet) | 1.2 | 0.3, 4 | 12, 6 | 5, 2 | 0.05 | 0.7, 0.85 | 1.2, 6, 1.5, 7 | Snappy. Aimed fire is dead on; only a mag dump climbs. |
| `pistol_45` (M4A3) | 1.8 | 0.4, 4 | 12, 6 | 6, 2.5 | 0.06 | 0.7, 0.85 | 1.6, 9, 2, 9 | A bigger push. Fast follow-ups walk up. |
| `shotgun_m37` | 4 | 0.8, 3 | 6, 4 | 8, 3 | 0.1 | 0.75, 0.9 | 3.5, 14, 3, 14 | Fired as fast as you pump, it climbs; paced, never. |
| `shotgun_doom` | 4.5 | 1.0, 3 | 6, 4 | 9, 3 | 0.1 | 0.75, 0.9 | 3.8, 15, 4, 15 | Heavier than the M37. |
| `shotgun_ssg` | 7 | 1.2, 2 | 8, 6 | 10, 4 | 0.12 | 0.7, 0.9 | 5.5, 22, 5, 18 | The train wreck: a huge kick, recovered by the time it's reloaded. |
| `shotgun_bullpup` | 5 | 1.0, 3 | 8, 4 | 10, 3.5 | 0.1 | 0.75, 0.9 | 3, 11, 2, 12 | Magazine-fed and fast: it climbs if you rush it. |
| `chaingun_556` | 0.35 | 0.25, 6 | 4, 6 | 4.5, 1.5 | 0.15 | 0.65, 0.85 | 0.6, 1.5, 0.8, 4 | Hits the cap in about 13 shots (1.5 s). Held, it sits there: pull down to stay on target. |
| `machinegun_762` | 0.55 | 0.4, 5 | 4, 6 | 6, 2 | 0.2 | 0.6, 0.85 | 1.0, 2.5, 1.2, 5 | A heavier walk than the chaingun; bracing matters more. |
| `launcher_40mm` (machine gun alt) | 3 | 0, 1 | 8, 6 | 5, 0 | 0 | 0.8, 0.9 | 2.5, 8, 1, 12 | A thump. Recovered before the next grenade. |
| `rocket_launcher` | 3 | 0.3, 2 | 8, 4 | 5, 1 | 0 | 0.8, 0.9 | 3, 7, 1, 16 | Mostly visual: its rate recovers every shot. |
| `rocket_rpg` | 1 | 0, 1 | 8, 4 | 3, 0 | 0 | 1, 1 | 1.5, 3, 0.5, 12 | Recoilless: the backblast cancels the kick. |
| plasma rifle, plasma carbine | **none** | | | | | | none | The owner: no kick. |
| BFG, Heavy BFG | **none** | | | | | | none | The owner: no kick. |
| chainsaws | **none** (gameplay) | | | | | | IK lane's: a buzz while running, not a per-shot jolt | |

**Rails (A_RailAttack)** take no aim offset: the railgun is Vanilla+, and rails are left out.

**Saws** get no gameplay recoil.

## 5. The math (RS_Ballistics `RSB_Recoil`, called by WM_Gun)

Once per shot, before the pellet loop:

```
RSB_Recoil.Step(profile, now, brace, runShot,
                in/out kickPitch, in/out kickYaw, in/out lastShotTic, out bloom)
```

1. **Recover:** `dt = now − lastShotTic`. Past `delay`, recover `(dt − delay) × recover / 35`
   degrees toward 0, on both axes in proportion.
2. **This shot** leaves turned by the kick so far (the first shot of a run: 0).
3. **Add** for the next shot:
   - `kickPitch = min(maxPitch, kickPitch + climb × brace)`
   - `kickYaw = clamp(kickYaw + drift × sin(2π × runShot / period) × brace, ±maxYaw)`
4. **Bloom:** `bloom = bloomPerDegree × kickPitch`, added to the class's spread, but not while
   FirstShotsAccurate holds the shot dead on.

- **Brace:** `crouch` when `player.crouchfactor < 0.75`, times `still` when the owner's
  `Vel.XY.Length() < 2`.
- **Every pellet:** `RSB_Recoil.Turn(shot, kickYaw, kickPitch)` rotates its velocity the way
  `ScatterShot` does (world yaw and pitch), before the scatter.
- **Gameplay off (`sv_rsb_recoil` false):** Step returns zeros and changes nothing.

## 6. What WM_Gun needs (RS_VR_Reload: 63, or whoever owns WM_Gun then)

1. **A property:** `WM_Gun.RecoilProfile "name"`, plus `AltRecoilProfile` for a second barrel
   such as the 40 mm launcher.
2. **Fields on the gun**, saved with it: `recoilPitch`, `recoilYaw`, `recoilShotTic`,
   `recoilRunShot` (reset when a held run starts, the same test as `refireCount`).
3. **In WM_TryFire and WM_TryAltFire:**
   - call `RSB_Recoil.Step` once before the pellet loop
   - call `RSB_Recoil.Turn` on each round after `A_FireProjectile`, before `ScatterShot`
   - add `bloom` to `sprH` and `sprV`
   - skip for the saw and rail paths
4. **A read for the visuals:** `WM_Gun.RecoilView()` gives the current kick, decayed to this
   tic, plus the last shot's tic. With the profile's `view` numbers and `rsb_recoil_view`, the
   IK lane and the prop build their jolt. Render only.
5. **The weapons lane** adds `WM_Gun.RecoilProfile` to each Vanilla gun: the same names as
   their FlashProfile, so `pistol_9mm` and so on.

**RS_Ballistics side:**
- the `recoil` kind in parser, defs and registry
- `RSB_Recoil.Step` and `RSB_Recoil.Turn`
- the profiles in §4
- the two cvars in CVARINFO
- menu rows under Ballistics & Effects → Recoil: "Gameplay recoil (server)" and "Recoil kick
  (visual)"

## 7. Headset check, once built

1. **Pistolet:** aimed shots land where the sights are; a fast mag dump walks up about 5°.
2. **Chaingun held:** the rounds climb and drift for about 1.5 s, then hold. Pulling down keeps
   them on target. Crouched, the climb is visibly smaller.
3. **SSG:** a huge visual kick, and the next shot after the reload is dead on.
4. **Plasma and BFG:** nothing.
5. **Gameplay off:** every round flies down the hand's line, and the visual jolt is still there.
6. **Netgame:** two players see the same impacts from the same burst.
