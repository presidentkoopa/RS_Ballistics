#!/usr/bin/env python3
"""
gen_liquid_variants.py -- a `.lava` and a `.slime` impact for every profile that has a `.liquid` one.

WHY THIS EXISTS. SURFACES.txt used to put FWATER, NUKAGE, BLOOD, SLIME and LAVA in one bucket called
`liquid`, so a round into molten rock threw a clear water splash and painted the surface DAMP. The
owner caught it ("just water? there is four or five different liquyids") and lava is now its own
surface. This writes the impacts to match.

WHAT LAVA DOES INSTEAD OF SPLASHING: lumps of molten rock thrown up, tumbling and cooling in the air
(`lava_globs`), the fine hot stuff that comes off with them (`lava_spit`), embers lifting on the heat
rather than falling (`lava_embers`), and the air over it burning (`lava_smoke`). A blast gets the
heavier `_big` sets.

AND WHAT IT DELIBERATELY DOES NOT DO:
  - NO WET. That was the bug. Molten rock is not damp.
  - NO DAMAGE PAINT AT ALL, wet or otherwise. A mark only means something on a surface that holds
    one, and lava flows -- a hole or a scorch in it would sit there being wrong.
  - NO GLOWING MARK (`mark`) for the same reason: a brief glow stamp on something already glowing is
    invisible work.
  - NO LIGHT OF ITS OWN where the profile already brings one. A rocket, a plasma ball and the BFG
    light their own hit and keep their own colour; only the plain kinetic hits get lava's warm one,
    because a bullet into lava has no light but the rock's.

    python tools/gen_liquid_variants.py            # rewrite the block between the markers in RSBDEFS.txt
    python tools/gen_liquid_variants.py --check    # print what it would write, change nothing

Run it again after editing any `.liquid` profile: the derived ones are not maintained by hand.

SLIME AND NUKAGE were the other half of the owner's catch. A `.liquid` splash is coloured 150,190,210 --
water. Every toxic pool in Doom was throwing up water. The splash colour needs NO engine work at all; it is
one `color` on one burst. What slime still cannot have is a GREEN WET MARK, because a surface paint carries
four amounts and no colour -- the same missing field blood needs, and the one thing here that is held.
"""
import argparse
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
DEFS = os.path.join(PKG, "RSBDEFS.txt")

BEGIN = "# ---- BEGIN liquid variants (tools/gen_liquid_variants.py)"
END = "# ---- END liquid variants"

# Bases whose hit is a BLAST rather than a strike: they take the heavier sets.
BIG = {"rocket", "rocket_rpg", "bfg", "bfg_heavy", "frag", "c4"}
# Bases that bring their own light and their own colour; lava does not recolour them.
OWN_LIGHT_KEYS = ("light", "lightcolor")

SMALL_SET = "lava_globs, lava_spit, lava_embers, lava_smoke"
BIG_SET = "lava_globs_big, lava_spit, lava_embers, lava_smoke_big"

# Keys carried across from the .liquid profile unchanged. Anything not listed is dropped, which is
# how the damage paints and the marks disappear without naming them one at a time.
KEEP = {"heat", "light", "lightcolor", "scale", "push", "volume", "exposure", "hearing", "tail",
        "smokevolume", "vary", "maybe", "hotspot", "glance"}


def base_of(ident):
    return ident.split("@")[0].split(".")[0]


def read_blocks(text, nl):
    """Every `impact <id>.liquid` block: (ident, tier suffix, [lines])."""
    lines = text.split(nl)
    out, i = [], 0
    while i < len(lines):
        m = re.match(r"^impact\s+([A-Za-z0-9_.@~]+)\s*(#.*)?$", lines[i])
        if not m or ".liquid" not in m.group(1):
            i += 1
            continue
        ident, body, i = m.group(1), [], i + 1
        while i < len(lines) and lines[i].strip() != "end":
            body.append(lines[i])
            i += 1
        out.append((ident, body))
        i += 1
    return out


def convert_slime(ident, body):
    """SLIME AND NUKAGE are still a liquid: the profile is kept whole and only the splash changes,
    from water to something thicker, greener and slower. No engine work is involved in that -- it is
    one `color` on one burst. The WET MARK it leaves stays colourless, which is the held part."""
    out = ["impact %s   # nukage and slime: the same hit as water, thrown up thicker, slower and green"
           % ident.replace(".liquid", ".slime")]
    for row in body:
        out.append("  " + row.strip().replace("splash_liquid", "splash_slime"))
    out.append("end")
    return out


def convert(ident, body):
    lava_id = ident.replace(".liquid", ".lava")
    base = base_of(ident)
    big = base in BIG
    kept, has_light = [], False
    for row in body:
        km = re.match(r"^\s*([a-z_]+)\s*=", row)
        if not km:
            continue
        key = km.group(1)
        if key == "bursts":
            continue
        if key not in KEEP:
            continue
        if key in OWN_LIGHT_KEYS:
            has_light = True
        kept.append("  " + row.strip())

    out = ["impact %s   # %s into molten rock: lumps thrown and cooling, spit, embers lifting, the air burning"
           % (lava_id, base.replace("_", " "))]
    out.append("  bursts      = %s" % (BIG_SET if big else SMALL_SET))
    out.append("  sound       = rsb/flame/hiss")
    if not has_light:
        # A kinetic hit has no light of its own; the rock it throws is the only light there is.
        out.append("  light       = %d, %.1f, %d" % (110 if big else 80, 2.4 if big else 1.8, 7 if big else 5))
        out.append("  lightcolor  = 255, 140, 55")
    out.extend(kept)
    out.append("end")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    text = io.open(DEFS, encoding="utf-8", newline="").read()
    nl = "\r\n" if "\r\n" in text else "\n"

    # Never derive from a previous run's output.
    if BEGIN in text and END in text:
        a, b = text.index(BEGIN), text.index(END) + len(END)
        source = text[:a] + text[b:]
    else:
        source = text

    blocks = read_blocks(source, nl)
    if not blocks:
        sys.exit("no .liquid impacts found -- nothing to derive from")

    body = [BEGIN,
            "# Derived from every `.liquid` profile above. DO NOT EDIT BY HAND: edit the .liquid one and",
            "# run tools/gen_liquid_variants.py again.",
            ""]
    for ident, lines in blocks:
        body.extend(convert(ident, lines))
        body.append("")
    for ident, lines in blocks:
        body.extend(convert_slime(ident, lines))
        body.append("")
    body.append(END)
    block = nl.join(body)

    print("%d lava and %d slime impacts derived from %d .liquid profiles" % (len(blocks), len(blocks), len(blocks)))
    if args.check:
        print()
        print(block)
        return

    out = source.rstrip("\r\n") + nl + nl + block + nl
    io.open(DEFS, "w", encoding="utf-8", newline="").write(out)
    print("RSBDEFS.txt updated")


# IMPORTING A GENERATOR MUST NOT RUN IT. Bare `main()` here meant that reading this file's
# tables -- or borrowing one function from it -- REWROTE RSBDEFS.txt as a side effect. It
# silently reverted eleven round looks mid-edit once, and ran a second time when another
# generator imported this one for its extreme transformer.
if __name__ == "__main__":
    main()
