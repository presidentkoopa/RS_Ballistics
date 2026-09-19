#!/usr/bin/env python3
"""
check_set_coverage.py -- does every gun in a weapon set actually have ballistics?

WHY THIS EXISTS. The RealRTCW set shipped and installed with SEVENTEEN GUNS carrying ZERO ballistics
profiles -- no flash, no recoil, no ejecta, no round -- and it reached the owner's New Game screen
firing with nothing on it. Nobody noticed because nothing fails: a gun with no flashprofile does not
error, it is just silent and dark, and a gun with a flashprofile naming a profile that does not exist
logs one line into a four-thousand-line boot log.

Both failures are invisible in play unless you are looking straight at the gun in a dark room. So they
have to be caught here instead, by reading the sheets and the definitions and comparing them.

    python tools/check_set_coverage.py                  # every WMSHEET.* next to RS_VR_Weapons
    python tools/check_set_coverage.py <sheet> [...]    # only these

Exit code 1 if any gun is missing a profile or names one that does not exist.

STATED IS NOT COVERED, AND THIS TOOL GOT THAT WRONG FIRST TIME. It counted guns that name no profile
as having no ballistics, and reported nine guns in plus_extras that way. The owner read it and said
"i routinely shoot those guns with ballistics" -- and they were right.

RS_Ballistics APPLIES UNIVERSALLY. RS_VR_Reload falls back to the literal profile name "default" when a
sheet states none (weapon.zs:394-397), and `flash default`, `ejecta default` and `round default` all
exist. So an unstated gun still fires with a flash, brass and a round look. A named profile is an
OVERRIDE, not the source. A COUNT OF MISSING KEYS IS NOT A COUNT OF MISSING BALLISTICS.

So this reports three states, and only the last is a defect:

  TUNED    the sheet names its own profile, and that profile is real
  GENERIC  the sheet names none, and the kind has a `default` -- the gun fires, on the house recipe
  NONE     the sheet names none and the kind has NO `default`, so nothing happens at all

RECOIL IS `NONE` TODAY and is the reason this distinction had to exist: there is no
RecoilProfileOrDefault and no `recoil default` profile, so a gun that states no recoilprofile gets
RSB_Recoil.Step returning 0, 0, 0 -- "dead on, and the kick is forgotten". Nine guns are in that state
right now. That is not untuned, it is absent.

It also means this tool now catches a class it would have missed entirely: a KIND with no `default` at
all. Add one tomorrow and every unstated gun silently gets nothing, and the old version called that
covered.

Exemptions are a NAMED list below rather than a rule inferred from the data, so a gun that quietly
loses its profiles cannot hide behind one.
"""
import io
import os
import re
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
DEFS = os.path.join(PKG, "RSBDEFS.txt")
SHEETS = os.path.join(os.path.dirname(PKG), "RS_VR_Weapons")

# WHAT A GUN IS EXEMPT FROM, AND WHY. Every exemption is a named list rather than a rule inferred from
# the data, so a gun that quietly loses its profiles cannot hide behind one.
#
# Nothing fires, so there is nothing to look like.
NO_BALLISTICS = re.compile(r"(knife|axe|grenade|melee|bayonet|kick|fist|shield|saw|chainsaw)", re.I)
EXEMPT = {
    # Ejects nothing WHILE FIRING: a revolver holds its brass in the cylinder, a break action holds
    # its until you open it, and an energy weapon or a launcher has no case at all.
    "ejecta": re.compile(r"(revolver|drilling|m30|flame|tesla|leichenfaust|panzer|nebelwerfer|faust|"
                         r"schreck|plasma|bfg|rail|laser|rocket|rpg|launcher|unmaker|moonlight)", re.I),
    # Fires its own projectile actor rather than a round this package describes, so `roundprofile`
    # would have nothing to say. This is the same boundary `damage = none` polices from the other side.
    "round": re.compile(r"(flame|tesla|leichenfaust|panzer|nebelwerfer|faust|schreck|plasma|bfg|rail|"
                        r"rocket|rpg|launcher|unmaker)", re.I),
    # A flamethrower's `flame` profile already owns its light; a flash on top would double it.
    "flash": re.compile(r"(flame)", re.I),
    # NOTHING IS EXEMPT FROM `recoil`. Even a flamethrower and a plasma rifle shove, and a gun that
    # states no recoil profile is a gun that does not move in your hands, which in VR is the single
    # most obvious way for a weapon to feel fake.
}

