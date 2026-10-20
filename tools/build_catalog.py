#!/usr/bin/env python3
"""Catalogue the RS_Ballistics sprite library: what each sequence actually is.

A sprite here is identified only by its Doom lump name, which says nothing
about what it depicts or which frames belong together. This walks sprites/,
groups frames into effects, and writes a catalogue you can read and look at:

    catalog/CATALOG.md     browsable tables, by category
    catalog/catalog.json   per-frame size, sha1, format, issues
    catalog/sheets/<id>.png  every frame of one effect, laid out in order

Output lives under catalog/ ON PURPOSE. build.ps1 packs sprites/ recursively,
so a contact sheet written next to the art would pack as a sprite lump and
shadow something. catalog/ is not in the build's allowlist.

Also checks, over this package only (--check):
  * two files resolving to one lump name -- inside a single pk3 one of them
    silently wins, and which one is load order, not a decision.
  * frames strict PNG readers reject (see repair_png below).

Re-run after adding art and commit what changes; everything it writes is
generated, never hand-edited.

Doom lump naming, as used here:
    RSE0A0      -> sprite RSE0, frame A, rotation 0
    RSB1A2A8    -> sprite RSB1, frame A rotation 2, mirrored as rotation 8
Rotation 0 means "one image, all angles", so an effect whose frames are all
rotation 0 is an animation sequence; anything else is a rotation set.
"""

import argparse
import collections
import hashlib
import io
import json
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SPRITES = os.path.join(ROOT, "sprites")
OUTDIR = os.path.join(ROOT, "catalog")

SPRITE_EXT = (".png", ".lmp")

# Art that sits directly in sprites/ rather than in a category folder.
ROOT_CATEGORY = "(uncategorised)"


def frame_order(ch):
    """Doom frame letters run A-Z, then [ \\ ] for frames 27-29."""
    return ord(ch.upper()) - ord("A")


def png_size(data):
    # IHDR width/height are two big-endian uint32 at byte 16, right after the
    # 8-byte signature and the chunk length/type.
    return struct.unpack(">II", data[16:24])


def patch_size(data):
    # A raw Doom patch starts with little-endian int16 width, height.
    return struct.unpack("<hh", data[0:4])


def png_chunks(data):
    """Yield (type, offset, length, crc_ok) for each PNG chunk."""
    off = 8
    while off < len(data) - 8:
        (length,) = struct.unpack(">I", data[off : off + 4])
        ctype = data[off + 4 : off + 8]
        body = data[off + 8 : off + 8 + length]
        (stored,) = struct.unpack(">I", data[off + 8 + length : off + 12 + length])
        yield ctype, off, length, (zlib.crc32(ctype + body) & 0xFFFFFFFF) == stored
        off += 12 + length
        if ctype == b"IEND":
            break


def repair_png(data):
    """Return data with every chunk CRC recomputed.

    Some frames carry a `grAb` chunk (Doom's sprite offset record) whose CRC
    was never updated after the offsets were edited. GZDoom does not verify
    chunk CRCs so these load in game, but strict readers -- Pillow included --
    refuse the whole file. Repairing in memory lets us still draw a sheet; the
    file on disk is reported, never silently rewritten.
    """
    out = bytearray(data)
    for ctype, off, length, ok in png_chunks(data):
        if not ok:
            body = bytes(out[off + 8 : off + 8 + length])
            crc = zlib.crc32(ctype + body) & 0xFFFFFFFF
            out[off + 8 + length : off + 12 + length] = struct.pack(">I", crc)
    return bytes(out)


def read_frame(path):
    with open(path, "rb") as fh:
        data = fh.read()
    issues = []
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        w, h = png_size(data)
        kind = "png"
        for ctype, _o, _l, ok in png_chunks(data):
            if not ok:
                issues.append(f"bad-crc:{ctype.decode('latin1')}")
    else:
        w, h = patch_size(data)
        kind = "patch"
        if path.lower().endswith(".png"):
            issues.append("patch-data-named-png")
    return {
        "w": w,
        "h": h,
        "bytes": len(data),
        "sha1": hashlib.sha1(data).hexdigest(),
        "format": kind,
        "issues": issues,
    }


