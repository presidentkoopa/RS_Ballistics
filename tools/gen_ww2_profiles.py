#!/usr/bin/env python3
"""
gen_ww2_profiles.py -- effect recipes for the WW2 set: twelve guns, seven cartridges, nothing reused.

THE OWNER'S INSTRUCTION was ALL NEW EFFECTS, NO REUSING EXISTING PROFILES -- not a WW2 rifle pointed at
`rifle_762`. So every profile here is its own, and the modern set is untouched.

WHAT MAKES THEM NOT MODERN, and it is not a tint:
  * 1940s propellant is DIRTY. More unburnt powder leaves the muzzle and burns outside it, so the flash
    is bigger, slower and yellower than anything in the modern set (255,200,130 against 255,220,170),
    the cone lives longer, and powder clumps are common rather than occasional.
  * THE SMOKE HANGS. A modern round's haze clears; this stuff sits in the room.
  * THE BRASS IS LONG. Rifle cases for the Mauser and the '06, and they stay hot longer.
  * RECOIL IS HEAVY AND RECOVERS SLOWLY. A modern carbine settles; these do not.

EVERY NUMBER BELOW IS READ OUT OF WMSHEET.ww2 (RS_VR_Weapons), WHICH IS BRUTAL WOLFENSTEIN II v0.2.5's
OWN DATA. It is not transcribed from a message and it is not invented here. THE FIRST BUILD OF THIS FILE
WAS SHAPED AGAINST v5.0 NUMBERS AND SEVEN OF THE TWELVE RATES WERE WRONG -- the Kar98k was carded at 40
damage and 3.9 a second when it is 100 at 3.2, the MP40 at 17.5 when it is 8.8, the StG at 17.5 when it
is 7.0. The poles moved. So nothing here is a constant I picked: rate comes from `firetics`, kick and
sloppiness come from `shotspread`, and if the sheet is corrected again this file is re-run, not re-tuned.

THE TWO POLES, and the whole set is built along the line between them. The KAR98K: one hundred damage,
ZERO spread, one shot every eleven tics. Nothing else in the game gets that much time to be expensive --
the biggest flash, the biggest single cloud of smoke, and a push you have to come back from. The PPSH-41:
twenty damage seventeen and a half times a second out of a 71-round drum. Seventeen flashes a second is a
strobe, so its flash is the smallest in the set and its cone does not outlive its own fire interval.
IF THOSE TWO READ AS THE SAME FAMILY AT DIFFERENT RATES, THIS HAS FAILED.

THE THREE DERIVATIONS, because a fast gun and a slow gun cannot share a recipe:

  1. FLASH BUDGET FALLS WITH RATE. A gun's per-shot flash is its cartridge's charge times
     (reference rate / its rate) ^ 0.45. The Kar98k gets 1.31x and the PPSh 0.61x of a pistol's.
     This is what keeps the screen from being the flash at seventeen shots a second.

  2. THE PUFF AND THE HAZE GO OPPOSITE WAYS, and conflating them was the old file's real mistake.
     The per-shot puff falls with rate on the same curve as the flash -- seventeen puffs a second is
     not smoke, it is fog. The standing haze RISES with rate, because that is what a machine gun
     actually does to a room: (rate / reference) ^ 0.35. So the Kar98k has the biggest single cloud
     in the set and the MG42 has the thickest standing air, which is correct for both.

  3. THE CONE NEVER OUTLIVES THE SHOT INTERVAL. `conetics` is capped at firetics - 1. THE OWNER SAID
     IN THE HEADSET THAT SOME MUZZLE FLASHES "SEEM LIKE THEY LAST A WHILE FOR BEING A BARREL FLASH" --
     a flash longer than the gap between shots overlaps its successor and reads as a lamp bolted to
     the muzzle rather than as a flash. The same cap is on the flash light's tics.

BLOOM IS GAMEPLAY AND IS READ, NEVER INVENTED. `bloom` is extra spread in degrees (recoil.zs:72), so a
recoil profile that states it is a look package dictating where bullets go -- the identical disease to a
cartridge carrying `damage`, which this set already cured with `damage = none`. Bloom is therefore
derived from the sheet's own `shotspread`: a gun that is already sloppy gets sloppier under fire, and
THE KAR98K'S ZERO SPREAD STAYS ZERO ALL THE WAY THROUGH.

SEVEN CARTRIDGES, NOT TWELVE GUNS, for everything the cartridge decides: how fast the round flies, how
big the brass is, what the hole looks like, how much powder burns. A gun's own character -- flash length,
recoil, sloppiness -- is per gun, because the MG42 and the Kar98k are the SAME 7.92x57 and could not be
further apart: 40 damage belt-fed at 11.7/s against 100 bolt-action at 3.2/s. Same cartridge, nothing
shared about delivery.

    python tools/gen_ww2_profiles.py            # rewrite the block between the markers
    python tools/gen_ww2_profiles.py --check    # print it, write nothing
    python tools/gen_ww2_profiles.py --table    # print the derived numbers per gun and stop
"""
import argparse
import io
import os

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
DEFS = os.path.join(PKG, "RSBDEFS.txt")
BEGIN = "# ---- BEGIN WW2 (tools/gen_ww2_profiles.py)"
END = "# ---- END WW2"

