#!/usr/bin/env python3
"""
cartridges.py -- ONE canonical table of what a cartridge is.

This is step 2 of the gun-weight proposal, and it is the half that makes the split honest. An MG42 and
a Kar98k fire the SAME 7.92x57 out of a 25 lb gun and a 9 lb gun, and their kick differs threefold. So
the round cannot know the kick and the gun cannot know the round:

    the CARTRIDGE knows bullet grains, muzzle fps, charge grains, and what one loaded round weighs
    the GUN knows its weight (`baseweight`, on the weapons lane's sheet)
    kick is computed from both, at the shot

Before this file the load lived inside five separate generators, one copy per weapon set, keyed by GUN.
Every gun firing 7.92x57 carried its own copy of 198/2493/47, and nothing checked that the copies
agreed. This is the single copy, keyed by the BALLISTICS PROFILE -- which is what RSBDEFS actually
names -- and tools/gen_cartridge_load.py writes it into the profiles.

    bullet grains, muzzle fps, charge grains, one LOADED ROUND in grains, note

ROUND GRAINS is the new figure and it is the one the weapons lane needs: a magazine's contribution to
a gun's weight is capacity x this. 7000 grains = 1 lb. These are published nominal masses for a
complete round -- bullet, powder and case together -- and they vary by loading roughly +/- 5%. That is
far below the precision baseweight needs, but it is not nothing, and saying so beats implying four
significant figures.

MUZZLE FPS IS NOT A PROPERTY OF A CARTRIDGE, and the figures here are nominal only. This was going to
be moved onto the cartridge profiles until the existing tables were reconciled against each other and
turned out to hold TWENTY-NINE distinct loads across THIRTEEN cartridges -- because barrel length
changes muzzle velocity, and charge varies with the loading:

    5.56      3020 (rotary)  2900 (HK416)  2650 (MK18)  2600 (MK18 sup)  2560 (G36C)
    9x19      1250 (MP40)    1230 (Glock)  1200 (Sten)  1150 (Luger)     1050 (subsonic)
    7.62 Tok  1600 (PPSh)    1390 (TT33)
    .45 ACP    920 (Thompson) 830 (1911)

Flattening those onto the cartridge would have changed the kick of sixteen guns to make a table tidy.

SO THE RUNTIME DOES NOT NEED FPS AT ALL. The per-gun `shot` line on each recoil profile already states
IMPULSE, which is (bullet x fps + 4700 x charge) / 7000 / 32.174 -- bullet, charge and barrel already
inside it, per gun. TT33 0.646 against PPSh 0.726; Glock 0.722 against its suppressed twin 0.630. So:

    climb = impulse x 32.174 / current_lb x CLIMB_PER_FPS x ACTION[action]

and the ONLY cartridge-level figure the shot still needs is the mass of one round, so that
current_lb = baseweight + rounds x round_lb falls as the gun empties. That is what this file is for.

WHAT IS DELIBERATELY ABSENT. A shot with no cartridge states nothing here: the BFG, plasma, the
chainsaw, the rail gun, the Tesla, the recoilless launchers. Inventing a load so the arithmetic would
run is false precision, and the stated `climb` on those profiles is the answer instead. The 10mm
caseless (ae_10mm) is the interesting edge -- it is FICTION with a stated mass and NO CASE, so its
round mass is bullet plus propellant block and nothing else.
"""

