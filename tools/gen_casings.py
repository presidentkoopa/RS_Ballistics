#!/usr/bin/env python3
"""
gen_casings.py -- 3D spent casings and shotgun hulls for RS_Ballistics.

MILLIMETRES. Every mesh is built in millimetres at its real size and scaled to map
units in MODELDEF (1 map unit = 30.5 mm: a 56-unit Doom marine is 1.71 m). Building
in millimetres keeps MD3's 1/64 grid far finer than the detail (a rim is 1.3 mm), and
the engine scale is one number per model.

TWO SOURCES:
  GENERATED here, owned outright: 9mm and .45 ACP cases (rimless: rim, extractor
  groove, body, open mouth with a dark inside, primer), the .357 Magnum case
  (rimmed), and the 12-gauge hull (red plastic on a brass base).
  CUT from Force Unleashed (Ermac, MIT -- licenses/force_unleashed_MIT.txt): the
  chaingun belt round (models/chaingun/cg_ammo10.md3, surface cg_ammo.001) is a real
  bottlenecked rifle cartridge with a modelled rim. Its bullet tip is dropped, the
  case scaled to a 5.56 NATO case's proportions, and the open neck capped dark
  inside. MODELDEF sizes the same mesh for 7.62.

SOLID COLOURS, no texture art (owner, 2026-09-14: the solid-generated look is the
default; texturing is parked). Each part is its own surface with a tiny solid skin.

    python tools/gen_casings.py

Every model is written, read back, written again and BYTE-COMPARED with the first
write -- so the packed normals survive the house reader (md3.py) exactly -- and its
bounds and triangle count are printed.
"""
import math
import os
import sys
import tempfile

sys.path.insert(0, "E:/DOOMWork/tools")
import md3            # noqa: E402  the house reader
import md3_write      # noqa: E402  the house writer
from PIL import Image  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
OUT = os.path.join(PKG, "models", "casings")
FU = "E:/DOOMWork/_old/doom-force-unleashed_devbuild/models/chaingun/cg_ammo10.md3"
MM_PER_UNIT = 30.5
SIDES = 12

SKINS = {
    "casing_brass.png": (184, 142, 68),
    "casing_inner.png": (46, 36, 22),
    "casing_primer.png": (160, 150, 132),
    "shell_hull.png": (150, 28, 24),
    "shell_inner.png": (40, 18, 16),
}


# ------------------------------------------------------------------ building
class Part:
    """One surface: triangles over per-triangle vertices (flat caps) or shared
    ring vertices (smooth sides)."""

    def __init__(self, name, skin):
        self.name, self.skin = name, skin
        self.verts, self.normals, self.tris = [], [], []

    def vert(self, p, n):
        self.verts.append(p)
        self.normals.append(n)
        return len(self.verts) - 1


def ring(x, r, k):
    a = math.tau * k / SIDES
    return (x, r * math.cos(a), r * math.sin(a))


def side_band(part, x0, r0, x1, r1, inward=False):
    """A cone or cylinder band from (x0, r0) to (x1, r1): smooth radial normals."""
    dx, dr = x1 - x0, r1 - r0
    ln = math.hypot(dx, dr) or 1.0
    nx, nr = (-dr / ln, dx / ln)
    if inward:
        nx, nr = -nx, -nr
    a0 = []
    a1 = []
    for k in range(SIDES):
        a = math.tau * k / SIDES
        n = (nx, nr * math.cos(a), nr * math.sin(a))
        a0.append(part.vert(ring(x0, r0, k), n))
        a1.append(part.vert(ring(x1, r1, k), n))
    for k in range(SIDES):
        j = (k + 1) % SIDES
        if inward:
            part.tris += [(a0[k], a1[j], a1[k]), (a0[k], a0[j], a1[j])]
        else:
            part.tris += [(a0[k], a1[k], a1[j]), (a0[k], a1[j], a0[j])]


def annulus(part, x, r_in, r_out, facing):
    """A flat ring at x between two radii, facing +X (1) or -X (-1)."""
    n = (float(facing), 0.0, 0.0)
    inner = [part.vert(ring(x, r_in, k), n) for k in range(SIDES)]
    outer = [part.vert(ring(x, r_out, k), n) for k in range(SIDES)]
    for k in range(SIDES):
        j = (k + 1) % SIDES
        if facing > 0:
            part.tris += [(inner[k], outer[k], outer[j]), (inner[k], outer[j], inner[j])]
        else:
            part.tris += [(inner[k], outer[j], outer[k]), (inner[k], inner[j], outer[j])]


def disc(part, x, r, facing):
    n = (float(facing), 0.0, 0.0)
    c = part.vert((x, 0.0, 0.0), n)
    rim = [part.vert(ring(x, r, k), n) for k in range(SIDES)]
    for k in range(SIDES):
        j = (k + 1) % SIDES
        part.tris.append((c, rim[k], rim[j]) if facing > 0 else (c, rim[j], rim[k]))


