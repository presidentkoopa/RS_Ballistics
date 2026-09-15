#!/usr/bin/env python3
"""
gen_brushes.py -- the wall damage brushes (engine #17: DAMAGEDEFS `brush`).

Generated from fixed seeds and owned outright (the house rule for chunks and casings). Writes:
  - damage/rsb/<brush>_<a..d>.png: 128 x 128 RGBA masks in the engine's channels --
    R soot, G hole depth, B heat, A wet
  - DAMAGEDEFS.txt: one `brush` block per brush, four variants each (the engine picks one per
    paint by a hash of the position)
  - optionally a contact sheet (--sheet out.png) to look them over; not part of the package

Byte-stable: only uniform draws from numpy's PCG64 with fixed seeds, no clocks, no metadata.
Brush +x is the axis a paint's `along` turns (a gouge along the travel, wood grain up the wall).
See Engine docs/WALL_DAMAGE_ART_PLAN.md for which weapon uses which brush.

    python tools/gen_brushes.py [--sheet path.png]
"""
import math
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "damage", "rsb")
N = 128
VARIANTS = "abcd"

_ax = (np.arange(N) + 0.5) / N * 2.0 - 1.0
X, Y = np.meshgrid(_ax, _ax)          # X: +x to the right (the brush axis), Y: down
R = np.sqrt(X * X + Y * Y)
TH = np.arctan2(Y, X)


def smooth(e0, e1, x):
    """smoothstep from e0 to e1 (either order)."""
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def value_noise(rng, cells):
    """Smooth noise in 0..1 over the brush, `cells` across."""
    g = rng.random((cells + 1, cells + 1))
    u = (X + 1.0) * 0.5 * cells
    v = (Y + 1.0) * 0.5 * cells
    iu = np.clip(np.floor(u).astype(int), 0, cells - 1)
    iv = np.clip(np.floor(v).astype(int), 0, cells - 1)
    fu = smooth(0.0, 1.0, u - iu)
    fv = smooth(0.0, 1.0, v - iv)
    a = g[iv, iu] * (1 - fu) + g[iv, iu + 1] * fu
    b = g[iv + 1, iu] * (1 - fu) + g[iv + 1, iu + 1] * fu
    return a * (1 - fv) + b * fv


def angular_noise(rng, harmonics=6):
    """A wobble round the centre in -1..1."""
    total = np.zeros_like(TH)
    norm = 0.0
    for k in range(2, harmonics + 2):
        amp = rng.random() / k
        total += amp * np.sin(k * TH + rng.random() * 2 * math.pi)
        norm += amp
    return total / max(norm, 1e-6)


def seg_dist(x0, y0, x1, y1):
    dx, dy = x1 - x0, y1 - y0
    ll = dx * dx + dy * dy
    t = np.clip(((X - x0) * dx + (Y - y0) * dy) / ll, 0.0, 1.0) if ll > 0 else 0.0
    px, py = x0 + t * dx, y0 + t * dy
    return np.sqrt((X - px) ** 2 + (Y - py) ** 2)


def polyline(points, width, depth0, depth1):
    """A line through `points`, `width` half-wide, depth fading from depth0 to depth1 along it."""
    out = np.zeros_like(X)
    n = len(points) - 1
    for i in range(n):
        d = seg_dist(points[i][0], points[i][1], points[i + 1][0], points[i + 1][1])
        depth = depth0 + (depth1 - depth0) * (i + 0.5) / n
        w = width * (1.0 - 0.6 * i / n)
        out = np.maximum(out, smooth(w, 0.0, d) * depth)
    return out


def crack(rng, r0, r1, angle, width, depth, steps=6, wander=0.12):
    pts = []
    a = angle
    for i in range(steps + 1):
        r = r0 + (r1 - r0) * i / steps
        pts.append((r * math.cos(a), r * math.sin(a)))
        a += (rng.random() * 2 - 1) * wander
    return polyline(pts, width, depth, depth * 0.35)


