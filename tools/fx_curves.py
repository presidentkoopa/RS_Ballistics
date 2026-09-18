#!/usr/bin/env python3
"""
fx_curves.py -- read the MOTION out of hand-animated effect frames, so our generated effects can move
the way an artist made one move without a single pixel of theirs ever shipping.

THE IDEA. RS_Main's combat effects are flat sprite art; we draw volumetric gas and engine-generated
dust and fire, so the pixels are below our bar and we do not take them (see tools/import_fx.py and
tools/import_smoke_books.py for what we did take and why). But the pixels are not the valuable part.
The valuable part is what an animator decided: how fast it grows, when it stops growing, how long it
stays bright, what colour it passes through, whether it rises, and -- the one nothing of ours does --
how its edges break up as it dies. That is measurable, it is not anyone's art, and it is exactly what
a PARTICLEDEFS ramp wants.

WHAT IT MEASURES, per frame, over a sequence:
  size        sqrt(lit area / largest lit area) -- a radius, which is what `size` ramps are
  alpha       mean alpha over the lit pixels -- how THICK it is, which is what an alpha ramp wants.
              Peak alpha is useless here: a cloud thinning to a haze still has one solid pixel in it,
              so peak reads 1.00 for the whole life and tells you nothing.
  bright      mean luminance of the lit pixels, weighted by alpha
  colour      mean colour of the lit pixels, weighted by alpha -- ready for a `color` ramp
  rise        how far the lit centroid climbs, as a fraction of the frame height (-> gravity)
  rough       boundary pixels / sqrt(area). A smooth disc is about 3.5; a torn, shredded cloud is
              double that or more. THIS IS THE ONE OUR GENERATORS CANNOT FOLLOW YET: `look = fire`
              and `look = dust` take one roughness for the whole life, so ours fade as a blob while
              a real fireball TEARS APART in its last three frames (3.9 -> 4.5 through life, then
              5.7, 7.7, 12.6). Flagged to the build lane as a ramp the particle record should carry.

WHAT IT PRINTS: the raw per-frame numbers, and each curve fitted to at most 8 keys (a PARTICLEDEFS
ramp's limit) by greedy worst-error insertion, formatted as a line you can paste straight in.

    python tools/fx_curves.py <folder> <4-letter sprite>          # one sequence
    python tools/fx_curves.py <folder> --all                      # every sequence in it
    python tools/fx_curves.py ... --keys 6 --raw

Folders may be given relative to RS_Main's combat effects, so `explosions RSE0` works.

It reads and measures only. It writes nothing, copies nothing, and ships nothing.
"""
import argparse
import collections
import math
import os
import sys

import numpy as np
from PIL import Image

FX = "E:/DOOMWork/RS_Main/sprites/combatfx"
LIT = 0.08          # alpha a pixel needs to count as part of the effect
MAX_KEYS = 8        # a PARTICLEDEFS ramp takes up to 8


def resolve(folder):
    for cand in (folder, os.path.join(FX, folder)):
        if os.path.isdir(cand):
            return cand
    sys.exit("no such folder: %s (tried it under %s too)" % (folder, FX))


def sequences(folder):
    groups = collections.defaultdict(list)
    for fn in sorted(os.listdir(folder)):
        if fn.lower().endswith(".png"):
            groups[fn[:4].upper()].append(fn)
    return groups


def measure(folder, names):
    """Per-frame (size, alpha, bright, colour, rise, rough) over a sequence."""
    out = []
    for fn in sorted(names, key=lambda f: f[4].upper()):
        im = np.asarray(Image.open(os.path.join(folder, fn)).convert("RGBA"), dtype=np.float32) / 255.0
        a = im[..., 3]
        lit = a > LIT
        area = int(lit.sum())
        if area == 0:
            out.append((0.0, 0.0, 0.0, (0.0, 0.0, 0.0), 0.0, 0.0))
            continue
        w = a[lit][:, None]
        colour = tuple(((im[..., :3][lit] * w).sum(0) / max(w.sum(), 1e-6)).tolist())
        ys, _ = np.nonzero(lit)
        # boundary pixels: lit, with at least one unlit 4-neighbour
        edge = np.zeros_like(lit)
        edge[1:-1, 1:-1] = lit[1:-1, 1:-1] & ~(lit[:-2, 1:-1] & lit[2:, 1:-1] & lit[1:-1, :-2] & lit[1:-1, 2:])
        out.append((float(area), float(a[lit].mean()), float(np.mean(colour)), colour,
                    float(ys.mean()) / im.shape[0], float(edge.sum()) / math.sqrt(area)))
    peak = max(f[0] for f in out) or 1.0
    top = out[0][4] if out else 0.0
    return [(math.sqrt(f[0] / peak), f[1], f[2], f[3], top - f[4], f[5]) for f in out]


