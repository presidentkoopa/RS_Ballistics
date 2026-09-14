#!/usr/bin/env python3
"""
import_rocket_voxel.py -- the rocket in flight: Doom's rocket as a voxel model.

SOURCE: RS_Main voxels/MISLA.kvx (owner, 2026-09-14: RS_Main is fair game, and "source the
voxel rocket for in flight"). The same file, byte for byte, is in the DXR engine's own
static resources (wadsrc/static/voxels/MISLA.kvx); neither place records its author.

WHAT IT WRITES (models/rocket/):
  rocket.kvx       the voxel, copied unchanged (its SHA-1 is checked)
  rocket_pal.png   its palette as a 16x16 skin, colour index i at texel (i % 16, i / 16),
                   each 6-bit VGA value expanded to 8 bits exactly as the engine does,
                   (c << 2) | (c >> 4) (voxels.cpp). MODELDEF must name it: a voxel drawn
                   as a model is coloured through that texture, and FVoxelModel binds the
                   skin it is given with no fallback (RS_VRBody's MODELDEF note).

    python tools/import_rocket_voxel.py
"""
import hashlib
import os
import struct

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
SRC = "E:/DOOMWork/RS_Main/voxels/MISLA.kvx"
SRC_MD5 = "f7b380190fbec2d614d45354c0efdaa8"
OUT = os.path.join(PKG, "models", "rocket")


def main():
    with open(SRC, "rb") as f:
        data = f.read()
    md5 = hashlib.md5(data).hexdigest()
    if md5 != SRC_MD5:
        raise SystemExit("%s changed (md5 %s, expected %s)" % (SRC, md5, SRC_MD5))
    sha1 = hashlib.sha1(data).hexdigest()
    numbytes, xs, ys, zs, xp, yp, zp = struct.unpack("<7i", data[:28])
    pal = data[-768:]
    if max(pal) > 63:
        raise SystemExit("the last 768 bytes are not a 6-bit VGA palette")

    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "rocket.kvx"), "wb") as f:
        f.write(data)
    img = Image.new("RGB", (16, 16))
    for i in range(256):
        r, g, b = (pal[i * 3 + k] for k in range(3))
        img.putpixel((i % 16, i // 16), tuple((c << 2) | (c >> 4) for c in (r, g, b)))
    img.save(os.path.join(OUT, "rocket_pal.png"))

    print("rocket.kvx: %d x %d x %d voxels, pivot %.2f %.2f %.2f, sha1 %s" % (
        xs, ys, zs, xp / 256.0, yp / 256.0, zp / 256.0, sha1))
    print("rocket_pal.png: 16x16, 6-bit palette expanded as the engine does")


if __name__ == "__main__":
    main()
