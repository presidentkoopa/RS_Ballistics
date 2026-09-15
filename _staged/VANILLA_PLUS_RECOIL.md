# STAGED -- Vanilla+ round 1: recoil is the accuracy penalty (the ballistics lane's proposal)

**Source:** `RS_VR_Weapons/_pending/VANILLA_PLUS_ROUND1.md`, section 2 (the owner led it with the weapons lane,
2026-09-15). The owner: "vanilla+ should take advantage of our more advanced ballistic shit, such as recoil. that should
be the source of all accuracy penalties ... isn't that how it works IRL?" and "Two handing the pistol negates the
accuracy penalty, both alt fire and normal fire".

**Status:** a proposal. Nothing is built. The weapons lane and the reload lane answer, then this lane builds its half.

**Vanilla stays exactly as it is:**
- Every addition is opt-in per recoil profile, with defaults that change nothing.
- The Vanilla guns' profiles never use them.

---

## A. Two hands tame the kick (braced recoil)

- **API (additive):** `RSB_Recoil.Step(profile, shooter, kickPitch, kickYaw, lastTic, runShot, bool twoHanded = false)`.
  - Today's callers are unchanged.
  - The gun passes true when its other hand holds the support grip.
- **Profile key:** `brace = crouched, still[, two hands]`. The third value defaults to 1 (no change).
  - It multiplies what each shot ADDS (climb and drift), like crouching and standing still, and stacks with them.
  - Bloom is `bloom x kick`, so braced fire also spreads less by itself.
  - The first shot of a run is still dead on.
- **Proposed two-hands scales** (first guesses, headset-tuned):

  | Guns | Two hands | Why |
  |---|---|---|
  | Pistols, Handgun (and their 3-round burst) | 0.25 | "negates" the penalty: a quarter of the kick |
  | Revolvers, aimed | 0.3 | a heavier push |
  | Revolver fanning | 1 | the other hand is fanning, not bracing |
  | Rifle, M16 (every mode) | 0.4 | shoulder-and-hand hold |
  | SMG, Tec9 (and shred) | 0.5 | a light gun still walks |
  | Shotguns: pump, slamfire, SSG, bullpup, Quad | 0.6 | the push is mostly body |

- **NETPLAY BLOCKER (must be solved first).** Recoil turns rounds, so it is GAMEPLAY and must be identical on every
  machine.
  - `RS_VR_Reload system.zs SupportHeld` reads LOCAL hand input; its own comment points to
    `Engine docs/NETWORK_HAND_INPUT_PLAN.md`, which is still "plan only".
  - Passed straight into Step, the kick would differ between machines in a netgame.
  - **Proposal (reload lane):**
    - A network event when a hand takes or lets go of a gun's support grip, the way the fan gesture travels.
    - The playsim keeps `braced` per player and hand, and the fire action passes that.
    - A one-tic delay on grab or release is harmless.
  - **The same state** should also feed `CanFire`'s two-handed check. It reads `SupportHeld` today, which has the same
    exposure.

## B. Recoil off: the spread fallback

- **Owner of the state:** RS_Ballistics (`RSB_Recoil.Step`). The reload lane needs no new fields: the fallback reuses the
  four values the gun already keeps (kickPitch as the spread built up, lastTic, runShot).
- **Profile key (opt-in):** `offspread = degrees a shot, most degrees`.
  - With `sv_rsb_recoil` off and `offspread` stated, Step returns yaw 0 and pitch 0 (no turn). Its bloom is the spread
    built up.
  - Each shot adds `degrees a shot x brace` (crouched, still, two hands), capped at `most`.
  - It recovers at the profile's own `recover` rate and delay.
  - Without `offspread`, off is exactly today: all zero. Every Vanilla profile is like that.
- **Suggested starting values:** about `climb x 0.6` a shot, `most` about `max pitch x 0.6`. That makes the cone the size
  the kick would have wandered. Examples:
  - pistol 0.7 a shot, most 3
  - rifle auto 0.35, most 3
  - shotgun 2.4, most 5
- **The round cone** (`spreadshape = cone`) is the reload lane's `ScatterShot`. The bloom widens its radius the same way it
  widens today's box.

## C. Profiles for the round-1 fire modes (this lane writes them once the names are agreed)

A gun names `recoilprofile` and `altrecoilprofile`. Select fire needs one per mode, so the reload lane passes the current
mode's profile (for example sheet keys `burstrecoilprofile` / `autorecoilprofile`, or a mode suffix). Their call.

| Profile | For | Shape (first guesses) |
|---|---|---|
| `plus_pistol` | Pistol / Handgun semi, 6 a second | climb 1.3, recover 12 / 6: at full rate nothing recovers between shots, so a fast string climbs; paced or two-handed stays on |
| `plus_pistol_burst` | the 3-round burst, a round every ~4 tics | climb 1.5, recover delay 8 so the burst never recovers mid-burst |
| `plus_revolver` | Moonlight, Sunset, Cola aimed | climb 2.4, recover 10 / 7 |
| `plus_revolver_fan` | fanning, up to ~8 a second | climb 3, drift 1.2 / 2, two hands 1, a wider bloom |
| `plus_rifle_single` / `_burst` / `_auto` | Rifle, M16 select fire | single 1.6; burst 1.2 with delay 8; auto 0.5 with a cap near 5 |
| `plus_smg` / `plus_smg_shred` | SMG, Tec9 / hold alt for double rate | 0.5 / 0.45 a shot, shred caps sooner and higher |
| `plus_shotgun_slam` | Steelgun slamfire | as the pump, delay shorter |
| `plus_quad_double` | Quad Super alt: one 20-pellet double-damage blast | climb 10, the heaviest view jolt |

**Looks for the modes:**
- The burst, fanning and shred reuse their gun's flash and tail, one per round.
- The Quad's double blast gets one bigger flash (`shotgun_quad_double`: the SSG's, surged) and one tail.
- The 20 pellets stay 20 rounds, as the owner said.

## D. Order
1. The reload lane agrees the networked braced state and the mode-profile naming.
2. This lane:
   - adds `twoHanded` and `brace`'s third value;
   - adds `offspread` and the recoil-off fallback;
   - writes the section C profiles and the Quad flash.
   - All are default-neutral for Vanilla. Check, install, push.
3. The weapons lane names the profiles on the Vanilla+ sheets.
4. The owner tunes the numbers in the headset.
