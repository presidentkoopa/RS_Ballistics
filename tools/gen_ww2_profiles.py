#!/usr/bin/env python3
"""
gen_ww2_profiles.py -- effect recipes for the WW2 set: sixteen guns, six cartridges, nothing reused.

THE OWNER'S INSTRUCTION was ALL NEW EFFECTS, NO REUSING EXISTING PROFILES -- not a WW2 rifle pointed at
`rifle_762`. So every profile here is its own, and the modern set is untouched.

WHAT MAKES THEM NOT MODERN, and it is not a tint:
  * 1940s propellant is DIRTY. More unburnt powder leaves the muzzle and burns outside it, so the flash
    is bigger, slower and yellower than anything in the modern set (255,200,130 against 255,220,170),
    the cone lives a tic longer, and powder clumps are common rather than occasional.
  * THE SMOKE HANGS. A modern round's haze clears; this stuff sits in the room. Higher smoke rate and a
    smoke volume with a long life on every gun.
  * THE BRASS IS LONG. Rifle cases for the Mauser and the '06, and they stay hot longer.
  * RECOIL IS HEAVY AND RECOVERS SLOWLY. A modern carbine settles; these do not.

THE TWO POLES, and the whole set is built along the line between them (the weapons lane's framing, and
a better brief than any adjective): the Kar98k is 40 damage at 3.9 shots a second with a 2,3 spread --
one shot that matters. The MP40 is 12 at 17.5 with 5,3 -- a hose. IF THOSE TWO READ AS THE SAME FAMILY
AT DIFFERENT RATES, THIS HAS FAILED.

SIX CARTRIDGES, NOT SIXTEEN GUNS, for everything the cartridge decides: how fast the round flies, how
big the brass is, what the hole looks like. A gun's own character -- flash, recoil -- is per gun,
because the MG42 and the Kar98k are the SAME 7.92x57 and could not be further apart: 37 damage belt-fed
at 11.7/s against 40 bolt-action at 3.9/s. They share the cartridge and share nothing about delivery.

RATE OF FIRE IS SHOT-TO-READY, not a state's first frame. The weapons lane caught that their sheet read
`firetics` from the opening frames, which makes a bolt-action Kar98k fire thirty-five times a second;
building against that would have given it a thin fast modern flash with no smoke, which is exactly the
failure the poles test for. The rates below are what a player can actually pull.

    python tools/gen_ww2_profiles.py            # rewrite the block between the markers
    python tools/gen_ww2_profiles.py --check    # print it, write nothing
"""
import argparse
import io
import os

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
DEFS = os.path.join(PKG, "RSBDEFS.txt")
BEGIN = "# ---- BEGIN WW2 (tools/gen_ww2_profiles.py)"
END = "# ---- END WW2"

# cartridge -> speed, round radius, brass kind, hole size, what it is
CARTRIDGE = {
    "9mm":     (330, 1.5, "small",  0.9, "9x19 Parabellum: light, fast, clean-ish for the period"),
    "45":      (250, 2.0, "medium", 1.2, ".45 ACP: heavy, slow, a big soft hole"),
    "762tok":  (430, 1.4, "small",  0.95, "7.62x25 Tokarev: a bottlenecked pistol round, fast and spiteful"),
    "792kurz": (470, 1.7, "medium", 1.15, "7.92x33 Kurz: a short rifle round, the first of its kind"),
    "792":     (620, 2.0, "rifle",  1.45, "7.92x57 Mauser: a full rifle cartridge, and it shows"),
    "3006":    (600, 2.0, "rifle",  1.4, ".30-06 Springfield: the American full-power round"),
    "12ga":    (300, 2.2, "hull",   1.0, "12 gauge buckshot: ten pellets of it"),
}

