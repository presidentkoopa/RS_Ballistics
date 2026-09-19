#!/usr/bin/env python3
"""
gen_shotout.py -- a shot-out version of every lamp texture in the IWADs.

WHY THIS PACKAGE EXISTS AT ALL. RS_Ballistics can already take a room's light away when you shoot its
lamps, but a Doom lamp texture is just a PICTURE of a lamp -- it emits nothing, so when the sector
dims, the picture dims with the walls and you are left looking at a working lamp in a dark room. The
owner, 2026-09-18: "why does a dead lamp look lit?" and "the textures i shoot should get visible
darker". This makes the broken one.

AND IT IS ITS OWN PK3 ON PURPOSE (the owner's call). The dependency points one way: RS_Ballistics does
the SWAP and this package holds the ART. Without this loaded, `TexMan.CheckForTexture` simply fails to
find the broken name and no swap happens -- no errors, no missing-texture squares, the room just dims
as before. And IWAD-derived art stays out of a general effects engine.

DERIVED FROM THE IWADs, so it stays local. These are id's pixels, darkened and broken: fine for the
owner's own machine, and NOT something to distribute. Same rule as the rest of this tree.

GENERATED, NOT DRAWN, and that is the point. Twenty-five hand-drawn variants rot the moment a PWAD
brings its own light textures; a generator covers anything tagged, including names nobody has seen.

HOW ONE IS MADE, from the texture's own pixels and a seed taken from its name, so a given texture
always produces the same broken version:
  1. THE LIT ELEMENT is found by luminance -- the bright part IS the lamp, the rest is its housing.
  2. The lit element is crushed to a fraction of its brightness and pushed toward neutral: a dead
     tube is dark grey-brown, not a dim version of its colour. A red lamp that dies red still reads
     as working.
  3. The housing is darkened much less, so the fixture is still visibly there in a lit room.
  4. A scorch is blown out from the middle of the lit area with a soft falloff.
  5. A few cracks are drawn across the lit element, dark and thin.

    python tools/gen_shotout.py            # write what is missing
    python tools/gen_shotout.py --force    # rewrite every texture
    python tools/gen_shotout.py --check    # say what it would do, write nothing

Writes textures/<NAME>_OUT.png and the TEXTURES lump that names them. ASSETS.md records every source.
"""
import argparse
import hashlib
import os
import re
import struct
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
# Folded into RS_Ballistics (owner, 2026-09-18: "FOLD IT INTO BALLISTICS"). The 23 broken lamps were
# briefly their own package; one pk3 fewer to load and one fewer line in a load order to forget.
OUT = os.path.join(PKG, "textures")

S = "D:/SteamLibrary/steamapps/Common/DooM VR/___Sourceport/"
WADS = [("DOOM", S + "doom.wad"), ("DOOM2", S + "doom2.wad"),
        ("TNT", S + "TNT.WAD"), ("PLUTONIA", S + "PLUTONIA.WAD")]
LAMPISH = re.compile(r"LITE|LAMP|LIGHT|GLOW", re.I)

# Looked at and NOT made broken: LITEMET and LITESTON are lit TRIM rather than lamps -- they are not in
# RS_Ballistics' fixture list either, so nothing would ever swap them, and a scorched strip of skirting
# would be a lie.
SKIP = {"LITEMET", "LITESTON"}

# THE LIT ELEMENT IS FOUND BY VALUE, NOT LUMINANCE, and the first attempt got this wrong in a way
# worth recording: perceived brightness weights blue at 0.114 and red at 0.299, so a saturated blue
# or red lamp scored FAR below any sensible threshold and was treated as housing -- every coloured
# lamp in the game came out still glowing. A lamp is the brightest thing in its own texture whatever
# its hue, so the measure is max(r,g,b), and the threshold is RELATIVE to each texture so a dim
# fixture (TEKLITE) is judged against itself rather than against a white strip light.
LIT_FLOOR = 0.40     # nothing dimmer than this is ever the lamp
LIT_OF_MAX = 0.66    # ...and it has to be this share of the brightest thing in its own texture
LIT_KEEP = 0.16      # what is left of the lit element once it is dead
HOUSING_KEEP = 0.72  # the frame stays visible: a broken lamp is still a lamp
NEUTRAL = 0.65       # how far a dead element is pushed toward grey (a dead red tube is not red)