def rimless_case(length, rim_r, rim_len, groove_r, groove_len, body_r0, body_r1, wall=0.45, primer_r=None):
    brass = Part("brass", "casing_brass.png")
    inner = Part("inner", "casing_inner.png")
    primer = Part("primer", "casing_primer.png")
    g0, g1 = rim_len, rim_len + groove_len
    side_band(brass, 0.0, rim_r, g0, rim_r)                 # the rim's edge
    annulus(brass, g0, groove_r, rim_r, 1)                  # rim face toward the mouth
    side_band(brass, g0, groove_r, g1, groove_r)            # extractor groove
    annulus(brass, g1, groove_r, body_r0, -1)               # groove up to the body
    side_band(brass, g1, body_r0, length, body_r1)          # the body, a slight taper
    annulus(brass, length, body_r1 - wall, body_r1, 1)      # the mouth's lip
    side_band(inner, length - 6.0, body_r1 - wall, length, body_r1 - wall, inward=True)
    disc(inner, length - 6.0, body_r1 - wall, 1)            # the dark inside, capped
    pr = primer_r or rim_r * 0.35
    annulus(brass, 0.0, pr, rim_r, -1)                      # the head
    disc(primer, -0.05, pr, -1)                             # the primer, just proud
    return [brass, inner, primer]


def rimmed_case(length, rim_r, rim_len, body_r0, body_r1, wall=0.45):
    brass = Part("brass", "casing_brass.png")
    inner = Part("inner", "casing_inner.png")
    primer = Part("primer", "casing_primer.png")
    side_band(brass, 0.0, rim_r, rim_len, rim_r)
    annulus(brass, rim_len, body_r0, rim_r, 1)
    side_band(brass, rim_len, body_r0, length, body_r1)
    annulus(brass, length, body_r1 - wall, body_r1, 1)
    side_band(inner, length - 8.0, body_r1 - wall, length, body_r1 - wall, inward=True)
    disc(inner, length - 8.0, body_r1 - wall, 1)
    pr = rim_r * 0.33
    annulus(brass, 0.0, pr, rim_r, -1)
    disc(primer, -0.05, pr, -1)
    return [brass, inner, primer]


def shotgun_hull(length=70.0, hull_r=10.1, rim_r=11.1, rim_len=1.4, base_len=16.0, wall=0.6):
    base = Part("base", "casing_brass.png")
    hull = Part("hull", "shell_hull.png")
    inner = Part("inner", "shell_inner.png")
    primer = Part("primer", "casing_primer.png")
    side_band(base, 0.0, rim_r, rim_len, rim_r)
    annulus(base, rim_len, hull_r + 0.15, rim_r, 1)
    side_band(base, rim_len, hull_r + 0.15, base_len, hull_r + 0.15)
    annulus(base, base_len, hull_r, hull_r + 0.15, 1)
    side_band(hull, base_len, hull_r, length, hull_r)
    annulus(hull, length, hull_r - wall, hull_r, 1)        # the opened crimp
    side_band(inner, length - 20.0, hull_r - wall, length, hull_r - wall, inward=True)
    disc(inner, length - 20.0, hull_r - wall, 1)
    pr = 2.8
    annulus(base, 0.0, pr, rim_r, -1)
    disc(primer, -0.05, pr, -1)
    return [base, hull, inner, primer]


def fu_rifle_case(case_len=44.7, body_r=4.8):
    """Force Unleashed's belt round: drop the bullet tip, scale to a real case, cap the
    open neck dark inside."""
    m = md3.MD3Model.load(FU)
    s = next(x for x in m.surfaces if x.name == "cg_ammo.001")
    vs, ns = s.verts[0], [md3_write.decode_normal(n) for n in s.normals[0]]
    xs = [v[0] for v in vs]
    x_min, x_max = min(xs), max(xs)
    # The profile (verified 2026-09-14): rim and head at the base, shoulder and neck to
    # 24.40, the bullet from 24.91. Everything past the neck is the bullet.
    neck_end = 24.45
    assert x_min < 19.3 and x_max > 25.4, "cg_ammo.001 is not the shape this cut was measured on"
    cy = sum(v[1] for v in vs) / len(vs)
    cz = sum(v[2] for v in vs) / len(vs)
    sx = case_len / (neck_end - x_min)
    # The body is one long cylinder with no vertices along it: measure where it meets
    # the shoulder (22.86..23.37, radius 0.86 on 2026-09-14's profile).
    body_rs = [math.hypot(v[1] - cy, v[2] - cz) for v in vs if 22.8 < v[0] < 23.4]
    assert body_rs, "no vertices where the body meets the shoulder"
    body_fu = max(body_rs)
    sr = body_r / body_fu
    brass = Part("brass", "casing_brass.png")
    remap = {}
    for (a, b, c) in s.triangles:
        if any(vs[i][0] > neck_end for i in (a, b, c)):
            continue
        tri = []
        for i in (a, b, c):
            if i not in remap:
                v = vs[i]
                n = ns[i]
                p = ((v[0] - x_min) * sx, (v[1] - cy) * sr, (v[2] - cz) * sr)
                nn = (n[0] / sx, n[1] / sr, n[2] / sr)     # normals under a non-uniform scale
                ln = math.sqrt(sum(q * q for q in nn)) or 1.0
                remap[i] = brass.vert(p, tuple(q / ln for q in nn))
            tri.append(remap[i])
        brass.tris.append(tuple(tri))
    mouth_r = max(math.hypot(v[1] - cy, v[2] - cz) for v in vs if 23.9 < v[0] <= neck_end) * sr
    inner = Part("inner", "casing_inner.png")
    disc(inner, case_len - 3.0, mouth_r * 0.92, 1)
    side_band(inner, case_len - 3.0, mouth_r * 0.92, case_len, mouth_r * 0.92, inward=True)
    return [brass, inner]