def lump_name(filename):
    """Lump name as GZDoom sees it: basename, extension dropped, uppercased."""
    return os.path.splitext(os.path.basename(filename))[0].upper()


def walk_sprites(base):
    """Yield (abs_path, lump_name) for every sprite file under base."""
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames if d != ".git" and not d.startswith("_")]
        for fn in filenames:
            # Dotfiles are repo plumbing, never art. splitext(".gitignore")
            # reports no extension, so without this they look like raw lumps.
            if fn.startswith("."):
                continue
            ext = os.path.splitext(fn)[1].lower()
            # Extensionless files are raw lumps and count; .md/.py/.txt do not.
            if ext and ext not in SPRITE_EXT:
                continue
            yield os.path.join(dirpath, fn), lump_name(fn)


def scan():
    """Group frames into effects, keyed by (category, sprite id)."""
    effects, skipped = {}, []
    for path, name in walk_sprites(SPRITES):
        rel = os.path.relpath(path, SPRITES).replace("\\", "/")
        parts = rel.split("/")
        category = parts[0] if len(parts) > 1 else ROOT_CATEGORY
        if len(name) < 6:
            skipped.append(rel)
            continue
        info = read_frame(path)
        info.update(
            {
                "lump": name,
                "file": "sprites/" + rel,
                "frame": name[4].upper(),
                "rotation": name[5],
                "mirror": name[6:8] if len(name) >= 8 else None,
            }
        )
        effects.setdefault((category, name[:4]), []).append(info)
    for frames in effects.values():
        frames.sort(key=lambda f: (frame_order(f["frame"]), f["rotation"]))
    return effects, skipped


def effect_entries(effects):
    out = []
    for (category, sprite), frames in sorted(effects.items()):
        kind = "sequence" if {f["rotation"] for f in frames} == {"0"} else "rotations"
        letters = sorted({f["frame"] for f in frames}, key=frame_order)
        out.append(
            {
                "id": sprite,
                "category": category,
                "kind": kind,
                "frame_count": len(frames),
                "frames": letters,
                "span": f"{letters[0]}-{letters[-1]}" if len(letters) > 1 else letters[0],
                "max_size": [max(f["w"] for f in frames), max(f["h"] for f in frames)],
                "bytes": sum(f["bytes"] for f in frames),
                "sheet": f"sheets/{sprite}.png",
                "lumps": [f["lump"] for f in frames],
                "issues": sorted({i for f in frames for i in f["issues"]}),
                "detail": frames,
            }
        )
    return out