def blob(cx, cy, radius, depth):
    return smooth(radius, radius * 0.3, np.sqrt((X - cx) ** 2 + (Y - cy) ** 2)) * depth


def edge_fade():
    """Everything inside the circle: a turned brush's square corners stay empty."""
    return smooth(0.98, 0.88, R)


# ---------------------------------------------------------------- the brushes: (soot, depth, heat, wet)
def hole_chip(rng):
    """A bullet hole in hard material: a dark core, a chipped rim, short spall cracks."""
    r0 = 0.24 * (1.0 + 0.2 * angular_noise(rng))
    depth = smooth(r0 + 0.05, r0 - 0.03, R)
    r1 = 0.48 * (1.0 + 0.25 * angular_noise(rng))
    depth = np.maximum(depth, smooth(r1, r1 - 0.14, R) * (0.3 + 0.3 * value_noise(rng, 8)))
    for _ in range(5 + int(rng.random() * 5)):
        a, d = rng.random() * 2 * math.pi, 0.28 + rng.random() * 0.27
        depth = np.maximum(depth, blob(d * math.cos(a), d * math.sin(a), 0.05 + rng.random() * 0.06, 0.4 + rng.random() * 0.3))
    for _ in range(3 + int(rng.random() * 4)):
        depth = np.maximum(depth, crack(rng, 0.2, 0.55 + rng.random() * 0.3, rng.random() * 2 * math.pi, 0.022, 0.32))
    soot = smooth(0.85, 0.15, R) * (0.55 + 0.45 * value_noise(rng, 6))
    soot = np.maximum(soot, depth * 0.6)
    heat = smooth(0.45, 0.1, R)
    return soot, depth, heat, np.zeros_like(R)


def hole_punch(rng):
    """A clean hole through sheet metal: a round core, a dent round it, small tears."""
    r0 = 0.22 * (1.0 + 0.06 * angular_noise(rng))
    depth = smooth(r0 + 0.025, r0 - 0.02, R)
    depth = np.maximum(depth, smooth(0.62, r0, R) ** 2 * 0.32)
    for _ in range(3 + int(rng.random() * 3)):
        a = rng.random() * 2 * math.pi
        depth = np.maximum(depth, polyline([(0.18 * math.cos(a), 0.18 * math.sin(a)),
                                            (0.30 * math.cos(a), 0.30 * math.sin(a))], 0.035, 0.9, 0.5))
    soot = smooth(0.72, 0.25, R) * (0.5 + 0.3 * value_noise(rng, 5))
    heat = smooth(0.55, 0.15, R)
    return soot, depth, heat, np.zeros_like(R)


def hole_splinter(rng):
    """A bullet hole in wood: a ragged core, splits running along the grain (+x)."""
    rag = 1.0 + 0.3 * (value_noise(rng, 10) - 0.5)
    e = np.sqrt((X / 0.30) ** 2 + (Y / 0.17) ** 2) * rag
    depth = smooth(1.08, 0.9, e)
    torn = np.sqrt((X / 0.58) ** 2 + (Y / 0.27) ** 2)
    depth = np.maximum(depth, smooth(1.0, 0.6, torn) * (0.15 + 0.2 * value_noise(rng, 9)))
    for _ in range(2 + int(rng.random() * 3)):
        y = (rng.random() * 2 - 1) * 0.14
        side = 1.0 if rng.random() < 0.5 else -1.0
        x1 = side * (0.5 + rng.random() * 0.38)
        pts = [(side * 0.15, y), (x1 * 0.5, y + (rng.random() * 2 - 1) * 0.03), (x1, y + (rng.random() * 2 - 1) * 0.05)]
        depth = np.maximum(depth, polyline(pts, 0.03, 0.35 + rng.random() * 0.2, 0.15))
    soot = smooth(0.6, 0.1, R) * 0.35 + depth * 0.3
    return soot, depth, np.zeros_like(R), np.zeros_like(R)


