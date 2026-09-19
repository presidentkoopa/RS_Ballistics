#!/usr/bin/env python3
"""
gen_recoil_real.py -- real-world recoil for the Vanilla, Vanilla+ and Modern guns.

THE OWNER: "WE WILL NEED TO INFER FOR THE VANILLA AND + SET BY FINDING POSSIBLE REAL WORLD
EQUIVALENTS. BERETTA, ITHACA, TEC9, ETC, ETC FOR THE BULLET GUNS, RIGHT?" -- right, and most of these
guns are already named after their twin. M37 is an Ithaca 37. M16 is an M16. Tec9 is a Tec-9.

THE SAME METHOD AS THE WW2 SET (tools/gen_ww2_profiles.py), which found that the real world spans
thirty-two times per shot where hand-picked numbers spanned four. Free recoil, the standard formula:

    Vg = (bullet_grains * muzzle_fps + 4700 * charge_grains) / (7000 * gun_lb)     [fps]
    E  = gun_lb * Vg^2 / 64.348                                                     [ft-lb]

Doom's guns are fictional, so the twin is an INFERENCE and every one is named in the table below. That
is the honest version of "sourced": the cartridge and the gun's weight are what the arithmetic needs,
and both are recoverable from a plausible twin even when the gun itself never existed.

WHAT IT REWRITES, AND WHAT IT LEAVES ALONE. Only `climb` and `max` -- the two that follow from
physics. `drift`, `recover`, `bloom`, `brace` and `view` are FEEL, they were authored by hand against
the guns in the owner's hands, and nothing here knows better than that. This is not a regeneration of
those profiles; it is one number in each of them getting a reason.

    python tools/gen_recoil_real.py            # rewrite climb and max in place
    python tools/gen_recoil_real.py --table    # print what it would write, change nothing
"""
import argparse
import io
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
DEFS = os.path.join(PKG, "RSBDEFS.txt")

# The same ladder the WW2 set uses: how much of the gun's rearward velocity reaches your AIM rather
# than a bipod, a shoulder or the floor. Kept identical so the two sets are on one scale.
ACTION = {"bolt": 1.55, "break": 1.50, "pump": 1.45, "revolver": 1.20, "semi": 1.15,
          "auto": 0.85, "belt": 0.45, "recoilless": 0.15}
CLIMB_PER_FPS = 0.148

# A CEILING, AND IT IS NOT A FUDGE. The arithmetic is linear in the gun's rearward velocity, which is
# right across the range these guns live in and wrong at the very top: a sawn-off double fired with
# BOTH BARRELS comes out at 6.6 degrees of muzzle rise a shot, and two shots would have you pointing at
# the ceiling. The physics is not wrong -- doing that to a real double gun genuinely hurts -- but a
# number that makes a weapon unusable is describing the world rather than the game.
#
# 4.2 is the WW2 set's own top end plus a little (its hardest, the M30 drilling, is 3.30), so the
# Super Shotgun stays the hardest-kicking thing in the game and every set is still on one scale. The
# SAME linear mapping as the WW2 set is kept deliberately: a gun that appears in both must not be
# described by two different curves.
CLIMB_CEILING = 4.2
MAX_CEILING = 9.0

# profile -> bullet grains, muzzle fps, charge grains, LOADED lb, action, the twin and why
#
# LOADED, NOT EMPTY, and it matters most exactly where it is easiest to get wrong. A pistol's empty
# weight is a fifth under the thing in your hand, and because a light gun flips FAST that error lands
# straight on climb -- an empty-weight Glock came out kicking harder than an Ithaca 37.
GUNS = {
    # ---- VANILLA and VANILLA+ (the same profiles serve both; VP_ guns name these)
    "pistol_9mm":      (115, 1150, 4.5,  2.3,  "semi", "Beretta 92FS -- the owner's own call, and Doom's pistol has always been one"),
    "pistol_45":       (230,  830, 5.0,  2.70, "semi", "M1911 -- a .45 service automatic, which is what pistol_45 says it is"),
    "shotgun_m37":     (437, 1325, 32,   6.5,  "pump", "Ithaca 37 -- the gun is literally named after it"),
    "shotgun_doom":    (437, 1325, 32,   7.0,  "pump", "a generic riot pump, heavier than the Ithaca"),
    "shotgun_ssg":     (874, 1325, 64,   7.0,  "break", "a sawn-off double fired with BOTH BARRELS -- twice the payload and twice the charge, which is why it is the hardest-kicking thing in the game"),
    "shotgun_bullpup": (960, 1325, 70,   8.4,  "pump", "a bullpup magazine shotgun, twenty pellets: more payload again, in a heavier gun"),
    "chaingun_556":    ( 62, 3020, 25,  35.0,  "belt", "an M134-class 5.56 rotary -- tiny per shot because the gun is enormous"),
    "machinegun_762":  (147, 2750, 46,  25.0,  "belt", "an M60-class 7.62 belt gun"),
    "launcher_40mm":   (3550, 250, 5.0,  6.5,  "semi", "an M79 40mm -- 230 g of projectile at 250 fps, so the kick is a slow shove rather than a snap"),
    # ---- MODERN / BREACH
    "glock17":         (115, 1230, 4.5,  2.00,  "semi", "Glock 17, 9x19"),
    "glock17_sup":     (115, 1050, 4.5,  2.70,  "semi", "Glock 17 with a can: heavier, and subsonic ammunition, so it kicks noticeably less"),
    "kimber1911":      (230,  830, 5.0,  2.70,  "semi", "Kimber 1911, .45 ACP"),
    "mk18":            ( 62, 2650, 25,   6.5,  "auto", "Mk18 CQBR, 10.3 inch 5.56"),
    "mk18_sup":        ( 62, 2600, 25,   7.6,  "auto", "the same with a suppressor: more weight, the same round"),
    "hk416_sup":       ( 62, 2900, 25,   8.9,  "auto", "HK416 suppressed, a longer barrel than the Mk18"),
    "mcx_sup":         (125, 1000, 12,   8.0,  "auto", "an MCX in .300 Blackout subsonic, which is the whole point of that gun"),
    "g36c_sup":        ( 62, 2560, 25,   7.9,  "auto", "G36C suppressed"),
    "mp5":             (115, 1250, 5.5,  6.8,  "auto", "MP5, 9x19 out of a heavy roller-locked gun"),
    "benelli_m4":      (437, 1325, 32,   8.4,  "semi", "Benelli M4, semi-auto 12 gauge -- the gas system eats some of it"),
}

