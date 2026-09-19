#!/usr/bin/env python3
"""
gen_extras_profiles.py -- their own profiles for the seven Vanilla+ extras that share the house ones.

WHAT THIS IS FOR. The coverage table said 0 broken across five sets, which is true and was not the
whole truth: seventeen guns are on the HOUSE RECIPE rather than their own, and seven of those share it
for their LOOKS as well as their kick. A Tec-9 and an M16 currently fire with the same muzzle flash,
throw the same brass and shoot the same-looking round, because neither states a profile and both fall
back to `default`.

Nothing is silent -- that is what the fallback is for -- but two guns that look identical is not a set
that is finished.

    Moonlight, Sunset, ColaRevolver     fan alt-fire, eight shots        -> revolvers
    Rifle, M16                          select-fire, three-round burst   -> 5.56 assault rifles
    SMG, Tec9                           "shred" alt at double rate       -> 9mm submachine guns

THE TWINS ARE INFERRED AND EVERY ONE IS NAMED, which is the owner's own instruction: "WE WILL NEED TO
INFER FOR THE VANILLA AND + SET BY FINDING POSSIBLE REAL WORLD EQUIVALENTS. BERETTA, ITHACA, TEC9."
Their cards carry no damage or spread at all -- only firetics and an alt mode -- so the ACTION is all
the sheet gives me, and the action is what tells you what kind of gun it is.

RECOIL COMES FROM THE SAME FREE-RECOIL ARITHMETIC as every other set here, on one scale with them.
Rounds point at cartridges that already exist (pistol_9mm, rifle_556, revolver_357): these are modern
guns firing modern ammunition and inventing a fourth 9mm would be inventing, not describing.

THE WEAPONS LANE HAS TO NAME THEM. A gun gets its own profile by stating it; RS_Ballistics is handed a
NAME and never the gun, so a gun that names nothing can only ever reach the house recipe. The lines
this file expects are printed by --wiring.

    python tools/gen_extras_profiles.py            # rewrite the block between the markers
    python tools/gen_extras_profiles.py --table    # the derived numbers, change nothing
    python tools/gen_extras_profiles.py --wiring   # the sheet lines the weapons lane needs to add
"""
import argparse
import io
import os

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
DEFS = os.path.join(PKG, "RSBDEFS.txt")
BEGIN = "# ---- BEGIN VANILLA+ EXTRAS (tools/gen_extras_profiles.py)"
END = "# ---- END VANILLA+ EXTRAS"

ACTION = {"revolver": 1.20, "semi": 1.15, "auto": 0.85}
CLIMB_PER_FPS = 0.148
CLIMB_CEILING = 4.2

# gun -> round, bullet grains, muzzle fps, charge grains, loaded lb, action, brass, flash size,
#        rate/s, the inferred twin and why
GUNS = {
    "moonlight":  ("revolver_357", 158, 1250, 14.0, 2.60, "revolver", "none", 1.15, 5.83,
                   "a .357 service revolver -- fan alt-fire and eight shots say revolver, and a long barrel says it is the tidier of the pair"),
    "sunset":     ("revolver_357", 240, 1180, 21.0, 3.10, "revolver", "none", 1.35, 5.83,
                   "the heavier twin: a .44 Magnum, so it hits harder and rises further than the Moonlight and reads as its opposite number"),
    "colarevolver": ("revolver_357", 158, 1150, 12.0, 2.20, "revolver", "none", 1.05, 5.83,
                   "a short snub .357 -- lighter and cruder than either, which is the joke in the name"),
    "rifle":      ("rifle_556",     62, 3100, 27.0, 7.90, "semi", "small", 1.00, 5.83,
                   "an M16A1: full-length 5.56, select fire, three-round burst exactly as the card says"),
    "m16":        ("rifle_556",     62, 3050, 27.0, 8.50, "semi", "small", 0.95, 5.83,
                   "an M16A4, heavier than the Rifle and a shade calmer for it"),
    "smg":        ("pistol_9mm",   115, 1200,  5.5, 7.70, "auto", "small", 0.70, 8.75,
                   "an Uzi-class 9mm: heavy for the round, so it is the steady one of the pair"),
    "tec9":       ("pistol_9mm",   115, 1250,  5.5, 3.50, "auto", "small", 0.80, 8.75,
                   "a Tec-9, and it is LIGHT -- three and a half pounds of 9mm submachine gun, which is exactly why it has the reputation it has"),
}

BRASS = {
    "small": (0.9, "rsb/casing/small", 10, "a pistol case"),
    "none":  (0.0, "", 0, "nothing ejects while firing"),
}


def derive(gid):
    rnd, wb, vb, wc, wg, action, brass, fsize, rate, note = GUNS[gid]
    vg = (wb * vb + 4700.0 * wc) / (7000.0 * wg)
    e = wg * vg * vg / 64.348
    climb = min(CLIMB_CEILING, vg * CLIMB_PER_FPS * ACTION[action])
    return {
        "round": rnd, "action": action, "brass": brass, "fsize": fsize, "rate": rate, "note": note,
        "vg": vg, "energy": e, "climb": climb,
        "max": max(3.0, min(9.0, 3.0 + 2.2 * climb)),
        "recover": int(round(min(30.0, max(8.0, 26.0 * (5.8333 / rate) ** 0.5)))),
        "conetics": 3 if rate < 11.0 else 2,
    }


