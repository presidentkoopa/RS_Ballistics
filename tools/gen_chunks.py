#!/usr/bin/env python3
"""
gen_chunks.py -- 3D debris chunks for RS_Ballistics' mesh particles (engine #10).

MAP UNITS, REAL SIZE. 1 md3 unit = 1 map unit (1 unit = 30.5 mm), the way the `mesh` key
draws a model (`size` 1 = as modelled). The engine's rules (Engine docs/
MESH_PARTICLES_10_IMPL_NOTES.md, "The mesh key"): exactly ONE surface, 1-64 triangles,
3-192 vertices, centred on the origin (it tumbles about it), one small power-of-two skin,
good normals (ambient occlusion reads them), static frame 0.

GENERATED HERE, owned outright, never scavenged (owner answer 6), several shapes a material:
  concrete  angular chips and flat slabs             convex hulls, flat-shaded
  wood      long splinters and a broken plank end    convex hulls, flat-shaded
  metal     bent shards                              two thin plates meeting at a bend
  glass     thin panes                               thin convex plates
  dirt      clods                                    lumpy hulls, smooth-shaded
Each shape comes from a fixed seed, so every run writes the same bytes. ONE WHITE SKIN
(models/debris/chunk.png): the engine multiplies it by a definition's `color`, which gives
the material (the solid-generated look is the default; texturing is parked).

    python tools/gen_chunks.py

Every model is written, read back, written again and BYTE-COMPARED with the first write,
and checked against the engine's triangle, vertex and centring limits.
"""
import math
import os
import random
import sys
import tempfile

sys.path.insert(0, "E:/DOOMWork/tools")
import md3            # noqa: E402  the house reader
import md3_write      # noqa: E402  the house writer
from PIL import Image  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
OUT = os.path.join(PKG, "models", "debris")
SKIN = "models/debris/chunk.png"
MAX_TRIS = 64
MAX_VERTS = 192
GRID = 64.0          # MD3 stores positions on a 1/64 grid


# ------------------------------------------------------------------ vectors
def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def length(a):
    return math.sqrt(dot(a, a))


def unit(a):
    ln = length(a)
    return (a[0] / ln, a[1] / ln, a[2] / ln) if ln > 1e-12 else (0.0, 0.0, 1.0)


# ------------------------------------------------------------------ the hull
def face_normal(P, f):
    return cross(sub(P[f[1]], P[f[0]]), sub(P[f[2]], P[f[0]]))


def hull(P):
    """The convex hull's triangles (i, j, k) over points P, each wound so that
    cross(Pj - Pi, Pk - Pi) points outward (the casings' winding)."""
    n = len(P)
    assert n >= 4, "a hull needs 4 points"
    i0 = 0
    i1 = max(range(n), key=lambda i: length(sub(P[i], P[i0])))
    i2 = max(range(n), key=lambda i: length(cross(sub(P[i1], P[i0]), sub(P[i], P[i0]))))
    nrm = cross(sub(P[i1], P[i0]), sub(P[i2], P[i0]))
    i3 = max(range(n), key=lambda i: abs(dot(nrm, sub(P[i], P[i0]))))
    assert abs(dot(nrm, sub(P[i3], P[i0]))) > 1e-9, "the points are flat"
    centre = tuple(sum(P[i][k] for i in (i0, i1, i2, i3)) / 4.0 for k in range(3))

    def outward(f):
        return f if dot(face_normal(P, f), sub(P[f[0]], centre)) > 0 else (f[0], f[2], f[1])

    faces = [outward(f) for f in ((i0, i1, i2), (i0, i1, i3), (i0, i2, i3), (i1, i2, i3))]
    for p in range(n):
        if p in (i0, i1, i2, i3):
            continue
        visible = [f for f in faces if dot(face_normal(P, f), sub(P[p], P[f[0]])) > 1e-9]
        if not visible:
            continue
        edges = set()
        for a, b, c in visible:
            edges.update(((a, b), (b, c), (c, a)))
        horizon = [e for e in edges if (e[1], e[0]) not in edges]
        faces = [f for f in faces if f not in visible] + [(u, v, p) for u, v in horizon]
    return faces


# ------------------------------------------------------------------ building
class Mesh:
    def __init__(self):
        self.verts, self.normals, self.tris = [], [], []

    def flat(self, P, faces):
        """Faceted: each triangle its own three vertices and its face normal."""
        for f in faces:
            n = face_normal(P, f)
            if length(n) < 1e-9:
                continue
            n = unit(n)
            base = len(self.verts)
            self.verts += [P[f[0]], P[f[1]], P[f[2]]]
            self.normals += [n, n, n]
            self.tris.append((base, base + 1, base + 2))

    def smooth(self, P, faces):
        """Rounded: shared vertices, normals averaged over the faces around them."""
        faces = [f for f in faces if length(face_normal(P, f)) > 1e-9]
        used = sorted({i for f in faces for i in f})
        remap = {i: len(self.verts) + k for k, i in enumerate(used)}
        acc = {i: (0.0, 0.0, 0.0) for i in used}
        for f in faces:
            n = face_normal(P, f)
            for i in f:
                acc[i] = add(acc[i], n)
        for i in used:
            self.verts.append(P[i])
            self.normals.append(unit(acc[i]))
        self.tris += [(remap[a], remap[b], remap[c]) for a, b, c in faces]


