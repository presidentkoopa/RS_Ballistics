#!/usr/bin/env python3
"""
gen_heavy_profiles.py -- profiles for the eight heavy Vanilla guns that never named any.

THESE EIGHT HAVE SHARED THE HOUSE RECIPE SINCE THEY WERE BUILT, in Vanilla, and Vanilla+ has just
grown a copy of each. An Unmaker and a Bolter fire with the same muzzle flash today. Nothing is
broken -- the fallback is doing its job -- but this is the difference between working and finished.

MOST OF THE FLASHES ALREADY EXISTED AND WERE SIMPLY NEVER WIRED, which is worth saying before
building anything: `unmaker`, `bfg_9000`, `chainsaw_heavy`, `plasma_carbine`, `rocket_launcher` and
`chaingun_556` are all in RSBDEFS and always have been. Building a second one would have been the
easy mistake and the wrong one. What is genuinely missing is RECOIL -- no energy weapon and no saw in
this package has ever had a recoil profile -- plus a flash for the two guns that have no twin.

THE OWNER ASKED FOR "LIGHT TO EXTREME" AND THIS IS WHERE THAT ACTUALLY LIVES. The WW2 set spans a
bolt rifle to an SMG. This one spans a CHAINSAW to an UNMAKER: a weapon firing THIRTY-FIVE TIMES A
SECOND, a BFG rifle at one and a sixth, a rotary launcher throwing rockets, and a saw with no
projectile at all.

    firetics 1 on the Unmaker is 35 shots a second -- TWICE the PPSh, which was already the gun that
    broke per-shot effects in the WW2 set. Its flash exists and is fine; what it must never get is a
    per-shot cloud or a per-shot mark.

RECOIL FOR AN ENERGY WEAPON IS STATED, NOT DERIVED, and the difference is said out loud. Free recoil
needs a bullet mass, a muzzle velocity and a charge; a plasma bolt has none of those, so the
arithmetic that gave the WW2 and Vanilla guns their numbers has nothing to work with. Inventing a
cartridge for a BFG so the formula would run is exactly the kind of false precision this file exists
to avoid. The two guns here that DO fire a cartridge -- the Assault Shotgun and the Rotary Gun -- are
derived like everything else.

    python tools/gen_heavy_profiles.py            # rewrite the block between the markers
    python tools/gen_heavy_profiles.py --wiring   # the sheet lines the weapons lane needs
"""
import argparse
import io
import os

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
DEFS = os.path.join(PKG, "RSBDEFS.txt")
BEGIN = "# ---- BEGIN HEAVY VANILLA (tools/gen_heavy_profiles.py)"
END = "# ---- END HEAVY VANILLA"

# THE WIRING, and the profiles each gun should name. "" means the gun states nothing for that kind,
# deliberately -- an energy weapon throws no brass and a shot-class weapon has no cartridge to name.
#
# The Vanilla gun and its new WM_VP_ twin name the SAME profiles. They are the same guns; a difference
# between them would be a bug rather than a feature.
WIRING = {
    "WM_Unmaker":         ("unmaker",         "unmaker",         "", ""),
    "WM_BFGRifle":        ("bfg_9000",        "bfg_9000",        "", ""),
    "WM_LongbarChainsaw": ("chainsaw_heavy",  "chainsaw_heavy",  "", ""),
    "WM_AssaultShotgun":  ("shotgun_assault", "shotgun_assault", "hull_12ga", "buckshot"),
    "WM_RotaryGun":       ("rotary_gun",      "chaingun_556",    "brass_556", "chaingun_556"),
    "WM_RotaryLauncher":  ("rotary_launcher", "rocket_launcher", "", ""),
    "WM_Bolter":          ("bolter",          "bolter",          "", ""),
    "WM_PlasmaCarbine":   ("plasma_carbine",  "plasma_carbine",  "", ""),
}

# ---------------------------------------------------------------- recoil that IS derived
# Two of the eight fire a real cartridge, so they get the same free-recoil arithmetic as every other
# set here: Vg = (grains * fps + 4700 * charge) / (7000 * lb), climb = Vg * 0.148 * action.
CLIMB_PER_FPS = 0.148
ACTION = {"semi": 1.15, "belt": 0.45}
DERIVED = {
    # profile: bullet grains, muzzle fps, charge grains, loaded lb, action, twin
    "shotgun_assault": (437, 1325, 32, 8.6, "semi",
                        "a gas-operated assault shotgun -- a Saiga or an AA-12, heavy enough that the gas system eats a good share of it"),
}