def fit(xs, ys, keys):
    """Greedy worst-error key insertion: the fewest keys whose straight-line fit tracks the curve."""
    n = len(xs)
    if n <= 2:
        return list(range(n))
    picked = [0, n - 1]
    while len(picked) < min(keys, n):
        line = np.interp(xs, [xs[i] for i in picked], [ys[i] for i in picked])
        err = np.abs(np.asarray(ys) - line)
        for i in picked:
            err[i] = -1
        worst = int(np.argmax(err))
        if err[worst] <= 1e-6:
            break
        picked.append(worst)
        picked.sort()
    return picked


def ramp(name, xs, ys, keys, fmt="%.2f"):
    idx = fit(xs, ys, keys)
    return "  %-9s= %s" % (name, ", ".join((fmt + " @%.2f") % (ys[i], xs[i]) for i in idx))


def colour_ramp(xs, cols, keys):
    lum = [sum(c) / 3.0 for c in cols]
    idx = fit(xs, lum, keys)
    return "  %-9s= %s" % ("color", ", ".join(
        "%d %d %d @%.2f" % (int(255 * cols[i][0]), int(255 * cols[i][1]), int(255 * cols[i][2]), xs[i])
        for i in idx))


def report(folder, sprite, names, keys, raw):
    m = measure(folder, names)
    n = len(m)
    xs = [i / max(n - 1, 1) for i in range(n)]
    size, alpha, bright, cols, rise, rough = (list(c) for c in zip(*m))
    print("=" * 78)
    print("%s/%s -- %d frames" % (os.path.basename(folder), sprite, n))
    if raw:
        print("  frame   size  alpha bright  rise  rough")
        for i in range(n):
            print("  %-6d %5.2f  %5.2f  %5.2f %5.2f  %5.1f" % (i, size[i], alpha[i], bright[i], rise[i], rough[i]))
    print(ramp("size", xs, size, keys))
    flat = (max(alpha) - min(alpha)) < 0.02
    print(ramp("alpha", xs, alpha, keys) + ("      <- FLAT: this art does not thin by alpha at all." if flat else ""))
    if flat:
        print("      It is drawn with hard alpha and thins by going DARKER instead, so the colour ramp")
        print("      above carries the fade. Ours thin by alpha, so take the fade from colour brightness:")
        print(ramp("(as alpha)", xs, [b / max(max(bright), 1e-6) for b in bright], keys))
    print(colour_ramp(xs, cols, keys))
    print(ramp("rough", xs, rough, keys, "%.1f") + "      <- no ramp for this yet; one number today")
    lift = rise[-1]
    print("  rise it climbs over its life: %.0f%% of its own height%s"
          % (lift * 100, "  (gravity should be negative)" if lift > 0.05 else "  (it does not rise)"))
    hold = max((i for i in range(n) if size[i] > 0.97), default=0) / max(n - 1, 1)
    print("  grows to full by %.0f%% of life, holds until %.0f%%" %
          (100 * (min((i for i in range(n) if size[i] > 0.97), default=0) / max(n - 1, 1)), 100 * hold))
    tear = (rough[-1] / max(np.median(rough[:max(n - 3, 1)]), 1e-6)) if n > 3 else 1.0
    print("  its edges end %.1fx as broken as they ran: %s" %
          (tear, "IT TEARS APART" if tear > 1.4 else "it fades whole"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    ap.add_argument("sprite", nargs="?")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--keys", type=int, default=MAX_KEYS)
    ap.add_argument("--raw", action="store_true")
    args = ap.parse_args()
    if args.keys < 2 or args.keys > MAX_KEYS:
        sys.exit("keys is 2..%d (a PARTICLEDEFS ramp's limit)" % MAX_KEYS)

    folder = resolve(args.folder)
    groups = sequences(folder)
    if args.all:
        for sprite in sorted(groups):
            if len(groups[sprite]) >= 4:
                report(folder, sprite, groups[sprite], args.keys, args.raw)
    else:
        if not args.sprite:
            sys.exit("name a 4-letter sprite, or --all. This folder has: " + ", ".join(sorted(groups)))
        sprite = args.sprite.upper()
        if sprite not in groups:
            sys.exit("%s is not in %s. It has: %s" % (sprite, folder, ", ".join(sorted(groups))))
        report(folder, sprite, groups[sprite], args.keys, args.raw)


main()
