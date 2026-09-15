#!/usr/bin/env python3
"""
gen_flipbooks.py -- generated volumetric flipbooks for the compressed particle atlas.

The file format follows "Engine docs/PARTICLE_ATLAS_COMPRESSED_PLAN.md" section 3: one DDS per frame named
<4-letter book><4-digit frame from 0001> under textures/, a DX10 header, dxgiFormat 98 (BC7_UNORM),
miscFlags2 = 2 (premultiplied alpha), a full mip chain of 2x2 box averages of the premultiplied level above,
the art kept inside a transparent border of S/32.

Each book is a 3D density field raymarched front to back, frame by frame (a smoke puff billowing out; a
fireball boiling out and cooling to smoke), lit from above by a within-slice shadow. Generated from fixed
seeds and owned outright.

THE BC7 ENCODER is this file's own: mode 6 only (one subset, RGBA endpoints of 7 bits and a p-bit, 4-bit
indices), principal-axis endpoints refined by least squares. Endpoints are clamped so rgb <= a, which keeps
every decoded texel premultiplied (mode 6 interpolates rgb and a with the same weights). Every level of every
file is re-opened with Pillow -- an independent BC7 decoder -- and checked against the spec.

OUTPUT GOES WHERE --out SAYS. The engine's compressed atlas step is built (cf3dba0d6f): `--out .` from the package
root writes the shipped books into textures/ (whole books at 512 only); previews (--frames, other sizes) go to a
scratch folder. Shipped today: RBVF (rsb_fireball). RBVS waits: its early frames read as a hard ball.

    python tools/gen_flipbooks.py --out <folder> [--books RBVS,RBVF] [--size 512] [--frames N]
                                  [--render PX] [--jobs N] [--sheet preview.png]
"""
import argparse, functools, io, math, os, struct, sys, time
from concurrent.futures import ProcessPoolExecutor

import numpy as np
from PIL import Image

# ---------------------------------------------------------------- noise
LATTICE = 64


@functools.lru_cache(maxsize=4)
def lattice(seed):
    return np.random.Generator(np.random.PCG64(seed)).random((LATTICE, LATTICE, LATTICE)).astype(np.float32)


def value_noise(g, x, y, z):
    xf, yf, zf = np.floor(x), np.floor(y), np.floor(z)
    fx, fy, fz = x - xf, y - yf, z - zf
    ux, uy, uz = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy), fz * fz * (3 - 2 * fz)
    m = LATTICE - 1
    x0, y0, z0 = xf.astype(np.int64) & m, yf.astype(np.int64) & m, zf.astype(np.int64) & m
    x1, y1, z1 = (x0 + 1) & m, (y0 + 1) & m, (z0 + 1) & m
    c00 = g[z0, y0, x0] * (1 - ux) + g[z0, y0, x1] * ux
    c10 = g[z0, y1, x0] * (1 - ux) + g[z0, y1, x1] * ux
    c01 = g[z1, y0, x0] * (1 - ux) + g[z1, y0, x1] * ux
    c11 = g[z1, y1, x0] * (1 - ux) + g[z1, y1, x1] * ux
    return (c00 * (1 - uy) + c10 * uy) * (1 - uz) + (c01 * (1 - uy) + c11 * uy) * uz


def fbm(g, x, y, z, octaves):
    total = np.zeros_like(x)
    amp, freq, norm = 0.5, 1.0, 0.0
    for o in range(octaves):
        total += amp * value_noise(g, x * freq + o * 17.13, y * freq + o * 31.7, z * freq + o * 7.31)
        norm += amp
        amp *= 0.5
        freq *= 2.03
    return total / norm


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------- the books
def march(res, R, slice_fn):
    """Front-to-back raymarch of a volume inside radius ~R. slice_fn(X, Y, z) -> (density, colour (h,w,3) 0..1).
    Returns premultiplied RGBA float (res, res, 4)."""
    a = ((np.arange(res) + 0.5) / res * 2.0 - 1.0).astype(np.float32)
    reach = min(0.97, R * 1.35)
    idx = np.nonzero(np.abs(a) <= reach)[0]
    out = np.zeros((res, res, 4), np.float32)
    if idx.size == 0:
        return out
    sl = slice(idx[0], idx[-1] + 1)
    X, Y = np.meshgrid(a[sl], a[sl])
    steps = max(40, int(res * 0.3))
    zs = np.linspace(reach, -reach, steps).astype(np.float32)
    dz = 2.0 * reach / steps
    T = np.ones_like(X)
    C = np.zeros(X.shape + (3,), np.float32)
    border = smooth(0.94, 0.86, np.maximum(np.abs(X), np.abs(Y)))
    for z in zs:
        dens, col = slice_fn(X, Y, float(z))
        if dens is None:
            continue
        dens = dens * border
        alpha = 1.0 - np.exp(-dens * dz * 3.0)
        C += (T * alpha)[..., None] * col
        T *= 1.0 - alpha
    A = 1.0 - T
    out[sl, sl, 3] = A
    out[sl, sl, :3] = np.minimum(C, A[..., None])
    return out