# gun -> cartridge, damage, rate/s, action, flash size, smoke, recoil (climb, drift, recover, max), note
GUN = {
    "kar98k":    ("792",     40, 3.9,  "bolt",  1.55, 1.9, (2.6, 0.5, 26, 9),
                  "THE KAR98K: the set in one gun. A full rifle cartridge fired four times a second -- a huge dirty flash, smoke that hangs in the doorway, and a push you have to come back from"),
    "mg42":      ("792",     37, 11.7, "belt",  0.85, 1.35, (0.55, 0.5, 9, 7),
                  "THE MG42: the same cartridge as the Kar98k and nothing else in common. Small per shot because there are twelve a second, but the smoke never gets a chance to clear"),
    "heavymg":   ("792",     28, 8.8,  "belt",  1.1, 1.5, (0.8, 0.7, 11, 8),
                  "THE HEAVY MG: the sloppiest thing in the set at a 5,4 spread, and it should look it -- the widest, dirtiest flash of the lot"),
    "garand":    ("3006",    30, 4.4,  "semi",  1.35, 1.6, (1.9, 0.45, 20, 8),
                  "THE M1 GARAND: a full-power round from a semi-auto -- a hard flash and a real push, eight times before the clip leaves"),
    "bar":       ("3006",    30, 5.0,  "auto",  1.3, 1.6, (1.7, 0.6, 18, 9),
                  "THE BAR: a rifle cartridge on full auto, which is as unreasonable as it sounds"),
    "trench":    ("12ga",    12, 5.0,  "pump",  1.6, 2.0, (2.3, 0.4, 22, 9),
                  "THE TRENCH GUN: ten pellets and a cloud. The only pellet gun in the set"),
    "m1911":     ("45",      18, 11.7, "semi",  0.85, 1.1, (1.0, 0.4, 12, 5),
                  "THE COLT M1911: a fat slow .45, a soft yellow flash and a lazy push"),
    "luger":     ("9mm",     12, 11.7, "semi",  0.7, 0.95, (0.8, 0.35, 11, 4),
                  "THE LUGER P08: small, sharp and tidy -- the cleanest thing here, which is not saying much"),
    "thompson":  ("45",      15, 11.7, "auto",  0.9, 1.25, (1.05, 0.65, 12, 7),
                  "THE THOMPSON M1A1: .45 on full auto -- fat rounds, a fat flash, and it climbs"),
    "mp40":      ("9mm",     12, 17.5, "auto",  0.6, 1.0, (0.5, 0.5, 8, 6),
                  "THE MP40: the other pole. Twelve damage seventeen times a second -- a small sooty flash and a gun you hose with"),
    "ppsh":      ("762tok",  15, 17.5, "auto",  0.65, 1.05, (0.5, 0.55, 8, 6),
                  "THE PPSH-41: seventeen a second out of a drum -- a fast spiteful little flash and a stream of brass"),
    "stg44":     ("792kurz", 20, 17.5, "auto",  0.8, 1.2, (0.75, 0.45, 10, 6),
                  "THE STG 44: the first assault rifle, and it sits exactly between the rifles and the subguns because that is what it was for"),
}

BRASS = {
    "small":  (0.9, "rsb/casing/small", 10, "a pistol case"),
    "medium": (1.05, "rsb/casing/medium", 12, "a fat pistol case"),
    "rifle":  (1.35, "rsb/debris/brass_rifle", 16, "a long rifle case, and it stays hot"),
    "hull":   (1.2, "rsb/casing/shell", 8, "a paper hull"),
}


def cartridge_blocks(nl):
    out = []
    for cid, (speed, radius, brass, hole, what) in CARTRIDGE.items():
        p = "ww2_" + cid
        out += ["ballistics %s   # %s" % (p, what),
                "  speed  = %d" % speed,
                "  radius = %.1f" % radius,
                "  damage = 5, 3",
                "end",
                "",
                "roundlook %s" % p,
                "  look   = sprite, RSBT",
                "  glide  = yes",
                "  wake   = %s" % ("pellet_vapour" if cid == "12ga" else "rifle_vapour" if speed >= 470 else "pistol_vapour"),
                "  impact = %s" % p,
                "  whiz   = %d, rsb/whiz" % (72 if speed >= 470 else 64),
                "  heat   = %d, 0.4, %d" % (6 if speed >= 470 else 4, 10 if speed >= 470 else 8),
                "  carve  = %d, 0.85" % (8 if speed >= 470 else 6),
                "end",
                "",
                "round %s" % p,
                "  ballistics = %s" % p,
                "  roundlook  = %s" % p,
                "end",
                ""]
    return out


