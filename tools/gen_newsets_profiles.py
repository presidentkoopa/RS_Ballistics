#!/usr/bin/env python3
"""
gen_newsets_profiles.py -- the rest of Aliens Eradication, and all of Cola 3.

The two ICONIC Aliens guns are in tools/gen_aliens_profiles.py and were built first, to a different
brief. The owner: "MAKE THE COLA ONES UNIQUE TOO BUT THEY AREN'T ICONIC LIKE THESE ARE." So:

  ALIENS -- these are guns people know from the film. Each one gets a signature drawn from what it
            IS, the same as the Smartgun and the Pulse Rifle.
  COLA   -- unique, not reverent. Each gets ONE real distinguishing fact and is otherwise a good,
            honest recipe. No gun here should be mistaken for its neighbour; none needs a monument.

EVERY SIGNATURE BELOW IS A PROPERTY OF THE REAL WEAPON, not a decoration:

  M37A2       it is an Ithaca 37 -- the shotgun from the film. Spread 5.6 HORIZONTAL, 0 vertical,
              off the weapons sheet: it fans sideways and does not rise.
  M4A3        the understated one. In a set with a Smartgun and a flamethrower, the sidearm's whole
              character is that it is ORDINARY -- tight, clean, and over quickly.
  M260B       a modern incinerator, not a 1940s Flammenwerfer: a shorter, hotter, tighter gout with
              blue at the root where the fuel is still burning clean.
  KS-23       A 23mm BORE, built on an aircraft cannon barrel, and RIFLED. The largest shotgun bore
              in the world by a wide margin -- so the widest flash and the hardest shotgun kick we
              ship, and it earns both arithmetically rather than by assertion.
  Jackhammer  a bullpup auto shotgun fed from a REVOLVING CYLINDER, so it leaks gas at the cylinder
              gap exactly as a revolver does. A side vent nothing else in the game has.
  Sidewinder  an ordinary 30-round 5.56 select-fire rifle, and it should read as the dependable one.
  Plasma Gun  throws a ball you can see coming.
  Particle    DOES NOT. See the note at the bottom: a particle accelerator is a BEAM and wants
              `cl_particlegun` laid as a trail, not a projectile.

RATES: firetics comes off the weapons sheet where stated. Three Aliens guns state none, so the rate
is ASSUMED and marked -- send me firetics and I re-run rather than re-tune.

    python tools/gen_newsets_profiles.py           # rewrite the block between the markers
    python tools/gen_newsets_profiles.py --table   # the derived numbers, change nothing
    python tools/gen_newsets_profiles.py --wiring  # the lines the weapons lane needs
"""
import argparse
import io
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
DEFS = os.path.join(PKG, "RSBDEFS.txt")
BEGIN = "# ---- BEGIN NEW SETS (tools/gen_newsets_profiles.py)"
END = "# ---- END NEW SETS"

CLIMB_PER_FPS = 0.148
CLIMB_CEILING = 4.2
ACTION = {"pump": 1.45, "semi": 1.15, "auto": 0.85, "belt": 0.45}

# gun -> bullet grains, muzzle fps, charge grains, loaded lb, action, rate/s, (spread), flash size,
#        brass profile, round profile, rate-is-assumed, note
GUNS = {
    # ---------------------------------------------------------------- ALIENS: reverence
    "ae_m37a2": (437, 1325, 32, 7.0, "pump", 2.92, (5.6, 0), 1.60, "hull_12ga", "buckshot", True,
                 "THE M37A2: an Ithaca 37, the shotgun from the film. Its spread is 5.6 HORIZONTAL and 0 VERTICAL -- it fans sideways and does not rise, which is the weapons lane's number and not my taste. A slow, deliberate, enormous boom"),
    "ae_m4a3":  (115, 1150, 4.5, 2.3, "semi", 5.83, (1, 1), 0.78, "brass_9mm", "pistol_9mm", True,
                 "THE M4A3 SERVICE PISTOL: in a set with a Smartgun and an incinerator, the sidearm's whole character is that it is ORDINARY. Tight, clean, small, over quickly -- and it should feel like the thing you reach for when the good guns are empty"),
    # ---------------------------------------------------------------- COLA: unique, not reverent
    "cl_ks23":  (1100, 1150, 58, 8.4, "pump", 2.92, (5.6, 0), 1.95, "hull_12ga", "buckshot", True,
                 "THE KS-23: a 23mm BORE built on an aircraft cannon barrel, and rifled. The largest shotgun bore in the world by a distance -- the widest flash and the hardest shotgun kick we ship, and it earns both by arithmetic"),
    "cl_jackhammer": (437, 1325, 32, 10.4, "auto", 4.38, (6.5, 0), 1.35, "hull_12ga", "buckshot", False,
                      "THE JACKHAMMER: a bullpup auto shotgun fed from a REVOLVING CYLINDER, so it leaks gas at the cylinder gap exactly as a revolver does -- a side vent nothing else in the game has"),
    "cl_sidewinder": (62, 3000, 26, 7.9, "semi", 5.83, (3, 3), 0.98, "brass_556", "rifle_556", False,
                      "THE SIDEWINDER: an ordinary 30-round 5.56 select-fire rifle, and it should read as the dependable one in a set full of oddities"),
}

