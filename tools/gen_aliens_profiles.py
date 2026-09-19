#!/usr/bin/env python3
"""
gen_aliens_profiles.py -- the two iconic Aliens guns, built from scratch.

THE OWNER: "ONE OF THESE IS FOR AN aliens ZDOOM MOD, SO IT BETTER BE AS FUCKIN COOL AS IT SHOULD BE.
THE SMART GUN AND PLASMA RIFLE ARE ICONIC." Taken literally. These two are the guns people know from
the film before they ever load the mod; everything else in the set can stay borrowed.

NO ART CAME ACROSS from the source mod -- no flash sprites, no smoke, no tracers -- so there is
nothing to match and nothing to copy. The look is invented here, from what the guns ARE.

WHAT THEY ACTUALLY ARE, because both signatures fall out of real properties rather than taste:

  10x28mm CASELESS, shared by both. Caseless means NO BRASS -- neither gun gets an ejecta profile at
  all, and that alone sets them apart from every other automatic weapon in the game.

  AND CASELESS RUNS HOT. A brass case is a heat sink: it absorbs the burn and you throw it away. Take
  the case away and that heat stays in the gun. It is the exact problem that killed the real G11. So
  the Pulse Rifle's signature is a barrel that heats FAST and glows -- visible, physical, and true.

  THE SMARTGUN'S SIGNATURE IS THAT IT DOES NOT MOVE. It hangs on a gyro-stabilised harness and is
  fired from a handle at the hip; the rig eats the recoil, not the shooter. Thirty-nine pounds of gun
  firing a pistol-class round through a stabiliser comes out at 0.07 degrees of climb -- THE BIGGEST
  GUN IN THE SET HAS THE LEAST KICK OF ANYTHING WE SHIP, which is the whole point of the weapon and
  is not a number anyone would have typed.

  And its sheet spread is 5.6 HORIZONTAL, 0 VERTICAL. It does not rise at all -- it WALKS SIDEWAYS.
  So its drift is the widest in the package and its climb is near zero, which is the inverse of every
  other belt gun here and comes straight off the weapons lane's own numbers.

THE SMARTGUN BEING CASELESS IS MY CALL AND IS OVERRULABLE IN ONE LINE. The relay confirmed only the
Pulse Rifle. The M56 and the M41A share ammunition in the source material, and two guns in one squad
feeding from one round is a better fact than two guns that disagree -- so it throws no brass either.
Say the word and it gets `brass_10mm` instead.

    python tools/gen_aliens_profiles.py            # rewrite the block between the markers
    python tools/gen_aliens_profiles.py --table    # the derived numbers, change nothing
    python tools/gen_aliens_profiles.py --wiring   # the lines the weapons lane needs
"""
import argparse
import io
import os

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
DEFS = os.path.join(PKG, "RSBDEFS.txt")
BEGIN = "# ---- BEGIN ALIENS (tools/gen_aliens_profiles.py)"
END = "# ---- END ALIENS"

CLIMB_PER_FPS = 0.148
# `harness` IS NEW AND IS THE SMARTGUN. A gyro-stabilised rig carrying the gun's whole weight passes
# almost nothing to your aim -- less even than a bipod-braced belt gun, which is the point of wearing
# one. Named for what it does, so the next shoulder-mounted weapon can use it.
ACTION = {"auto": 0.85, "belt": 0.45, "harness": 0.25, "semi": 1.15}

# 10x28mm CASELESS, shared by both. Bullet grains, muzzle fps, propellant grains.
ROUND = (180, 2200, 30)

# gun -> loaded lb, action, rate/s, spread, flash size, note
GUNS = {
    "ae_pulserifle": (10.8, "auto", 11.67, (3, 3), 1.05,
                      "THE M41A PULSE RIFLE: 10mm caseless, and caseless means two things at once -- no brass leaves this gun at all, and the barrel keeps the heat a case would have carried away. It runs hot fast and shows it"),
    "ae_smartgun":   (39.0, "harness", 11.67, (5.6, 0), 1.30,
                      "THE M56 SMARTGUN: thirty-nine pounds on a gyro harness, fired from the hip. The rig eats the recoil, so the biggest gun in the game has the LEAST kick of anything we ship -- and its spread is flat: it walks sideways and never rises"),
}


def derive(gid):
    wg, action, rate, spread, fsize, note = GUNS[gid]
    wb, vb, wc = ROUND
    vg = (wb * vb + 4700.0 * wc) / (7000.0 * wg)
    e = wg * vg * vg / 64.348
    sx, sy = spread
    return {
        "wg": wg, "action": action, "rate": rate, "spread": spread, "fsize": fsize, "note": note,
        "vg": vg, "energy": e,
        "climb": vg * CLIMB_PER_FPS * ACTION[action],
        "drift": 0.30 + 0.055 * (sx + sy),
        "bloom": 0.02 * (sx + sy),
        "vary": min(0.95, 0.35 + 0.035 * (sx + sy)),
        "recover": int(round(min(30.0, max(8.0, 26.0 * (5.8333 / rate) ** 0.5)))),
        "conetics": 2,          # 11.7 a second: a longer cone overlaps its own successor
        "lighttics": 2,
    }