def pit(rng):
    """A soft hit in dirt and rock: a shallow bowl, no rim, a darker ring of disturbed soil."""
    rr = R * (1.0 + 0.18 * angular_noise(rng))
    depth = np.clip(1.0 - (rr / 0.55) ** 2, 0.0, 1.0) * (0.45 + 0.15 * value_noise(rng, 7))
    soot = smooth(0.35, 0.55, rr) * smooth(0.95, 0.7, rr) * (0.15 + 0.25 * value_noise(rng, 9))
    soot = np.maximum(soot, depth * 0.7)
    return soot, depth, np.zeros_like(R), np.zeros_like(R)


def crater(rng):
    """A blast into a surface: a wide shallow crater, a broken rim, radiating cracks, scorch to the edge."""
    rr = R * (1.0 + 0.15 * angular_noise(rng))
    depth = smooth(0.42, 0.0, rr) ** 0.7 * (0.55 + 0.25 * value_noise(rng, 6))
    for _ in range(8 + int(rng.random() * 7)):
        a, d = rng.random() * 2 * math.pi, 0.32 + rng.random() * 0.16
        depth = np.maximum(depth, blob(d * math.cos(a), d * math.sin(a), 0.04 + rng.random() * 0.06, 0.3 + rng.random() * 0.25))
    for _ in range(6 + int(rng.random() * 5)):
        depth = np.maximum(depth, crack(rng, 0.35, 0.65 + rng.random() * 0.28, rng.random() * 2 * math.pi, 0.02, 0.3, wander=0.18))
    streaks = 1.0 + 0.35 * angular_noise(rng, 12)
    soot = smooth(1.0, 0.15, R / streaks) * (0.5 + 0.5 * value_noise(rng, 5))
    soot = np.maximum(soot, smooth(0.45, 0.0, R))
    heat = smooth(0.38, 0.0, R) * (0.6 + 0.4 * value_noise(rng, 6))
    return soot, depth, heat, np.zeros_like(R)


def scorch(rng):
    """Burn and soot: a soft falloff with a darker, blotchy centre. No hole."""
    rr = R * (1.0 + 0.22 * angular_noise(rng))
    soot = smooth(0.95, 0.1, rr) * (0.55 + 0.45 * value_noise(rng, 6))
    soot = np.maximum(soot, smooth(0.35, 0.0, rr) * (0.8 + 0.2 * value_noise(rng, 9)))
    heat = smooth(0.32, 0.0, R) * 0.8
    return soot, np.zeros_like(R), heat, np.zeros_like(R)


def scorch_ring(rng):
    """An energy burn: a scorched ring round a cleaner inner disc, barely dished."""
    rr = R * (1.0 + 0.08 * angular_noise(rng))
    ring = smooth(0.22, 0.48, rr) * smooth(0.92, 0.58, rr)
    soot = np.clip(ring * (0.7 + 0.3 * value_noise(rng, 10)) + smooth(0.3, 0.0, rr) * 0.15, 0.0, 1.0)
    depth = smooth(0.5, 0.2, rr) * 0.25
    heat = ring
    return soot, depth, heat, np.zeros_like(R)


def gouge(rng):
    """A ricochet's scrape along +x: a furrow that starts narrow, scoops and tapers out."""
    wobble = 0.03 * np.sin(X * (3 + rng.random() * 3) + rng.random() * 6.28)
    t = np.clip((X + 0.85) / 1.65, 0.0, 1.0)
    profile = np.where(t < 0.6, t / 0.6, (1.0 - t) / 0.4) ** 0.8
    inside = (X > -0.85) & (X < 0.8)
    w = 0.15 * profile * (1.0 + 0.3 * (value_noise(rng, 12) - 0.5))
    dy = np.abs(Y - wobble)
    depth = np.where(inside, smooth(w + 0.01, w * 0.2, dy) * (0.35 + 0.55 * profile), 0.0)
    soot = np.where(inside, smooth(w * 2.2 + 0.03, 0.0, dy) * 0.5 * profile, 0.0)
    return soot, depth, depth.copy(), np.zeros_like(R)