# Energy weapons: no cartridge, so the kick is STATED and says what it reasons from.
ENERGY = {
    "cl_plasmagun": (0.34, 0.42, 13, 11.67, 1.15, (140, 190, 255),
                     "THE PLASMA GUN: it throws a BALL you can see coming and can sidestep. Twelve a second, so the muzzle stays small and the bolts do the work"),
}



# A SOUND NAME THAT DOES NOT EXIST DOES NOT ERROR -- it is simply silent, which is the single failure
# shape that has cost this project more than any other. I killed `rsb/tail/rail` on the Tesla hours
# ago and then wrote it again here, in a different file, from memory. So the generator now refuses to
# write one rather than trusting me to remember.
#
# Knows the two conventions that defeat a naive check: SNDINFO's `$random` groups define most names,
# and a flash's `tail` names a PREFIX -- /int under a ceiling, /ext under open sky.
def check_sounds(body):
    snd = os.path.join(PKG, "SNDINFO.txt")
    declared = set()
    for line in io.open(snd, encoding="utf-8", errors="replace"):
        t = line.split("//")[0].strip()
        if not t:
            continue
        for kw in ("$random", "$alias", "$playersound", "$limit", "$pitchset", "$volume"):
            if t.lower().startswith(kw):
                t = t[len(kw):].strip()
                break
        m = re.match(r"^([A-Za-z0-9_/-]+)", t)
        if m:
            declared.add(m.group(1).lower())
    bad, where = [], "?"
    for line in body:
        t = line.strip()
        if "=" not in t and t.split():
            where = t.split("#")[0].strip() or where
            continue
        if "=" not in t:
            continue
        key = t.split("=")[0].strip().lower()
        if key not in ("tail", "sound", "sounds", "whiz", "sputter"):
            continue
        for tok in t.split("=", 1)[1].split(","):
            tok = tok.strip().lower()
            if not tok.startswith("rsb/"):
                continue
            ok = tok in declared
            if not ok and key == "tail":
                ok = (tok + "/int") in declared or (tok + "/ext") in declared
            if not ok:
                bad.append("%s: %s = %s IS NOT DECLARED IN SNDINFO" % (where, key, tok))
    if bad:
        raise SystemExit("REFUSED BEFORE WRITING -- a sound name that does not exist is simply silent:"
                         + chr(10) + "  " + (chr(10) + "  ").join(bad))

def derive(gid):
    wb, vb, wc, wg, action, rate, spread, fsize, brass, rnd, assumed, note = GUNS[gid]
    vg = (wb * vb + 4700.0 * wc) / (7000.0 * wg)
    e = wg * vg * vg / 64.348
    sx, sy = spread
    return dict(vg=vg, energy=e, wg=wg, impulse=wg * vg / 32.174, action=action, rate=rate, spread=spread, fsize=fsize,
                brass=brass, rnd=rnd, assumed=assumed, note=note,
                climb=min(CLIMB_CEILING, vg * CLIMB_PER_FPS * ACTION[action]),
                drift=0.30 + 0.055 * (sx + sy), bloom=0.02 * (sx + sy),
                vary=min(0.95, 0.35 + 0.035 * (sx + sy)),
                recover=int(round(min(30.0, max(8.0, 26.0 * (5.8333 / rate) ** 0.5)))),
                conetics=int(max(2, min(5, round(3 + fsize)))) if rate < 8 else 2)


