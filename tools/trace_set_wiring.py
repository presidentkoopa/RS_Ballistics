#!/usr/bin/env python3
"""
trace_set_wiring.py -- follow a weapon set gun by gun, all the way through to the sounds.

WHY THIS EXISTS AND WHY IT IS NOT check_set_coverage.py. That tool asks "does every gun NAME a
profile, and does that name resolve" -- one hop. This one walks the whole chain and checks the leaves:

    gun -> flash          -> its gunshot TAIL is a declared sound
        -> ejecta         -> its casing SOUND is declared
        -> round -> roundlook -> the WHIZ sound is declared
                              -> the impact family exists across every material
                                 -> each material's own SOUND is declared

The difference matters. A gun can name a flash that exists, whose `tail` names a sound that does not,
and every one-hop check in the project passes while the gun is silent. That is exactly how the Tesla
shipped naming `rsb/tail/rail` with no such sound -- caught, but only because the sound check happened
to be global. Per set, per gun, to the leaf, is the check that does not depend on luck.

READS THE INSTALLED PK3, not the source tree, for the same reason everything else here does: "it is in
RSBDEFS" and "it is in the pack he is running" are different statements.

Understands the two conventions that trip every naive sound check: SNDINFO's `$random` groups define
most names, and a flash's `tail` names a PREFIX -- RSB_Tail plays <name>/int under a ceiling and
<name>/ext under open sky, so the bare name is never itself a sound.

    python tools/trace_set_wiring.py                      # the two WW2 sets
    python tools/trace_set_wiring.py <WMSHEET> [...]      # any sheets you like

Exit code 1 if anything in any chain does not resolve.
"""
import io, os, re, sys, zipfile

PKG = "E:/DOOMWork/RS_Ballistics"
with zipfile.ZipFile(os.path.join(PKG, "RS_Ballistics.pk3")) as z:
    DEFS = z.read("RSBDEFS.txt").decode("utf-8", "replace")
    SND = z.read("SNDINFO.txt").decode("utf-8", "replace")

# ---- every profile block, by "kind name" -> {key: value-string}
blocks, cur, key = {}, None, None
for line in DEFS.splitlines():
    s = line.split("#")[0].rstrip()
    m = re.match(r"^([a-z]+)\s+(\S+)", s)
    if m and "=" not in s:
        cur = (m.group(1).lower(), m.group(2).lower()); blocks[cur] = {}; continue
    if s.strip() == "end":
        cur = None; continue
    if cur and "=" in s:
        k, v = s.split("=", 1)
        blocks[cur][k.strip().lower()] = v.strip()

def get(kind, name, k=None):
    if not name: return None
    b = blocks.get((kind, name.lower()))
    if b is None: return None
    return b if k is None else b.get(k)

# ---- declared sounds, including $random groups and the tail's /int /ext convention
declared = set()
for line in SND.splitlines():
    s = line.split("//")[0].strip()
    if not s: continue
    for kw in ("$random", "$alias", "$playersound", "$limit", "$pitchset", "$volume"):
        if s.lower().startswith(kw): s = s[len(kw):].strip(); break
    m = re.match(r"^([A-Za-z0-9_/\-]+)", s)
    if m: declared.add(m.group(1).lower())

def sound_ok(name, prefix=False):
    n = name.lower()
    if n in ("none", ""): return True
    if n in declared: return True
    if prefix and ((n + "/int") in declared or (n + "/ext") in declared): return True
    return False

MATS = ["", ".metal", ".wood", ".dirt", ".glass", ".liquid", ".brick", ".marble", ".tile",
        ".tech", ".pipe", ".screen", ".light", ".lava", ".slime", ".flesh"]

bad, checked = [], 0
SHEETS = sys.argv[1:] or ["WMSHEET.ww2", "WMSHEET.rtcw"]
for sheet in SHEETS:
    path = sheet if os.path.sep in sheet or "/" in sheet else os.path.join(
        os.path.dirname(PKG), "RS_VR_Weapons", sheet)
    cur_gun, guns = None, {}
    for ln in io.open(path, encoding="utf-8", errors="replace"):
        s = ln.split("#")[0].strip()
        g = re.match(r'^gun\s+"([^"]+)"', s)
        if g: cur_gun = g.group(1); guns.setdefault(cur_gun, {}); continue
        k = re.match(r'^(flash|recoil|ejecta|round)profile\s*=\s*"?([^"\s]+)"?', s)
        if k and cur_gun: guns[cur_gun][k.group(1)] = k.group(2)
    print("\n=== %s ===" % sheet)
    for gun in sorted(guns):
        named = guns[gun]
        if not named:
            print("  %-20s (melee/thrown: names nothing, needs nothing)" % gun); continue
        notes, prob = [], []
        # LOOKS
        for kind in ("flash", "recoil", "ejecta", "round"):
            n = named.get(kind)
            if not n: continue
            checked += 1
            if get(kind, n) is None: prob.append("%s '%s' MISSING" % (kind, n))
        # SOUND: the flash's gunshot tail (a PREFIX -- /int and /ext)
        fl = named.get("flash")
        if fl:
            t = get("flash", fl, "tail")
            if t:
                nm = t.split(",")[0].strip(); checked += 1
                if not sound_ok(nm, prefix=True): prob.append("tail '%s' NOT DECLARED" % nm)
                else: notes.append("tail")
        # SOUND: the ejecta's casing
        ej = named.get("ejecta")
        if ej:
            sd = get("ejecta", ej, "sound")
            if sd:
                checked += 1
                if not sound_ok(sd.strip()): prob.append("ejecta sound '%s' NOT DECLARED" % sd)
                else: notes.append("brass")
        # THE ROUND -> roundlook -> whiz + impact family (every material)
        rd = named.get("round")
        if rd:
            look = get("round", rd, "roundlook")
            if look:
                lk = get("roundlook", look)
                if lk is None: prob.append("roundlook '%s' MISSING" % look)
                else:
                    wz = lk.get("whiz")
                    if wz:
                        nm = wz.split(",")[-1].strip(); checked += 1
                        if not sound_ok(nm): prob.append("whiz '%s' NOT DECLARED" % nm)
                        else: notes.append("whiz")
                    base = lk.get("impact")
                    if base and base.lower() != "none":
                        found = 0
                        for mat in MATS:
                            b = get("impact", base + mat)
                            if b is None: continue
                            found += 1
                            sd = b.get("sound")
                            if sd:
                                checked += 1
                                if not sound_ok(sd.strip()):
                                    prob.append("impact%s sound '%s' NOT DECLARED" % (mat, sd))
                        if found == 0: prob.append("impact family '%s' MISSING" % base)
                        else: notes.append("%d impacts" % found)
        print("  %-20s %-34s %s" % (gun, ", ".join(notes), "OK" if not prob else "  <-- " + "; ".join(prob)))
        bad += prob

print("\n%d references traced through looks AND sounds." % checked)
print("RESULT: %s" % ("EVERY ONE RESOLVES" if not bad else "%d PROBLEMS" % len(bad)))
sys.exit(1 if bad else 0)