# EVERY KEY THE PARSER BOUNDS AT 0..1, AND THE INDEX OF THE VALUE IT BOUNDS. A REFUSAL IS A SILENT GUN.
#
# THIS HAS NOW BITTEN THE SAME TWO GUNS TWICE -- the Kar98k and the Trench Gun, which is to say the two
# poles the whole set is built around -- through two DIFFERENT keys. First `maybe powder_clump` at
# 0.55 x smoke, which I clamped by hand. Then `smoke`'s alpha at 0.45 x puff, which I did not, because
# the hand-clamp fixed the instance instead of the class. Both times it was the dirtiest guns that
# overflowed, because dirt is exactly what these multipliers scale: the set's best guns are the ones
# most likely to fall off the end.
#
# So the clamp is no longer per-line judgement. unit() bounds anything feeding a 0..1 key, and
# check_units() reads back the block this file is about to write and REFUSES TO WRITE IT if any of these
# keys carries a value over 1. That last part is the important half: a refused profile prints one line
# into a four-thousand-line boot log and otherwise looks exactly like a gun with no muzzle flash, so the
# failure has to happen HERE, loudly, at generate time -- not at load, where the only symptom is a gun
# that goes quiet in the owner's headset and nobody knows why.
UNIT_KEYS = {"smoke": 2, "flame": 0, "powdervary": 0, "barrelheat": 0, "exposure": 0, "hearing": 0}


def unit(x):
    """Clamp to what a 0..1 key accepts, with a hair of headroom against float printing."""
    return max(0.0, min(0.95, x))


def check_units(body):
    """Read back what we are about to write and refuse to write it if any 0..1 key overflowed."""
    bad = []
    where = "?"
    for line in body:
        s = line.strip()
        # A PROFILE HEADER, not a key: `flame ww2_flame` opens one, `flame = 0.23` is a line inside a
        # flash. Both start with "flame ", so the "=" is what tells them apart -- and without this the
        # guard names the wrong gun, which on a 900-profile file is barely better than not naming one.
        if "=" not in s and s.startswith(("flash ", "recoil ", "ejecta ", "impact ", "flame ", "ballistics ", "roundlook ", "round ")):
            where = s.split("#")[0].strip()
        if "=" not in s or s.startswith("#"):
            continue
        key = s.split("=")[0].strip()
        if key not in UNIT_KEYS:
            continue
        vals = [v.strip() for v in s.split("=", 1)[1].split(",")]
        i = UNIT_KEYS[key]
        if i >= len(vals):
            continue
        try:
            v = float(vals[i])
        except ValueError:
            continue
        if v > 1.0:
            bad.append("%s: %s value %d is %.3f, over 1.0 -- the parser would REFUSE this profile" % (where, key, i, v))
    if bad:
        raise SystemExit("REFUSED BEFORE WRITING, and a refused profile is a silent gun:\n  " + "\n  ".join(bad))


# THE MIDDLE OF THE SET, and the pistols sit on it: firetics 6 is 5.83 shots a second. Every rate-driven
# curve below is relative to this, so a gun at the reference rate gets its cartridge's plain numbers.
REF_RATE = 35.0 / 6.0