def cut(rng):
    """A chainsaw's bite along +x: a straight narrow slot with torn edges and burrs."""
    inside = smooth(0.95, 0.82, np.abs(X))
    w = 0.06 * (1.0 + 0.5 * (value_noise(rng, 16) - 0.5))
    dy = np.abs(Y - 0.01 * np.sin(X * 9 + rng.random() * 6.28))
    depth = smooth(w + 0.012, w * 0.4, dy) * 0.95 * inside
    burr = smooth(0.16, w, dy) * (0.15 + 0.2 * value_noise(rng, 14)) * inside
    depth = np.maximum(depth, burr)
    soot = smooth(0.22, 0.0, dy) * 0.45 * inside
    heat = smooth(w * 1.6, 0.0, dy) * inside
    return soot, depth, heat, np.zeros_like(R)


def crack_glass(rng):
    """Glass under a hit: a small shattered core and a radial star of fractures with branches."""
    depth = smooth(0.11, 0.05, R) * 0.8
    for _ in range(7 + int(rng.random() * 6)):
        a = rng.random() * 2 * math.pi
        r1 = 0.5 + rng.random() * 0.45
        depth = np.maximum(depth, crack(rng, 0.06, r1, a, 0.016, 0.4, steps=7, wander=0.08))
        for _ in range(int(rng.random() * 3)):
            rb = 0.2 + rng.random() * (r1 - 0.25)
            ab = a + (rng.random() * 2 - 1) * 0.45
            start = (rb * math.cos(a), rb * math.sin(a))
            length = 0.15 + rng.random() * 0.25
            end = (start[0] + length * math.cos(ab), start[1] + length * math.sin(ab))
            depth = np.maximum(depth, polyline([start, end], 0.013, 0.28, 0.1))
    ring_r = 0.22 + rng.random() * 0.12
    arcs = smooth(0.2, 0.6, np.sin(TH * (3 + int(rng.random() * 3)) + rng.random() * 6.28))
    depth = np.maximum(depth, smooth(0.018, 0.0, np.abs(R - ring_r)) * arcs * 0.25)
    return np.zeros_like(R), depth, np.zeros_like(R), np.zeros_like(R)


def melt(rng):
    """A beam's molten spot: a smooth glassy bowl, slag spatter round it, a soot ring, a white-hot core."""
    rr = R * (1.0 + 0.1 * angular_noise(rng))
    depth = smooth(0.5, 0.0, rr) ** 0.6 * (0.7 + 0.2 * value_noise(rng, 5))
    for _ in range(6 + int(rng.random() * 6)):
        a, d = rng.random() * 2 * math.pi, 0.42 + rng.random() * 0.22
        depth = np.maximum(depth, blob(d * math.cos(a), d * math.sin(a), 0.03 + rng.random() * 0.04, 0.15 + rng.random() * 0.15))
    soot = smooth(1.0, 0.4, rr) * smooth(0.18, 0.45, rr) * (0.5 + 0.5 * value_noise(rng, 7))
    heat = smooth(0.55, 0.0, rr) ** 0.8 * (0.8 + 0.2 * value_noise(rng, 6))
    return soot, depth, heat, np.zeros_like(R)


def stipple(rng):
    """Powder stipple: specks of burnt powder peppered round a shot fired close, thickest in the middle."""
    soot = smooth(0.9, 0.0, R) * 0.2 * (0.6 + 0.4 * value_noise(rng, 8))
    depth = np.zeros_like(R)
    for _ in range(40 + int(rng.random() * 25)):
        rad = abs(rng.random() - rng.random()) * 0.85
        a = rng.random() * 2 * math.pi
        speck = blob(rad * math.cos(a), rad * math.sin(a), 0.035 + rng.random() * 0.035, 1.0)
        soot = np.maximum(soot, speck * (0.6 + 0.4 * rng.random()))
        depth = np.maximum(depth, speck * 0.35)
    return soot, depth, np.zeros_like(R), np.zeros_like(R)