def blocks():
    out = [BEGIN,
           "# THEIR OWN PROFILES FOR THE SEVEN VANILLA+ EXTRAS. DO NOT EDIT BY HAND: change",
           "# tools/gen_extras_profiles.py and run it again.",
           "#",
           "# These seven shared the HOUSE RECIPE for their looks as well as their kick, so a Tec-9 and an",
           "# M16 fired with the same muzzle flash and threw the same brass. Nothing was silent -- that is",
           "# what the fallback is for -- but two guns that look identical is not a finished set.",
           "#",
           "# Their cards carry no damage and no spread, only firetics and an alt mode, so the ACTION is all",
           "# the sheet gives and the action is what says what kind of gun it is. Twins are INFERRED and each",
           "# one is named on its own profile.",
           ""]
    for gid in GUNS:
        d = derive(gid)
        p = "vp_" + gid
        fsize = d["fsize"]
        out += ["flash %s   # %s" % (p, d["note"]),
                "  # %s, %.1f a second, %.1f ft-lb of free recoil (Vg %.2f fps)" % (d["action"], d["rate"], d["energy"], d["vg"]),
                "  light         = %d, %.1f, 3" % (int(150 * fsize), 2.2 + 1.6 * fsize),
                "  lightcolor    = 255, 214, 160",
                "  cone          = %d, %d, %d, 8" % (12 + int(10 * fsize), 40 + int(18 * fsize), int(105 * fsize)),
                "  conetics      = %d" % d["conetics"],
                "  bursts        = flash_core, flash_petals, spk_streaks_fine",
                "  flame         = %.2f" % (0.10 * fsize + 0.05),
                "  smoke         = 1, %.3f, %.2f" % (0.022 * fsize, min(0.95, 0.32 * fsize)),
                "  smokeparticle = rsb_smoke_gun",
                "  vary          = light 0.25, flame 0.2, cone 0.15, sparks 0.3, smoke 0.3",
                "  powderburn    = %d, 6, 0.55" % (int(22 * fsize) + 6),
                "  powdervary    = 0.35",
                "  maybe         = spk_specks 0.25",
                "  blastkick     = kick_puff, %d, 3" % (48 + int(20 * fsize)),
                "  exposure      = %.2f, %d" % (min(0.9, 0.26 * fsize + 0.12), int(80 * fsize) + 36),
                "  hearing       = %.2f, %d" % (min(0.9, 0.30 * fsize + 0.12), int(90 * fsize) + 44),
                "  barrelheat    = %.2f, 0.22, 0.32" % min(0.95, 0.22 * fsize),
                "  barrelsmoke   = rsb_smoke_barrel, %.1f" % min(7.8, 1.9 * fsize),
                "  tail          = %s, %.1f" % ("rsb/tail/ar" if d["round"] == "rifle_556" else "rsb/tail/pistol", 0.8),
                "end",
                "",
                "recoil %s   # %.1f ft-lb a shot, %s" % (p, d["energy"], d["action"]),
                "  climb   = %.2f" % d["climb"],
                "  drift   = %.2f, 5" % (0.30 + 0.05 * (2 if d["action"] == "auto" else 1)),
                "  recover = %d, 6" % d["recover"],
                "  max     = %.1f, 2" % d["max"],
                "  bloom   = 0.05",
                "  brace   = 0.70, 0.85",
                "  view    = %.1f, %d, 1, 6" % (1.0 + 1.2 * (d["climb"] / 2.6), 4 + int(4 * (d["climb"] / 2.6))),
                "end",
                ""]
        sc, snd, hot, what = BRASS[d["brass"]]
        if d["brass"] == "none":
            out += ["# no `ejecta %s`: a revolver holds its brass in the cylinder until you dump all six --" % p,
                    "# leave ejectaprofile off this card, the same as the WW2 revolver and the M30 drilling.",
                    ""]
            continue
        out += ["ejecta %s   # %s" % (p, what),
                "  look    = model, RSB_Casing9mm",
                "  scale   = %.2f" % sc,
                "  speed   = 1.0, 0.25",
                "  bounce  = 0.5, 0.35, 5",
                "  gravity = 0.6",
                "  sound   = %s" % snd,
                "  hot     = %d" % hot,
                "  life    = 2100",
                "  portsmoke = rsb_smoke_port, 2",
                "  wisp    = rsb_casing_wisp, 12",
                "end",
                ""]
    out.append(END)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--table", action="store_true")
    ap.add_argument("--wiring", action="store_true")
    args = ap.parse_args()

    if args.table:
        print("%-14s %7s %7s %7s %6s   %s" % ("gun", "Vg", "ft-lb", "climb", "max", "inferred twin"))
        for gid in sorted(GUNS, key=lambda g: -derive(g)["energy"]):
            d = derive(gid)
            print("%-14s %7.2f %7.1f %7.2f %6.1f   %s" % (gid, d["vg"], d["energy"], d["climb"], d["max"], d["note"]))
        return
    if args.wiring:
        print("WMSHEET.plus_extras -- one line per kind, per gun:")
        for gid in GUNS:
            d = derive(gid)
            name = "vp_" + gid
            print('\n  gun "WM_%s"' % {"colarevolver": "ColaRevolver", "m16": "M16", "smg": "SMG",
                                       "tec9": "Tec9", "rifle": "Rifle", "moonlight": "Moonlight",
                                       "sunset": "Sunset"}[gid])
            print('    flashprofile   = "%s"' % name)
            print('    recoilprofile  = "%s"' % name)
            if d["brass"] != "none":
                print('    ejectaprofile  = "%s"' % name)
            print('    roundprofile   = "%s"' % d["round"])
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
    n = len([l for l in blocks() if l.startswith(("flash ", "recoil ", "ejecta "))])
    print("%d profiles for %d guns" % (n, len(GUNS)))


main()