def impact_blocks(nl):
    """One impact family per cartridge, and the period's holes are bigger and sootier."""
    out = []
    for cid, (speed, radius, brass, hole, what) in CARTRIDGE.items():
        p = "ww2_" + cid
        heavy = speed >= 470
        out += ["impact %s   # %s" % (p, what),
                "  bursts    = %s" % ("chips_concrete, dust_concrete, spark_hot, dust_jet_concrete" if heavy
                                      else "chips_tight_concrete, dust_concrete, spark_hot"),
                "  mark      = pool, %.1f, 60" % (3.0 * hole),
                "  markcolor = 60, 54, 48",
                "  sound     = rsb/impact/concrete",
                "  light     = %d, 1.1, 2" % (48 if heavy else 36),
                "  lightcolor = 255, 200, 140",
                "  glance    = 22, rsb/ricochet, spark_hot",
                "  damage    = hole_punch, %.2f, 0.5, 0.2, 0.18" % (1.5 * hole),
                "  glancedamage = gouge, %.2f, 0.25, 0.15, 0.15, travel" % (2.4 * hole),
                "end",
                "",
                "impact %s.metal" % p,
                "  bursts    = spark_metal, ember_metal, spark_spray",
                "  mark      = pool, %.1f, 45" % (2.4 * hole),
                "  markcolor = 255, 190, 110",
                "  sound     = rsb/impact/metal",
                "  light     = %d, 1.6, 3" % (64 if heavy else 48),
                "  lightcolor = 255, 200, 140",
                "  glance    = 28, rsb/ricochet, spark_metal",
                "  damage    = pit, %.2f, 0.35, 0.25, 0.3" % (1.3 * hole),
                "end",
                "",
                "impact %s.wood" % p,
                "  bursts    = splinter_wood, dust_wood",
                "  sound     = rsb/impact/wood",
                "  damage    = hole_splinter, %.2f, 0.55, 0.12, 0" % (1.7 * hole),
                "end",
                "",
                "impact %s.dirt" % p,
                "  bursts    = clods_dirt, dust_dirt",
                "  sound     = none",
                "  damage    = pit, %.2f, 0.6, 0.1, 0" % (2.0 * hole),
                "end",
                "",
                "impact %s.glass" % p,
                "  bursts    = glint_glass",
                "  sound     = rsb/glass",
                "  damage    = crack, %.2f, 0.3, 0, 0" % (2.6 * hole),
                "end",
                "",
                "impact %s.liquid" % p,
                "  bursts    = splash_slime" if cid == "12ga" else "  bursts    = splash_liquid",
                "  sound     = none",
                "end",
                ""]
    return out


