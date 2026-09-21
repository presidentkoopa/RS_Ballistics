#!/usr/bin/env python3
"""
model_lint.py -- can every round that names a model actually draw one?

WHY THIS EXISTS. A round look can say `look = model, RSBMD` and be COMPLETELY CORRECT as far as every
other tool in this package is concerned -- the parser accepts it, the profile count goes up by one, the
compile check passes, the boot test goes green -- and the round still flies invisible. Four separate
ways, none of which says anything:

  1. NO MODELDEF BLOCK names that frame. MODELDEF is a different lump with no link back to RSBDEFS;
     nothing checks that a look's frame is one somebody bound a model to.
  2. NO SPRITE LUMP for that frame. A model hangs on a sprite frame -- the renderer indexes the
     sprite by it -- so frame D with no RSBMD0 lump has nothing to hang on.
  3. THE BLOCK IS ONLY ON THE PARENT CLASS. MODELDEF binds a model to ONE class and not to its
     children (FindModelFrameRaw matches smff->type == ti exactly, src/r_data/models.cpp ~4128), so
     RSB_EnemyBullet draws NOTHING off RSB_Bullet's blocks. Every monster's round, silently dark.
  4. THE MESH FILE IS NOT IN THE PACK. MODELDEF names a path; nothing packs it for naming it.

Every one of those is the same shape this project keeps paying for: a thing that is missing looks
exactly like a thing that is fine. So it is checked here, before the pack exists, and the build
refuses rather than shipping a round nobody can see.

    python tools/model_lint.py            # the source tree next to this file
    python tools/model_lint.py <dir>

Exit code 1 on any defect. Run by build.ps1 before packing.
"""
import io, os, re, sys

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), ".."))

# THE CLASSES A ROUND CAN BE. Both fly a roundlook, so both need every frame the looks name.
# RSB_EnemyBullet is here because it is a SUBCLASS and MODELDEF does not follow inheritance -- that is
# the whole point of naming it rather than checking RSB_Bullet alone.
ROUND_CLASSES = ["RSB_Bullet", "RSB_EnemyBullet"]


def read(p):
    return io.open(os.path.join(ROOT, p), encoding="utf-8", errors="replace", newline="").read()


# ---------------------------------------------------------------- what the looks ask for
# name -> (sprite, frame letter), for every roundlook that names a model.
asked = {}
cur = None
for ln in read("RSBDEFS.txt").split("\n"):
    s = ln.split("#")[0].rstrip()
    m = re.match(r"^roundlook\s+(\S+)", s)
    if m:
        cur = m.group(1)
        continue
    if re.match(r"^\s*(end|[a-z]+\s+\S+)\s*$", s) and "=" not in s and not m:
        if s.strip() == "end":
            cur = None
        continue
    m = re.match(r"^\s*look\s*=\s*model\s*,\s*(\S+)\s*$", s)
    if m and cur:
        asked[cur] = m.group(1).upper()

# ---------------------------------------------------------------- what MODELDEF provides
# class -> {"SPRT" + frame letter: model path it draws}
provided = {}
meshes = set()
# AND THE SKINS. A model whose texture is missing still draws -- untextured -- and says nothing.
# The Star Wars bolts are thirteen frames riding four GENERATED skins, so a skin that failed to
# write is a whole colour of bolt gone grey, and the mesh check alone would pass it.
skins = set()
block_class, block_path, block_models = None, None, {}
for ln in read("MODELDEF.txt").split("\n"):
    s = re.sub(r"//.*", "", ln).strip()
    # A BLOCK STARTS with `Model <class>` and NOTHING ELSE on the line. The anchored end matters:
    # `Model 0 "btracer.obj"` INSIDE a block also begins with Model and a token, and reading it as a
    # new block threw away every FrameIndex in this file -- which this lint then reported as 96
    # missing bindings for models that were bound perfectly well.
    m = re.match(r"^Model\s+([A-Za-z_]\S*)\s*$", s, re.I)
    if m:
        block_class, block_path, block_models = m.group(1), None, {}
        continue
    if s == "}":
        block_class = None
        continue
    if not block_class:
        continue
    m = re.match(r'^Path\s+"([^"]+)"', s, re.I)
    if m:
        block_path = m.group(1)
        continue
    m = re.match(r'^(?:Surface)?Skin\s+\d+(?:\s+\d+)?\s+"([^"]+)"', s, re.I)
    if m:
        skins.add(("%s/%s" % (block_path, m.group(1))) if block_path else m.group(1))
        continue
    m = re.match(r'^Model\s+(\d+)\s+"([^"]+)"', s, re.I)
    if m:
        block_models[int(m.group(1))] = m.group(2)
        continue
    m = re.match(r"^FrameIndex\s+(\S{4})\s+(\S)\s+(\d+)\s+(\d+)", s, re.I)
    if m:
        key = (m.group(1) + m.group(2)).upper()
        mesh = block_models.get(int(m.group(3)), "")
        full = ("%s/%s" % (block_path, mesh)) if block_path else mesh
        provided.setdefault(block_class, {})[key] = full
        if full:
            meshes.add(full)

# ---------------------------------------------------------------- the checks
bad = []
for look in sorted(asked):
    want = asked[look]
    if len(want) != 5:
        bad.append("roundlook %s: look = model, %s is not four letters and a frame letter" % (look, want))
        continue
    sprite_lump = os.path.join(ROOT, "sprites", want + "0.png")
    if not os.path.exists(sprite_lump):
        bad.append("roundlook %s names frame %s, and sprites/%s0.png does not exist -- "
                   "a model has no sprite frame to hang on and the round flies invisible" % (look, want, want))
    for cls in ROUND_CLASSES:
        if want not in provided.get(cls, {}):
            bad.append("roundlook %s names frame %s, and no `Model %s` block binds it -- "
                       "%s draws nothing for this round" % (look, want, cls, cls))

# every mesh a block names has to be IN THE TREE, or the block is a promise nothing keeps
for mesh in sorted(meshes):
    if not os.path.exists(os.path.join(ROOT, mesh)):
        bad.append("MODELDEF names %s, which is not in the package" % mesh)
for skin in sorted(skins):
    if not os.path.exists(os.path.join(ROOT, skin)):
        bad.append("MODELDEF skins a model with %s, which is not in the package -- it would draw untextured" % skin)

# and a frame bound to a model that no look ever asks for is dead weight, worth saying but not failing
unused = sorted(set(k for c in ROUND_CLASSES for k in provided.get(c, {})) - set(asked.values()))

print("%d round looks name a model, across %d frames; %d classes carry them"
      % (len(asked), len(set(asked.values())), len(ROUND_CLASSES)))
for frame in sorted(set(asked.values())):
    who = sorted(k for k, v in asked.items() if v == frame)
    mesh = provided.get(ROUND_CLASSES[0], {}).get(frame, "?")
    print("  %-6s %-28s %d look(s)%s" % (frame, mesh, len(who), "" if len(who) > 1 else ": " + who[0]))
if unused:
    print("  (bound but never asked for: %s)" % ", ".join(unused))

if bad:
    print("\n%d DEFECT(S):" % len(bad))
    for b in bad:
        print("  %s" % b)
    sys.exit(1)
print("every round that names a model has a frame, a sprite to hang it on, a block on every round "
      "class, and a mesh in the tree.")
