#!/usr/bin/env python3
"""
import_fx.py -- effect sprites for RS_Ballistics' particle definitions.

TWO SOURCES, BOTH CLEARED BY THE OWNER:

  COPIED from RS_Main's combat effects (owner, 2026-09-14: "RS_Main is fair game").
  Each group is renamed to a sprite name of RS_Ballistics' own, its frames
  renumbered to consecutive letters (a particle flipbook steps the frame letter),
  and every frame padded, centred, onto one square canvas per group so the atlas
  layers don't stretch frames of different sizes differently.

  GENERATED here, owned outright: debris pieces (concrete chips, wood splinters,
  dirt clods, glass shards). Neutral grey, so a particle definition's colour ramp
  tints them per material; shaded from one side so they read as solid pieces when
  the room's light falls on them. Deterministic: the same seed makes the same
  pixels, every run.

THE RULES IT KEEPS (owner, 2026-09-14): grounded combat effects -- the Matrix
lobby, F.E.A.R., Trepang2, Max Payne, Selaco. Nothing cartoony, nothing neon.
Debris never glows: these are body sprites for lit definitions.

    python tools/import_fx.py            # write what is missing, never overwrite
    python tools/import_fx.py --check    # say what would be written, write nothing

Every written file is re-opened and checked. ASSETS.md (the package root, which
build.ps1 does not pack) records where each sprite came from: the source frames and
their SHA-1, or the generator and seed.
"""
import hashlib
import math
import os
import random
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
SPRITES = os.path.join(PKG, "sprites")
FX = "E:/DOOMWork/RS_Main/sprites/combatfx"

# new name, RS_Main folder, RS_Main sprite, frames in order (None = every frame, sorted), what it is
#
# Looked at and NOT taken: JXPL (a speckled black border that reads as noise round
# every blast; RSI4 is the clean burn-out), RSL0 (a ring outline and pixel noise:
# cartoon), the pixel-art debris and embers (RSU0, RSU3, RSU5, RSS0, RSI2), the
# starburst flashes (RSU1, RSU2), the magenta hit flash (RSH0), the red rings (RSF9).
COPIED = [
    ("RSDS", "blast", "JSMO", None, "rolling dust and smoke cloud, greyscale (tinted per material)"),
    ("RSFB", "fire", "RSI4", None, "fireball burning out"),
    ("RSFL", "fire", "RSI3", None, "flame tongues"),
    ("RSFK", "fire", "RSI8", None, "a single rising flame lick"),
    ("RSSO", "fire", "RSI6", None, "sooty puff with an ember"),
    ("RSSP", "sparks", "RSS3", None, "spray of hot spark streaks"),
    ("RSEC", "lightning", "RSL2", None, "electric arc (energy weapons only)"),
]

# new name, kind, variants, seed, what it is
GENERATED = [
    ("RSCH", "chip", 4, 1101, "concrete and stone chips"),
    ("RSSL", "splinter", 4, 2203, "wood splinters"),
    ("RSCL", "clod", 4, 3307, "dirt clods"),
    ("RSGS", "shard", 4, 4409, "glass shards"),
]

LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
GEN_SIZE = 64


def sha1(path):
    with open(path, "rb") as f:
        return hashlib.sha1(f.read()).hexdigest()


def frame_name(sprite, i):
    return "%s%s0.png" % (sprite, LETTERS[i])


def source_frames(folder, sprite):
    d = os.path.join(FX, folder)
    return sorted((f for f in os.listdir(d) if f[:4].upper() == sprite), key=lambda f: f[4].upper())


# ------------------------------------------------------------------ copied
def plan_copied():
    jobs = []
    for new, folder, sprite, order, what in COPIED:
        names = order or source_frames(folder, sprite)
        paths = [os.path.join(FX, folder, n) for n in names]
        if len(paths) > len(LETTERS):
            raise SystemExit("%s: %d frames, more than A-Z" % (sprite, len(paths)))
        images = [Image.open(p).convert("RGBA") for p in paths]
        side = max(max(im.width, im.height) for im in images)
        side += side % 2
        outs = []
        for i, (p, im) in enumerate(zip(paths, images)):
            canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            canvas.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
            outs.append((frame_name(new, i), canvas, p))
        jobs.append((new, what, side, outs))
    return jobs


# ------------------------------------------------------------------ generated
def polygon(rng, cx, cy, n, r_lo, r_hi, stretch=(1.0, 1.0), turn=None):
    turn = rng.uniform(0, math.tau) if turn is None else turn
    pts = []
    for k in range(n):
        a = turn + math.tau * (k + rng.uniform(-0.3, 0.3)) / n
        r = rng.uniform(r_lo, r_hi)
        x, y = math.cos(a) * r * stretch[0], math.sin(a) * r * stretch[1]
        ct, st = math.cos(turn), math.sin(turn)
        pts.append((cx + x * ct - y * st, cy + x * st + y * ct))
    return pts


def on_edge(m, w, h, x, y):
    return any(not m[min(w - 1, max(0, x + dx)), min(h - 1, max(0, y + dy))]
               for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))


