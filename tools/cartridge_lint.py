#!/usr/bin/env python3
"""
cartridge_lint.py -- does every gun that asks for a round's weight actually get one?

WHY THIS EXISTS, and it is a defect I shipped rather than one I anticipated.

`roundmass` was written into eleven WW2 cartridges by a one-off script. Those blocks are OWNED by
gen_ww2_profiles.py, and a generator owns its blocks: every re-run since silently deleted the line
again. Ten of eighteen gone, four commits back.

NOTHING NOTICED. The profile still parsed. The boot still went green. `check_set_coverage.py` still
read every gun as tuned. `boot_verify.ps1` reported nothing refused -- because nothing WAS refused: a
missing OPTIONAL key is indistinguishable from a key nobody wanted. The only thing that noticed was a
gun firing in a live level with a log line I nearly did not write.

So the chain is checked here instead, in both directions:

  FORWARD   a recoil profile naming `cartridge = X` must resolve to a ballistics profile X that
            exists AND states roundmass. Without it the live-weight kick silently does nothing and
            the gun keeps its written climb for ever, looking exactly like a gun that works.
  BACKWARD  a cartridge that tools/cartridges.py holds a round mass for must CARRY it in RSBDEFS.
            This is the direction that actually broke: the data existed, the generator dropped it,
            and every forward check still passed because no gun was pointing at it yet.

    python tools/cartridge_lint.py [<dir>]

Exit 1 on either. Run by build.ps1.
"""
import io, os, re, sys

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from cartridges import LOAD, NO_CARTRIDGE

defs = io.open(os.path.join(ROOT, "RSBDEFS.txt"), encoding="utf-8", errors="replace", newline="").read()

# kind name -> {key: value}, last one wins exactly as the engine's registry does
blocks, cur = {}, None
for line in defs.split("\n"):
    s = line.split("#")[0].rstrip()
    m = re.match(r"^([a-z]+)\s+(\S+)\s*$", s)
    if m and "=" not in s:
        cur = (m.group(1).lower(), m.group(2).lower())
        blocks[cur] = {}
        continue
    if s.strip() == "end":
        cur = None
        continue
    if cur and "=" in s:
        k, v = s.split("=", 1)
        blocks[cur][k.strip().lower()] = v.strip()

bad = []

# ------------------------------------------------------------------ forward
asked = {}
for (kind, name), keys in blocks.items():
    if kind != "recoil":
        continue
    c = keys.get("cartridge", "")
    if not c or c.lower() == "none":
        continue
    asked[name] = c
    bl = blocks.get(("ballistics", c.lower()))
    if bl is None:
        bad.append("recoil %s names cartridge %s, and no such ballistics profile exists -- its live "
                   "weight silently does nothing" % (name, c))
    elif "roundmass" not in bl:
        bad.append("recoil %s names cartridge %s, which states no roundmass -- the gun cannot know "
                   "what its ammunition weighs, so its kick never follows the magazine" % (name, c))

# ------------------------------------------------------------------ backward
for prof in sorted(LOAD):
    bl = blocks.get(("ballistics", prof.lower()))
    if bl is None:
        # A cartridge the table describes and RSBDEFS does not define is a different lint's business
        # (it may simply not ship yet); say it, do not fail on it.
        print("  note: cartridges.py holds %s, which RSBDEFS does not define" % prof)
        continue
    if "roundmass" not in bl:
        bad.append("ballistics %s is missing its roundmass -- cartridges.py holds %d grains for it, so "
                   "the value exists and the block lost it (a generator that owns this block and does "
                   "not emit the line DELETES it every run)" % (prof, LOAD[prof][3]))

print("%d recoil profiles name a cartridge; %d cartridges carry a round mass (%d in the table)"
      % (len(asked), sum(1 for k, v in blocks.items() if k[0] == "ballistics" and "roundmass" in v), len(LOAD)))
for prof in sorted(NO_CARTRIDGE):
    if ("ballistics", prof) in blocks and "roundmass" in blocks[("ballistics", prof)]:
        bad.append("ballistics %s states a roundmass, but cartridges.py lists it as having no "
                   "cartridge on purpose: %s" % (prof, NO_CARTRIDGE[prof]))

if bad:
    print("\n%d DEFECT(S):" % len(bad))
    for b in bad:
        print("  %s" % b)
    sys.exit(1)
print("every gun that asks what its ammunition weighs gets an answer.")