KINDS = ("flash", "recoil", "ejecta", "round")

# A `default` THAT EXISTS IS NOT THE SAME AS A `default` THAT IS REACHED, and this tool would have
# started lying the moment `recoil default` was written.
#
# GENERIC means "states none, and the house recipe catches it". For flash, ejecta and round that is
# true automatically: RS_VR_Reload resolves an unstated name to the literal "default". For RECOIL it is
# not -- the weapon passes recoilProfileName straight through, and the fallback added in
# RSB_Recoil.Profile sits behind sv_rsb_recoil_default, which is OFF because turning it on changes how
# seventeen of the owner's guns handle.
#
# So a recoil profile existing at "default" must NOT quietly move those seventeen from NONE to GENERIC.
# They still have no kick. Remove a kind from here only when its default is genuinely reached by
# default -- and then this tool starts passing them on its own, which is the correct signal that the
# work actually landed.
# EMPTY, AND THAT IS THE POINT: `recoil` was in here while its fallback was gated off, and came out
# when the gate opened. The mechanism stays because the NEXT kind added without a house recipe needs
# it, and because a kind coming off this list is the honest signal that the work actually landed --
# the guns start passing on their own rather than because someone decided they should.
UNREACHED_DEFAULTS = {}


# THE FILE THE GAME LOADS IS THE PK3, NOT THE SOURCE TREE, AND THEY ARE NOT THE SAME STATEMENT.
#
# This cost the owner a working feature. The weapons lane wired five `deflect` profiles by name, their
# lint checked those names against RSBDEFS.txt IN MY SOURCE TREE and went green, and the profiles were
# real -- but they had not been PACKED. He hit a shield with plasma and nothing happened, because the
# pk3 in his load order did not contain them. A reference with no definition, one level up from the 68
# dead rtcw_ names: not a name with nothing behind it, but a name whose definition exists everywhere
# except the file being run.
#
# So this tool reads the INSTALLED pk3 by default and only falls back to the source tree when there is
# no pk3 to read -- saying loudly which one it used, because "it is in RSBDEFS" and "it is in the pack
# he is running" are different claims and only the second one matters.
def read_defs():
    """RSBDEFS as the GAME sees it: out of the installed pk3, falling back to source with a warning."""
    pk3 = os.path.join(PKG, "RS_Ballistics.pk3")
    src = io.open(DEFS, encoding="utf-8", errors="replace").read()
    if not os.path.exists(pk3):
        print("RSBDEFS: from the SOURCE TREE -- no packed pk3 to read, so this proves nothing about what the game loads")
        return src, None
    with zipfile.ZipFile(pk3) as z:
        packed = z.read("RSBDEFS.txt").decode("utf-8", "replace")
    if packed.replace("\r\n", "\n") != src.replace("\r\n", "\n"):
        print("RSBDEFS: from the INSTALLED pk3 -- WHICH DIFFERS FROM THE SOURCE TREE.")
        print("         Something is built and not packed, or packed and not committed. The pk3 wins here,")
        print("         because it is what the game loads -- run build.ps1 if the source is the newer one.")
    else:
        print("RSBDEFS: from the INSTALLED pk3 (identical to the source tree)")
    return packed, pk3


def declared_sounds(path):
    """Every sound name SNDINFO defines: plain rows, and the $random / $alias / $playersound groups.

    THE GROUPS ARE THE POINT. Most of this package's sounds are defined as `$random rsb/impact/concrete
    { ... }` -- eleven takes behind one name -- and a check that only reads plain rows reports 26 of 28
    names as missing. That is the standard's "a check that cries wolf is worse than no check", and it
    happened here on the first attempt.
    """
    have = set()
    for line in io.open(path, encoding="utf-8", errors="replace"):
        s = line.split("//")[0].strip()
        if not s:
            continue
        for kw in ("$random", "$alias", "$playersound", "$limit", "$pitchset", "$volume"):
            if s.lower().startswith(kw):
                s = s[len(kw):].strip()
                break
        m = re.match(r"^([A-Za-z0-9_/\-]+)", s)
        if m:
            have.add(m.group(1).lower())
    return have


