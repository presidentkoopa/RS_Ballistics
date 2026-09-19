#!/usr/bin/env python3
"""
gen_ww2_profiles.py -- effect recipes for the WW2 set: twenty-six guns, ten cartridges, nothing reused.

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

TEN CARTRIDGES, NOT TWENTY-SIX GUNS, for everything the cartridge decides: how fast the round flies, how
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
import sys

# THE ONE CANONICAL CARTRIDGE TABLE. Imported, never copied -- and importable at all only because
# every generator now guards main(), which this file learned the hard way too.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cartridges import LOAD as CART_LOAD

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
# key -> list of (value index, low, high), READ OFF THE PARSER'S OWN REFUSAL MESSAGES rather than
# guessed. Not every bound is 0..1, which is exactly how the second round of this bug got through: the
# guard knew about 0..1 keys, so `licks` (0-2), `tail` volume (0..1) and `barrelsmoke` puffs (0-8) all
# sailed past it and refused four more profiles at load.
UNIT_KEYS = {
    "smoke":       [(2, 0.0, 1.0)],
    "powdervary":  [(0, 0.0, 1.0)],
    "barrelheat":  [(0, 0.0, 1.0)],
    "exposure":    [(0, 0.0, 1.0)],
    "hearing":     [(0, 0.0, 2.0)],
    "tail":        [(1, 0.0, 1.0)],
    "barrelsmoke": [(1, 0.0, 8.0)],
    "licks":       [(0, 0.0, 2.0), (1, 0.0, 2.0), (2, 0.0, 1.0)],
    "beamlight":   [(3, 0.0, 1.0)],
    "cling":       [(0, 0.0, 1.0)],
}


def unit(x):
    """Clamp to what a 0..1 key accepts, with a hair of headroom against float printing."""
    return max(0.0, min(0.95, x))


def within(x, lo, hi):
    """Clamp to any bounded key, with a hair of headroom at the top."""
    return max(lo, min(hi - (hi - lo) * 0.02, x))


def check_units(body):
    """Read back what we are about to write and refuse to write it if any BOUNDED key fell outside its
    range. Not only 0..1 -- see UNIT_KEYS."""
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
        for i, lo, hi in UNIT_KEYS[key]:
            if i >= len(vals):
                continue
            try:
                v = float(vals[i])
            except ValueError:
                continue
            if v < lo or v > hi:
                bad.append("%s: %s value %d is %.3f, outside %g..%g -- the parser would REFUSE this profile"
                           % (where, key, i, v, lo, hi))
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
    # THE SECOND WAVE'S CARTRIDGES. The .22 is the interesting one: a tiny charge is HALF OF WHY A
    # SUPPRESSED GUN IS QUIET, the can being the other half, so it gets a charge a quarter of the 9mm's
    # rather than a 9mm recipe turned down.
    "22lr":    (290, 0.9, "tiny",   0.5,  0.22, 0.35, 0.08, ".22 LR: the OSS's answer, and a charge small enough to be half the reason it is quiet"),
    "357":     (380, 2.1, "medium", 1.35, 1.05, 1.30, 1.15, ".357 class: a big slow hole and far more flash than a handgun has any right to"),
    "93x74r":  (640, 2.1, "rifle",  1.50, 1.40, 1.70, 1.80, "9.3x74R: the drilling's rifle barrel, a boar round, the biggest hole in the set"),
    # THE MOSIN'S OWN. It was borrowing the Kar98k's 7.92x57 -- same job, same class, openly stated in
    # a comment -- because nothing here described a rimmed Russian round. It does now: slightly slower
    # and fatter than the Mauser, and a rimmed case that tumbles differently out of the port.
    "762x54r": (600, 2.0, "rifle",  1.50, 1.30, 1.75, 1.65, "7.62x54R: rimmed, Russian, and still in service longer than anything else here"),
}

# A GUN WHOSE SUPPRESSOR MAKES IT DIFFERENT IN KIND RATHER THAN QUIETER (owner's framing, and the
# weapons lane confirmed the HDM is genuinely suppressed in the source rather than only named that way:
# RealRTCW's soundRange is 1 for the HDM against 64 for a silenced Luger and 2000 for a Mosin).
#
# It gets NO CONE, NO FLAME, NO POWDER BURN, NO EXPOSURE AND NO HEARING DAMAGE -- not smaller versions of
# them. What is left is gas leaving the ports, a faint glow at the can and a tail that is the action
# working rather than the shot. This follows glock17_sup / mk18_sup, which is our own established shape
# for this; it is not a new one invented for the HDM.
SUPPRESSED = {"hdm"}

# HOW WELL THE GUN IS MADE. LOOK ONLY -- it scales smoke and powder spray and NOTHING ELSE, never a
# number deciding where a bullet goes or what it does. Default 1.0, so a gun not listed is untouched.
#
# THIS EXISTS BECAUSE THE SHEET CANNOT SEPARATE THEM. The MP40, the Sten and the MP34 are the same
# cartridge at the same rate with the same spread, so every derivation below gives all three identical
# numbers and the player would meet three guns that look like one. But they are NOT the same gun: the
# Sten is a stamped pipe that leaks gas out of every seam and the MP34 is a Steyr machined like a watch.
# That difference is real, it is visible, and it is MINE to decide -- it is a look, which is this
# package's job, and it touches nothing the weapons lane owns.
FINISH = {
    "sten":      1.25,   # stamped, loose, gassy -- the crudest gun of the war and it should read that way
    "mp34":      0.82,   # the Sten's exact opposite carrying the Sten's exact numbers, which is the joke
    "m30":       0.85,   # a sporting drilling, built for a customer rather than for a quartermaster
    "goldluger": 0.80,   # gold-plated, and presumably never fired in anger
}

# HOW MUCH OF THE CARTRIDGE'S KICK REACHES THE SHOOTER. A bolt gun is fired deliberately from the
# shoulder and every bit of it arrives; a belt gun is heavy and braced and almost none does; an
# automatic is being held down through the burst.
ACTION = {
    "bolt": 1.55,
    "break": 1.50,
    "revolver": 1.20,
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
    # .30-06, NOT 7.92, ON THE WEAPONS LANE'S CALL AND I AGREE: it is a Browning M1919, which is a .30-06
    # gun, even though Brutal Wolfenstein feeds it out of the MG42's 7.92 pool. The real cartridge beats
    # the donor's plumbing, and this has to match the `roundprofile` they wired or the brass and the hole
    # would disagree with the round.
    "heavymg":   ("3006",     40, 1,  4, (8, 6), "belt",
                  "THE CHAINGUN: a Browning M1919 and the sloppiest thing in the set at an 8,6 spread, and it should look it -- the widest powder spray and the most bloom of the lot"),
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

    # ---- THE SECOND WAVE. Rows from the weapons lane, same three columns, same derivations. Five of
    # these have no Brutal Wolfenstein class at all (HDM, Sten, MP34, TT33, Venom) and their numbers are
    # RealRTCW's -- which is why the rows come from the lane that reads those files and not from me.
    "p38":       ("9mm",      20, 1,  6, (1, 1), "semi",
                  "THE WALTHER P38: the Luger's replacement and a plainer gun in every way -- the same 9mm at the same rate, and it should look ordinary next to it"),
    "sten":      ("9mm",      20, 1,  4, (3, 3), "auto",
                  "THE STEN: a pipe with a trigger. Same cartridge and rate as the MP40, and the crudeness has to come from the powder spray rather than from the numbers, which are identical"),
    "mp34":      ("9mm",      20, 1,  4, (3, 3), "auto",
                  "THE MP34: the Sten's opposite -- a beautifully made gun with exactly the Sten's numbers, which is the joke and worth showing in how clean its flash is"),
    "goldluger": ("9mm",     100, 1, 16, (2, 2), "semi",
                  "THE GOLDEN LUGER: a hundred damage out of a 9mm at two shots a second. The SLOWEST thing in the set, slower even than the Trench Gun, so it can afford the biggest flash any pistol gets"),
    "tt33":      ("762tok",   30, 1,  7, (1, 1), "semi",
                  "THE TT-33 TOKAREV: the PPSh's cartridge fired deliberately instead of hosed -- fast, spiteful, and a sharp little flash"),
    "mosin":     ("762x54r", 100, 1, 12, (0, 0), "bolt",
                  "THE MOSIN-NAGANT: the Kar98k's opposite number and not its twin -- a longer, rougher, slower rifle firing a rimmed round, one shot every twelve tics with no spread at all"),
    "hdm":       ("22lr",     25, 1,  6, (1, 1), "semi",
                  "THE HIGH STANDARD HDM: the OSS's suppressed .22, and the quietest thing anyone built. NO FLASH, NO CONE, NO REPORT -- gas out of the ports, a glow at the can, and the action working"),
    "revolver":  ("357",      60, 1,  9, (2, 3), "revolver",
                  "THE REVOLVER: a big slow cartridge and a cylinder gap, so far more flash than a handgun should have -- and no brass, because a revolver holds onto it"),
    "g43":       ("792",      80, 1, 10, (3, 3), "semi",
                  "THE G43: Germany's answer to the Garand. Full-power 7.92 from a semi-auto at three and a half a second -- nearly the Kar98k's flash without the wait"),
    "fg42":      ("792",      40, 1,  3, (2, 2), "auto",
                  "THE FG42: full-power rifle rounds on full auto at twelve a second out of a paratrooper's rifle, which is the least reasonable thing in the whole set"),
    "marksman":  ("792",     100, 1,  5, (10, 8), "semi",
                  "THE MARKSMAN: a hundred damage and a TEN DEGREE spread, which makes it the sloppiest gun in the game by a distance. Whatever it is, it is not a marksman rifle, and the powder should spray everywhere"),
    "venom":     ("792",      60, 1,  2, (6, 4), "belt",
                  "THE VENOM: full-power 7.92 seventeen and a half times a second. It ties the PPSh for rate while firing four times the cartridge, so it has the thickest standing smoke of anything here"),
    "aa12":      ("12ga",     16, 10, 6, (4, 2), "auto",
                  "THE AA-12: ten pellets six times a second. The only automatic shotgun, and the per-shot cloud has to come down hard or it is a fog machine"),
    "auto5":     ("12ga",     16, 10, 11, (5, 3), "semi",
                  "THE AUTO-5: Browning's humpback, ten pellets three times a second -- half the AA-12's rate and twice its cloud"),
    "m30":       ("12ga",     13, 9,  7, (10, 1), "break",
                  "THE M30 DRILLING: two shotgun barrels and a rifle one. A 10,1 spread is a flat horizontal fan, which is a strange and specific thing, and the break action means no brass leaves it while firing"),
}

BRASS = {
    "small":  (0.9, "rsb/casing/small", 10, "a pistol case"),
    "medium": (1.05, "rsb/casing/medium", 12, "a fat pistol case"),
    "rifle":  (1.35, "rsb/debris/brass_rifle", 16, "a long rifle case, and it stays hot"),
    "hull":   (1.2, "rsb/casing/shell", 8, "a paper hull"),
    "tiny":   (0.6, "rsb/casing/small", 6, "a .22 case, barely there"),
}

# ACTIONS THAT THROW NOTHING WHILE THEY FIRE. A revolver holds its brass in the cylinder until you dump
# all six; a break-action drilling holds its until you open it. Both would look wrong spraying cases
# every shot, so they get NO ejecta profile at all -- the weapons lane leaves `ejectaprofile` off those
# cards, and the generated block says so where the profile would have been.
#
# WHAT KIND of case a gun throws is the CARTRIDGE'S (a .45 case is a .45 case in any gun). WHETHER it
# throws one at all is the ACTION'S. Putting "none" in the cartridge table conflated those and would
# have got it wrong the moment a second gun fired .357 from a self-loader.
NO_EJECT = {"break", "revolver"}


# ============================================================================ REAL RECOIL
# WHAT THE GUN ACTUALLY DOES TO YOUR SHOULDER, from published figures rather than from numbers I liked.
# The owner: "PER-GUN, USE REAL-WORLD EQUIVALENTS."
#
# Four sourced numbers per gun -- bullet weight in grains, muzzle velocity in fps, powder charge in
# grains, and the gun's loaded weight in pounds -- and the physics does the rest. These are checkable
# against any reloading manual or armoury table, which is the whole point: the standard says damage and
# rate of fire must be sourced and never invented, and there is no reason recoil should be the exception.
#
# THE FORMULA is free recoil, the standard one:
#     Vg = (bullet_grains * muzzle_fps + 4700 * charge_grains) / (7000 * gun_lb)     [fps]
#     E  = gun_lb * Vg^2 / 64.348                                                    [ft-lb]
# 4700 fps is the conventional effective velocity of the propellant gas leaving the muzzle.
#
# WHAT IT FOUND, and it is why the old hand-picked numbers felt flat. Per shot the set spans
# THIRTY-TWO TIMES, from the Trench Gun at 22.5 ft-lb to the PPSh at 0.7. My invented values spanned
# about four. The real world is far more dramatic than I guessed and the set was the poorer for it.
#
# AND PER SECOND THE HEAVY GUNS CONVERGE -- Kar98k 58, Garand 57, BAR 60, MG42 74 ft-lb a second. They
# deliver nearly the same energy and package it completely differently: one hammer blow against a
# continuous shove. The subguns sit an entire tier below at 9 to 23. That axis is free from real data
# and no amount of tuning by feel would have found it.
#
# ALSO TRUE AND WORTH KEEPING: the M1911 kicks harder PER SHOT than the StG 44. A .45 pistol against an
# assault rifle. It is the kind of fact that makes a set feel observed rather than balanced.
#
# WHAT DRIVES CLIMB IS Vg, THE GUN'S REARWARD VELOCITY, not the energy. Energy is what the shoulder
# absorbs; velocity is how fast the thing actually moves, which is what a muzzle rising is. Using energy
# directly would make the Trench Gun absurd.
#
# ESTIMATES ARE MARKED. Where a figure is a fantasy gun or a weapon whose real loading is not settled,
# the comment says so rather than presenting a guess as a reading.
#
# gun -> bullet grains, muzzle fps, charge grains, loaded lb
RECOIL_DATA = {
    "kar98k":    (198, 2493, 47,   8.9),
    "g43":       (198, 2493, 47,   9.7),
    "fg42":      (198, 2493, 47,   9.9),
    "marksman":  (198, 2493, 47,   9.0),
    "mosin":     (148, 2838, 48,   8.8),   # 7.62x54R light ball out of a 91/30
    "mg42":      (198, 2493, 47,  25.5),
    "venom":     (198, 2493, 47,  25.0),   # ESTIMATE: fantasy rotary, weight assumed MG42 class
    "garand":    (150, 2800, 50,  10.5),
    "bar":       (150, 2800, 50,  16.0),
    "heavymg":   (150, 2800, 50,  31.0),   # Browning M1919, .30-06, on its tripod
    "stg44":     (125, 2250, 25,  10.2),
    "trench":    (437, 1325, 32,   7.5),   # 12ga 00 buck, nine pellets, total shot weight
    "aa12":      (437, 1325, 32,  12.0),
    "auto5":     (437, 1325, 32,   9.0),
    "m30":       (437, 1325, 32,   7.0),
    "thompson":  (230,  920,  5.0, 10.8),
    "m1911":     (230,  830,  5.0,  2.44),
    "mp40":      (115, 1250,  6.0,  8.75),
    "sten":      (115, 1200,  6.0,  7.1),
    "mp34":      (115, 1250,  6.0,  9.4),
    "luger":     (115, 1150,  5.0,  1.92),
    "p38":       (115, 1150,  5.0,  1.8),
    "goldluger": (115, 1150,  5.0,  1.92),
    "ppsh":      ( 86, 1600,  5.5, 12.0),
    "tt33":      ( 86, 1390,  5.5,  1.9),
    "hdm":       ( 40, 1050,  1.5,  2.75),  # .22 LR through an integral suppressor
    "revolver":  (158, 1250, 14.0,  2.6),
}

# TURNING THE GUN'S REARWARD VELOCITY INTO DEGREES OF MUZZLE RISE. Calibrated so the Kar98k lands where
# it already was, which keeps every other gun a RELATIVE change with a real reason rather than a reshuffle.
CLIMB_PER_FPS = 0.148


def free_recoil(gid):
    """Gun recoil velocity (fps) and free recoil energy (ft-lb), or None where there is no data."""
    if gid not in RECOIL_DATA:
        return None, None
    wb, vb, wc, wg = RECOIL_DATA[gid]
    vg = (wb * vb + 4700.0 * wc) / (7000.0 * wg)
    return vg, wg * vg * vg / 64.348


def print_recoil():
    print("%-10s %6s %7s %8s %9s  %6s" % ("gun", "Vg", "ft-lb", "ft-lb/s", "vs MP40", "climb"))
    base = free_recoil("mp40")[1]
    rows = []
    for gid in GUN:
        vg, e = free_recoil(gid)
        if vg is None:
            continue
        d = derive(gid)
        rows.append((gid, vg, e, e * d["rate"], e / base, d["climb"]))
    for r in sorted(rows, key=lambda x: -x[2]):
        print("%-10s %6.2f %7.1f %8.1f %8.1fx  %6.2f" % r)


def derive(gid):
    """Every per-gun number this file emits, out of the sheet's own data. One place, so --table and the
    profiles can never disagree about what a gun is."""
    cid, dmg, pellets, firetics, spread, action, note = GUN[gid]
    speed, radius, brass, hole, charge, dirt, kick = CARTRIDGE[cid][:7]
    # WHICH CARTRIDGE, carried through so the recoil profile can REFER to it. Not a copy of anything:
    # the only figure read through the reference is roundmass, so a gun gets lighter as it empties.
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
    fin = FINISH.get(gid, 1.0)               # build quality: look only, see FINISH
    d["finish"] = fin
    d["puff"] = dirt * budget * fin          # per-shot smoke
    d["haze"] = dirt * gather                # standing smoke, and barrel heat with it
    # CLIMB FROM THE REAL GUN. Vg is what the thing actually does; ACTION is how much of it reaches
    # your aim rather than the floor or a bipod. A gun with no published figures falls back to the old
    # per-cartridge estimate, and says so in --recoil by being absent from it.
    vg, energy = free_recoil(gid)
    d["vg"] = vg if vg else 0.0
    d["energy"] = energy if energy else 0.0
    # IMPULSE, lb-s: the momentum out of the muzzle, which is what pushes an arm. Gun weight cancels
    # (vg already divided by it), so this is a fact about the CARTRIDGE -- the MG42 and the Kar98k
    # share it exactly and are three times apart in energy. Zero where there is no cartridge.
    d["impulse"] = (RECOIL_DATA[gid][3] * vg / 32.174) if vg and gid in RECOIL_DATA else 0.0
    d["climb"] = (vg * CLIMB_PER_FPS * ACTION[action]) if vg else (kick * ACTION[action])
    d["drift"] = 0.30 + 0.055 * slop
    d["recover"] = int(round(min(30.0, max(8.0, 26.0 * (REF_RATE / rate) ** 0.5))))
    d["max"] = int(round(min(10.0, max(4.0, 3.0 + 2.2 * d["climb"]))))
    d["bloom"] = 0.02 * slop                 # READ from the sheet, never invented -- see the header
    d["vary"] = unit((0.35 + 0.035 * slop) * fin)   # a sloppy OR badly made gun sprays powder wider
    # NOTHING OUTLIVES THE SHOT INTERVAL. This is the owner's headset note about flashes that "last a
    # while": one that overlaps the next shot stops reading as a flash.
    d["cid"] = cid
    d["conetics"] = int(max(2, min(5, min(firetics - 1, round(3 + d["fsize"])))))
    d["lighttics"] = int(max(1, min(3, firetics - 1)))
    return d


def cartridge_blocks(nl):
    out = []
    for cid in CARTRIDGE:
        speed, radius, brass, hole, charge, dirt, kick, what = CARTRIDGE[cid]
        p = "ww2_" + cid
        # WHAT ONE ROUND WEIGHS, from tools/cartridges.py, WHICH HOLDS THE ONLY COPY.
        #
        # It was written into these blocks once by a one-off script, and every re-run of this
        # generator silently erased it again -- ten of eighteen gone, and nothing said so until a gun
        # asked for it in a live level. A GENERATOR OWNS ITS BLOCKS: any line it does not emit is a
        # line it deletes. Exactly the two-sources-of-truth defect this package is built against.
        out += ["ballistics %s   # %s" % (p, what),
                "  speed  = %d" % speed,
                "  roundmass = %g   # one loaded round, grains (7000 = 1 lb)" % CART_LOAD[p][3],
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
                # THE ROUND IN FLIGHT: one mesh, sized by frame (MODELDEF). The calibre is READ from
                # the cartridge, the same way the vapour wake above it is -- buckshot is a stub, a
                # pistol round a short dart, a 9.3x74R the long heavy streak. Nothing is per-gun and
                # nothing is typed twice: change a speed and the streak follows it.
                "  look   = model, RSBM%s" % ("F" if cid == "12ga" else
                                              "A" if speed < 450 else
                                              "C" if speed < 550 else
                                              "D" if speed < 635 else "E"),
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
        if gid in SUPPRESSED:
            # DIFFERENT IN KIND, NOT QUIETER. No cone, no flame, no powder burn, no exposure, no hearing
            # -- those keys are ABSENT rather than small, which is the whole point. What a suppressed gun
            # actually shows is gas leaving the ports, a faint glow at the can, and the action working.
            out += ["flash %s   # %s" % (p, d["note"]),
                    "  # %s, %d damage at %.1f a second (firetics %d), spread %d,%d -- SUPPRESSED"
                    % (d["action"], d["dmg"], d["rate"], d["firetics"], d["spread"][0], d["spread"][1]),
                    "  light         = %d, 0.8, 1" % int(max(30.0, min(90.0, 150.0 * fsize))),
                    "  lightcolor    = 255, 214, 170",
                    "  bursts        = sup_gas_puff",
                    "  maybe         = spk_specks 0.10",
                    "  smoke         = 1, %.3f, %.2f" % (0.020 * puff, unit(0.25 * puff)),
                    "  smokeparticle = rsb_smoke_gun",
                    "  vary          = light 0.3, smoke 0.4",
                    "  powdervary    = %.2f" % d["vary"],
                    "  barrelheat    = %.2f, 0.20, 0.35" % unit(0.20 * haze),
                    "  barrelsmoke   = rsb_smoke_barrel, %.1f" % within(2.2 * haze, 0.0, 8.0),
                    "  barrelshimmer = 2.5, 0.4",
                    "  smokevolume   = %d, %.1f, %.1f, %d, %d" % (int(10 * haze) + 4, 0.8 * haze, 0.3 * haze, 40, 8),
                    "  tail          = rsb/tail/pistol, 0.2",
                    "end",
                    ""]
            out += recoil_and_ejecta(p, d)
            continue
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
                "  barrelsmoke   = rsb_smoke_barrel_soot, %.1f" % within(2.6 * haze, 0.0, 8.0),
                "  tail          = %s, %.1f" % ("rsb/tail/br" if heavy else "rsb/tail/smg", 0.9 if heavy else 0.7),
                "end",
                ""]
        out += recoil_and_ejecta(p, d)
    return out


def recoil_and_ejecta(p, d):
    """Shared by the ordinary and suppressed paths: a can changes the FLASH, not the kick or the brass."""
    out = []
    heavy = d["heavy"]
    if True:
        # RECOIL IS PER GUN because it is the gun, not the cartridge: the MG42 and the Kar98k fire the
        # same 7.92x57 and one of them is braced on a bipod.
        out += ["recoil %s   # %s at %.1f a second, spread %d,%d" % (p, d["action"], d["rate"], d["spread"][0], d["spread"][1]),
                "  climb   = %.2f" % d["climb"],
                # THE PHYSICS, STATED. climb above is derived from these; without them the only copy
                # lives in this file and the Body IK lane has to be handed a stale table by hand.
                "  shot    = %.2f, %.1f, %.3f" % (d["vg"], d["energy"], d["impulse"]),
                "  cartridge = ww2_%s" % d["cid"],
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
        if d["action"] in NO_EJECT:
            # NO EJECTA PROFILE AT ALL. See BRASS["none"]: a revolver and a break-action hold their cases
            # until you open them, and an empty-but-present profile would still be a thing to wire.
            out += ["# no `ejecta %s`: a %s action throws nothing while it fires -- leave ejectaprofile"
                    % (p, d["action"]), "# off this card. The %s is still its brass, it just stays in the gun." % what, ""]
            return out
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


# THE ORDNANCE. tube length (map units behind the muzzle), backblast strength, front flash size, note.
#
# ONE LINE OF BACKBLAST EACH, which is the whole point of building it as a capability first: before
# `backblast` existed, each of these would have restated its tube length in FIVE keys with three of them
# negative, and the failure mode is a backblast out of the FRONT with no error anywhere.
#
# THESE ARE NOT HITSCAN and have no sheet row -- they fire projectiles (Panzerfaust 750 damage,
# Panzerschreck 750, Nebelwerfer undug), so there is no rate, spread or cartridge to derive from and
# nothing here pretends otherwise. What a launcher needs from this package is a flash and a recoil, and
# both are stated rather than derived.
ORDNANCE = {
    "panzerfaust": (39, 0.85, 1.5, 0,
                    "THE PANZERFAUST: a disposable tube with a warhead on a stick. Fired once and thrown away, so it gets the dirtiest, least controlled blast of the three -- and being the shortest tube, the backblast lands nearest the shooter"),
    "panzerschreck": (64, 1.15, 1.7, 1,
                      "THE PANZERSCHRECK: a real rocket launcher with a blast shield, because the backblast will take your face off. The longest tube here, so the blast throws furthest behind"),
    # 42, NOT 51, AND NO LONGER A GUESS. Reload measured the owner's own mesh: the tube is 27.44 model
    # units, 9.33 map units, against about a metre for the real thing -- so the model shipped at roughly
    # a fifth of life size while every other WW2 gun sits at 1.15 to 1.27x. The owner has ruled it ships
    # at ~4.5x, which puts the tube near 42. My 51 was close for the wrong reason: I guessed from the
    # real weapon, not from the mesh, and the mesh was wrong.
    "nebelwerfer": (42, 1.4, 1.9, 1,
                    "THE NEBELWERFER: a twin over-under tube, and the heaviest blast of the three. Two rockets are two separate moving parts -- that half is the reload lane's; this is what one tube does when it goes"),
}


def ordnance_blocks():
    out = []
    for gid in ORDNANCE:
        tube, blast, fsize, braced, note = ORDNANCE[gid]
        p = "ww2_" + gid
        out += ["flash %s   # %s" % (p, note),
                "  light      = %d, %.1f, 4" % (int(360 * fsize), 3.0 + 1.6 * fsize),
                "  lightcolor = 255, 196, 124",
                "  cone       = %d, %d, %d, 10" % (int(16 * fsize), int(44 * fsize), int(90 * fsize)),
                "  conetics   = 4",
                "  bursts     = flash_core, flash_petals, backblast_fire, backblast_smoke, backblast_sparks",
                "  backblast  = %d, %.2f" % (tube, blast),
                "  maybe      = spk_stars 0.3, powder_clump 0.8",
                "  flame      = %.2f" % unit(0.06 * fsize),
                "  smoke      = 3, %.3f, %.2f" % (0.040 * fsize, unit(0.40 * fsize)),
                "  smokeparticle = rsb_smoke_soot_gun",
                "  vary       = light 0.2, flame 0.2, cone 0.15, sparks 0.3, smoke 0.3",
                "  surge      = 0.12, 1.3",
                "  barrelheat = %.2f, 0.20, 0.40" % unit(0.45 * blast),
                "  barrelsmoke = rsb_smoke_barrel_soot, %.1f" % within(3.0 * blast, 0.0, 8.0),
                "  barrelshimmer = 3.5, 0.5",
                "  powderburn = %d, 12, 0.6" % int(40 * fsize),
                "  powdervary = 0.45",
                "  blastkick  = kick_blast, %d, 12" % int(96 * fsize),
                "  shockwave  = %d, %.1f, 6" % (int(64 * blast), 1.8 * blast),
                "  tail       = rsb/tail/rpg, 1",
                "  exposure   = %.2f, %d" % (unit(0.95 * fsize), int(190 * fsize)),
                "  hearing    = %.2f, %d" % (unit(0.95 * fsize), int(220 * fsize)),
                "end",
                "",
                # RECOILLESS MEANS RECOILLESS. The blast out of the back cancels the push, so these barely
                # move -- which is the single most surprising thing about firing one and worth getting right.
                "recoil %s   # recoilless: the backblast cancels the kick, so it barely moves" % p,
                "  climb   = %.2f" % (0.9 if braced else 1.2),
                "  drift   = 0.40, 5",
                "  recover = 8, 4",
                "  max     = 3, 2",
                "  bloom   = 0.00",
                "  brace   = 0.6, 0.85",
                "  view    = 1.5, 3, 1, 12",
                "end",
                ""]
    return out


# ============================================================================ THE FANTASY GUNS
# DELIBERATELY NOT PERIOD, and that is the point: they are the Wolfenstein half of a Wolfenstein set.
# Everything above this line is derived from a sheet row; NONE of these are, because none of them is
# hitscan and four of the five have no rate, spread or cartridge to derive from. What a look needs from
# a wonder-weapon is not a damage figure.
#
# THE RULE THEY ALL FOLLOW: no powder, no soot, no brass, no smoke that hangs. These do not burn
# nitrocellulose. Where a real gun gets dirt, these get LIGHT -- which is also why the Tesla is the one
# that found an engine gap.
def fantasy_blocks():
    out = []

    # ---------------------------------------------------------------- THE TESLA GUN
    # THE OWNER ASKED FOR CRAZY LIGHTING AND THIS IS WHERE IT GOES. A lightning arc does not light the
    # room from the muzzle -- it lights it FROM ITS WHOLE LENGTH, every wall it passes, for two tics,
    # and then the room is black again. That is the thing to sell.
    #
    # `lights` on a trail is CAPPED AT 16 (parser.zs, the trail `lights` key), so a 1000-unit arc gets a
    # light every 62 units and at close range you can see the beads. Sixteen is what there is, so
    # sixteen is what it takes -- and this is the case for the SEGMENT LIGHT going to the build lane:
    # one capsule light along the arc would be cheaper than sixteen point lights and would not bead.
    out += ["trail ww2_tesla   # THE TESLA GUN: a white-hot arc in a violet halo that lights every wall it passes and is gone in two tics",
            "  line        = 1.1, 5.0, 4.0, 2",
            "  linecolor   = 235, 245, 255",
            "  linecolorend = 150, 120, 255",
            "  linelook    = 0.9, 4.5",
            # LICKS ARE THE JAG. Lightning is not a straight line, and a straight one reads as a laser;
            # these throw the arc off its own axis and back again.
            "  licks       = 0.45, 1.85, 0.22, 3.0",
            # THE VISIBLE BOLT IS HAND-DRAWN LIGHTNING strung along the path, not procedural noise. A
            # twenty-five frame discharge playing ONCE means no two shots are ever the same frame at the
            # same time, which is the thing procedural jitter never quite sells.
            "  helix       = rsb_lightning, 2.0, 10.0, 46.0",
            "  helixmotion = 14, 2.6, 0.9",
            "  helixcolor  = 170, 200, 255",
            "  helixmax    = 900",
            # ONE CAPSULE LIGHT DOWN THE WHOLE ARC, not sixteen point lights beaded along it. `lights`
            # caps at 16, so a long bolt lit that way shows the beads at close range -- and this is
            # cheaper as well as better, because the engine already has segment lights and a beam is
            # the shape they were invented for. Falls off slightly toward the far end, because a bolt
            # is brightest where it leaves the coils.
            "  beamlight   = 170, 3.6, 3, 0.75",
            # SIX LINKS, WANDERING, WHITE-HOT TO VIOLET. The whole point of the weapon in one place: the
            # room is lit by the SHAPE of the bolt, and the colour runs along it the way electricity does.
            "  beamjag     = 6, 26",
            "  lightcolor  = 235, 245, 255",
            "  beamcolorend = 150, 120, 255",
            "  heat        = 9, 0.8, 26",
            "end",
            "",
            "flash ww2_tesla   # the coils letting go: a hard blue-white crack at the muzzle, arcs off the horns, and NO smoke -- this thing burns no powder",
            "  light         = 330, 7.0, 2",
            "  lightcolor    = 190, 215, 255",
            "  cone          = 20, 70, 90, 6",
            "  conetics      = 2",
            "  bursts        = lightning_coils, lightning_specks, wisp_electric, energy_sparks_rail, plasma_ozone",
            "  maybe         = lightning_forks 0.85, arc_electric_one 0.8, spk_stars 0.45",
            "  flame         = 0.00",
            "  vary          = light 0.35, sparks 0.4",
            "  barrelglow    = 0.0, 26, 1.6",
            "  barrelglowcolor = 150, 190, 255",
            "  barrelshimmer = 4.0, 0.7",
            "  shockwave     = 40, 1.1, 4, 0, 0.35",
            "  exposure      = 0.80, 150",
            "  hearing       = 0.45, 120",
            "  tail          = rsb/tail/ar, 0.9",
            "end",
            "",
            "recoil ww2_tesla   # a coil gun has nothing to push back with: it SHUDDERS rather than kicks",
            "  climb   = 0.22",
            "  drift   = 0.85, 5",
            "  recover = 10, 5",
            "  max     = 4, 2",
            "  bloom   = 0.00",
            "  brace   = 0.6, 0.85",
            "  view    = 1.2, 5, 1, 7",
            "end",
            ""]
    # THE STRIKE. Arcs crawl on what it hit and keep crawling after the bolt is gone -- the one thing
    # this weapon leaves behind, and it is a burn rather than a hole.
    for mat, bursts, dmg, snd in [
            ("", "lightning_crawl, lightning_specks, energy_sparks_rail, spark_spray", "scorch, 7.0, 0.1, 0.45, 0.8", "rsb/impact/concrete"),
            (".metal", "lightning_crawl, lightning_specks, spark_metal, ember_metal", "pit, 6.0, 0.25, 0.4, 0.95", "rsb/impact/metal"),
            (".wood", "lightning_crawl, splinter_wood, melt_smoke_rise", "scorch, 8.0, 0.2, 0.5, 0.7", "rsb/impact/wood"),
            (".dirt", "lightning_crawl, clods_dirt, dust_dirt", "scorch, 9.0, 0.3, 0.3, 0.5", "none"),
            (".glass", "glint_glass, lightning_crawl", "crack, 9.0, 0.3, 0.1, 0.3", "rsb/glass"),
            (".liquid", "splash_liquid, lightning_crawl", "none", "none"),
            # A SHOT-OUT PANEL IS THE BEST THING THIS WEAPON DOES: the arcs keep crawling over the tech
            # after the bolt is long gone, lighting the wall they are on.
            (".tech", "lightning_crawl, lightning_forks, bits_wire, bits_board", "pit, 8.0, 0.3, 0.5, 1.0", "rsb/impact/metal"),
            (".screen", "lightning_crawl, bits_board", "crack, 10.0, 0.3, 0.2, 0.6", "rsb/glass")]:
        out += ["impact ww2_tesla%s" % mat,
                "  bursts    = %s" % bursts,
                "  sound     = %s" % snd,
                "  light     = 110, 2.2, 3",
                "  lightcolor = 180, 205, 255",
                "  damage    = %s" % dmg,
                "end",
                ""]
    out += ["ballistics ww2_tesla   # an arc, and it arrives when it arrives",
            "  speed  = 1400",
            "  radius = 3.0",
            "  damage = none",
            "end",
            "",
            # A TRAIL IS LAID BY THE GUN, not named on a round look -- RSB_Trail.Lay(profile, shooter,
            # from, to), one call per shot, the same way the rail gun and the BFG ray do it. There is no
            # `trail` key here and there should not be; `trail ww2_tesla` above is what the weapons lane
            # lays. This round look is the OTHER path: if the Tesla is wired as a flying bolt instead of
            # an instant beam, it is a fat blue-white streak that lights what it passes.
            "roundlook ww2_tesla   # the bolt itself, if it flies: a short blue-white streak lighting its own path",
            "  look   = none",
            "  glide  = yes",
            "  impact = ww2_tesla",
            "  light  = 90, 2.6",
            "  lightcolor = 180, 205, 255",
            "  lightlook  = streak",
            "  heat   = 10, 0.9, 28",
            "end",
            "",
            "round ww2_tesla",
            "  ballistics = ww2_tesla",
            "  roundlook  = ww2_tesla",
            "end",
            ""]

    # ---------------------------------------------------------------- THE LEICHENFAUST
    # "Corpse fist": 20 damage on contact and then A_Explode(800, 300), which is by a wide margin the
    # biggest blast in the set. 1943 is the prototype and 1944 the refinement, so the 43 is dirtier and
    # less contained and the 44 is tighter and colder -- the same weapon twice, one year apart.
    for gid, tint, wild, note in [
            ("leichenfaust43", (140, 255, 140), 1.25,
             "THE LEICHENFAUST 1943: the prototype, and it looks it -- a ragged green vent that spits as much as it fires"),
            ("leichenfaust44", (170, 255, 210), 0.85,
             "THE LEICHENFAUST 1944: the year-later refinement. Tighter, brighter, colder, and far more frightening for it")]:
        p2 = "ww2_" + gid
        r, g, b = tint
        out += ["flash %s   # %s" % (p2, note),
                "  light         = %d, %.1f, 3" % (int(300 * wild), 5.0 + 1.5 * wild),
                "  lightcolor    = %d, %d, %d" % (r, g, b),
                "  cone          = %d, %d, %d, 8" % (int(22 * wild), int(66 * wild), int(120 * wild)),
                "  conetics      = 3",
                "  bursts        = plasma_glow, plasma_vent_ring, plasma_ozone, unmaker_arcs",
                "  maybe         = plasma_crackle_muzzle %.2f, melt_embers %.2f" % (unit(0.7 * wild), unit(0.5 * wild)),
                "  flame         = 0.00",
                "  vary          = light 0.3, sparks 0.35",
                "  barrelglow    = 0.0, %d, %.1f" % (int(22 * wild), 1.4 * wild),
                "  barrelglowcolor = %d, %d, %d" % (r, g, b),
                "  barrelshimmer = %.1f, 0.6" % (4.5 * wild),
                "  shockwave     = %d, %.1f, 6, 0, 0.5" % (int(70 * wild), 2.0 * wild),
                "  exposure      = %.2f, %d" % (unit(0.85 * wild), int(180 * wild)),
                "  hearing       = %.2f, %d" % (unit(0.75 * wild), int(190 * wild)),
                "  tail          = rsb/tail/rpg, %.2f" % within(0.9 * wild, 0.0, 1.0),
                "end",
                "",
                "recoil %s   # it does not recoil so much as OBJECT: a long slow shove and a wander that takes its time" % p2,
                "  climb   = %.2f" % (0.7 * wild),
                "  drift   = %.2f, 5" % (0.9 * wild),
                "  recover = 24, 6",
                "  max     = 6, 3",
                "  bloom   = 0.00",
                "  brace   = 0.6, 0.85",
                "  view    = %.1f, 6, 1, 10" % (1.4 * wild),
                "end",
                ""]

    # ---------------------------------------------------------------- THE BLUE MP40
    # The MP40 rate firing plasma instead of 9mm. Its A_FireBullets line is commented out in the source:
    # it is a projectile weapon wearing an SMG body, which is exactly how it should read -- the MP40
    # rhythm, none of the MP40 dirt. Its recoil IS the MP40 recoil, derived like every other gun here.
    # NOT DERIVED FROM THE MP40 ROW, and it was until the weapons lane caught it. BWII comments OUT this
    # gun\'s A_FireBullets and fires a Plasma_Ball instead: same body, different weapon. A hitscan SMG\'s
    # recoil row says nothing about what a plasma emitter does to your wrists, so this is a CHOICE and is
    # written as one -- a light, fast shudder with no bloom, because a projectile carries no spread to grow.
    mp = derive("mp40")
    out += ["flash ww2_bluemp40   # THE BLUE MP40: the MP40 rhythm with none of its dirt -- a cold blue crack nine times a second and not one grain of powder",
            "  light         = 150, 3.4, 3",
            "  lightcolor    = 140, 185, 255",
            "  cone          = 14, 44, 60, 8",
            "  conetics      = %d" % mp["conetics"],
            "  bursts        = plasma_glow_small, plasma_crackle_muzzle",
            "  maybe         = plasma_ozone 0.5, spk_specks 0.25",
            "  flame         = 0.00",
            "  vary          = light 0.3, sparks 0.35",
            "  barrelglow    = 0.0, 14, 1.1",
            "  barrelglowcolor = 140, 185, 255",
            "  barrelshimmer = 2.8, 0.5",
            "  exposure      = 0.35, 90",
            "  hearing       = 0.30, 90",
            "  tail          = rsb/tail/smg, 0.5",
            "end",
            "",
            "recoil ww2_bluemp40   # an emitter, not a cartridge: a light fast shudder at the MP40 rhythm, and no bloom because a bolt carries no spread to grow",
            "  climb   = 0.22",
            "  drift   = 0.45, 5",
            "  recover = %d, 6" % mp["recover"],
            "  max     = 3, 2",
            "  bloom   = 0.00",
            "  brace   = 0.6, 0.85",
            "  view    = 1.1, 4, 1, 6",
            "end",
            ""]
    return out


# ============================================================================ LIGHT -> EXTREME
# THE OWNER ASKED FOR THE WHOLE RANGE ON EVERY GUN. The effects ladder already covers light-to-heavy on
# its own -- it scales counts, light, size and smoke, and it scales an authored profile too
# (flash.zs, "a profile written for a level is scaled by it too"). So plain and heavy need nothing
# written, and EXTREME is the only rung worth authoring, because it is the only one where the answer is
# not "the same thing, more of it".
#
# THIS IS A TRANSFORMER, NOT A SECOND SET OF RECIPES, and that is the whole design. It takes the flash
# blocks this file already generated and rewrites them, so an @extreme can never drift away from the gun
# it belongs to. Change the Kar98k and its extreme changes with it. The alternative -- writing thirty
# more profiles by hand -- is thirty more things to forget to update, and the WW2 set has already been
# rebuilt once under numbers that moved.
#
# WHAT EXTREME ACTUALLY ADDS is structure the ladder cannot: bursts that are not in the base recipe at
# all, chances pushed toward certainty, a longer cone, and a shockwave on anything big enough to earn
# one. It does NOT simply multiply the numbers, because the ladder is already doing that underneath.
EXTREME_ADD_BURSTS = ["flash_embers", "spk_embers_heavy"]


def _nums(v):
    """Values, each tagged with whether it was written as a whole number -- a TIC COUNT IS NOT A FLOAT,
    and rewriting `3` as `3.90` turns three tics into three, silently, while reading like a rounding
    detail. Anything integral in the base stays integral here."""
    out = []
    for t in v.split(","):
        t = t.strip()
        try:
            out.append((float(t), "." not in t))
        except ValueError:
            out.append((t, False))
    return out


def _fmt(vals):
    out = []
    for v, whole in vals:
        if not isinstance(v, float):
            out.append(str(v))
        elif whole:
            out.append("%d" % round(v))
        else:
            out.append("%.2f" % v)
    return ", ".join(out)


def _scale(vals, i, mul):
    """Scale one value in place, keeping its integer-ness."""
    if i < len(vals) and isinstance(vals[i][0], float):
        vals[i] = (vals[i][0] * mul, vals[i][1])


def extreme_blocks(body):
    """Every `flash` block in `body`, again as its @extreme variant."""
    out = []
    block = None
    for line in body:
        st = line.strip()
        if st.startswith("flash ") and "=" not in st:
            block = [line]
            continue
        if block is not None:
            block.append(line)
            if st == "end":
                out += _extreme_one(block)
                block = None
    return out


def _extreme_one(block):
    head = block[0].strip()
    name = head.split("#")[0].strip().split()[1]
    note = head.split("#", 1)[1].strip() if "#" in head else ""
    body = block[1:-1]

    # A SUPPRESSED GUN AT EXTREME IS STILL SUPPRESSED. It gets more gas and a stronger glow at the can
    # and NOTHING ELSE -- no cone, no embers, no shockwave. An extreme setting is the player asking for
    # more of what the gun is, not for it to become a different gun.
    quiet = any("sup_gas_puff" in l for l in body)

    out = ["flash %s@extreme   # %s%s" % (name, note, " -- AT EXTREME" if note else "AT EXTREME")]
    has_shock = any(l.strip().startswith("shockwave") for l in body)
    big = False
    for line in body:
        st = line.strip()
        if not st or st.startswith("#") or "=" not in st:
            out.append(line)
            continue
        key = st.split("=")[0].strip()
        val = st.split("=", 1)[1]
        pad = " " * (len(line) - len(line.lstrip()))

        if key == "light":
            v = _nums(val)
            if v and isinstance(v[0][0], float):
                big = v[0][0] >= 200
                v[0] = (min(420.0, v[0][0] * 1.15), v[0][1])
            out.append("%s%-13s = %s" % (pad, key, _fmt(v)))
            continue
        if key == "cone" and not quiet:
            # LONGER IN SPACE. Deliberately NOT longer in time -- see conetics below.
            v = _nums(val)
            _scale(v, 2, 1.35)
            out.append("%s%-13s = %s" % (pad, key, _fmt(v)))
            continue
        # `conetics` IS NOT TOUCHED AT ANY EFFECTS LEVEL, and the first version of this transformer
        # added a tic to it, which would have put the Thompson and the PPSh back exactly where the
        # owner found them: a flash that outlives the gap between shots, overlapping its successor and
        # reading as a lamp bolted to the muzzle. Extreme means MORE, never LONGER. The base recipe
        # already caps this at firetics - 1 and nothing above it gets to undo that.
        if key == "bursts":
            extra = "" if quiet else (", " + ", ".join(EXTREME_ADD_BURSTS))
            out.append("%s%-13s =%s%s" % (pad, key, val.rstrip(), extra))
            continue
        if key == "maybe":
            parts = []
            for t in val.split(","):
                t = t.strip()
                bits = t.rsplit(" ", 1)
                if len(bits) == 2:
                    try:
                        parts.append("%s %.2f" % (bits[0], min(0.95, float(bits[1]) * 1.4)))
                        continue
                    except ValueError:
                        pass
                parts.append(t)
            if not quiet:
                parts.append("flash_tongue 0.45")
            out.append("%s%-13s = %s" % (pad, key, ", ".join(parts)))
            continue
        if key == "powderburn":
            v = _nums(val)          # `radius, tics, soot`
            _scale(v, 0, 1.4)
            if len(v) > 1 and isinstance(v[1][0], float):
                v[1] = (v[1][0] + 4, v[1][1])
            out.append("%s%-13s = %s" % (pad, key, _fmt(v)))
            continue
        if key == "blastkick":
            # `blastkick = <impact>, radius, tics`. ONLY THE RADIUS. Scaling everything numeric turned
            # 3 tics into 3.90 -- which the parser reads as 3, so it looked harmless and was not.
            v = _nums(val)
            _scale(v, 1, 1.3)
            out.append("%s%-13s = %s" % (pad, key, _fmt(v)))
            continue
        if key == "barrelsmoke":
            v = _nums(val)          # `<particle>, puffs a tic` -- bounded 0-8, and the Venom hits it
            _scale(v, 1, 1.3)
            if len(v) > 1 and isinstance(v[1][0], float):
                v[1] = (min(7.8, v[1][0]), v[1][1])
            out.append("%s%-13s = %s" % (pad, key, _fmt(v)))
            continue
        out.append(line)

    # A SHOCKWAVE ON ANYTHING BIG ENOUGH TO EARN ONE, and only at extreme. The air bending behind a
    # muzzle is the single most expensive thing in the flash, so it is the last rung, not the first.
    if big and not has_shock and not quiet:
        out.append("  shockwave     = 46, 1.3, 5")
    out.append("end")
    out.append("")
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
    ap.add_argument("--recoil", action="store_true")
    args = ap.parse_args()

    if args.table:
        print_table()
        return
    if args.recoil:
        print_recoil()
        return

    text = io.open(DEFS, encoding="utf-8", newline="").read()
    nl = "\r\n" if "\r\n" in text else "\n"

    body = [BEGIN,
            "# THE WW2 SET. Twenty-six guns and a flamethrower, ten cartridges, NOTHING REUSED FROM THE",
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
    guns = gun_blocks(nl) + ordnance_blocks() + fantasy_blocks()
    body += guns
    # LIGHT -> EXTREME ON EVERY GUN (owner). Derived from the blocks above rather than written beside
    # them, so an extreme variant cannot drift from the gun it belongs to.
    body += ["", "# ---- EVERY FLASH ABOVE, AGAIN, AT THE EXTREME EFFECTS LEVEL.",
             "# Generated from the base blocks by a transformer, never hand-written: see extreme_blocks().",
             "# The ladder already scales counts, light, size and smoke (including for an authored profile),",
             "# so these add STRUCTURE the ladder cannot -- bursts that are not in the base recipe, chances",
             "# pushed toward certainty, a longer cone, and a shockwave on anything big enough to earn one.",
             ""]
    body += extreme_blocks(guns)
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


# IMPORTING A GENERATOR MUST NOT RUN IT. Bare `main()` here meant that reading this file's
# tables -- or borrowing one function from it -- REWROTE RSBDEFS.txt as a side effect. It
# silently reverted eleven round looks mid-edit once, and ran a second time when another
# generator imported this one for its extreme transformer.
if __name__ == "__main__":
    main()
