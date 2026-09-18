#!/usr/bin/env python3
"""
import_smoke_books.py -- longer, smoother smoke books out of RS_Main's combat effects.

Every smoke in the package -- the muzzle puff, the ejection port, the barrel, a rocket's trail, a
two-stroke's exhaust -- drew the SAME six-frame card (RSSK), and those six were a paletted subset of
a seventeen-frame roll. Six frames of 8-bit smoke is where the banding and the "that puff again"
tell come from. The frames are right there, so:

  RSSK  17 frames  the smoke roll, all of it, in RGBA        (was 6 paletted frames of the same art)
  RSSG  23 frames  a darker puff that grows and thins        gun smoke, its own look at last
  RSSW   8 frames  a thin rising thread                      what hot brass trails (rsb_casing_wisp)

COSTS NOTHING TO DRAW. A particle is one quad either way; only which frame of the atlas it samples
changes. The atlas holds 2048 frames; this adds 42.

TIMING IS KEPT, NOT CHANGED. A definition's `texture = "RSSKA0", 6, fps, once` played its book in
6/fps seconds, and its size, alpha and drag ramps were tuned against that. Raising the frame count
without raising the fps would stretch the book past the particle's life and cut the dissipation off,
so PARTICLEDEFS gets its fps scaled by 17/6 in the same pass (tools/gen_smoke_fps.py prints them).

Frames are padded onto one square canvas per book, centred, so the atlas never stretches one frame
against another -- the same rule import_fx.py keeps.

    python tools/import_smoke_books.py            # write what is missing
    python tools/import_smoke_books.py --check    # say what would be written, write nothing
    python tools/import_smoke_books.py --force    # rewrite every frame (RSSK's six are replaced)

ASSETS.md records every source frame and its SHA-1, between its markers.
"""
import argparse
import hashlib
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
SPRITES = os.path.join(PKG, "sprites")
FX = "E:/DOOMWork/RS_Main/sprites/combatfx"

# our name, RS_Main folder, its sprite, what it is
#
# Looked at and NOT taken: RSK6-RSK9 (four pale puffs dissolving -- our impact dust is the engine's
# own `look = dust`, which tears and churns in the world instead of replaying a card), RSK1-RSK3
# (the same rolls as lumps, no alpha).
BOOKS = [
    ("RSSK", "smoke", "RSK0", "the smoke roll: billows out, turns over, thins away"),
    ("RSSG", "smoke", "RSK4", "gun smoke: a darker puff that grows as it thins"),
    ("RSSW", "smoke", "RSK5", "a thin thread of smoke rising, what hot brass trails"),
]
LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
ASSET_BEGIN = "<!-- BEGIN smoke books (tools/import_smoke_books.py) -->"
ASSET_END = "<!-- END smoke books -->"


def sha1(path):
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def replace_block(text, begin, end, block, nl):
    if begin in text and end in text:
        a = text.index(begin)
        b = text.index(end) + len(end)
        return text[:a] + block + text[b:]
    return text.rstrip("\r\n") + nl + nl + block + nl


def source_frames(folder, sprite):
    d = os.path.join(FX, folder)
    names = sorted((f for f in os.listdir(d) if f[:4].upper() == sprite and f.lower().endswith(".png")),
                   key=lambda f: f[4].upper())
    return [os.path.join(d, n) for n in names]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    assets = [ASSET_BEGIN, ""]
    wrote = skipped = 0
    for name, folder, sprite, what in BOOKS:
        paths = source_frames(folder, sprite)
        if not paths:
            sys.exit("no frames for %s in %s" % (sprite, folder))
        if len(paths) > len(LETTERS):
            sys.exit("%s: %d frames, more than A-Z" % (sprite, len(paths)))
        images = [Image.open(p).convert("RGBA") for p in paths]
        side = max(max(im.width, im.height) for im in images)
        side += side % 2
        print("%s <- %s/%s  %d frames, %dx%d canvas  (%s)" % (name, folder, sprite, len(paths), side, side, what))
        for i, (p, im) in enumerate(zip(paths, images)):
            out_name = "%s%s0.png" % (name, LETTERS[i])
            dst = os.path.join(SPRITES, out_name)
            if args.check:
                print("   %-12s %s  <- %s" % ("would write" if (args.force or not os.path.isfile(dst))
                                              else "have", out_name, os.path.basename(p)))
            elif args.force or not os.path.isfile(dst):
                canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
                canvas.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
                canvas.save(dst)
                back = Image.open(dst)
                if back.size != (side, side) or back.mode != "RGBA":
                    sys.exit("%s came back %s %s" % (out_name, back.size, back.mode))
                wrote += 1
            else:
                skipped += 1
            assets.append("- `sprites/%s` from `RS_Main/sprites/combatfx/%s/%s`, padded onto a %dx%d "
                          "canvas (sha1 %s)" % (out_name, folder, os.path.basename(p), side, side, sha1(p)))
    assets.append("")
    assets.append(ASSET_END)

    if args.check:
        return
    path = os.path.join(PKG, "ASSETS.md")
    with open(path, "r", encoding="utf-8", newline="") as f:
        text = f.read()
    nl = "\r\n" if "\r\n" in text else "\n"
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(replace_block(text, ASSET_BEGIN, ASSET_END, nl.join(assets), nl))
    print("updated ASSETS.md")
    print("%d frames written, %d already there" % (wrote, skipped))


main()