# WHAT A SOUND KEY NAMES. Most name a sound outright. `tail` names a PREFIX: RSB_Tail plays
# <name>/int under a ceiling and <name>/ext under open sky, so `rsb/tail/ar` is never itself a sound
# and looking for it finds nothing. A checker that does not know this reports ten false positives --
# which it did, on the second attempt, and cost another pass.
SOUND_KEYS = ("sound", "tail", "whiz", "sounds", "glance", "sputter")
PREFIX_KEYS = ("tail",)


def check_sounds(defs_text, sndinfo_path):
    """Every sound a profile names, against what SNDINFO actually declares."""
    have = declared_sounds(sndinfo_path)
    bad = []
    used = 0
    where = "?"
    for n, line in enumerate(defs_text.splitlines(), 1):
        s = line.split("#")[0].strip()
        if "=" not in s:
            m = re.match(r"^([a-z]+)\s+([^\s#]+)", s)
            if m:
                where = s
            continue
        key = s.split("=")[0].strip().lower()
        if key not in SOUND_KEYS:
            continue
        for tok in s.split("=", 1)[1].split(","):
            tok = tok.strip().lower()
            if not tok.startswith("rsb/"):
                continue
            used += 1
            ok = tok in have
            if not ok and key in PREFIX_KEYS:
                ok = (tok + "/int") in have or (tok + "/ext") in have
            if not ok:
                bad.append("  RSBDEFS line %d (%s): %s = %s IS NOT DECLARED IN SNDINFO" % (n, where, key, tok))
    print("sounds: %d names used, %d declared in SNDINFO" % (used, len(have)))
    for b in bad:
        print(b)
    return 1 if bad else 0


def defined_profiles(text):
    """Every profile in RSBDEFS, by kind, base name only (variants resolve back to their base)."""
    have = {k: set() for k in ("flash", "recoil", "ejecta", "round", "ballistics", "roundlook",
                               "impact", "burst", "wake", "trail", "flame", "hotspot", "style", "fixture")}
    for line in text.splitlines():
        m = re.match(r"^([a-z]+)\s+([^\s#]+)", line)
        if not m:
            continue
        kind, name = m.group(1), m.group(2)
        if kind not in have:
            continue
        have[kind].add(name.split("~")[0].split("@")[0].split(".")[0].lower())
    return have


def guns_in(path):
    """gun name -> {kind: profile name}, read out of a WMSHEET."""
    out = {}
    cur = None
    for line in io.open(path, encoding="utf-8", errors="replace"):
        s = line.split("#")[0].strip()
        m = re.match(r'^gun\s+"([^"]+)"', s)
        if m:
            cur = m.group(1)
            out[cur] = {}
            continue
        if cur is None:
            continue
        m = re.match(r'^(flash|recoil|ejecta|round)profile\s*=\s*"?([^"\s]+)"?', s)
        if m:
            out[cur][m.group(1)] = m.group(2).lower()
    return out


def guns_in_zscript(root):
    """gun class -> {kind: profile name}, read out of ZScript class properties.

    A SHEET IS NOT THE ONLY WAY A GUN NAMES A PROFILE, and assuming it was made this tool blind to an
    entire set. RS_Modern (the Breach guns) declares them as class properties instead:

        WM_Gun.RoundProfile  "glock17";
        WM_Gun.FlashProfile  "glock17";

    That is a perfectly good way to do it and it is what a package with no sheet uses. A checker that
    only reads WMSHEETs reports such a set as not existing rather than as unchecked, which is the worse
    of the two failures -- it is absence rendering as plausible, the same disease it was built to catch.
    """
    out = {}
    cur = None
    for dirpath, _dirs, files in os.walk(root):
        for f in sorted(files):
            if not f.lower().endswith(".zs"):
                continue
            for line in io.open(os.path.join(dirpath, f), encoding="utf-8", errors="replace"):
                t = line.split("//")[0].strip()
                m = re.match(r"^class\s+([A-Za-z0-9_]+)", t)
                if m:
                    cur = m.group(1)
                    continue
                m = re.match(r'^WM_Gun\.(Round|Flash|Recoil|Ejecta)Profile\s+"([^"]+)"', t, re.I)
                if m and cur:
                    out.setdefault(cur, {})[m.group(1).lower()] = m.group(2).lower()
    return out