# ------------------------------------------------------------------ writing
def to_model(parts, name):
    pts = [v for p in parts for v in p.verts]
    c = [sum(v[i] for v in pts) / len(pts) for i in range(3)]
    surfaces = []
    for idx, p in enumerate(parts):
        # Snapped to MD3's 1/64 grid BEFORE the first write: the writer measures a
        # frame's bounds and radius from the positions it is given, so an unsnapped
        # first write and its read-back would measure them differently.
        verts = [tuple(round((v[i] - c[i]) * 64.0) / 64.0 for i in range(3)) for v in p.verts]
        surfaces.append(md3.MD3Surface(
            index=idx, name=p.name, num_frames=1,
            shaders=[md3.MD3Shader(name=p.skin, shader_index=0)],
            triangles=list(p.tris), st=[(0.5, 0.5)] * len(verts),
            verts=[verts], normals=[[md3_write.encode_normal(n) for n in p.normals]]))
    frame = md3.MD3Frame(mins=(0, 0, 0), maxs=(0, 0, 0), origin=(0, 0, 0), radius=0.0, name="rest")
    return md3.MD3Model(source=name, name=name, num_frames=1, frames=[frame], tags=[], surfaces=surfaces)


def write_checked(model, path):
    md3_write.write(model, path)
    back = md3.MD3Model.load(path)
    tmp = os.path.join(tempfile.gettempdir(), "rsb_casing_roundtrip.md3")
    md3_write.write(back, tmp)
    with open(path, "rb") as f1, open(tmp, "rb") as f2:
        a, b = f1.read(), f2.read()
    if a != b:
        raise SystemExit("%s: write -> read -> write is not byte-identical" % path)
    allv = [v for s in back.surfaces for v in s.verts[0]]
    lo = [min(v[i] for v in allv) for i in range(3)]
    hi = [max(v[i] for v in allv) for i in range(3)]
    tris = sum(s.num_triangles for s in back.surfaces)
    radius = max(hi[1] - lo[1], hi[2] - lo[2]) / 2.0
    return tris, [hi[i] - lo[i] for i in range(3)], radius


def main():
    os.makedirs(OUT, exist_ok=True)
    for fn, rgb in SKINS.items():
        Image.new("RGB", (8, 8), rgb).save(os.path.join(OUT, fn))

    models = {
        # 9mm Luger: 19.15 long, 9.93 across the rim
        "casing_9mm": rimless_case(19.15, 4.96, 1.27, 4.0, 0.85, 4.95, 4.83),
        # .45 ACP: 22.8 long, 12.0 across
        "casing_45": rimless_case(22.8, 6.0, 1.25, 5.0, 0.95, 6.0, 5.98),
        # .357 Magnum: 33.0 long, rimmed 11.2, body 9.6
        "casing_357": rimmed_case(33.0, 5.6, 1.5, 4.8, 4.78),
        # 12 gauge: 70 long opened, 20.2 across the hull
        "shell_12ga": shotgun_hull(),
        # rifle: Force Unleashed's belt round, cut and scaled to a 5.56 NATO case
        "casing_rifle": fu_rifle_case(),
    }
    print("%-14s %5s  %-28s %s" % ("model", "tris", "size mm (x, y, z)", "map units long / lying radius"))
    for name, parts in models.items():
        path = os.path.join(OUT, name + ".md3")
        tris, size, radius = write_checked(to_model(parts, name), path)
        print("%-14s %5d  %-28s %.3f u long, %.3f u radius" % (
            name, tris, "%.1f x %.1f x %.1f" % tuple(size), size[0] / MM_PER_UNIT, radius / MM_PER_UNIT))
    print("byte-compared: every model reads back and rewrites identically")


if __name__ == "__main__":
    main()