def gun_block(gid):
    d = derive(gid)
    f = d["fsize"]
    out = ["flash %s   # %s" % (gid, d["note"]),
           "  # %s, %.1f a second%s, spread %g,%g -- %.1f ft-lb of free recoil (Vg %.2f fps)"
           % (d["action"], d["rate"], " (rate ASSUMED: the sheet states no firetics)" if d["assumed"] else "",
              d["spread"][0], d["spread"][1], d["energy"], d["vg"]),
           "  light         = %d, %.1f, %d" % (int(155 * f), 2.3 + 1.6 * f, 3 if d["rate"] < 8 else 2),
           "  lightcolor    = 255, 216, 164",
           "  cone          = %d, %d, %d, 8" % (13 + int(10 * f), 42 + int(18 * f), int(100 * f)),
           "  conetics      = %d" % d["conetics"],
           "  bursts        = flash_core, flash_petals, %s"
           % ("spk_streaks_wide" if d["spread"][0] > 4 else "spk_streaks_fine"),
           "  flame         = %.2f" % (0.10 * f + 0.05),
           "  smoke         = 1, %.3f, %.2f" % (0.026 * f, min(0.95, 0.38 * f)),
           "  smokeparticle = rsb_smoke_gun",
           "  vary          = light 0.25, flame 0.2, cone 0.15, sparks 0.3, smoke 0.3",
           "  powderburn    = %d, 6, 0.6" % (int(24 * f) + 6),
           "  powdervary    = %.2f" % d["vary"],
           "  maybe         = spk_specks 0.3",
           "  blastkick     = kick_puff, %d, 3" % (52 + int(22 * f)),
           "  exposure      = %.2f, %d" % (min(0.9, 0.28 * f + 0.14), int(90 * f) + 40),
           "  hearing       = %.2f, %d" % (min(0.9, 0.32 * f + 0.14), int(100 * f) + 46),
           "  barrelheat    = %.2f, 0.22, 0.32" % min(0.95, 0.24 * f),
           "  barrelsmoke   = rsb_smoke_barrel, %.1f" % min(7.8, 2.1 * f)]
    if gid == "cl_jackhammer":
        # THE CYLINDER GAP. A revolving-cylinder gun vents sideways at the gap between cylinder and
        # barrel, which is why you keep your hand off the front of a revolver. `barrels` is the key
        # that already existed for off-axis muzzle emission, and this is a second, honest caller.
        out += ["  barrels       = 2, 4.5   # the cylinder gap: gas leaks off-axis, as it does on a revolver"]
    out += ["  tail          = %s, 0.9" % ("rsb/tail/shotgun" if d["rnd"] == "buckshot" else
                                           "rsb/tail/ar" if d["rnd"] == "rifle_556" else "rsb/tail/pistol"),
            "end",
            "",
            "recoil %s   # %.1f ft-lb a shot, %s -- spread %g,%g"
            % (gid, d["energy"], d["action"], d["spread"][0], d["spread"][1]),
            "  climb   = %.2f" % d["climb"],
            "  shot    = %.2f, %.1f, %.3f" % (d["vg"], d["energy"], d["impulse"]),
            "  drift   = %.2f, 5" % d["drift"],
            "  recover = %d, 6" % d["recover"],
            "  max     = %.1f, %.1f" % (max(3.0, min(9.0, 3.0 + 2.2 * d["climb"])),
                                        max(2.0, 1.0 + 0.5 * d["spread"][0])),
            "  bloom   = %.2f" % d["bloom"],
            "  brace   = 0.75, 0.90",
            "  view    = %.1f, %d, 1, 7" % (1.0 + 1.2 * (d["climb"] / 2.6), 4 + int(4 * (d["climb"] / 2.6))),
            "end",
            ""]
    return out