def centred_on_grid(point_sets):
    """Every set moved so the union's bounds centre is the origin, snapped to MD3's grid
    BEFORE the hull (so the first write and its read-back measure the same), duplicates
    dropped."""
    allp = [p for s in point_sets for p in s]
    lo = [min(p[i] for p in allp) for i in range(3)]
    hi = [max(p[i] for p in allp) for i in range(3)]
    c = [(lo[i] + hi[i]) / 2.0 for i in range(3)]
    out = []
    for s in point_sets:
        seen, q = set(), []
        for p in s:
            t = tuple(round((p[i] - c[i]) * GRID) / GRID for i in range(3))
            if t not in seen:
                seen.add(t)
                q.append(t)
        out.append(q)
    return out


def on_sphere(rng):
    u = rng.uniform(-1.0, 1.0)
    t = rng.uniform(0.0, math.tau)
    s = math.sqrt(1.0 - u * u)
    return (s * math.cos(t), s * math.sin(t), u)


def blob(rng, n, rx, ry, rz, jitter):
    pts = []
    for _ in range(n):
        d = on_sphere(rng)
        r = 1.0 - jitter * rng.random()
        pts.append((d[0] * rx * r, d[1] * ry * r, d[2] * rz * r))
    return pts


# ------------------------------------------------------------------ the shapes
def chip(seed):
    """Concrete: an angular chip, 2-4 cm."""
    rng = random.Random(seed)
    (P,) = centred_on_grid([blob(rng, 11, rng.uniform(0.35, 0.6), rng.uniform(0.3, 0.55), rng.uniform(0.25, 0.5), 0.45)])
    m = Mesh()
    m.flat(P, hull(P))
    return m


def slab(seed):
    """Concrete: a flat broken slab, about 5 cm across."""
    rng = random.Random(seed)
    (P,) = centred_on_grid([blob(rng, 12, rng.uniform(0.8, 1.0), rng.uniform(0.6, 0.8), rng.uniform(0.18, 0.25), 0.3)])
    m = Mesh()
    m.flat(P, hull(P))
    return m


def splinter(seed):
    """Wood: a long thin splinter, tapering to points, 6-9 cm."""
    rng = random.Random(seed)
    half = rng.uniform(1.0, 1.5)
    w = rng.uniform(0.12, 0.18)
    pts = [(-half, rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03)),
           (half, rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03))]
    for _ in range(9):
        x = rng.uniform(-half * 0.8, half * 0.8)
        taper = 1.0 - 0.7 * (abs(x) / half) ** 2
        pts.append((x, rng.uniform(-w, w) * taper, rng.uniform(-w * 0.6, w * 0.6) * taper))
    (P,) = centred_on_grid([pts])
    m = Mesh()
    m.flat(P, hull(P))
    return m


def plank(seed):
    """Wood: a plank end, square at one end and broken jagged at the other, about 5 cm."""
    rng = random.Random(seed)
    pts = [(-0.8, y, z) for y in (-0.45, 0.45) for z in (-0.22, 0.22)]
    for _ in range(7):
        pts.append((rng.uniform(0.25, 0.85), rng.uniform(-0.45, 0.45), rng.uniform(-0.22, 0.22)))
    (P,) = centred_on_grid([pts])
    m = Mesh()
    m.flat(P, hull(P))
    return m


def bent(seed):
    """Metal: a torn shard bent at a crease -- two thin plates meeting at the bend."""
    rng = random.Random(seed)
    t = 0.035
    angle = math.radians(rng.uniform(25.0, 45.0))

    def plate(x0, x1):
        pts = []
        for _ in range(5):
            x, y = rng.uniform(x0, x1), rng.uniform(-0.35, 0.35)
            pts += [(x, y, -t), (x, y, t)]
        for y in (-0.3, 0.3):   # both plates share the crease line
            pts += [(0.0, y, -t), (0.0, y, t)]
        return pts

    a = plate(-0.6, 0.0)
    b = [(x * math.cos(angle) - z * math.sin(angle), y, x * math.sin(angle) + z * math.cos(angle))
         for x, y, z in plate(0.0, 0.55)]
    A, B = centred_on_grid([a, b])
    m = Mesh()
    m.flat(A, hull(A))
    m.flat(B, hull(B))
    return m