def check(sheet, have, guns=None, label=None):
    guns = guns_in(sheet) if guns is None else guns
    name = label or os.path.basename(sheet)
    if not guns:
        print("%s: NO GUNS FOUND -- is this a sheet?" % name)
        return 1
    bad = []
    tuned = generic = 0
    generic_guns = []
    for gun in sorted(guns):
        named = guns[gun]
        if NO_BALLISTICS.search(gun):
            continue
        want = [k for k in KINDS if not (k in EXEMPT and EXEMPT[k].search(gun))]
        # NONE is the only defect: the sheet says nothing AND the kind has no house recipe to fall
        # back on, so the gun fires with nothing at all.
        nothing = [k for k in want if k not in named
                   and ("default" not in have.get(k, ()) or k in UNREACHED_DEFAULTS)]
        # GENERIC is fine, and saying otherwise is what got this tool corrected by the owner.
        onhouse = [k for k in want if k not in named and "default" in have.get(k, ())]
        dangling = ["%s -> %s" % (k, v) for k, v in named.items() if v not in have.get(k, ())]
        if nothing:
            why = []
            for k in nothing:
                why.append("%sprofile (%s)" % (k, UNREACHED_DEFAULTS.get(k, "that kind has no `default` to fall back on")))
            bad.append("  %-22s NOTHING HAPPENS: states no %s" % (gun, "; ".join(why)))
        if dangling:
            bad.append("  %-22s NAMES A PROFILE THAT DOES NOT EXIST: %s" % (gun, "; ".join(dangling)))
        if nothing or dangling:
            continue
        if onhouse:
            generic += 1
            generic_guns.append("%s (%s)" % (gun, ", ".join(onhouse)))
        else:
            tuned += 1
    total = len([g for g in guns if not NO_BALLISTICS.search(g)])
    print("%s: %d tuned, %d on the house recipe, %d broken (%d melee or thrown, skipped)"
          % (name, tuned, generic, total - tuned - generic, len(guns) - total))
    for g in generic_guns:
        print("    generic: %s" % g)
    for b in bad:
        print(b)
    return 1 if bad else 0


def main():
    if not os.path.exists(DEFS):
        sys.exit("no RSBDEFS at %s" % DEFS)
    defs_text, _pk3 = read_defs()
    have = defined_profiles(defs_text)
    print("RSBDEFS: %d flash, %d recoil, %d ejecta, %d round"
          % (len(have["flash"]), len(have["recoil"]), len(have["ejecta"]), len(have["round"])))
    sheets = sys.argv[1:]
    if not sheets:
        if not os.path.isdir(SHEETS):
            sys.exit("no %s -- pass sheet paths instead" % SHEETS)
        sheets = [os.path.join(SHEETS, f) for f in sorted(os.listdir(SHEETS))
                  if f.upper().startswith("WMSHEET")]
    if not sheets:
        sys.exit("no WMSHEET files found")
    rc = check_sounds(defs_text, os.path.join(PKG, "SNDINFO.txt"))
    for s in sheets:
        rc |= check(s, have)
    # AND EVERY PACKAGE THAT DECLARES PROFILES IN ZSCRIPT INSTEAD OF A SHEET -- ALL OF THEM, NOT A LIST.
    #
    # THIS BLIND SPOT HAS NOW COST TWO LANES A DAY APART. First it hid RS_Modern from me entirely, and
    # I fixed that by naming RS_Modern. Then the weapons lane's own check hit the same wall from the
    # other side: THIRTY-TWO VANILLA GUNS name their profiles as `WM_Gun.FlashProfile "unmaker"` class
    # properties, their check read sheets, so a fully wired set read as a set that named nothing -- and
    # I built duplicate profiles on the strength of it.
    #
    # Naming one package was fixing the instance. Walking every sibling package is fixing the class,
    # and it is the same lesson as `unit()` and as reading the PACKED pk3: the second time a shape
    # appears, stop patching the case.
    parent = os.path.dirname(PKG)
    for pkg in sorted(os.listdir(parent)):
        if not pkg.startswith("RS_") or pkg.startswith("RS_Ballistics"):
            continue
        root = os.path.join(parent, pkg, "zscript")
        if not os.path.isdir(root):
            continue
        zguns = guns_in_zscript(root)
        if zguns:
            rc |= check(None, have, guns=zguns, label="%s (zscript)" % pkg)
    print("\nCOVERAGE %s" % ("INCOMPLETE -- see above" if rc else "COMPLETE"))
    sys.exit(rc)


main()