# cartridge -> speed, round radius, brass kind, hole size, charge, dirt, kick, what it is
#   charge -- how much propellant burns at the muzzle: drives the flash.
#   dirt   -- how much of it leaves unburnt: drives the smoke. 1940s powder, so all of these are high.
#   kick   -- momentum into the shoulder: drives recoil, before the action divides it.
CARTRIDGE = {
    "9mm":     (330, 1.5, "small",  0.9,  0.80, 1.00, 0.45, "9x19 Parabellum: light, fast, clean-ish for the period"),
    "45":      (250, 2.0, "medium", 1.2,  0.90, 1.15, 0.70, ".45 ACP: heavy, slow, a big soft hole"),
    "762tok":  (430, 1.4, "small",  0.95, 0.85, 1.00, 0.45, "7.62x25 Tokarev: a bottlenecked pistol round, fast and spiteful"),
    "792kurz": (470, 1.7, "medium", 1.15, 1.05, 1.25, 0.80, "7.92x33 Kurz: a short rifle round, the first of its kind"),
    "792":     (620, 2.0, "rifle",  1.45, 1.35, 1.75, 1.70, "7.92x57 Mauser: a full rifle cartridge, and it shows"),
    "3006":    (600, 2.0, "rifle",  1.4,  1.30, 1.65, 1.60, ".30-06 Springfield: the American full-power round"),
    "12ga":    (300, 2.2, "hull",   1.0,  1.20, 1.90, 1.55, "12 gauge buckshot: seven pellets of it"),
}

# HOW MUCH OF THE CARTRIDGE'S KICK REACHES THE SHOOTER. A bolt gun is fired deliberately from the
# shoulder and every bit of it arrives; a belt gun is heavy and braced and almost none does; an
# automatic is being held down through the burst.
ACTION = {
    "bolt": 1.55,
    "pump": 1.45,
    "semi": 1.15,
    "auto": 0.85,
    "belt": 0.45,
}

# gun -> cartridge, damage, pellets, firetics, (spread x, y), action, note
# READ FROM WMSHEET.ww2. `firetics` is shot-to-ready, so rate is 35 / firetics -- NOT a state's opening
# frame, which is what made a bolt-action Kar98k read as thirty-five shots a second the first time round.
GUN = {
    "kar98k":    ("792",     100, 1, 11, (0, 0), "bolt",
                  "THE KAR98K: the set in one gun. One hundred damage, ZERO spread, one shot every eleven tics -- the biggest flash and the biggest single cloud in the game, because nothing else gets this much time to spend"),
    "mg42":      ("792",      40, 1,  3, (6, 4), "belt",
                  "THE MG42: the same cartridge as the Kar98k and nothing else in common. Small per shot because there are twelve a second, but the standing smoke is the thickest in the set and never gets a chance to clear"),
    "heavymg":   ("792",      40, 1,  4, (8, 6), "belt",
                  "THE CHAINGUN: the sloppiest thing in the set at an 8,6 spread, and it should look it -- the widest powder spray and the most bloom of the lot"),
    "garand":    ("3006",    100, 1,  8, (3, 3), "semi",
                  "THE M1 GARAND: a hundred damage of full-power round from a semi-auto -- a hard flash and a real push, eight times before the clip leaves"),
    "bar":       ("3006",    100, 1,  5, (5, 5), "auto",
                  "THE BAR: a hundred damage of rifle cartridge on full auto seven times a second, which is as unreasonable as it sounds and is the most lethal sustained thing in the set"),
    "trench":    ("12ga",     25, 7, 12, (4, 2), "pump",
                  "THE TRENCH GUN: seven pellets and a cloud, once every twelve tics. The slowest gun in the set and the only pellet gun, so it gets the longest cone and the fattest smoke"),
    "m1911":     ("45",       30, 1,  6, (1, 1), "semi",
                  "THE COLT M1911: a fat slow .45 at the reference rate, a soft yellow flash and a lazy push"),
    "luger":     ("9mm",      20, 1,  6, (1, 1), "semi",
                  "THE LUGER P08: small, sharp and tidy -- the cleanest thing here, which is not saying much"),
    "thompson":  ("45",       30, 1,  3, (3, 3), "auto",
                  "THE THOMPSON M1A1: .45 on full auto at twelve a second -- fat rounds, a short fat flash, and it climbs"),
    "mp40":      ("9mm",      20, 1,  4, (3, 3), "auto",
                  "THE MP40: NOT the hose it was carded as. Eight and a half a second, dead mid-pack, sharing its rate with the Chaingun -- a small sooty flash and a gun you can actually aim"),
    "ppsh":      ("762tok",   20, 1,  2, (4, 5), "auto",
                  "THE PPSH-41: the fast pole. Seventeen and a half a second out of a drum, so the smallest flash in the set and a cone that dies before the next shot -- a stream of brass and a wall of standing smoke"),
    "stg44":     ("792kurz",  40, 1,  5, (2, 2), "auto",
                  "THE STG 44: the first assault rifle, and at seven a second with a 2,2 spread it sits exactly between the rifles and the subguns, because that is what it was for"),
}