# ---------------------------------------------------------------- the WAD
def load(path):
    d = open(path, "rb").read()
    magic, n, off = struct.unpack("<4sII", d[:12])
    ent, order = {}, []
    for i in range(n):
        e = off + i * 16
        lo, sz, nm = struct.unpack("<II8s", d[e:e + 16])
        nm = nm.rstrip(b"\0").decode("ascii", "replace")
        ent.setdefault(nm, (lo, sz))
        order.append(nm)
    return d, ent, order


def lamps_in(path):
    """Every lamp-ish wall texture and flat in one IWAD, composed to RGBA."""
    d, ent, order = load(path)
    L = lambda nm: d[ent[nm][0]:ent[nm][0] + ent[nm][1]]
    pal = L("PLAYPAL")[:768]
    PAL = [(pal[i * 3], pal[i * 3 + 1], pal[i * 3 + 2]) for i in range(256)]
    pn = L("PNAMES")
    cnt = struct.unpack("<I", pn[:4])[0]
    pnames = [pn[4 + i * 8:12 + i * 8].rstrip(b"\0").decode("ascii", "replace").upper() for i in range(cnt)]

    def picture(raw):
        w, h = struct.unpack("<HH", raw[:4])
        cols = struct.unpack("<%dI" % w, raw[8:8 + 4 * w])
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        px = im.load()
        for x in range(w):
            p = cols[x]
            while raw[p] != 0xFF:
                top, run = raw[p], raw[p + 1]
                p += 3
                for y in range(run):
                    yy = top + y
                    if 0 <= yy < h:
                        px[x, yy] = PAL[raw[p + y]] + (255,)
                p += run + 1
        return im

    out = {}
    for tl in ("TEXTURE1", "TEXTURE2"):
        if tl not in ent:
            continue
        b = L(tl)
        c = struct.unpack("<I", b[:4])[0]
        for o in struct.unpack("<%dI" % c, b[4:4 + 4 * c]):
            nm = b[o:o + 8].rstrip(b"\0").decode("ascii", "replace").upper()
            if not LAMPISH.search(nm) or nm in SKIP:
                continue
            w, h = struct.unpack("<HH", b[o + 12:o + 16])
            npp = struct.unpack("<H", b[o + 20:o + 22])[0]
            im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            for k in range(npp):
                ox, oy, pi = struct.unpack("<hhH", b[o + 22 + k * 10:o + 28 + k * 10])
                p = pnames[pi]
                if p in ent:
                    try:
                        im.alpha_composite(picture(L(p)), (max(0, ox), max(0, oy)))
                    except Exception:
                        pass
            out[nm] = im

    inflats = False
    for nm in order:
        if nm in ("F_START", "FF_START"):
            inflats = True
            continue
        if nm in ("F_END", "FF_END"):
            inflats = False
            continue
        if inflats and ent[nm][1] >= 4096 and LAMPISH.search(nm) and nm not in SKIP:
            b = L(nm)
            im = Image.new("RGBA", (64, 64))
            px = im.load()
            for i in range(4096):
                px[i % 64, i // 64] = PAL[b[i]] + (255,)
            out[nm] = im
    return out


# ---------------------------------------------------------------- the break
def shoot_out(name, src):
    rng = hashlib.sha1(name.encode()).digest()
    seq = [b / 255.0 for b in rng]
    im = src.convert("RGBA")
    w, h = im.size
    px = im.load()

    # THE BAR IS THE 97th PERCENTILE, NOT THE MAXIMUM. Using the brightest pixel let a single
    # specular speck set the threshold for the whole texture: TEKLITE and TEKLITE2 came back with SIX
    # and SIXTEEN lit pixels out of 64x128 and were visibly unchanged. A percentile ignores the speck
    # and finds the panel.
    vals = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a:
                vals.append(max(r, g, b) / 255.0)
    vals.sort()
    peak = vals[int(len(vals) * 0.97)] if vals else 0.0
    cut = max(LIT_FLOOR, peak * LIT_OF_MAX)

    lit = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if max(r, g, b) / 255.0 >= cut:
                lit.append((x, y))
                grey = (r + g + b) / 3.0
                r = r + (grey - r) * NEUTRAL
                g = g + (grey - g) * NEUTRAL
                b = b + (grey - b) * NEUTRAL
                px[x, y] = (int(r * LIT_KEEP), int(g * LIT_KEEP), int(b * LIT_KEEP), a)
            else:
                px[x, y] = (int(r * HOUSING_KEEP), int(g * HOUSING_KEEP), int(b * HOUSING_KEEP), a)

    if lit:
        cx = sum(p[0] for p in lit) / len(lit)
        cy = sum(p[1] for p in lit) / len(lit)
        reach = max(6.0, (w + h) * 0.18)
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                dist = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                k = max(0.0, 1.0 - dist / reach)
                if k > 0:
                    f = 1.0 - 0.55 * k * k
                    px[x, y] = (int(r * f), int(g * f), int(b * f), a)

        dr = ImageDraw.Draw(im)
        for c in range(3):
            a0 = seq[c * 4] * 6.283
            ln = reach * (0.7 + 0.8 * seq[c * 4 + 1])
            x0 = cx + (seq[c * 4 + 2] - 0.5) * reach * 0.5
            y0 = cy + (seq[c * 4 + 3] - 0.5) * reach * 0.5
            import math
            dr.line([(x0 - math.cos(a0) * ln, y0 - math.sin(a0) * ln),
                     (x0 + math.cos(a0) * ln, y0 + math.sin(a0) * ln)], fill=(14, 12, 12, 255), width=1)
    return im


def nl_join(rows):
    return chr(10).join(rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    found, sources = {}, {}
    for tag, path in WADS:
        if not os.path.isfile(path):
            print("missing IWAD, skipped: %s (%s)" % (tag, path))
            continue
        for nm, im in lamps_in(path).items():
            if nm not in found:
                found[nm] = im
                sources[nm] = [tag]
            else:
                sources[nm].append(tag)
    if not found:
        sys.exit("no lamp textures found in any IWAD")

    if not args.check:
        os.makedirs(OUT, exist_ok=True)
    wrote = skipped = 0
    assets = []
    for nm in sorted(found):
        out_name = "%s_OUT.png" % nm
        dst = os.path.join(OUT, out_name)
        if args.check:
            print("%-12s %-3dx%-3d  %s  -> %s" % (nm, found[nm].width, found[nm].height,
                                                  "+".join(sources[nm]), out_name))
        elif args.force or not os.path.isfile(dst):
            shoot_out(nm, found[nm]).save(dst)
            wrote += 1
        else:
            skipped += 1
        assets.append("- `textures/%s` -- %s shot out, generated by tools/gen_shotout.py from the IWAD's own "
                      "`%s` (%s)" % (out_name, nm, nm, "+".join(sources[nm])))

    if args.check:
        print("\n%d lamp textures would be written" % len(found))
        return

    # ASSETS.md IS SHARED NOW. This tool used to own a package of its own and wrote the whole file;
    # folded into RS_Ballistics it must write only its own block, between markers, or it would erase
    # the record of every sound and sprite the package has imported.
    BEGIN = "<!-- BEGIN shot-out lamps (tools/gen_shotout.py) -->"
    END = "<!-- END shot-out lamps -->"
    body = nl_join([BEGIN, "",
                    "Derived from the IWADs on this machine -- id Software's own lamp textures, darkened and",
                    "broken. For this install, NOT for distribution, the same rule as the rest of the tree.",
                    ""] + assets + ["", END])
    path = os.path.join(PKG, "ASSETS.md")
    with open(path, "r", encoding="utf-8", newline="") as f:
        text = f.read()
    if BEGIN in text and END in text:
        a = text.index(BEGIN)
        b = text.index(END) + len(END)
        text = text[:a] + body + text[b:]
    else:
        text = text.rstrip(chr(13) + chr(10)) + chr(10) * 2 + body + chr(10)
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    print("%d written, %d already there; ASSETS.md updated, no TEXTURES lump needed" % (wrote, skipped))


main()