def smoke_frame(frame, frames, res, seed):
    """RBVS -- a smoke puff: billows up and out, lit from above, breaks up and fades."""
    g = lattice(seed)
    t = frame / max(1, frames - 1)
    R = 0.36 + 0.50 * (1.0 - (1.0 - t) ** 2.4)
    rise, evolve = 0.35 * t, 1.3 * t
    scale = 14.0 * (1.0 - t) ** 1.1 + 0.6
    erode = 0.02 + 0.40 * t ** 1.4
    step_rows = 2.0 / res

    def slice_fn(X, Y, z):
        if abs(z) > R * 1.3:
            return None, None
        Z = np.full_like(X, z)
        wob = fbm(g, X * 1.6 + 11.1, (Y + rise) * 1.6, Z * 1.6 + evolve * 0.5, 2)
        r = np.sqrt(X * X + Y * Y + Z * Z) / (R * (0.75 + 0.5 * wob))
        shape = smooth(1.0, 0.45, r)
        if shape.max() < 1e-4:
            return None, None
        bill = fbm(g, X * 2.6, (Y + rise) * 2.6, Z * 2.6 + evolve, 5)
        dens = np.clip((shape * (0.5 + bill) - 0.52 - erode) * 3.0, 0.0, None) * scale
        light = np.exp(-np.cumsum(dens, axis=0) * step_rows * 6.0)
        grey = 0.32 + 0.68 * light
        return dens, np.repeat(grey[..., None], 3, axis=2)

    return march(res, R, slice_fn)


FIRE_T = np.array([0.2, 0.4, 0.6, 0.8, 1.0], np.float32)
FIRE_R = np.array([0.35, 0.85, 1.0, 1.0, 1.0], np.float32)
FIRE_G = np.array([0.05, 0.20, 0.50, 0.82, 0.97], np.float32)
FIRE_B = np.array([0.02, 0.03, 0.08, 0.30, 0.80], np.float32)


def fireball_frame(frame, frames, res, seed):
    """RBVF -- a fireball: a white-hot core boiling out, cooling through orange and red to rolling smoke."""
    g = lattice(seed)
    t = frame / max(1, frames - 1)
    R = 0.30 + 0.55 * (1.0 - (1.0 - t) ** 3)
    rise, evolve = 0.25 * t, 2.0 * t
    scale = 12.0 * (1.0 - t) ** 0.9 + 0.8
    erode = 0.04 + 0.40 * t ** 1.6
    cool = (1.0 - t) ** 1.6
    step_rows = 2.0 / res

    def slice_fn(X, Y, z):
        if abs(z) > R * 1.3:
            return None, None
        Z = np.full_like(X, z)
        wob = fbm(g, X * 1.8 + 5.5, (Y + rise) * 1.8, Z * 1.8 + evolve * 0.4, 2)
        rr = np.sqrt(X * X + Y * Y + Z * Z) / R
        r = rr / (0.72 + 0.56 * wob)
        shape = smooth(1.0, 0.4, r)
        if shape.max() < 1e-4:
            return None, None
        turb = fbm(g, X * 3.6, (Y + rise) * 3.6, Z * 3.6 + evolve, 5)
        dens = np.clip((shape * (0.55 + turb) - 0.55 - erode) * 3.0, 0.0, None) * scale
        temp = np.clip((1.25 - rr * 1.1) * cool * 1.4 + (turb - 0.5) * 0.9, 0.0, 1.0)
        glow = smooth(0.2, 0.65, temp)[..., None]
        fire = np.dstack([np.interp(temp, FIRE_T, FIRE_R), np.interp(temp, FIRE_T, FIRE_G),
                          np.interp(temp, FIRE_T, FIRE_B)]).astype(np.float32)
        light = np.exp(-np.cumsum(dens, axis=0) * step_rows * 5.0)
        smoke = (0.10 + 0.32 * light)[..., None]
        return dens, fire * glow + smoke * (1.0 - glow)

    return march(res, R, slice_fn)


