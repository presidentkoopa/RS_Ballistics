#!/usr/bin/env python3
"""
gun_weights.py -- hand the weapons lane every gun weight this package is holding, with its provenance.

WHY THIS EXISTS. Every gun's kick is computed from four real figures, and one of them -- the gun's
weight -- lives in a Python table inside THIS package. That makes the ballistics lane a second source
of truth about somebody else's guns, held by the package least entitled to hold it. If the weapons
lane changes a gun, these numbers go stale silently and nothing anywhere says so.

So the weights go where the guns are (`baseweight` on the sheet), and this prints what to put there.

TWO THINGS THAT MAKE A NUMBER HERE NOT A DROP-IN VALUE:

1. THESE ARE LOADED WEIGHTS. Free recoil needs the loaded gun, and the difference is largest exactly
   where it is easiest to get wrong -- a full magazine is a fifth of a Glock. Using empty weights once
   put a Glock above an Ithaca 37 on climb. `baseweight` is specified as the EMPTY gun:

       baseweight = loaded_lb  -  capacity x round_lb

   Capacity is the WEAPONS LANE'S number, off their own sheets. This tool does not do the subtraction,
   because a figure computed from a capacity I guessed would arrive looking measured.

2. NOT EVERY WEIGHT MEANS THE SAME THING. Three bases, printed per gun:

       REAL       the gun IS that gun and this is its published loaded weight
       ANALOGUE   a Doom gun standing in for a named real one (the owner's instruction: "find
                  possible real world equivalents"). The WEIGHT is measured -- for the analogue.
                  Which analogue fits a Doom sprite is a JUDGEMENT, and it is the judgement, not
                  the weight, that anyone reviewing this should argue with.
       FICTION    a gun that only exists in its film or game; the figure is whatever that fiction
                  states, and where it states nothing it is marked ESTIMATE.

    python tools/gun_weights.py            # the table
    python tools/gun_weights.py --tsv      # tab separated, for pasting into a sheet

Nothing is imported: these generators RUN when imported (one of them rewrote RSBDEFS.txt and reverted
eleven round looks mid-edit), so the tables are read out of the source with ast and never executed.
"""
import ast, io, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))

# file, dict, index of: weight, bullet grains, fps, charge, note  (None = that table has none)
TABLES = [
    ("gen_ww2_profiles.py",     "RECOIL_DATA", 3, 0, 1, 2, None, "REAL",     "WW2 / Brutal Wolfenstein"),
    ("gen_recoil_real.py",      "GUNS",        3, 0, 1, 2, 5,    "ANALOGUE", "Vanilla + Modern"),
    ("gen_extras_profiles.py",  "GUNS",        4, 1, 2, 3, 9,    "ANALOGUE", "Vanilla+ extras"),
    ("gen_heavy_profiles.py",   "DERIVED",     3, 0, 1, 2, 5,    "ANALOGUE", "Vanilla heavy"),
    ("gen_newsets_profiles.py", "GUNS",        3, 0, 1, 2, 11,   "FICTION",  "Aliens / Cola"),
    ("gen_aliens_profiles.py",  "GUNS",        0, None, None, None, 5, "FICTION", "Aliens"),
]
ESTIMATE_WORDS = ("estimate", "assum", "guess", "fantasy", "invent")


def num(node):
    try:
        v = ast.literal_eval(node)
        return float(v) if isinstance(v, (int, float)) else None
    except Exception:
        return None


def text(node):
    try:
        v = ast.literal_eval(node)
        return v if isinstance(v, str) else ""
    except Exception:
        return ""


def trailing_comment(lines, lineno):
    """The `# ...` on the row's own line -- where WW2 marks an estimate, and the only place it is."""
    if lineno <= 0 or lineno > len(lines):
        return ""
    s = lines[lineno - 1]
    i = s.find("#")
    return s[i + 1:].strip() if i >= 0 else ""


rows = []
for fname, dictname, wi, bi, vi, ci, ni, basis, setname in TABLES:
    path = os.path.join(HERE, fname)
    if not os.path.exists(path):
        print("MISSING GENERATOR: %s -- this tool cannot see weights it cannot read" % fname, file=sys.stderr)
        sys.exit(1)
    src = io.open(path, encoding="utf-8").read()
    lines = src.split("\n")
    found = False
    for node in ast.walk(ast.parse(src)):
        if not isinstance(node, ast.Assign) or not isinstance(node.value, ast.Dict):
            continue
        if not any(isinstance(t, ast.Name) and t.id == dictname for t in node.targets):
            continue
        found = True
        for k, v in zip(node.value.keys, node.value.values):
            try:
                gun = ast.literal_eval(k)
            except Exception:
                continue
            if not isinstance(v, (ast.Tuple, ast.List)) or wi >= len(v.elts):
                continue
            el = v.elts
            w = num(el[wi])
            if w is None:
                continue
            note = text(el[ni]) if (ni is not None and ni < len(el)) else ""
            comment = trailing_comment(lines, getattr(v, "lineno", 0)) or \
                trailing_comment(lines, getattr(k, "lineno", 0))
            rows.append({
                "set": setname, "gun": gun, "loaded_lb": w, "basis": basis,
                "grains": num(el[bi]) if bi is not None and bi < len(el) else None,
                "fps": num(el[vi]) if vi is not None and vi < len(el) else None,
                "charge": num(el[ci]) if ci is not None and ci < len(el) else None,
                "note": (note or comment).replace("\t", " "),
            })
        break
    if not found:
        print("NO %s IN %s -- the table was renamed and this tool would have gone quiet about it"
              % (dictname, fname), file=sys.stderr)
        sys.exit(1)


def estimated(r):
    return any(w in r["note"].lower() for w in ESTIMATE_WORDS)


for r in rows:
    if estimated(r):
        r["basis"] = "ESTIMATE"

rows.sort(key=lambda r: (r["set"], r["gun"]))

if "--tsv" in sys.argv:
    print("set\tgun\tloaded_lb\tbasis\tbullet_grains\tmuzzle_fps\tcharge_grains\tbasis_note")
    for r in rows:
        print("%s\t%s\t%.2f\t%s\t%s\t%s\t%s\t%s" % (
            r["set"], r["gun"], r["loaded_lb"], r["basis"],
            "" if r["grains"] is None else "%g" % r["grains"],
            "" if r["fps"] is None else "%g" % r["fps"],
            "" if r["charge"] is None else "%g" % r["charge"], r["note"]))
    sys.exit(0)

print("%d guns carry a weight in this package. EVERY ONE IS THE LOADED GUN." % len(rows))
print("baseweight is the EMPTY gun:  baseweight = loaded_lb - capacity x round_lb,  with YOUR capacity.\n")
last = None
for r in rows:
    if r["set"] != last:
        last = r["set"]
        print("-- %s" % last)
    n = r["note"]
    if len(n) > 96:
        n = n[:93] + "..."
    print("   %-22s %6.2f lb  %-9s %s" % (r["gun"], r["loaded_lb"], r["basis"], n))

counts = {}
for r in rows:
    counts[r["basis"]] = counts.get(r["basis"], 0) + 1
print("\n" + ", ".join("%d %s" % (counts[b], b) for b in sorted(counts)))
print("ANALOGUE means the weight is measured FOR THE ANALOGUE and the pairing is a judgement -- argue")
print("with the pairing, not the pound. ESTIMATE means nobody has published one and I chose it.")