def build_sheets(entries, outdir, cell_cap=256):
    try:
        from PIL import Image
    except ImportError:
        print("  ! Pillow not installed, skipping contact sheets", file=sys.stderr)
        return 0
    os.makedirs(outdir, exist_ok=True)
    made = 0
    for e in entries:
        ims = []
        for f in e["detail"]:
            if f["format"] != "png":
                continue  # a raw patch needs a palette we do not carry
            with open(os.path.join(ROOT, f["file"]), "rb") as fh:
                data = fh.read()
            if f["issues"]:
                data = repair_png(data)
            try:
                ims.append(Image.open(io.BytesIO(data)).convert("RGBA"))
            except Exception as exc:  # one bad frame must not lose the sheet
                print(f"  ! {f['file']}: {type(exc).__name__}", file=sys.stderr)
        if not ims:
            continue
        for im in ims:
            if im.width > cell_cap or im.height > cell_cap:
                im.thumbnail((cell_cap, cell_cap), Image.LANCZOS)
        cw = max(i.width for i in ims)
        ch = max(i.height for i in ims)
        cols = min(len(ims), 13)
        rows = (len(ims) + cols - 1) // cols
        pad = 2
        sheet = Image.new("RGBA", (cols * (cw + pad), rows * (ch + pad)), (30, 30, 36, 255))
        for n, im in enumerate(ims):
            x = (n % cols) * (cw + pad) + (cw - im.width) // 2
            y = (n // cols) * (ch + pad) + (ch - im.height) // 2
            sheet.alpha_composite(im, (x, y))
        sheet.save(os.path.join(outdir, f"{e['id']}.png"))
        made += 1
    return made


def write_markdown(entries, path, skipped):
    by_cat = {}
    for e in entries:
        by_cat.setdefault(e["category"], []).append(e)
    total = sum(e["frame_count"] for e in entries)
    lines = [
        "# RS_Ballistics sprite catalogue",
        "",
        f"{len(entries)} effects, {total} frames, {len(by_cat)} categories.",
        "",
        "Generated by `tools/build_catalog.py`. Do not hand-edit: re-run the",
        "script after adding art and commit what it changes.",
        "",
        "`sequence` effects are animations (every frame is rotation 0, one image",
        "for all view angles). `rotations` effects are drawn per view angle.",
        "",
    ]
    for cat in sorted(by_cat):
        items = by_cat[cat]
        lines += [
            f"## {cat}",
            "",
            f"{len(items)} effects, {sum(i['frame_count'] for i in items)} frames.",
            "",
            "| id | kind | frames | span | max size | sheet |",
            "|---|---|---|---|---|---|",
        ]
        for e in items:
            w, h = e["max_size"]
            flag = " ⚠" if e["issues"] else ""
            lines.append(
                f"| `{e['id']}`{flag} | {e['kind']} | {e['frame_count']} | {e['span']} "
                f"| {w}x{h} | [sheet]({e['sheet']}) |"
            )
        lines.append("")

    flagged = [e for e in entries if e["issues"]]
    if flagged:
        lines += [
            "## File integrity",
            "",
            "These load in GZDoom, which does not verify PNG chunk CRCs, but",
            "strict readers reject them. `bad-crc:grAb` means the sprite offset",
            "chunk was edited without recomputing its checksum, so the offsets",
            "themselves are worth re-checking. `patch-data-named-png` means the",
            "file is a raw Doom patch wearing a `.png` extension (harmless to",
            "the lump name, which drops the extension, but it misleads tools).",
            "",
            "| id | category | frames affected | issue |",
            "|---|---|---|---|",
        ]
        for e in sorted(flagged, key=lambda x: (x["category"], x["id"])):
            n = sum(1 for f in e["detail"] if f["issues"])
            lines.append(
                f"| `{e['id']}` | {e['category']} | {n}/{e['frame_count']} "
                f"| {', '.join(e['issues'])} |"
            )
        lines.append("")

    if skipped:
        lines += ["## Not catalogued", "", "Names too short to carry a frame letter and rotation:", ""]
        lines += [f"- `{s}`" for s in sorted(skipped)]
        lines.append("")
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines))


def check(entries):
    """In-package checks: one lump name must mean one file."""
    seen = collections.defaultdict(list)
    for e in entries:
        for f in e["detail"]:
            seen[f["lump"]].append(f["file"])
    dupes = {n: v for n, v in seen.items() if len(v) > 1}
    flagged = [e for e in entries if e["issues"]]
    print(f"  {len(seen)} lump names over {sum(len(v) for v in seen.values())} files")
    print(f"  {len(dupes)} DUPLICATE lump names")
    for n, v in sorted(dupes.items()):
        print(f"    {n}: {', '.join(v)}")
    bad = sum(1 for e in flagged for f in e["detail"] if f["issues"])
    print(f"  {bad} frames with file-integrity issues across {len(flagged)} effects")
    return 1 if dupes else 0


def main():
    ap = argparse.ArgumentParser(description="Catalogue the RS_Ballistics sprites.")
    ap.add_argument("--check", action="store_true", help="only run the in-package checks")
    ap.add_argument("--no-sheets", action="store_true", help="skip contact sheets")
    args = ap.parse_args()

    effects, skipped = scan()
    entries = effect_entries(effects)
    print(f"{len(entries)} effects, {sum(e['frame_count'] for e in entries)} frames")

    if args.check:
        return check(entries)

    os.makedirs(OUTDIR, exist_ok=True)
    with open(os.path.join(OUTDIR, "catalog.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump({"effects": entries, "uncatalogued": sorted(skipped)}, fh, indent=1, sort_keys=True)
        fh.write("\n")
    write_markdown(entries, os.path.join(OUTDIR, "CATALOG.md"), skipped)
    if not args.no_sheets:
        print(f"{build_sheets(entries, os.path.join(OUTDIR, 'sheets'))} contact sheets")
    print("wrote catalog/catalog.json, catalog/CATALOG.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