# prefix -> (frames, renderer, seed, what it is)
BOOKS = {
    "RBVS": (64, smoke_frame, 3100, "volumetric smoke puff"),
    "RBVF": (64, fireball_frame, 3200, "volumetric fireball cooling to smoke"),
}

# ---------------------------------------------------------------- BC7 (mode 6)
W4 = np.array([0, 4, 9, 13, 17, 21, 26, 30, 34, 38, 43, 47, 51, 55, 60, 64], np.int32)


def to_blocks(level):
    side = level.shape[0]
    b = max(1, (side + 3) // 4)
    pad = b * 4 - side
    if pad:
        level = np.pad(level, ((0, pad), (0, pad), (0, 0)), mode="edge")
    return level.reshape(b, 4, b, 4, 4).transpose(0, 2, 1, 3, 4).reshape(b * b, 16, 4)


def quantize(e):
    """Endpoints (N,4) 0..255 -> 7-bit values (N,4) and a p-bit (N,), rgb clamped to <= a."""
    best_q = best_p = best_err = None
    for p in (0, 1):
        q = np.clip(np.rint((e - p) / 2.0), 0, 127).astype(np.int32)
        q[:, :3] = np.minimum(q[:, :3], q[:, 3:4])
        err = ((q * 2 + p - e) ** 2).sum(1)
        if best_err is None:
            best_q, best_p, best_err = q, np.full(len(e), p, np.int32), err
        else:
            take = err < best_err
            best_q = np.where(take[:, None], q, best_q)
            best_p = np.where(take, p, best_p)
            best_err = np.minimum(err, best_err)
    return best_q, best_p


def palette(q0, p0, q1, p1):
    v0 = (q0 * 2 + p0[:, None])[:, None, :]
    v1 = (q1 * 2 + p1[:, None])[:, None, :]
    w = W4[None, :, None]
    return ((64 - w) * v0 + w * v1 + 32) >> 6          # (N,16,4)


def encode_bc7(px):
    """(N,16,4) uint8 premultiplied -> (N,16) uint8 BC7 mode 6 blocks."""
    P = px.astype(np.float32)
    N = len(P)
    mean = P.mean(1)
    X = P - mean[:, None, :]
    cov = np.einsum("nki,nkj->nij", X, X)
    v = np.full((N, 4), 0.5, np.float32)
    for _ in range(8):
        v = np.einsum("nij,nj->ni", cov, v)
        v /= np.maximum(np.linalg.norm(v, axis=1, keepdims=True), 1e-8)
    proj = np.einsum("nki,ni->nk", X, v)
    e0 = np.clip(mean + v * proj.min(1)[:, None], 0, 255)
    e1 = np.clip(mean + v * proj.max(1)[:, None], 0, 255)

    best = None
    for _ in range(3):
        q0, p0 = quantize(e0)
        q1, p1 = quantize(e1)
        pal = palette(q0, p0, q1, p1).astype(np.float32)
        err = ((P[:, :, None, :] - pal[:, None, :, :]) ** 2).sum(-1)     # (N,16,16)
        idx = err.argmin(-1).astype(np.int32)
        tot = np.take_along_axis(err, idx[..., None], -1)[..., 0].sum(1)
        if best is None:
            best = [q0, p0, q1, p1, idx, tot]
        else:
            take = tot < best[5]
            for k, cur in enumerate((q0, p0, q1, p1, idx)):
                shape = (-1,) + (1,) * (cur.ndim - 1)
                best[k] = np.where(take.reshape(shape), cur, best[k])
            best[5] = np.minimum(tot, best[5])
        w = W4[idx].astype(np.float32) / 64.0
        a11, a12, a22 = ((1 - w) ** 2).sum(1), ((1 - w) * w).sum(1), (w * w).sum(1)
        b1 = ((1 - w)[..., None] * P).sum(1)
        b2 = (w[..., None] * P).sum(1)
        det = a11 * a22 - a12 * a12
        ok = (np.abs(det) > 1e-6)[:, None]
        safe = np.where(np.abs(det) > 1e-6, det, 1.0)[:, None]
        e0 = np.clip(np.where(ok, (a22[:, None] * b1 - a12[:, None] * b2) / safe, e0), 0, 255)
        e1 = np.clip(np.where(ok, (a11[:, None] * b2 - a12[:, None] * b1) / safe, e1), 0, 255)

    q0, p0, q1, p1, idx, _ = best
    flip = idx[:, 0] >= 8                                 # the anchor index's top bit must be 0
    q0, q1 = np.where(flip[:, None], q1, q0), np.where(flip[:, None], q0, q1)
    p0, p1 = np.where(flip, p1, p0), np.where(flip, p0, p1)
    idx = np.where(flip[:, None], 15 - idx, idx)

    fields = [(np.full(N, 1 << 6, np.int64), 7)]           # mode 6: six 0 bits, then a 1
    for c in range(4):
        fields += [(q0[:, c], 7), (q1[:, c], 7)]
    fields += [(p0, 1), (p1, 1), (idx[:, 0], 3)]
    fields += [(idx[:, k], 4) for k in range(1, 16)]
    bits = np.zeros((N, 128), np.uint8)
    pos = 0
    for vals, n in fields:
        vals = vals.astype(np.int64)
        for k in range(n):
            bits[:, pos + k] = (vals >> k) & 1
        pos += n
    assert pos == 128
    return np.packbits(bits, axis=1, bitorder="little")


# ---------------------------------------------------------------- DDS
SIGNATURE = (0x42535352, 0x314C4647)     # "RSSB" "GFL1" in Reserved1[9], [10]


def header(side, levels):
    top = max(1, (side + 3) // 4) ** 2 * 16
    h = struct.pack("<4sIIIIIII", b"DDS ", 124, 0x000A1007, side, side, top, 0, levels)
    h += struct.pack("<11I", 0, 0, 0, 0, 0, 0, 0, 0, 0, SIGNATURE[0], SIGNATURE[1])
    h += struct.pack("<II4sIIIII", 32, 0x4, b"DX10", 0, 0, 0, 0, 0)
    h += struct.pack("<IIIII", 0x00401008, 0, 0, 0, 0)
    h += struct.pack("<IIIII", 98, 3, 0, 1, 2)
    assert len(h) == 148
    return h


def mip_chain(img8):
    levels = [img8]
    cur = img8.astype(np.float32)
    while cur.shape[0] > 1:
        cur = (cur[0::2, 0::2] + cur[1::2, 0::2] + cur[0::2, 1::2] + cur[1::2, 1::2]) / 4.0
        levels.append(np.clip(np.rint(cur), 0, 255).astype(np.uint8))
    return levels


def check_file(path, side, src_levels):
    data = open(path, "rb").read()
    levels = int(math.log2(side)) + 1
    payload = sum(max(1, (max(1, side >> i) + 3) // 4) ** 2 * 16 for i in range(levels))
    assert len(data) == 148 + payload, "file size"
    assert data[:148] == header(side, levels), "header bytes"
    assert struct.unpack_from("<I", data, 28)[0] == levels and struct.unpack_from("<I", data, 128)[0] == 98
    assert struct.unpack_from("<I", data, 144)[0] == 2
    Image.open(path).load()                                # Pillow accepts the whole file
    worst, off, psnr = 0, 148, None
    for i in range(levels):
        s = max(1, side >> i)
        nbytes = max(1, (s + 3) // 4) ** 2 * 16
        one = header(s, 1) + data[off:off + nbytes]
        off += nbytes
        dec = np.asarray(Image.open(io.BytesIO(one)).convert("RGBA")).astype(np.int32)
        worst = max(worst, int((dec[..., :3].max(-1) - dec[..., 3]).max()))
        if i == 0:
            mse = ((dec - src_levels[0].astype(np.int32)) ** 2).mean()
            psnr = 99.0 if mse == 0 else 10 * math.log10(255 * 255 / mse)
    assert worst <= 2, "rgb above alpha by %d" % worst
    return psnr, worst


def make_frame(task):
    prefix, frame, frames, size, render, out_dir, seed = task
    _, renderer, _, _ = BOOKS[prefix]
    rgba = renderer(frame, frames, render, seed)
    if render != size:
        chans = [np.asarray(Image.fromarray(rgba[..., c]).resize((size, size), Image.BICUBIC)) for c in range(4)]
        rgba = np.clip(np.dstack(chans), 0.0, 1.0)
        rgba[..., :3] = np.minimum(rgba[..., :3], rgba[..., 3:4])
    img8 = np.clip(np.rint(rgba * 255.0), 0, 255).astype(np.uint8)
    img8[..., :3] = np.minimum(img8[..., :3], img8[..., 3:4])
    levels = mip_chain(img8)
    blob = header(size, len(levels)) + b"".join(encode_bc7(to_blocks(l)).tobytes() for l in levels)
    path = os.path.join(out_dir, "%s%04d.dds" % (prefix, frame + 1))
    with open(path, "wb") as f:
        f.write(blob)
    psnr, worst = check_file(path, size, levels)
    return prefix, frame, psnr, worst


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True, help="folder to write textures/ into (the package root ships them; a scratch folder previews)")
    ap.add_argument("--books", default=",".join(BOOKS))
    ap.add_argument("--size", type=int, default=512, choices=(256, 512, 1024))
    ap.add_argument("--frames", type=int, default=0, help="override every book's frame count (previews)")
    ap.add_argument("--render", type=int, default=0, help="raymarch resolution, upscaled to --size (default: --size)")
    ap.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 2) - 2))
    ap.add_argument("--sheet", default="", help="a preview PNG over grey (every few frames of each book)")
    args = ap.parse_args()
    out = os.path.abspath(os.path.join(args.out, "textures"))
    # THE PACKAGE takes only whole books at the shipping size (the engine's compressed atlas, cf3dba0d6f, wants every
    # frame of a book at one side): a preview (--frames) or another size goes to a scratch folder.
    package = os.path.abspath(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    if out.startswith(package) and (args.frames or args.size != 512):
        sys.exit("--frames or a size other than 512 is a preview: write it to a scratch folder, not the package")
    os.makedirs(out, exist_ok=True)
    render = args.render or args.size
    books = [b.strip().upper() for b in args.books.split(",") if b.strip()]
    tasks = []
    for b in books:
        if b not in BOOKS:
            sys.exit("unknown book %s (have %s)" % (b, ", ".join(BOOKS)))
        frames = args.frames or BOOKS[b][0]
        tasks += [(b, f, frames, args.size, render, out, BOOKS[b][2]) for f in range(frames)]
    start = time.time()
    stats = {}
    with ProcessPoolExecutor(max_workers=args.jobs) as pool:
        for prefix, frame, psnr, worst in pool.map(make_frame, tasks):
            stats.setdefault(prefix, []).append((frame, psnr, worst))
    for b in books:
        rows = sorted(stats[b])
        ps = [p for _, p, _ in rows]
        print("%s: %d frames at %d px -- PSNR min %.1f / mean %.1f dB, rgb over alpha at most %d -- %s"
              % (b, len(rows), args.size, min(ps), sum(ps) / len(ps), max(w for _, _, w in rows), BOOKS[b][3]))
    print("%d files in %.0f s -> %s" % (len(tasks), time.time() - start, out))
    if args.sheet:
        tile = 128
        sheet_rows = []
        for b in books:
            frames = args.frames or BOOKS[b][0]
            pick = sorted(set(int(round(i * (frames - 1) / 7)) for i in range(8)))
            row = []
            for f in pick:
                im = np.asarray(Image.open(os.path.join(out, "%s%04d.dds" % (b, f + 1))).convert("RGBA")).astype(np.float32) / 255
                comp = im[..., :3] + 0.22 * (1 - im[..., 3:4])
                row.append(np.asarray(Image.fromarray(np.clip(comp * 255, 0, 255).astype(np.uint8)).resize((tile, tile), Image.BILINEAR)))
            while len(row) < 8:
                row.append(np.full((tile, tile, 3), 56, np.uint8))
            sheet_rows.append(np.concatenate(row, axis=1))
        Image.fromarray(np.concatenate(sheet_rows, axis=0)).save(args.sheet)
        print("sheet -> " + args.sheet)


if __name__ == "__main__":
    main()