# ballistics profile -> (bullet grains, muzzle fps, charge grains, loaded round grains, note)
LOAD = {
    # ---------------------------------------------------------------- Vanilla / Vanilla+ / Modern
    # These are the owner's instruction to infer from real-world equivalents. The CARTRIDGE is real
    # even where the gun is a Doom sprite: a 9mm is a 9mm whoever is holding it.
    "pistol_9mm":   (115, 1150, 4.5, 190, "9x19 Parabellum, 115 gr ball"),
    "pistol_45":    (230,  830, 5.0, 324, ".45 ACP, 230 gr ball"),
    "revolver_357": (158, 1250, 15.0, 278, ".357 Magnum, 158 gr"),
    "rifle_556":    ( 62, 3020, 25.0, 190, "5.56x45 NATO, M855 62 gr"),
    "rifle_762":    (147, 2750, 46.0, 370, "7.62x51 NATO, M80 147 gr"),
    "buckshot":     (437, 1325, 32.0, 694, "12 gauge 2 3/4 in, nine 00 pellets -- the 437 gr is the "
                                           "TOTAL shot column, not one pellet"),
    # `default` is the house fallback and fires no particular thing. It states no load on purpose:
    # a made-up cartridge on the profile every unstated gun falls back to would quietly become the
    # most-used figure in the package.

    # ---------------------------------------------------------------- WW2 / Brutal Wolfenstein
    "ww2_9mm":      (115, 1150, 4.5, 190, "9x19 Parabellum"),
    "ww2_45":       (230,  830, 5.0, 324, ".45 ACP"),
    "ww2_762tok":   ( 86, 1390, 7.0, 167, "7.62x25 Tokarev -- a bottlenecked pistol round"),
    "ww2_792kurz":  (125, 2250, 25.0, 259, "7.92x33 Kurz, the first intermediate cartridge"),
    "ww2_792":      (198, 2493, 47.0, 409, "7.92x57 Mauser, sS heavy ball"),
    "ww2_3006":     (150, 2800, 50.0, 401, ".30-06 Springfield, M2 ball"),
    "ww2_762x54r":  (148, 2838, 48.0, 386, "7.62x54R, light ball"),
    "ww2_93x74r":   (286, 2360, 60.0, 540, "9.3x74R -- a boar round in a drilling"),
    "ww2_357":      (158, 1250, 15.0, 278, ".357 class"),
    "ww2_22lr":     ( 40, 1050, 1.5,  56, ".22 LR -- the tiny charge is half of why the HDm is quiet"),
    "ww2_12ga":     (437, 1325, 32.0, 694, "12 gauge 00 buck"),

    # ---------------------------------------------------------------- Blood
    # A 26.5 mm signal flare: a 35 g star lobbed on a small charge. Its mass lived in
    # gen_blood_profiles.py until the WW2 roundmass loss showed what a second copy costs.
    "bl_flare":     (540, 250, 4.0, 900, "26.5 mm flare -- a heavy star at low velocity"),

    # ---------------------------------------------------------------- Aliens
    # FICTION, and the one cartridge here with no case at all. 10mm explosive-tip caseless: the round
    # is bullet plus a moulded propellant block, so its mass is the two together and there is no brass
    # to subtract or to throw. This is why AE_PulseRifle must not name an ejecta profile.
    "ae_10mm":      (210, 2400, 40.0, 250, "10mm caseless, M41A -- no case, so round mass is bullet "
                                           "plus propellant block and nothing else"),
}

# Profiles that fire something with no cartridge, listed so that "absent" is a DECISION and not an
# omission -- the same reason `damage = none` is written out rather than left off.
NO_CARTRIDGE = {
    "enemy_bullet": "a monster's shot: whatever a zombieman is firing, it is not a catalogued load",
    "default":      "the house fallback; a made-up load here would become the most-used figure we ship",
    "ww2_tesla":    "an arc, not a round",
}

GRAINS_PER_LB = 7000.0


def round_lb(profile):
    """One loaded round in pounds, or None where this cartridge does not exist."""
    r = LOAD.get(profile)
    return (r[3] / GRAINS_PER_LB) if r else None


if __name__ == "__main__":
    print("%-14s %7s %7s %8s %9s  %s" % ("profile", "grains", "fps", "charge", "round gr", "one round, lb"))
    for p in sorted(LOAD):
        wb, vb, wc, wr, _note = LOAD[p]
        print("%-14s %7g %7g %8g %9g  %.4f" % (p, wb, vb, wc, wr, wr / GRAINS_PER_LB))
    print("\n%d cartridges. %d profiles state no load on purpose: %s"
          % (len(LOAD), len(NO_CARTRIDGE), ", ".join(sorted(NO_CARTRIDGE))))