def pane(seed):
    """Glass: a thin shard of pane, 2-3 cm."""
    rng = random.Random(seed)
    t = 0.02
    pts = []
    for _ in range(rng.randint(3, 5)):
        a = rng.uniform(0.0, math.tau)
        r = rng.uniform(0.3, 0.55)
        x, y = r * math.cos(a), r * math.sin(a)
        pts += [(x, y, -t), (x, y, t)]
    (P,) = centred_on_grid([pts])
    m = Mesh()
    m.flat(P, hull(P))
    return m


def clod(seed):
    """Dirt: a rounded lumpy clod, 2-4 cm."""
    rng = random.Random(seed)
    (P,) = centred_on_grid([blob(rng, 14, rng.uniform(0.4, 0.6), rng.uniform(0.4, 0.6), rng.uniform(0.35, 0.5), 0.3)])
    m = Mesh()
    m.smooth(P, hull(P))
    return m


SHAPES = [
    ("concrete/chip1", chip, 101), ("concrete/chip2", chip, 102), ("concrete/chip3", chip, 103), ("concrete/chip4", chip, 104),
    ("concrete/slab1", slab, 111), ("concrete/slab2", slab, 112),
    ("wood/splinter1", splinter, 201), ("wood/splinter2", splinter, 202), ("wood/splinter3", splinter, 203),
    ("wood/plank1", plank, 211),
    ("metal/shard1", bent, 301), ("metal/shard2", bent, 302), ("metal/shard3", bent, 303),
    ("glass/shard1", pane, 401), ("glass/shard2", pane, 402), ("glass/shard3", pane, 403),
    ("dirt/clod1", clod, 501), ("dirt/clod2", clod, 502), ("dirt/clod3", clod, 503),
]


# ------------------------------------------------------------------ writing
def to_model(m, name):
    surface = md3.MD3Surface(
        index=0, name="chunk", num_frames=1,
        shaders=[md3.MD3Shader(name=SKIN, shader_index=0)],
        triangles=list(m.tris), st=[(0.5, 0.5)] * len(m.verts),
        verts=[list(m.verts)], normals=[[md3_write.encode_normal(n) for n in m.normals]])
    frame = md3.MD3Frame(mins=(0, 0, 0), maxs=(0, 0, 0), origin=(0, 0, 0), radius=0.0, name="rest")
    return md3.MD3Model(source=name, name=name, num_frames=1, frames=[frame], tags=[], surfaces=[surface])


def write_checked(model, path):
    md3_write.write(model, path)
    back = md3.MD3Model.load(path)
    tmp = os.path.join(tempfile.gettempdir(), "rsb_chunk_roundtrip.md3")
    md3_write.write(back, tmp)
    with open(path, "rb") as f1, open(tmp, "rb") as f2:
        if f1.read() != f2.read():
            raise SystemExit("%s: write -> read -> write is not byte-identical" % path)
    if len(back.surfaces) != 1:
        raise SystemExit("%s: %d surfaces, the engine takes exactly one" % (path, len(back.surfaces)))
    s = back.surfaces[0]
    if not (1 <= s.num_triangles <= MAX_TRIS):
        raise SystemExit("%s: %d triangles, the engine takes 1-%d" % (path, s.num_triangles, MAX_TRIS))
    v = s.verts[0]
    if not (3 <= len(v) <= MAX_VERTS):
        raise SystemExit("%s: %d vertices, the engine takes 3-%d" % (path, len(v), MAX_VERTS))
    lo = [min(p[i] for p in v) for i in range(3)]
    hi = [max(p[i] for p in v) for i in range(3)]
    size = [hi[i] - lo[i] for i in range(3)]
    diameter = length(tuple(size))
    off = length(tuple((hi[i] + lo[i]) / 2.0 for i in range(3)))
    if off > 0.1 * diameter:
        raise SystemExit("%s: its bounds centre is %.3f off the origin (over 10%% of %.3f)" % (path, off, diameter))
    return s.num_triangles, len(v), size, diameter


def main():
    os.makedirs(OUT, exist_ok=True)
    Image.new("RGB", (8, 8), (255, 255, 255)).save(os.path.join(OUT, "chunk.png"))
    print("%-16s %4s %5s  %-22s %s" % ("chunk", "tris", "verts", "size (map units)", "diameter"))
    for name, build, seed in SHAPES:
        path = os.path.join(OUT, name + ".md3")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        tris, verts, size, diameter = write_checked(to_model(build(seed), name), path)
        print("%-16s %4d %5d  %-22s %.2f u (%.0f mm)" % (
            name, tris, verts, "%.2f x %.2f x %.2f" % tuple(size), diameter, diameter * 30.5))
    print("byte-compared: every chunk reads back and rewrites identically; one surface, within the engine's limits")


if __name__ == "__main__":
    main()