def gun_blocks(nl):
    out = []
    for gid, (cid, dmg, rate, action, fsize, smoke, rec, note) in GUN.items():
        p = "ww2_" + gid
        speed = CARTRIDGE[cid][0]
        brass = CARTRIDGE[cid][2]
        heavy = speed >= 470
        fast = rate >= 11.0
        # A FAST GUN CANNOT AFFORD A BIG FLASH: at seventeen a second the screen is the flash.
        light = int(150 * fsize + (60 if heavy else 0))
        cone_len = 110 * fsize + (40 if heavy else 0)
        out += ["flash %s   # %s" % (p, note),
                "  light         = %d, %.1f, %d" % (light, 2.2 + 1.6 * fsize, 3 if not fast else 2),
                "  lightcolor    = 255, 200, 130",
                "  cone          = %d, %d, %d, %d" % (12 + int(10 * fsize), 40 + int(18 * fsize), int(cone_len), 8),
                "  conetics      = %d" % (4 if not fast else 3),
                "  bursts        = flash_core, flash_petals%s" % (", spk_heavy_streaks" if heavy else ", spk_streaks_fine"),
                "  flame         = %.2f" % (0.10 * fsize + 0.05),
                "  smoke         = 1, %.3f, %.2f" % (0.030 * smoke, 0.45 * smoke),
                "  smokeparticle = rsb_smoke_soot_gun",
                "  powderburn    = %d, %d, %.2f" % (int(30 * fsize) + 8, 7, 0.75),
                "  powdervary    = 0.45",
                # CLAMPED, and this bit me: the dirtiest guns have smoke 1.9 and 2.0, so 0.55 x smoke is
                # 1.04 and 1.10 -- over 1.0, and the parser refuses the whole profile. The two REFUSED
                # were the Kar98k and the Trench Gun, i.e. the two the set is built around, and a
                # refused flash is a silent gun rather than an error anyone would see in play.
                "  maybe         = powder_clump %.2f, flash_soot %.2f, spk_specks 0.3"
                % (min(0.95, 0.55 * smoke), min(0.9, 0.4 * smoke)),
                "  blastkick     = kick_puff, %d, 3" % (56 + int(24 * fsize)),
                "  exposure      = %.2f, %d" % (0.30 * fsize + 0.15, int(90 * fsize) + 40),
                "  hearing       = %.2f, %d" % (0.35 * fsize + 0.15, int(100 * fsize) + 50),
                "  smokevolume   = %d, %.1f, %.1f, %d, %d" % (int(14 * smoke) + 6, 1.1 * smoke, 0.8 * smoke, 150, 10),
                "  barrelheat    = %.2f, %.2f, %.2f" % (0.30 * smoke, 0.22, 0.30),
                "  barrelsmoke   = rsb_smoke_barrel_soot, %.1f" % (2.6 * smoke),
                "  tail          = %s, %.1f" % ("rsb/tail/br" if heavy else "rsb/tail/smg", 0.9 if heavy else 0.7),
                "end",
                ""]
        # RECOIL IS PER GUN because it is the gun, not the cartridge.
        climb, drift, recover, mx = rec
        out += ["recoil %s   # %s at %.1f a second" % (p, action, rate),
                "  climb   = %.2f" % climb,
                "  drift   = %.2f, %d" % (drift, 5),
                "  recover = %d, %d" % (recover, 6),
                "  max     = %d, %d" % (mx, max(2, mx // 2)),
                "  bloom   = %.2f" % (0.08 if not heavy else 0.14),
                "  brace   = 0.6, 0.85",
                "  view    = %.1f, %d, 1, %d" % (1.0 + 1.2 * (climb / 2.6), 4 + int(4 * (climb / 2.6)), 6),
                "end",
                ""]
        sc, snd, hot, what = BRASS[brass]
        out += ["ejecta %s   # %s" % (p, what),
                "  look    = model, RSB_Casing9mm",
                "  scale   = %.2f" % sc,
                "  speed   = %.1f, 0.25" % (1.0 + 0.3 * (1.0 if heavy else 0.0)),
                "  bounce  = 0.5, 0.35, 5",
                "  gravity = 0.6",
                "  sound   = %s" % snd,
                "  hot     = %d" % hot,
                "  life    = 2100",
                "  portsmoke = rsb_smoke_port, %d" % (3 if heavy else 2),
                "  wisp    = rsb_casing_wisp, %d" % (18 if heavy else 12),
                "end",
                ""]
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    text = io.open(DEFS, encoding="utf-8", newline="").read()
    nl = "\r\n" if "\r\n" in text else "\n"

    body = [BEGIN,
            "# THE WW2 SET. Sixteen guns, six cartridges, NOTHING REUSED FROM THE MODERN SET (owner).",
            "# DO NOT EDIT BY HAND: change tools/gen_ww2_profiles.py and run it again.",
            "#",
            "# The two poles the whole set is built between: the Kar98k, 40 damage at 3.9 a second, one shot",
            "# that matters -- and the MP40, 12 at 17.5, a hose. If they read as one family at two rates,",
            "# this failed.",
            ""]
    body += cartridge_blocks(nl)
    body += impact_blocks(nl)
    body += gun_blocks(nl)
    body += ["flame ww2_flame   # THE FLAMMENWERFER: a fat wet gout, not a modern jet -- slower, shorter, and it clings",
             "  reach       = 420",
             "  speed       = 700",
             "  spread      = 2.2",
             "  stream      = flame_core, flame_body, flame_tip, flame_embers",
             "  landing     = flame_splash, flame_sheet, flame_embers_rise, flame_smoke, flame_lick",
             "  cling       = 0.32",
             "  tube        = 6, 1.0, 3, 0.5",
             "  tubelook    = 1.8, 3.2, 0.5",
             "  tubecolors  = 255, 246, 220, 255, 205, 110, 255, 130, 36, 190, 55, 10, 100, 22, 5",
             "  tubelicks   = 0.7, 0.07, 2.2",
             "  heat        = 5, 20, 1.3, 0.09, 34",
             "  heatland    = 32, 1.5",
             "  landingtics = 2",
             "  scorch      = pool, 12, 120",
             "  scorchcolor = 255, 95, 20",
             "  scorchtics  = 9",
             "  light       = 260, 2.8, 0.38",
             "  lightcolor  = 255, 140, 50",
             "  landlight   = 180, 2.4",
             "  sounds      = rsb/flame/loop, rsb/flame/start, rsb/flame/stop",
             "  pilot       = pilot_flame",
             "  sputter     = 0.2, rsb/flame/hiss",
             "  flameout    = flame_out_puff",
             "  smokevolume = 20, 0.6, 1.8, 0.85",
             "  damage      = scorch, 14, 0, 0.06, 0",
             "end",
             "",
             END]
    block = nl.join(body)

    if BEGIN in text and END in text:
        a, b = text.index(BEGIN), text.index(END) + len(END)
        out = text[:a] + block + text[b:]
    else:
        out = text.rstrip("\r\n") + nl + nl + block + nl

    n = len([l for l in body if l.startswith(("ballistics ", "round ", "roundlook ", "impact ", "flash ", "recoil ", "ejecta ", "flame "))])
    print("%d WW2 profiles: %d cartridges, %d guns" % (n, len(CARTRIDGE), len(GUN)))
    if args.check:
        print()
        print(block[:3000])
        return
    io.open(DEFS, "w", encoding="utf-8", newline="").write(out)
    print("RSBDEFS.txt updated")


main()