def blocks():
    out = [BEGIN,
           "# THE TWO ICONIC ALIENS GUNS. DO NOT EDIT BY HAND: change tools/gen_aliens_profiles.py.",
           "#",
           "# Both fire 10x28mm CASELESS and NEITHER HAS AN EJECTA PROFILE -- caseless throws no brass,",
           "# and that absence is deliberate. If one ever appears, someone has wired the wrong thing.",
           "#",
           "# Caseless also means the barrel keeps heat a brass case would have carried out of the gun.",
           "# That is what killed the real G11, and it is the Pulse Rifle's whole visual signature here.",
           ""]

    # ---------------------------------------------------------------- the cartridge
    out += ["ballistics ae_10mm   # 10x28mm caseless: a heavy pistol-calibre round pushed hard, shared by both guns",
            "  speed  = 470",
            "  radius = 1.8",
            "  damage = none",
            "end",
            "",
            "roundlook ae_10mm",
            "  look   = sprite, RSBT",
            "  glide  = yes",
            "  wake   = rifle_vapour",
            "  impact = ae_10mm",
            "  whiz   = 68, rsb/whiz",
            "  heat   = 5, 0.4, 9",
            "  carve  = 7, 0.85",
            "end",
            "",
            "round ae_10mm",
            "  ballistics = ae_10mm",
            "  roundlook  = ae_10mm",
            "end",
            ""]

    hole = 1.3
    for mat, bursts, snd, dmg in [
            ("", "chips_concrete, dust_concrete, spark_hot, dust_jet_concrete", "rsb/impact/concrete",
             "hole_punch, %.2f, 0.5, 0.2, 0.18" % (1.5 * hole)),
            (".metal", "spark_metal, ember_metal, spark_spray", "rsb/impact/metal",
             "pit, %.2f, 0.35, 0.25, 0.3" % (1.3 * hole)),
            (".wood", "splinter_wood, dust_wood", "rsb/impact/wood",
             "hole_splinter, %.2f, 0.55, 0.12, 0" % (1.7 * hole)),
            (".dirt", "clods_dirt, dust_dirt", "none", "pit, %.2f, 0.6, 0.1, 0" % (2.0 * hole)),
            (".glass", "glint_glass", "rsb/glass", "crack, %.2f, 0.3, 0, 0" % (2.6 * hole)),
            (".liquid", "splash_liquid", "none", None)]:
        out += ["impact ae_10mm%s" % mat,
                "  bursts    = %s" % bursts,
                "  sound     = %s" % snd]
        if mat == "":
            out += ["  mark      = pool, %.1f, 60" % (3.0 * hole),
                    "  markcolor = 60, 54, 48",
                    "  light     = 44, 1.1, 2",
                    "  lightcolor = 255, 210, 150",
                    "  glance    = 24, rsb/ricochet, spark_hot"]
        if dmg:
            out += ["  damage    = %s" % dmg]
        out += ["end", ""]

    # ---------------------------------------------------------------- the guns
    for gid in GUNS:
        d = derive(gid)
        fsize = d["fsize"]
        hot = (gid == "ae_pulserifle")
        out += ["flash %s   # %s" % (gid, d["note"]),
                "  # %s, %.1f a second, spread %g,%g -- %.1f ft-lb of free recoil (Vg %.2f fps)"
                % (d["action"], d["rate"], d["spread"][0], d["spread"][1], d["energy"], d["vg"]),
                "  light         = %d, %.1f, %d" % (int(170 * fsize), 2.4 + 1.6 * fsize, d["lighttics"]),
                "  lightcolor    = 255, 226, 186",
                "  cone          = %d, %d, %d, 8" % (14 + int(10 * fsize), 44 + int(18 * fsize), int(95 * fsize)),
                "  conetics      = %d" % d["conetics"],
                "  bursts        = flash_core, flash_petals, spk_streaks_fine",
                "  flame         = %.2f" % (0.10 * fsize + 0.05),
                "  smoke         = 1, %.3f, %.2f" % (0.026 * fsize, min(0.95, 0.38 * fsize)),
                "  smokeparticle = rsb_smoke_gun",
                "  vary          = light 0.25, flame 0.2, cone 0.15, sparks 0.3, smoke 0.3",
                "  powderburn    = %d, 6, 0.6" % (int(24 * fsize) + 6),
                "  powdervary    = %.2f" % d["vary"],
                "  maybe         = spk_specks 0.3",
                "  blastkick     = kick_puff, %d, 3" % (52 + int(22 * fsize)),
                "  exposure      = %.2f, %d" % (min(0.9, 0.28 * fsize + 0.14), int(90 * fsize) + 40),
                "  hearing       = %.2f, %d" % (min(0.9, 0.32 * fsize + 0.14), int(100 * fsize) + 46)]
        if hot:
            # THE CASELESS SIGNATURE, and the one place this gun should look unlike anything else we
            # ship. Heat that a brass case would have carried out of the gun stays in the barrel.
            out += ["  barrelheat    = 0.95, 0.14, 0.18",
                    "  barrelglow    = 0.35, 30, 1.7",
                    "  barrelglowcolor = 255, 96, 40",
                    "  barrelshimmer = 4.2, 0.7",
                    "  barrelsmoke   = rsb_smoke_barrel, 2.4"]
        else:
            out += ["  barrelheat    = 0.55, 0.20, 0.30",
                    "  barrelglow    = 0.55, 22, 1.2",
                    "  barrelglowcolor = 255, 120, 60",
                    "  barrelshimmer = 3.4, 0.6",
                    "  barrelsmoke   = rsb_smoke_barrel, 2.8",
                    "  smokevolume   = 26, 1.5, 1.1, 150, 10"]
        out += ["  tail          = rsb/tail/ar, 0.9",
                "end",
                "",
                "recoil %s   # %.1f ft-lb a shot through a %s -- climb %.2f, and the spread is %g,%g"
                % (gid, d["energy"], d["action"], d["climb"], d["spread"][0], d["spread"][1]),
                "  climb   = %.2f" % d["climb"],
                "  drift   = %.2f, 5" % d["drift"],
                "  recover = %d, 6" % d["recover"],
                "  max     = %.1f, %.1f" % (max(3.0, min(9.0, 3.0 + 2.2 * d["climb"])),
                                            max(2.0, 1.0 + 0.5 * d["spread"][0])),
                "  bloom   = %.2f" % d["bloom"],
                "  brace   = 0.75, 0.90",
                "  view    = %.1f, %d, 1, 7" % (1.0 + 1.2 * (d["climb"] / 2.6), 4 + int(4 * (d["climb"] / 2.6))),
                "end",
                "",
                "# NO `ejecta %s`: 10mm CASELESS throws nothing. If brass ever appears on this gun," % gid,
                "# something has been wired to the wrong profile.",
                ""]

    # ---------------------------------------------------------------- the underbarrel
    out += ["flash ae_pulserifle_grenade   # the M41A's underbarrel 30mm: a slow heavy lob, so a fat soft shove rather than a crack",
            "  light         = 260, 4.6, 3",
            "  lightcolor    = 255, 206, 150",
            "  cone          = 22, 62, 120, 8",
            "  conetics      = 3",
            "  bursts        = flash_core, flash_petals, flash_launcher_puff",
            "  flame         = 0.16",
            "  smoke         = 2, 0.055, 0.7",
            "  smokeparticle = rsb_smoke_soot_gun",
            "  vary          = light 0.2, flame 0.2, cone 0.15, smoke 0.3",
            "  powderburn    = 30, 8, 0.55",
            "  powdervary    = 0.4",
            "  blastkick     = kick_puff, 74, 3",
            "  exposure      = 0.6, 140",
            "  hearing       = 0.7, 170",
            "  barrelheat    = 0.3, 0.22, 0.32",
            "  barrelsmoke   = rsb_smoke_barrel_soot, 2.6",
            "  tail          = rsb/tail/rpg, 0.8",
            "end",
            "",
            "recoil ae_pulserifle_grenade   # a 30mm lobbed from under the barrel: a shove up and back, gone by the time you can fire again",
            "  climb   = 2.10",
            "  drift   = 0.40, 5",
            "  recover = 20, 6",
            "  max     = 7.0, 2",
            "  bloom   = 0.00",
            "  brace   = 0.75, 0.90",
            "  view    = 2.0, 7, 1, 10",
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
        print("%-15s %6s %7s %7s %7s %7s   %s" % ("gun", "lb", "Vg", "ft-lb", "climb", "drift", "why"))
        for gid in GUNS:
            d = derive(gid)
            print("%-15s %6.1f %7.2f %7.1f %7.2f %7.2f   %s"
                  % (gid, d["wg"], d["vg"], d["energy"], d["climb"], d["drift"], d["action"]))
        return
    if args.wiring:
        print('  gun "AE_PulseRifle"')
        print('    flashprofile   = "ae_pulserifle"')
        print('    recoilprofile  = "ae_pulserifle"')
        print('    roundprofile   = "ae_10mm"')
        print('    (NO ejectaprofile -- 10mm caseless throws no brass. Remove the borrowed brass_556.)')
        print('    altflashprofile = "ae_pulserifle_grenade"   (the underbarrel 30mm, if alt fire uses it)')
        print()
        print('  gun "AE_Smartgun"')
        print('    flashprofile   = "ae_smartgun"')
        print('    recoilprofile  = "ae_smartgun"')
        print('    roundprofile   = "ae_10mm"')
        print('    (NO ejectaprofile -- same caseless round. Remove the borrowed brass_762.)')
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
    n = len([l for l in blocks() if l.startswith(("flash ", "recoil ", "impact ", "ballistics ", "roundlook ", "round "))])
    print("%d profiles for 2 guns, 1 cartridge and an underbarrel launcher" % n)


main()
