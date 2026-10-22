#!/usr/bin/env python3
"""Lay out a sprite's frames side by side, for the README to show.

    python tools/make_docs_sheets.py

Writes docs/<SPRITE>.png, one image per sprite named in SHEETS below. This
is documentation only: docs/ is deliberately not in build.ps1's allowlist,
so nothing here reaches the pk3 or becomes a lump.

Frames are ordered by their Doom frame letter (RSCSA0, RSCSB0, ... ), which
is the order they play in.
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SPRITES = os.path.join(ROOT, "sprites")
DOCS = os.path.join(ROOT, "docs")

# What the README shows, and why each one is worth a picture.
SHEETS = {
    "RSSP": "spray of hot spark streaks",
    "RSDS": "rolling dust and smoke cloud",
    "RSFK": "a single rising flame lick",
    "RSEC": "electric arc",
    "RSCS": "spent casing",
    "RSFB": "fireball burning out",
    "RSL1": "textured spark burst",
}

# A sprite lump is NAME + frame letter + rotation, e.g. RSCSA0.
LUMP = re.compile(r"^(?P<name>[A-Z0-9]{4})(?P<frame>[A-Z\[\]\\])(?P<rot>[0-8])", re.I)
CELL_CAP = 256


def frames_for(sprite):
    out = []
    for fn in os.listdir(SPRITES):
        stem = os.path.splitext(fn)[0].upper()
        m = LUMP.match(stem)
        if not m or m.group("name") != sprite:
            continue
        out.append((ord(m.group("frame").upper()) - 65, m.group("rot"), fn))
    out.sort()
    return [os.path.join(SPRITES, fn) for _f, _r, fn in out]


def main():
    try:
        from PIL import Image
    except ImportError:
        print("Pillow is needed to draw the sheets", file=sys.stderr)
        return 1
    os.makedirs(DOCS, exist_ok=True)
    for sprite, what in SHEETS.items():
        paths = frames_for(sprite)
        if not paths:
            print(f"  ? {sprite}: no frames found")
            continue
        ims = [Image.open(p).convert("RGBA") for p in paths]
        for im in ims:
            if im.width > CELL_CAP or im.height > CELL_CAP:
                im.thumbnail((CELL_CAP, CELL_CAP), Image.LANCZOS)
        cw = max(i.width for i in ims)
        ch = max(i.height for i in ims)
        cols = min(len(ims), 13)
        rows = (len(ims) + cols - 1) // cols
        pad = 2
        sheet = Image.new(
            "RGBA", (cols * (cw + pad), rows * (ch + pad)), (30, 30, 36, 255)
        )
        for n, im in enumerate(ims):
            x = (n % cols) * (cw + pad) + (cw - im.width) // 2
            y = (n // cols) * (ch + pad) + (ch - im.height) // 2
            sheet.alpha_composite(im, (x, y))
        # Small art is unreadable at native size on a web page; scale it up
        # with nearest neighbour so the pixels stay crisp rather than mushy.
        if sheet.width < 700:
            k = max(1, 700 // sheet.width)
            if k > 1:
                sheet = sheet.resize((sheet.width * k, sheet.height * k), Image.NEAREST)
        sheet.save(os.path.join(DOCS, f"{sprite}.png"))
        print(f"  {sprite:6} {len(ims):3} frames  {sheet.width}x{sheet.height}  ({what})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
