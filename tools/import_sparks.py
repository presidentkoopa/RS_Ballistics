#!/usr/bin/env python3
"""
import_sparks.py -- the textured spark library for muzzle sparks (the owner, 2026-09-14:
every gun's bore sparks were one plain glowing streak, all the same size, colour, shape and
direction -- "you have all that access to combat fx and art source ... and this is what you got?").

Copies spark art from the owner's permitted pools, shaped for the particle atlas, and records
each source by SHA-1 in ASSETS.md:
  RSKS A      a long thin spark streak               RS_Main combatfx/sparks RSS4A0 (133x7)
  RSKR A      a photoreal spark streak, laid along X  ART SOURCE PARTICLES/photorealisticspark/spark.png (rotated, 256x32)
  RSKT A      a four-point star twinkle               RS_Main combatfx/sparks RSS1A0
  RSKP A-D    tiny spark clusters, flickering         RS_Main combatfx/sparks RSS0A0-D0
  RSKE A-B    a glowing ember dot, a soft ember ball  RS_Main combatfx/sparks RSS0S0, RSS4B0
  RSKB A      a photoreal sparkler burst               ART SOURCE PARTICLES/photorealisticspark/yellowflare.png (192x192)
A streak's long axis is X, the way the engine stretches a velocity-oriented particle.

    python tools/import_sparks.py
"""
import hashlib
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
OUT = os.path.join(PKG, "sprites")
MAIN = "E:/DOOMWork/RS_Main/sprites/combatfx/sparks/"
ART = "E:/oldshit/ART SOURCE/SPRITES/PARTICLES/photorealisticspark/"

# (output lump, source, how)
PLAN = [
    ("RSKSA0", MAIN + "RSS4A0.png", "copy"),
    ("RSKRA0", ART + "spark.png", "rotate"),
    ("RSKTA0", MAIN + "RSS1A0.png", "copy"),
    ("RSKPA0", MAIN + "RSS0A0.png", "copy"),
    ("RSKPB0", MAIN + "RSS0B0.png", "copy"),
    ("RSKPC0", MAIN + "RSS0C0.png", "copy"),
    ("RSKPD0", MAIN + "RSS0D0.png", "copy"),
    ("RSKEA0", MAIN + "RSS0S0.png", "copy"),
    ("RSKEB0", MAIN + "RSS4B0.png", "copy"),
    ("RSKBA0", ART + "yellowflare.png", "shrink"),
]


def sha1(path):
    with open(path, "rb") as f:
        return hashlib.sha1(f.read()).hexdigest()


def main():
    lines = ["", "## RSK*: the textured spark library (tools/import_sparks.py)", ""]
    for lump, src, how in PLAN:
        im = Image.open(src).convert("RGBA")
        if how == "rotate":
            im = im.rotate(90, expand=True).resize((256, 32), Image.LANCZOS)
        elif how == "shrink":
            im = im.resize((192, 192), Image.LANCZOS)
        out = os.path.join(OUT, lump + ".png")
        im.save(out)
        rel = src.replace("E:/DOOMWork/", "").replace("E:/oldshit/", "")
        lines.append("- `sprites/%s.png` from `%s` (sha1 %s)%s" % (lump, rel, sha1(src), "" if how == "copy" else ", " + how))
        print("%s  %dx%d  <- %s (%s)" % (lump, im.size[0], im.size[1], src, how))
    assets = os.path.join(PKG, "ASSETS.md")
    with open(assets, encoding="utf-8") as f:
        text = f.read()
    if "## RSK*: the textured spark library" not in text:
        with open(assets, "a", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines) + "\n")
        print("ASSETS.md: sources recorded")


if __name__ == "__main__":
    main()