# ---------------------------------------------------------------- recoil that is STATED
# No cartridge, so no arithmetic. Each number is a judgement and says what it is reasoning from.
STATED = {
    "unmaker": (0.06, 0.20, 8, 3.0, 0.00,
                "THIRTY-FIVE SHOTS A SECOND. Anything you can feel per shot becomes unusable thirty-five times over, so this is a hum rather than a kick -- it accumulates into a real climb and recovers almost instantly"),
    "bfg_9000": (2.80, 0.35, 26, 8.0, 0.00,
                 "one enormous discharge every thirty tics: a deep shove you have to come back from, and all the time in the world to do it"),
    "chainsaw_heavy": (0.15, 1.30, 10, 4.0, 0.00,
                       "A SAW DOES NOT KICK, IT WANDERS. Almost no climb and the widest drift in the package -- the blade pulls the gun around rather than back, which is why bloom stays zero: it fires nothing to scatter"),
    "plasma_carbine": (0.35, 0.40, 14, 4.5, 0.00,
                       "an emitter at twelve a second: a light fast shudder, no cartridge to scatter, so no bloom"),
    "bolter": (1.80, 0.45, 20, 7.0, 0.06,
               "a heavy self-propelled bolt every eighteen tics -- it leaves under its own power, so the push is the launch rather than a recoil impulse, and it is slow enough to be felt as one shove"),
    "rotary_launcher": (1.10, 0.50, 12, 5.4, 0.00,
                        "rockets out of a revolving tube: the same recoilless shove as the launcher it borrows from, with the drum's own wander on top"),
}

# ---------------------------------------------------------------- flashes that must be BUILT
# Everything else names a flash that already exists. These three have no twin in the package.
FLASHES = {
    "bolter": dict(light=(210, 4.2, 3), color=(255, 200, 140), cone=(20, 60, 130), conetics=3,
                   bursts="flash_core, flash_petals, spk_heavy_streaks", flame=0.18, smoke=(1, 0.055, 0.7),
                   note="THE BOLTER: a rocket-propelled slug leaving under its own power. A big dirty launch flash and a lot of smoke, once every eighteen tics"),
    "shotgun_assault": dict(light=(240, 4.6, 3), color=(255, 206, 150), cone=(24, 66, 150), conetics=3,
                            bursts="flash_core, flash_petals, spk_streaks_wide", flame=0.20, smoke=(1, 0.060, 0.72),
                            note="THE ASSAULT SHOTGUN: seven pellets out of a gas gun, and the gas system means a longer, dirtier flash than a pump"),
    # The two ROTARY guns exist to look rotary. Their base recipes are the Chaingun's and the
    # Launcher's, because that is honestly what they are -- but a revolving cluster flashes from a
    # DIFFERENT BARREL each shot, which is a real distinction the single-barrel guns cannot have and
    # is exactly what the `barrels` key was built for.
    "rotary_gun": dict(light=(150, 3.0, 2), color=(255, 210, 150), cone=(16, 48, 80), conetics=2,
                       bursts="flash_core, flash_petals, spk_chaingun", flame=0.12, smoke=(1, 0.030, 0.45),
                       barrels=(6, 3.5),
                       note="THE ROTARY GUN: the Chaingun's recipe fired from a REVOLVING CLUSTER -- each shot leaves a different barrel, which is the whole visual difference between the two and is not a difference I invented"),
    "rotary_launcher": dict(light=(320, 5.2, 4), color=(255, 196, 124), cone=(24, 64, 140), conetics=4,
                            bursts="flash_core, flash_petals, backblast_fire, backblast_smoke", flame=0.10,
                            smoke=(2, 0.050, 0.66), barrels=(6, 6.0), backblast=(30, 0.7),
                            note="THE ROTARY LAUNCHER: rockets out of a revolving drum. Six tubes, and enough vents backward to be worth showing"),
}


def derived_climb(p):
    wb, vb, wc, wg, action, _note = DERIVED[p]
    vg = (wb * vb + 4700.0 * wc) / (7000.0 * wg)
    return vg, wg * vg * vg / 64.348, vg * CLIMB_PER_FPS * ACTION[action]