def shade(mask, rng, base, light=(-0.7, -0.7), contrast=0.35, speckle=0.08, alpha=255, edge=None):
    """Fill the mask with a neutral grey lit from one side, with speckle; an optional
    bright edge (glass catching the light)."""
    w, h = mask.size
    px = mask.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    xs = [x for x in range(w) for y in range(h) if px[x, y]]
    ys = [y for x in range(w) for y in range(h) if px[x, y]]
    if not xs:
        return out
    cx, cy = sum(xs) / len(xs), sum(ys) / len(ys)
    span = max(max(xs) - min(xs), max(ys) - min(ys), 1) / 2.0
    for y in range(h):
        for x in range(w):
            if not px[x, y]:
                continue
            d = ((x - cx) * light[0] + (y - cy) * light[1]) / span
            v = base * (1.0 + contrast * d) * (1.0 + rng.uniform(-speckle, speckle))
            g = max(0, min(255, int(v)))
            a = alpha
            if edge is not None and on_edge(px, w, h, x, y):
                g, a = edge, 255
            op[x, y] = (g, g, g, a)
    return out


def rough_shade(mask, rng, base, facets=2, rim=0.62, contrast=0.45, speckle=0.16):
    """Broken stone: shade(), then fracture facets (each line across the piece darkens
    one side, as a face turned from the light) and a dark rim where the edge falls away."""
    img = shade(mask, rng, base=base, contrast=contrast, speckle=speckle)
    w, h = img.size
    px = img.load()
    m = mask.load()
    lines = [(rng.uniform(0, math.pi), rng.uniform(-7, 7), rng.uniform(0.70, 0.86)) for _ in range(facets)]
    for y in range(h):
        for x in range(w):
            if not m[x, y]:
                continue
            g, _, _, a = px[x, y]
            k = 1.0
            for ang, off, f in lines:
                if (x - w / 2.0) * math.cos(ang) + (y - h / 2.0) * math.sin(ang) > off:
                    k *= f
            if on_edge(m, w, h, x, y):
                k *= rim
            # grit: a few darker pits
            if rng.random() < 0.035:
                k *= 0.6
            v = max(0, min(255, int(g * k)))
            px[x, y] = (v, v, v, a)
    return img


def generate(kind, variant, seed):
    rng = random.Random(seed * 131 + variant)
    s = GEN_SIZE
    mask = Image.new("L", (s, s), 0)
    dr = ImageDraw.Draw(mask)
    c = s / 2.0
    if kind == "chip":
        dr.polygon(polygon(rng, c, c, rng.randint(7, 10), 11, 27), fill=255)
        return rough_shade(mask, rng, base=168, facets=rng.randint(2, 3))
    if kind == "splinter":
        dr.polygon(polygon(rng, c, c, 6, 8, 12, stretch=(2.6, 0.45)), fill=255)
        img = shade(mask, rng, base=175, contrast=0.3, speckle=0.05)
        # grain: darker lines along the splinter, kept inside its shape
        grain = ImageDraw.Draw(img)
        for _ in range(3):
            y0 = c + rng.uniform(-3, 3)
            grain.line([(c - 26, y0), (c + 26, y0 + rng.uniform(-2, 2))], fill=(118, 118, 118, 255), width=1)
        return Image.composite(img, Image.new("RGBA", img.size, (0, 0, 0, 0)), mask)
    if kind == "clod":
        dr.polygon(polygon(rng, c, c, rng.randint(9, 12), 16, 25), fill=255)
        return shade(mask, rng, base=150, contrast=0.3, speckle=0.18)
    if kind == "shard":
        dr.polygon(polygon(rng, c, c, rng.randint(3, 4), 14, 28, stretch=(1.4, 0.8)), fill=255)
        return shade(mask, rng, base=215, contrast=0.2, speckle=0.02, alpha=110, edge=250)
    raise ValueError(kind)


def plan_generated():
    jobs = []
    for new, kind, variants, seed, what in GENERATED:
        outs = [(frame_name(new, v), generate(kind, v, seed), None) for v in range(variants)]
        jobs.append((new, "%s (generated: %s, seed %d)" % (what, kind, seed), GEN_SIZE, outs))
    return jobs


# ------------------------------------------------------------------ main
def main(argv):
    check_only = "--check" in argv
    jobs = plan_copied() + plan_generated()
    os.makedirs(SPRITES, exist_ok=True)
    written, skipped = 0, 0
    records = []
    for new, what, side, outs in jobs:
        for name, img, src in outs:
            dst = os.path.join(SPRITES, name)
            if os.path.exists(dst):
                skipped += 1
            elif not check_only:
                img.save(dst)
                back = Image.open(dst)
                back.load()
                if back.size != img.size:
                    raise SystemExit("%s: wrote %s, read back %s" % (name, img.size, back.size))
                written += 1
            records.append((new, what, side, name, src))
        print("%s  %2d frames  %dx%d  %s" % (new, len(outs), side, side, what))

    if check_only:
        print("check only: %d frames would be written, %d exist" % (len(records) - skipped, skipped))
        return 0

    lines = ["# RS_Ballistics effect sprites: where each came from", "",
             "Written by `tools/import_fx.py`. Not packed (build.ps1 packs an allowlist).", "",
             "- **Copied** frames come from RS_Main's combat effects, cleared by the owner on",
             "  2026-09-14 (\"RS_Main is fair game\"). SHA-1 is of the RS_Main source file.",
             "- **Generated** frames are made by the script from a fixed seed and are owned outright.",
             ""]
    current = None
    for new, what, side, name, src in records:
        if new != current:
            lines += ["", "## %s: %s" % (new, what), ""]
            current = new
        if src:
            rel = src.replace("\\", "/").replace("E:/DOOMWork/", "")
            lines.append("- `sprites/%s` from `%s` (sha1 %s)" % (name, rel, sha1(src)))
        else:
            lines.append("- `sprites/%s` generated" % name)
    with open(os.path.join(PKG, "ASSETS.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("written %d, already there %d; ASSETS.md updated" % (written, skipped))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