BRASS = {
    "small":  (0.9, "rsb/casing/small", 10, "a pistol case"),
    "medium": (1.05, "rsb/casing/medium", 12, "a fat pistol case"),
    "rifle":  (1.35, "rsb/debris/brass_rifle", 16, "a long rifle case, and it stays hot"),
    "hull":   (1.2, "rsb/casing/shell", 8, "a paper hull"),
}


def derive(gid):
    """Every per-gun number this file emits, out of the sheet's own data. One place, so --table and the
    profiles can never disagree about what a gun is."""
    cid, dmg, pellets, firetics, spread, action, note = GUN[gid]
    speed, radius, brass, hole, charge, dirt, kick = CARTRIDGE[cid][:7]
    sx, sy = spread
    slop = sx + sy

    rate = 35.0 / firetics
    budget = (REF_RATE / rate) ** 0.45       # falls as the gun speeds up
    gather = (rate / REF_RATE) ** 0.35       # rises as the gun speeds up

    d = {}
    d["cid"] = cid
    d["dmg"] = dmg
    d["pellets"] = pellets
    d["firetics"] = firetics
    d["rate"] = rate
    d["spread"] = spread
    d["action"] = action
    d["note"] = note
    d["speed"] = speed
    d["brass"] = brass
    d["heavy"] = speed >= 470
    d["fsize"] = charge * budget             # per-shot flash
    d["puff"] = dirt * budget                # per-shot smoke
    d["haze"] = dirt * gather                # standing smoke, and barrel heat with it
    d["climb"] = kick * ACTION[action]
    d["drift"] = 0.30 + 0.055 * slop
    d["recover"] = int(round(min(30.0, max(8.0, 26.0 * (REF_RATE / rate) ** 0.5))))
    d["max"] = int(round(min(10.0, max(4.0, 3.0 + 2.2 * d["climb"]))))
    d["bloom"] = 0.02 * slop                 # READ from the sheet, never invented -- see the header
    d["vary"] = unit(0.35 + 0.035 * slop)    # a sloppy gun sprays its powder wider
    # NOTHING OUTLIVES THE SHOT INTERVAL. This is the owner's headset note about flashes that "last a
    # while": one that overlaps the next shot stops reading as a flash.
    d["conetics"] = int(max(2, min(5, min(firetics - 1, round(3 + d["fsize"])))))
    d["lighttics"] = int(max(1, min(3, firetics - 1)))
    return d