def blocks():
    out = [BEGIN,
           "# THE REST OF ALIENS ERADICATION, AND ALL OF COLA 3. DO NOT EDIT BY HAND:",
           "# change tools/gen_newsets_profiles.py and run it again.",
           "#",
           "# Two briefs. The Aliens guns are ones people know from the film and each gets a signature",
           "# drawn from what it IS. The Cola guns get one real distinguishing fact each and an honest",
           "# recipe otherwise -- unique, not reverent, which is the owner's own division.",
           ""]
    for gid in GUNS:
        out += gun_block(gid)

    for gid, (climb, drift, recover, rate, fsize, col, note) in ENERGY.items():
        r, g, b = col
        out += ["flash %s   # %s" % (gid, note),
                "  light         = %d, %.1f, 2" % (int(150 * fsize), 3.0 + 1.2 * fsize),
                "  lightcolor    = %d, %d, %d" % (r, g, b),
                "  cone          = %d, %d, %d, 8" % (int(14 * fsize), int(46 * fsize), int(66 * fsize)),
                "  conetics      = 2",
                "  bursts        = plasma_glow_small, plasma_crackle_muzzle",
                "  maybe         = plasma_ozone 0.45, spk_specks 0.2",
                "  flame         = 0.00",
                "  vary          = light 0.3, sparks 0.35",
                "  barrelglow    = 0.0, %d, 1.2" % int(16 * fsize),
                "  barrelglowcolor = %d, %d, %d" % (r, g, b),
                "  barrelshimmer = 2.8, 0.5",
                "  exposure      = 0.35, 92",
                "  hearing       = 0.30, 92",
                "  tail          = rsb/tail/smg, 0.5",
                "end",
                "",
                "recoil %s   # an emitter: no cartridge to derive from, so this is stated -- a light fast shudder and no bloom, because a bolt carries no spread to grow" % gid,
                "  climb   = %.2f" % climb,
                "  drift   = %.2f, 5" % drift,
                "  recover = %d, 6" % recover,
                "  max     = %.1f, 2" % max(3.0, 3.0 + 2.2 * climb),
                "  bloom   = 0.00",
                "  brace   = 0.75, 0.90",
                "  view    = %.1f, 4, 1, 6" % (1.0 + 1.2 * (climb / 2.6)),
                "end",
                ""]

    # ---------------------------------------------------------------- the incinerator
    out += ["flame ae_flamer   # THE M260B INCINERATOR: not a 1940s Flammenwerfer. A shorter, hotter, tighter gout with BLUE AT THE ROOT where the fuel is still burning clean, going orange as it tumbles and starves. Corridor work",
            "  reach       = 360",
            "  speed       = 820",
            "  spread      = 1.7",
            "  stream      = flame_core, flame_body, flame_tip, flame_embers",
            "  landing     = flame_splash, flame_sheet, flame_embers_rise, flame_smoke, flame_lick",
            "  cling       = 0.38",
            "  tube        = 5, 1.0, 3, 0.45",
            "  tubelook    = 1.5, 2.8, 0.45",
            "  tubecolors  = 190, 220, 255, 255, 240, 200, 255, 180, 70, 255, 96, 24, 120, 28, 8",
            "  tubelicks   = 0.6, 0.08, 2.6",
            "  heat        = 5, 18, 1.4, 0.10, 30",
            "  heatland    = 28, 1.6",
            "  landingtics = 2",
            "  scorch      = pool, 11, 120",
            "  scorchcolor = 255, 110, 30",
            "  scorchtics  = 9",
            "  light       = 240, 3.0, 0.40",
            "  lightcolor  = 255, 158, 66",
            "  landlight   = 170, 2.5",
            "  sounds      = rsb/flame/loop, rsb/flame/start, rsb/flame/stop",
            "  pilot       = pilot_flame",
            "  sputter     = 0.18, rsb/flame/hiss",
            "  flameout    = flame_out_puff",
            "  smokevolume = 18, 0.6, 1.9, 0.8",
            "  damage      = scorch, 13, 0, 0.06, 0",
            "end",
            "",
            "recoil ae_flamer   # a pressurised tank shoves rather than snaps, and keeps shoving while the trigger is down",
            "  climb   = 0.16",
            "  drift   = 0.90, 5",
            "  recover = 22, 6",
            "  max     = 5, 3",
            "  bloom   = 0.00",
            "  brace   = 0.75, 0.90",
            "  view    = 1.1, 4, 1, 6",
            "end",
            ""]

    # ---------------------------------------------------------------- the particle beam
    out += ["# THE PARTICLE GUN. Not a laser, not a plasma bolt, and the difference is physical.",
            "#",
            "# A PARTICLE BEAM IS MATTER, NOT LIGHT. It fires charged particles at a fraction of light",
            "# speed. In vacuum you would see NOTHING -- there is no beam to look at. What you see in air",
            "# is THE AIR ITSELF: the particles strip electrons off everything they pass through and the",
            "# ionised channel glows. So the visible line is not the weapon, it is the damage the weapon",
            "# is doing to the atmosphere on its way past. That single fact drives every number below.",
            "#",
            "# IT FRAYS. A beam of like-charged particles pushes itself apart, and every metre of air",
            "# scatters it further -- real accelerators call it blooming and it is why particle weapons",
            "# are a short-range idea. So the licks START TIGHT AND END LOOSE: a clean aperture and a",
            "# ragged far end, the exact opposite of the rail gun's clean slug and of the Tesla's",
            "# uniformly jagged arc.",
            "#",
            "# IT DEPOSITS ALONG ITS WHOLE LENGTH, not at the end. The heat is the longest and strongest",
            "# of any beam we ship, because the air is being cooked the entire way rather than at a point.",
            "#",
            "# AND THE CHANNEL STAYS CONDUCTIVE for a moment after. Ionised air is a path for current, so",
            "# arcs jump along and off it once the beam itself is gone -- which is why the helix is arcs",
            "# rather than motes, and why the line outlives the shot by a few tics.",
            "#",
            "# LAID BY THE GUN, one line per shot, the same as the rail and the Tesla:",
            "#     RSB_Trail.Lay(\"cl_particlegun\", shooter, muzzlePos, hitPos);",
            "# Its shotclass must stop being RSB_PlasmaBall -- there is no projectile, and a ball you can",
            "# sidestep is the one thing this weapon is not.",
            "trail cl_particlegun   # the air torn open along a line: white where it is worst, violet where it fades, fraying as it goes and still crackling after",
            "  line         = 0.9, 7.0, 3.2, 4",
            "  linecolor    = 240, 248, 255",
            "  linecolorend = 122, 58, 255",
            "  linelook     = 1.2, 4.4",
            "  # TIGHT AT THE APERTURE, RAGGED AT THE FAR END: atmospheric blooming, and the one thing",
            "  # that makes this read as particles rather than as light.",
            "  licks        = 0.12, 0.95, 0.07, 1.6",
            "  linepulse    = 3, 0.42, 2.0",
            "  # ARCS, NOT MOTES. The channel is still conductive when the beam has gone.",
            "  helix        = rsb_arc, 3.5, 5.5, 14.0",
            "  helixmotion  = 11, 2.2, 0.8",
            "  helixcolor   = 190, 150, 255",
            "  helixmax     = 700",
            "  beamlight    = 150, 2.6, 4, 0.55",
            "  lightcolor   = 225, 210, 255",
            "  beamcolorend = 110, 50, 235",
            "  # THE LONGEST, STRONGEST HEAT OF ANY BEAM HERE: the air is cooked the whole way, not at a point.",
            "  heat         = 9, 1.0, 30",
            "end",
            "",
            "flash cl_particlegun   # the aperture letting go: a hard violet-white crack and a smell of ozone. No powder, no smoke, no cone worth the name -- nothing is burning here",
            "  light         = 220, 4.6, 2",
            "  lightcolor    = 216, 198, 255",
            "  cone          = 13, 38, 46, 6",
            "  conetics      = 2",
            "  bursts        = energy_sparks_rail, plasma_ozone, arcs_electric",
            "  maybe         = spk_stars 0.35, wisp_electric 0.4",
            "  flame         = 0.00",
            "  vary          = light 0.3, sparks 0.35",
            "  barrelglow    = 0.0, 22, 1.5",
            "  barrelglowcolor = 190, 170, 255",
            "  barrelshimmer = 3.6, 0.65",
            "  shockwave     = 34, 0.9, 4, 0, 0.45",
            "  exposure      = 0.55, 130",
            "  hearing       = 0.35, 100",
            "  tail          = rsb/tail/ar, 0.8",   # NOT rsb/tail/rail: no such sound, and I wrote it twice
            "end",
            "",
            "recoil cl_particlegun   # a stream of particles has almost no mass to push back with. What you feel is the machine, not the shot: a hard electrical SNAP rather than a shove",
            "  climb   = 0.55",
            "  drift   = 0.30, 5",
            "  recover = 12, 6",
            "  max     = 4.2, 2",
            "  bloom   = 0.00",
            "  brace   = 0.75, 0.90",
            "  view    = 1.3, 5, 1, 6",
            "end",
            ""]

    # WHAT IT DOES WHERE IT LANDS, and it is not a hole. A particle beam does not punch -- it dumps
    # energy into the first few millimetres and the surface comes apart: it pits, it scorches, it
    # throws off what it has boiled. Arcs crawl on it afterwards because the spot is still charged.
    for mat, bursts, snd, dmg in [
            ("", "arcs_electric, energy_sparks_rail, melt_embers, melt_smoke_rise", "rsb/impact/electric",
             "pit, 8.0, 0.35, 0.4, 0.9"),
            (".metal", "arcs_electric, spark_metal, melt_slag_splash, melt_embers", "rsb/impact/metal",
             "pit, 7.0, 0.4, 0.45, 1.0"),
            (".wood", "arcs_electric, melt_smoke_rise, splinter_wood", "rsb/impact/wood",
             "scorch, 9.0, 0.3, 0.55, 0.8"),
            (".dirt", "clods_dirt, dust_dirt, melt_smoke_rise", "none", "scorch, 10.0, 0.35, 0.3, 0.5"),
            (".glass", "glint_glass, arc_electric_one", "rsb/glass", "crack, 10.0, 0.3, 0.1, 0.3"),
            (".liquid", "splash_liquid, arcs_electric", "none", None),
            (".tech", "arcs_electric, arc_electric_one, bits_wire, bits_board", "rsb/impact/metal",
             "pit, 9.0, 0.35, 0.5, 1.0")]:
        out += ["impact cl_particlegun%s" % mat,
                "  bursts    = %s" % bursts,
                "  sound     = %s" % snd,
                "  light     = 120, 2.4, 3",
                "  lightcolor = 216, 198, 255"]
        if dmg:
            out += ["  damage    = %s" % dmg]
        out += ["end", ""]

    out.append(END)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--table", action="store_true")
    ap.add_argument("--wiring", action="store_true")
    args = ap.parse_args()
    if args.table:
        print("%-16s %7s %7s %7s %7s  %s" % ("gun", "Vg", "ft-lb", "climb", "drift", "note"))
        for gid in GUNS:
            d = derive(gid)
            print("%-16s %7.2f %7.1f %7.2f %7.2f  %s%s"
                  % (gid, d["vg"], d["energy"], d["climb"], d["drift"], d["action"],
                     "  (rate assumed)" if d["assumed"] else ""))
        for gid, v in ENERGY.items():
            print("%-16s %7s %7s %7.2f %7.2f  stated (no cartridge)" % (gid, "-", "-", v[0], v[1]))
        print("%-16s %7s %7s %7.2f %7.2f  stated (beam)" % ("cl_particlegun", "-", "-", 0.55, 0.30))
        return
    if args.wiring:
        for gun, fl, rc, ej, rd in [
                ("AE_M37A2", "ae_m37a2", "ae_m37a2", "hull_12ga", "buckshot"),
                ("AE_M4A3", "ae_m4a3", "ae_m4a3", "brass_9mm", "pistol_9mm"),
                ("AE_Flamer", "(none -- the flame owns the light)", "ae_flamer", "", ""),
                ("CL_KS23", "cl_ks23", "cl_ks23", "hull_12ga", "buckshot"),
                ("CL_Jackhammer", "cl_jackhammer", "cl_jackhammer", "hull_12ga", "buckshot"),
                ("CL_Sidewinder", "cl_sidewinder", "cl_sidewinder", "brass_556", "rifle_556"),
                ("CL_PlasmaGun", "cl_plasmagun", "cl_plasmagun", "", ""),
                ("CL_ParticleGun", "cl_particlegun", "cl_particlegun", "", "")]:
            print('  gun "%s"' % gun)
            print('    flashprofile   = "%s"' % fl)
            print('    recoilprofile  = "%s"' % rc)
            if ej: print('    ejectaprofile  = "%s"' % ej)
            if rd: print('    roundprofile   = "%s"' % rd)
            if gun == "CL_ParticleGun":
                print('    REMOVE shotclass RSB_PlasmaBall -- it is a beam; lay trail "cl_particlegun"')
            print()
        return
    body = blocks()
    check_sounds(body)
    text = io.open(DEFS, encoding="utf-8", newline="").read()
    nl = "\r\n" if "\r\n" in text else "\n"
    block = nl.join(body)
    if BEGIN in text and END in text:
        a, b = text.index(BEGIN), text.index(END) + len(END)
        out = text[:a] + block + text[b:]
    else:
        out = text.rstrip("\r\n") + nl + nl + block + nl
    io.open(DEFS, "w", encoding="utf-8", newline="").write(out)
    n = len([l for l in blocks() if l.startswith(("flash ", "recoil ", "flame ", "trail "))])
    print("%d profiles across the two new sets" % n)


# IMPORTING A GENERATOR MUST NOT RUN IT. Bare `main()` here meant that reading this file's
# tables -- or borrowing one function from it -- REWROTE RSBDEFS.txt as a side effect. It
# silently reverted eleven round looks mid-edit once, and ran a second time when another
# generator imported this one for its extreme transformer.
if __name__ == "__main__":
    main()
