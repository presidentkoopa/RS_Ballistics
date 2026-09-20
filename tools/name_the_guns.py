#!/usr/bin/env python3
"""
name_the_guns.py -- every gun that should name a profile and does not, with the line to add.

THE OWNER: "you don't need any of that shit to assign unique profiles to each fuckin gun." Correct.
Most of what the coverage checker calls "on the house recipe" is NOT a missing profile at all -- it is
a gun failing to NAME one that has existed for weeks. WM_Chainsaw names `flash chainsaw` and no
recoil, while `recoil chainsaw` sits in RSBDEFS unused.

So this sorts the two apart and prints the sheet lines:

  NAME IT        a profile of exactly the right name already exists. One line on the sheet.
  MIRROR IT      an off-hand twin (BW_*_Off) should name what its main-hand twin names. It is the
                 same gun in the other hand, so sharing is correct, not borrowing.
  I OWE ONE      nothing suitable exists and the ballistics lane has to write it.

    python tools/name_the_guns.py
"""
import io, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
SHEETS = "E:/DOOMWork/RS_VR_Weapons"

defs = io.open(os.path.join(PKG, "RSBDEFS.txt"), encoding="utf-8", errors="replace").read()
have = {}
# [ 	]+ AND NOT \s+: \s matches a NEWLINE, so `end` followed by `recoil x` matched as one
# header and ate the real one. Six of ninety recoil profiles survived that, and the tool then
# reported eighty-four guns as needing profiles I had already written.
for m in re.finditer(r"(?m)^([a-z]+)[ 	]+(\S+)", defs):
    kind, name = m.group(1).lower(), m.group(2).lower()
    if "=" in m.group(0):
        continue
    have.setdefault(kind, set()).add(name)

# gun -> {key: value}, per sheet
guns, order = {}, []
for f in sorted(os.listdir(SHEETS)):
    if not f.startswith("WMSHEET."):
        continue
    cur = None
    for ln in io.open(os.path.join(SHEETS, f), encoding="utf-8", errors="replace"):
        s = ln.split("#")[0].strip()
        g = re.match(r'^gun\s+"([^"]+)"', s)
        if g:
            cur = g.group(1)
            guns[cur] = {"_sheet": f[8:]}
            order.append(cur)
            continue
        sl = re.match(r'^slot\s*=\s*(\d+)', s)
        if sl and cur: guns[cur]["_slot"] = sl.group(1)
        if cur and re.search(r'(?i)chainsaw', cur): guns[cur]["_saw"] = True
        k = re.match(r'^(flash|recoil|ejecta|round)profile\s*=\s*"?([^"\s]+)"?', s)
        if k and cur:
            guns[cur][k.group(1)] = k.group(2)


# THE LAST FEW, ANSWERED BY HAND BECAUSE THEY NEEDED A JUDGEMENT AND NOT A LOOKUP.
#
# A FLAMETHROWER HAS NO MUZZLE FLASH ON PURPOSE -- the flame owns the light, which is the wiring
# every flamer in the package already uses. That is a `none` and not a gap.
# A CHAINSAW IS SLOT 1 AND STILL KICKS: it vibrates the whole time it runs, and `chainsaw` exists.
ANSWERS = {
    "WM_Flamer":       [("flash", "none"), ("recoil", "flamer")],
    "WM_Flamethrower": [("flash", "none"), ("recoil", "flamer_heavy")],
    "BW_Flamethrower": [("flash", "none")],
    "AE_Flamer":       [("flash", "none")],
    "BL_SprayCan":     [("flash", "none")],
    "BM_SprayCan":     [("flash", "none"), ("recoil", "none")],
    "RC_Chainsaw":     [("flash", "chainsaw"), ("recoil", "chainsaw")],
}

KINDS = ("flash", "recoil", "ejecta", "round")
name_it, mirror_it, owe, say_none = [], [], [], []

for g in order:
    d = guns[g]
    sheet = d["_sheet"]
    # OFF-HAND TWINS: the same gun in the other hand. BW_Kar98_Off should say what BW_Kar98 says.
    if g.endswith("_Off") and g[:-4] in guns:
        twin = guns[g[:-4]]
        miss = [(k, twin[k]) for k in KINDS if k in twin and k not in d]
        if miss:
            mirror_it.append((g, g[:-4], miss))
        continue
    for k in KINDS:
        if k in d:
            continue
        # THE COMMONEST CASE BY FAR: it names a flash, and a profile of that exact name exists for
        # the kind it is missing. Nothing to write -- one line to say.
        src = d.get("flash") or d.get("round")
        if src and src.lower() in have.get(k, set()):
            name_it.append((g, sheet, k, src))
        elif g in ANSWERS and k in [a for a, _ in ANSWERS[g]]:
            name_it.append((g, sheet, k, dict(ANSWERS[g])[k]))
        elif k in ("flash", "recoil"):
            # A KNIFE HAS NO MUZZLE FLASH, AND SAYING SO IS THE ANSWER -- not inventing one.
            #
            # Slot 1 is melee and slot 9 is thrown: neither has a muzzle, so `none` is CORRECT rather
            # than a gap. It has to be STATED, because a gun naming no profile falls back to the house
            # recipe -- a real flash and a real kick on a pitchfork. That is the whole absence rule,
            # and these are the guns it was written for.
            if d.get("_slot") in ("1", "9") and not d.get("_saw"):
                say_none.append((g, sheet, k))
            else:
                owe.append((g, sheet, k))

print("NAME IT -- the profile already exists, the gun just never said so:\n")
last = None
for g, sheet, k, src in name_it:
    if g != last:
        print('gun "%s"   (%s)' % (g, sheet))
        last = g
    print('  %-20s = "%s"' % (k + "profile", src))

print("\n\nMIRROR IT -- an off-hand twin should name what its main hand names:\n")
for g, twin, miss in mirror_it:
    print('gun "%s"   -- the same gun as %s, other hand' % (g, twin))
    for k, v in miss:
        print('  %-20s = "%s"' % (k + "profile", v))

print("\n\nI OWE ONE -- nothing suitable exists; the ballistics lane writes it:\n")
for g, sheet, k in owe:
    print("  %-22s %-14s needs its own %s" % (g, sheet, k))
print("\n%d lines to add, %d off-hand twins to mirror, %d profiles for me to write."
      % (len(name_it), len(mirror_it), len(owe)))