def blocks():
    out = [BEGIN,
           "# THE EIGHT HEAVY VANILLA GUNS. DO NOT EDIT BY HAND: change tools/gen_heavy_profiles.py.",
           "#",
           "# They have shared the house recipe since they were built -- an Unmaker and a Bolter fired with",
           "# the same muzzle flash -- and Vanilla+ has just grown a copy of each. MOST OF THEIR FLASHES",
           "# ALREADY EXISTED AND WERE NEVER WIRED (unmaker, bfg_9000, chainsaw_heavy, plasma_carbine,",
           "# rocket_launcher, chaingun_556); building second ones would have been the easy mistake.",
           "#",
           "# What was genuinely missing is RECOIL. No energy weapon and no saw in this package has ever had",
           "# a recoil profile, and for those there is no cartridge to derive one from -- so those numbers",
           "# are STATED and each says what it reasons from. Inventing a cartridge for a BFG so the formula",
           "# would run is false precision, not rigour.",
           ""]

    for p, f in FLASHES.items():
        note = f["note"]
        lr, lp, lt = f["light"]
        r, g, b = f["color"]
        ci, co, cl = f["cone"]
        sc, ss, sa = f["smoke"]
        out += ["flash %s   # %s" % (p, note),
                "  light         = %d, %.1f, %d" % (lr, lp, lt),
                "  lightcolor    = %d, %d, %d" % (r, g, b),
                "  cone          = %d, %d, %d, 8" % (ci, co, cl),
                "  conetics      = %d" % f["conetics"],
                "  bursts        = %s" % f["bursts"],
                "  flame         = %.2f" % f["flame"],
                "  smoke         = %d, %.3f, %.2f" % (sc, ss, sa),
                "  smokeparticle = rsb_smoke_gun",
                "  vary          = light 0.25, flame 0.2, cone 0.15, sparks 0.3, smoke 0.3"]
        if "barrels" in f:
            n, rad = f["barrels"]
            out += ["  barrels       = %d, %.1f" % (n, rad)]
        if "backblast" in f:
            tube, blast = f["backblast"]
            out += ["  backblast     = %d, %.2f" % (tube, blast)]
        out += ["  powdervary    = 0.35",
                "  maybe         = spk_specks 0.25",
                "  barrelheat    = 0.28, 0.22, 0.32",
                "  barrelsmoke   = rsb_smoke_barrel, 2.2",
                "  tail          = rsb/tail/br, 0.9",
                "end",
                ""]

    for p, (wb, vb, wc, wg, action, note) in DERIVED.items():
        vg, e, climb = derived_climb(p)
        out += ["recoil %s   # %s -- %.1f ft-lb, Vg %.2f fps, derived" % (p, note, e, vg),
                "  climb   = %.2f" % climb,
                "  drift   = 0.55, 4",
                "  recover = 16, 6",
                "  max     = %.1f, 3" % max(3.0, min(9.0, 3.0 + 2.2 * climb)),
                "  bloom   = 0.08",
                "  brace   = 0.75, 0.90",
                "  view    = %.1f, %d, 1, 8" % (1.0 + 1.2 * (climb / 2.6), 4 + int(4 * (climb / 2.6))),
                "end",
                ""]

    for p, (climb, drift, recover, mx, bloom, note) in STATED.items():
        out += ["recoil %s   # %s" % (p, note),
                "  climb   = %.2f" % climb,
                "  drift   = %.2f, 5" % drift,
                "  recover = %d, 6" % recover,
                "  max     = %.1f, 3" % mx,
                "  bloom   = %.2f" % bloom,
                "  brace   = 0.75, 0.90",
                "  view    = %.1f, %d, 1, 8" % (1.0 + 1.2 * (climb / 2.6), 4 + int(4 * (climb / 2.6))),
                "end",
                ""]
    out.append(END)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--wiring", action="store_true")
    args = ap.parse_args()
    if args.wiring:
        print("Both the Vanilla gun and its WM_VP_ twin name the SAME profiles -- they are the same guns.\n")
        for gun, (fl, rc, ej, rd) in WIRING.items():
            print('  gun "%s"   (and "%s")' % (gun, gun.replace("WM_", "WM_VP_")))
            print('    flashprofile   = "%s"' % fl)
            print('    recoilprofile  = "%s"' % rc)
            if ej:
                print('    ejectaprofile  = "%s"' % ej)
            else:
                print('    (no ejectaprofile: nothing leaves this gun while it fires)')
            if rd:
                print('    roundprofile   = "%s"' % rd)
            else:
                print('    (no roundprofile: it fires a shotclass, not a cartridge)')
            print()
        return
    text = io.open(DEFS, encoding="utf-8", newline="").read()
    nl = "\r\n" if "\r\n" in text else "\n"
    block = nl.join(blocks())
    if BEGIN in text and END in text:
        a, b = text.index(BEGIN), text.index(END) + len(END)
        out = text[:a] + block + text[b:]
    else:
        out = text.rstrip("\r\n") + nl + nl + block + nl
    io.open(DEFS, "w", encoding="utf-8", newline="").write(out)
    n = len([l for l in blocks() if l.startswith(("flash ", "recoil "))])
    print("%d profiles: %d flashes built, %d recoil derived, %d recoil stated" %
          (n, len(FLASHES), len(DERIVED), len(STATED)))
    print("reused and not rebuilt: unmaker, bfg_9000, chainsaw_heavy, plasma_carbine, chaingun_556, rocket_launcher, hull_12ga, brass_556, buckshot")


main()
