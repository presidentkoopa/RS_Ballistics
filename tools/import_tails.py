#!/usr/bin/env python3
"""
import_tails.py -- gunshot tails (a flash's `tail`, RSB_Tail in flash.zs).

A tail is the room answering a shot: the boom rolling on after the bang. The owner's ART SOURCE
library has player-perspective tails recorded indoors ("int") and under open sky ("ext") for each
kind of gun. This copies the chosen sets unchanged into sounds/rsb/tail/<kind>/<int|ext>/ and writes:
  - SNDINFO: rsb/tail/<kind>/int and rsb/tail/<kind>/ext as $random groups, each file with a $limit
    (a kind with no recording of its own for one side borrows another kind's files, named here)
  - ASSETS.md: where each copy came from, with the source's SHA-1

Run again safely: identical copies are skipped, and the SNDINFO block and ASSETS section are written
once (between their markers, replaced when present).
"""
import glob, hashlib, os, shutil, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = "E:/oldshit/ART SOURCE/SOUNDS/COMBAT/Atmosphere"

# kind -> side -> (source folder under SRC, file pattern) or ("borrow", another kind)
TAILS = {
    "pistol":     {"int": ("int/pistol", "*.ogg"),   "ext": ("ext/pistol", "*.ogg")},
    "pistol_mag": {"int": ("borrow", "pistol"),       "ext": ("ext/pistol_mag", "*.ogg")},
    "shotgun":    {"int": ("int/shotgun", "*.ogg"),  "ext": ("ext/shotgun", "*.ogg")},
    "dbshotgun":  {"int": ("borrow", "shotgun"),      "ext": ("ext/dbshotgun", "*.ogg")},
    "ar":         {"int": ("int/ar", "*.ogg"),       "ext": ("ext/ar", "*.ogg")},
    "lmg":        {"int": ("int/lmg", "*.ogg"),      "ext": ("ext/lmg", "*.ogg")},
    "br":         {"int": ("borrow", "ar"),           "ext": ("ext/br", "*.ogg")},
    "smg":        {"int": ("int/smg", "*.ogg"),      "ext": ("ext/smg", "*.ogg")},
    "rpg":        {"int": ("distant/int/rpg", "*med*.ogg"), "ext": ("distant/ext/rpg", "*med*.ogg")},
}
LIMIT = 2
SND_BEGIN = "// ---- BEGIN gunshot tails (tools/import_tails.py)"
SND_END = "// ---- END gunshot tails"
ASSET_BEGIN = "<!-- BEGIN gunshot tails (tools/import_tails.py) -->"
ASSET_END = "<!-- END gunshot tails -->"


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


names = {}          # (kind, side) -> [sound names]
snd_lines, borrow_lines, asset_lines = [], [], []
copied = skipped = 0
for kind, sides in TAILS.items():
    for side in ("int", "ext"):
        folder, pattern = sides[side]
        if folder == "borrow":
            continue
        files = sorted(glob.glob(os.path.join(SRC, folder, pattern)))
        if not files:
            sys.exit("no files for %s %s in %s -- nothing written further" % (kind, side, folder))
        group = []
        for i, src in enumerate(files, 1):
            rel = "sounds/rsb/tail/%s/%s/%s" % (kind, side, os.path.basename(src).lower())
            dst = os.path.join(ROOT, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            if os.path.isfile(dst) and sha1(dst) == sha1(src):
                skipped += 1
            else:
                shutil.copyfile(src, dst)
                copied += 1
            name = "rsb/tail/%s/%s%d" % (kind, side, i)
            group.append(name)
            snd_lines.append("%-26s %s" % (name, rel))
            snd_lines.append("$limit %s %d" % (name, LIMIT))
            asset_lines.append("- `%s` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/%s/%s` (sha1 %s)"
                               % (rel, folder, os.path.basename(src), sha1(src)))
        names[(kind, side)] = group
        snd_lines.append("$random rsb/tail/%s/%s { %s }" % (kind, side, " ".join(group)))
        snd_lines.append("")
for kind, sides in TAILS.items():
    for side in ("int", "ext"):
        folder, other = sides[side]
        if folder != "borrow":
            continue
        group = names.get((other, side))
        if not group:
            sys.exit("%s %s borrows %s, which has none -- nothing written further" % (kind, side, other))
        borrow_lines.append("$random rsb/tail/%s/%s { %s }   // borrows %s's" % (kind, side, " ".join(group), other))

snd_path = os.path.join(ROOT, "SNDINFO.txt")
raw = open(snd_path, "rb").read()
nl = "\r\n" if b"\r\n" in raw else "\n"
block = nl.join([SND_BEGIN,
                 "// A flash's `tail` names rsb/tail/<kind>; RSB_Tail plays /int under a ceiling, /ext under open sky, and the",
                 "// next shot of the same hand stops it. Recorded player-perspective tails from the owner's ART SOURCE.",
                 ""] + snd_lines + borrow_lines + [SND_END])
open(snd_path, "wb").write(replace_block(raw.decode("utf-8"), SND_BEGIN, SND_END, block, nl).encode("utf-8"))

asset_path = os.path.join(ROOT, "ASSETS.md")
raw = open(asset_path, "rb").read()
anl = "\r\n" if b"\r\n" in raw else "\n"
ablock = anl.join([ASSET_BEGIN, "## Gunshot tails (sounds/rsb/tail)", "",
                   "Copied unchanged from the owner's ART SOURCE library (a permitted asset pool). SHA-1 is of the source.", ""]
                  + asset_lines + [ASSET_END])
open(asset_path, "wb").write(replace_block(raw.decode("utf-8"), ASSET_BEGIN, ASSET_END, ablock, anl).encode("utf-8"))

print("gunshot tails: %d copied, %d already there, %d kinds, %d files" %
      (copied, skipped, len(TAILS), sum(len(g) for g in names.values())))