# THE RECOILLESS ONES ARE NOT A CARTRIDGE PROBLEM and the formula does not describe them: a launcher
# that vents its gas out of the back has almost nothing left to give the shooter. Stated, not derived,
# and said out loud so nobody looks for the arithmetic later.
RECOILLESS = {
    "rocket_launcher": (1.10, "a shoulder tube that vents backward -- most of it goes out of the rear"),
    "rocket_rpg":      (1.00, "recoilless by design: the backblast cancels the kick"),
}


def free_recoil(row):
    wb, vb, wc, wg = row[0], row[1], row[2], row[3]
    vg = (wb * vb + 4700.0 * wc) / (7000.0 * wg)
    return vg, wg * vg * vg / 64.348


def derived():
    """profile -> (climb, max, Vg, energy, note)."""
    out = {}
    for p, row in GUNS.items():
        vg, e = free_recoil(row)
        climb = vg * CLIMB_PER_FPS * ACTION[row[4]]
        climb = min(CLIMB_CEILING, climb)
        out[p] = (climb, max(3.0, min(MAX_CEILING, 3.0 + 2.2 * climb)), vg, e, row[5])
    for p, (climb, note) in RECOILLESS.items():
        out[p] = (climb, max(3.0, min(MAX_CEILING, 3.0 + 2.2 * climb)), 0.0, 0.0, note)
    return out


def rewrite(text, name, climb, mx):
    """Replace only `climb` and `max` inside one recoil block. Everything else is hand-authored feel."""
    m = re.search(r"(?m)^recoil %s(?:\s|$).*?^end" % re.escape(name), text, re.S)
    if not m:
        return text, False
    block = m.group(0)
    new = re.sub(r"(?m)^(\s*climb\s*=\s*)[-0-9.]+", lambda g: "%s%.2f" % (g.group(1), climb), block, count=1)
    # `max` is pitch, yaw -- only the pitch cap follows from the kick; the yaw cap is drift's business.
    new = re.sub(r"(?m)^(\s*max\s*=\s*)[-0-9.]+", lambda g: "%s%.1f" % (g.group(1), mx), new, count=1)
    if new == block:
        return text, False
    return text[:m.start()] + new + text[m.end():], True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--table", action="store_true")
    args = ap.parse_args()
    d = derived()

    if args.table:
        print("%-16s %6s %7s %7s %6s   %s" % ("profile", "Vg", "ft-lb", "climb", "max", "inferred twin"))
        for p in sorted(d, key=lambda k: -d[k][3]):
            climb, mx, vg, e, note = d[p]
            print("%-16s %6.2f %7.1f %7.2f %6.1f   %s" % (p, vg, e, climb, mx, note))
        return

    text = io.open(DEFS, encoding="utf-8", newline="").read()
    done, missing = 0, []
    for p in sorted(d):
        climb, mx = d[p][0], d[p][1]
        text, ok = rewrite(text, p, climb, mx)
        if ok:
            done += 1
        else:
            missing.append(p)
    io.open(DEFS, "w", encoding="utf-8", newline="").write(text)
    print("%d recoil profiles given real-world figures" % done)
    if missing:
        print("NOT FOUND (no such recoil block, or nothing to change): %s" % ", ".join(missing))


main()