# name, function, seed base, turn, flip
BRUSHES = [
    ("hole_chip",     hole_chip,     1100, "hashed", "hashed"),
    ("hole_punch",    hole_punch,    1200, "hashed", "hashed"),
    ("hole_splinter", hole_splinter, 1300, "none",   "hashed"),
    ("pit",           pit,           1400, "hashed", "hashed"),
    ("crater",        crater,        1500, "hashed", "hashed"),
    ("scorch",        scorch,        1600, "hashed", "hashed"),
    ("scorch_ring",   scorch_ring,   1700, "hashed", "hashed"),
    ("gouge",         gouge,         1800, "none",   "none"),
    ("cut",           cut,           1900, "none",   "none"),
    ("crack",         crack_glass,   2000, "hashed", "hashed"),
    ("melt",          melt,          2100, "hashed", "hashed"),
    ("stipple",       stipple,       2200, "hashed", "hashed"),
]


def to_png(channels, path):
    fade = edge_fade()
    rgba = np.stack([np.clip(c * fade, 0.0, 1.0) for c in channels], axis=-1)
    img = Image.fromarray(np.round(rgba * 255.0).astype(np.uint8), "RGBA")
    img.save(path, format="PNG", optimize=False)
    return rgba


def preview(rgba):
    """A wall-grey tile with the damage drawn roughly as the engine's default look would."""
    soot, depth, heat = rgba[..., 0], rgba[..., 1], rgba[..., 2]
    base = np.full(R.shape + (3,), 0.62)
    shade = (1.0 - 0.75 * depth) * (1.0 - 0.7 * soot)
    col = base * shade[..., None]
    col[..., 0] = np.clip(col[..., 0] + heat * 0.35, 0, 1)
    return np.round(col * 255).astype(np.uint8)


def main():
    sheet_path = sys.argv[sys.argv.index("--sheet") + 1] if "--sheet" in sys.argv else None
    os.makedirs(OUT_DIR, exist_ok=True)
    lines = [
        "// RS_Ballistics wall damage brushes (engine #17). WRITTEN BY tools/gen_brushes.py -- change the tool",
        "// and run it again rather than editing here. Masks: R soot, G hole depth, B heat, A wet (channels = rgba).",
        "// Generated from fixed seeds and owned outright. Four variants a brush; the engine picks one per paint",
        "// by a hash of the position. A brush's +x is the axis a paint's `along` gives (RSBDEFS `damage`).",
        "",
    ]
    tiles = []
    for name, fn, seed, turn, flip in BRUSHES:
        paths = []
        row = []
        for i, letter in enumerate(VARIANTS):
            rng = np.random.Generator(np.random.PCG64(seed + i))
            rel = "damage/rsb/%s_%s.png" % (name, letter)
            rgba = to_png(fn(rng), os.path.join(ROOT, rel))
            paths.append('"%s"' % rel)
            row.append(preview(rgba))
        tiles.append(row)
        lines += ["brush %s" % name, "{",
                  "\tmasks = " + ", ".join(paths),
                  "\tchannels = rgba",
                  "\tturn = " + turn,
                  "\tflip = " + flip,
                  "}", ""]
    with open(os.path.join(ROOT, "DAMAGEDEFS.txt"), "w", newline="\n", encoding="utf-8") as f:
        f.write("\n".join(lines))
    if sheet_path:
        sheet = np.concatenate([np.concatenate(row, axis=1) for row in tiles], axis=0)
        Image.fromarray(sheet, "RGB").save(sheet_path)
    print("brushes: %d, %d masks, DAMAGEDEFS.txt written" % (len(BRUSHES), len(BRUSHES) * len(VARIANTS)))


if __name__ == "__main__":
    main()