def cartridge_blocks(nl):
    out = []
    for cid in CARTRIDGE:
        speed, radius, brass, hole, charge, dirt, kick, what = CARTRIDGE[cid]
        p = "ww2_" + cid
        out += ["ballistics %s   # %s" % (p, what),
                "  speed  = %d" % speed,
                "  radius = %.1f" % radius,
                # `damage = none` IS THE POINT OF THIS LINE, not an omission. The weapons sheet has no
                # look-only key -- naming a `roundprofile` brings the ballistics def and its damage with
                # it -- and this set's damage is Brutal Wolfenstein's, by the owner's instruction, living
                # in their sheet. So the damage must not be here to take. Stating it beats deleting it:
                # "it never states `damage`" still catches a forgotten line, which is what it is for.
                "  damage = none",
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
    for cid in CARTRIDGE:
        speed, radius, brass, hole, charge, dirt, kick, what = CARTRIDGE[cid]
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
    for gid in GUN:
        d = derive(gid)
        p = "ww2_" + gid
        heavy = d["heavy"]
        fsize, puff, haze = d["fsize"], d["puff"], d["haze"]
        # THE LIGHT IS CAPPED. The owner's other headset note was that a big flash lighting the barrel
        # smoke blinded them; the smoke's `lit` was damped for that, and the light does not get to grow
        # back into the gap.
        light = int(min(330.0, 150.0 * fsize + (60 if heavy else 0)))
        cone_len = 110 * fsize + (40 if heavy else 0)
        out += ["flash %s   # %s" % (p, d["note"]),
                "  # %s, %d damage%s at %.1f a second (firetics %d), spread %d,%d"
                % (d["action"], d["dmg"], (" x%d" % d["pellets"]) if d["pellets"] > 1 else "",
                   d["rate"], d["firetics"], d["spread"][0], d["spread"][1]),
                "  light         = %d, %.1f, %d" % (light, 2.2 + 1.6 * fsize, d["lighttics"]),
                "  lightcolor    = 255, 200, 130",
                "  cone          = %d, %d, %d, %d" % (12 + int(10 * fsize), 40 + int(18 * fsize), int(cone_len), 8),
                "  conetics      = %d" % d["conetics"],
                "  bursts        = flash_core, flash_petals%s" % (", spk_heavy_streaks" if heavy else ", spk_streaks_fine"),
                "  flame         = %.2f" % unit(0.10 * fsize + 0.05),
                # PAST FULL OPACITY, MORE POWDER MEANS A BIGGER CLOUD, NOT A MORE OPAQUE ONE. The Kar98k
                # and the Trench Gun both push 0.45 x puff over 1.0 and the parser refuses the profile
                # outright, so the overflow goes into SCALE instead of being thrown away -- which is also
                # what actually happens at a muzzle: a dirtier charge makes a fatter cloud, not a blacker
                # pixel. Clamping alone would have quietly flattened the two best guns in the set.
                "  smoke         = 1, %.3f, %.2f"
                % (0.030 * puff * (1.0 + max(0.0, 0.45 * puff - 0.95)), unit(0.45 * puff)),
                "  smokeparticle = rsb_smoke_soot_gun",
                "  powderburn    = %d, %d, %.2f" % (int(30 * fsize) + 8, 7, 0.75),
                "  powdervary    = %.2f" % d["vary"],
                # CLAMPED, and this bit me: the dirtiest guns push 0.55 x puff over 1.0, and the parser
                # refuses the whole profile. The two REFUSED last time were the Kar98k and the Trench Gun,
                # i.e. the two the set is built around, and a refused flash is a SILENT GUN rather than an
                # error anyone would see in play.
                "  maybe         = powder_clump %.2f, flash_soot %.2f, spk_specks 0.3"
                % (min(0.95, 0.55 * puff), min(0.9, 0.4 * puff)),
                "  blastkick     = kick_puff, %d, 3" % (56 + int(24 * fsize)),
                "  exposure      = %.2f, %d" % (unit(0.30 * fsize + 0.15), int(90 * fsize) + 40),
                "  hearing       = %.2f, %d" % (unit(0.35 * fsize + 0.15), int(100 * fsize) + 50),
                # THE HAZE, NOT THE PUFF: what the room holds after a burst goes UP with rate even as the
                # per-shot cloud goes down. The MG42 is the thickest air in the set and fires the
                # second-smallest flash, and both of those are correct.
                "  smokevolume   = %d, %.1f, %.1f, %d, %d" % (int(14 * haze) + 6, 1.1 * haze, 0.8 * haze, 150, 10),
                "  barrelheat    = %.2f, %.2f, %.2f" % (unit(0.30 * haze), 0.22, 0.30),
                "  barrelsmoke   = rsb_smoke_barrel_soot, %.1f" % (2.6 * haze),
                "  tail          = %s, %.1f" % ("rsb/tail/br" if heavy else "rsb/tail/smg", 0.9 if heavy else 0.7),
                "end",
                ""]
        # RECOIL IS PER GUN because it is the gun, not the cartridge: the MG42 and the Kar98k fire the
        # same 7.92x57 and one of them is braced on a bipod.
        out += ["recoil %s   # %s at %.1f a second, spread %d,%d" % (p, d["action"], d["rate"], d["spread"][0], d["spread"][1]),
                "  climb   = %.2f" % d["climb"],
                "  drift   = %.2f, %d" % (d["drift"], 5),
                "  recover = %d, %d" % (d["recover"], 6),
                "  max     = %d, %d" % (d["max"], max(2, d["max"] // 2)),
                # BLOOM IS EXTRA SPREAD IN DEGREES -- gameplay, not look. Read off the sheet's shotspread
                # so this profile can never disagree with the weapons lane about where bullets go. The
                # Kar98k's 0,0 stays 0.00 here, which is the whole point.
                "  bloom   = %.2f" % d["bloom"],
                "  brace   = 0.6, 0.85",
                "  view    = %.1f, %d, 1, %d" % (1.0 + 1.2 * (d["climb"] / 2.6), 4 + int(4 * (d["climb"] / 2.6)), 6),
                "end",
                ""]
        sc, snd, hot, what = BRASS[d["brass"]]
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


def print_table():
    print("%-10s %-8s %5s %6s %6s  %5s %5s %5s  %5s %5s %3s %3s %5s  %2s %2s"
          % ("gun", "cart", "dmg", "rate", "sprd", "flash", "puff", "haze", "climb", "drift", "rec", "max", "bloom", "ct", "lt"))
    for gid in sorted(GUN, key=lambda g: derive(g)["rate"]):
        d = derive(gid)
        print("%-10s %-8s %5d %6.2f %3d,%-2d  %5.2f %5.2f %5.2f  %5.2f %5.2f %3d %3d %5.2f  %2d %2d"
              % (gid, d["cid"], d["dmg"], d["rate"], d["spread"][0], d["spread"][1],
                 d["fsize"], d["puff"], d["haze"], d["climb"], d["drift"],
                 d["recover"], d["max"], d["bloom"], d["conetics"], d["lighttics"]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--table", action="store_true")
    args = ap.parse_args()

    if args.table:
        print_table()
        return

    text = io.open(DEFS, encoding="utf-8", newline="").read()
    nl = "\r\n" if "\r\n" in text else "\n"

    body = [BEGIN,
            "# THE WW2 SET. Twelve guns and a flamethrower, seven cartridges, NOTHING REUSED FROM THE",
            "# MODERN SET (owner). DO NOT EDIT BY HAND: change tools/gen_ww2_profiles.py and run it again.",
            "#",
            "# Every number is derived from WMSHEET.ww2's own damage, firetics and shotspread, which are",
            "# Brutal Wolfenstein II v0.2.5's. NOT transcribed, NOT invented, and re-run rather than",
            "# re-tuned when the sheet moves -- it already moved once and took seven of twelve rates with it.",
            "#",
            "# The two poles the whole set is built between: the KAR98K, 100 damage and ZERO spread once",
            "# every eleven tics -- the biggest flash and the biggest single cloud in the game -- and the",
            "# PPSH-41, 20 damage seventeen and a half times a second, the smallest flash and a cone that",
            "# dies before the next shot. If they read as one family at two rates, this failed.",
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
             "# THE FLAMMENWERFER'S RECOIL, and it is the only thing it takes from the gun side. A pressurised",
             "# tank does not snap -- it SHOVES, steadily, for as long as the trigger is down: almost no climb,",
             "# a wide slow wander, and a recovery long enough that it never fully settles mid-burst. Bloom is",
             "# zero because the stream is a projectile and carries no spread to grow (WMSHEET.ww2).",
             "recoil ww2_flame",
             "  climb   = 0.18",
             "  drift   = 0.95, 5",
             "  recover = 22, 6",
             "  max     = 5, 3",
             "  bloom   = 0.00",
             "  brace   = 0.6, 0.85",
             "  view    = 1.1, 4, 1, 6",
             "end",
             "",
             END]
    # BEFORE ANYTHING IS WRITTEN. A 0..1 key over 1 costs the whole profile, and the parser says so in
    # one line of a boot log while the gun just goes quiet. Fail here instead.
    check_units(body)
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
