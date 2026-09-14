#!/usr/bin/env python3
"""
import_debris_sounds.py -- the debris landing sounds (engine #11: PARTICLEDEFS `landsound`).

Copies the chosen RS_Main sounds (owner, 2026-09-14: "RS_Main is fair game") into
sounds/rsb/debris/<group>/, names each by its real format, and writes:
  - SNDINFO: rsb/debris/<group> as a $random with a $limit (the engine caps the rest)
  - ASSETS.md: where each copy came from, with the source's SHA-1
Sounds RS_Ballistics already ships are aliased, not copied. Picks were measured
(duration, loudness, brightness) -- see _staged/DEBRIS_SOUNDS_PLAN.md.

Run again safely: identical copies are skipped, and the SNDINFO block and ASSETS
section are written once (between their markers, replaced when present).
"""
import hashlib, os, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAIN = r"E:/DOOMWork/RS_Main/sounds"

# group -> list of (source, kind) where kind is "copy" (from RS_Main) or "alias" (a path already in the package)
GROUPS = {
    "chips":      [(MAIN + "/combatfx/impact/impact6.wav", "copy"), (MAIN + "/combatfx/impact/impact9.mp3", "copy"),
                   (MAIN + "/combatfx/impact/impact5.wav", "copy")],
    "rubble":     [(MAIN + "/ch/ROCKHIT1.wav", "copy"), (MAIN + "/ch/DSMOTHUD.ogg", "copy")],
    "metal":      [(MAIN + "/combatfx/magdrops/DSBOUNC%d.ogg" % i, "copy") for i in range(1, 7)],
    "metal_big":  [(MAIN + "/combatfx/magdrops/DSAOUNC%d.ogg" % i, "copy") for i in (1, 2, 3)]
                  + [(MAIN + "/combatfx/magdrops/DSAOUNC%d" % i, "copy") for i in (4, 5, 6)],
    "nut":        [("sounds/rsb/debris/metal/dsbounc1.ogg", "alias"), ("sounds/rsb/debris/metal/dsbounc3.ogg", "alias"),
                   ("sounds/rsb/debris/metal/dsbounc4.ogg", "alias")],
    "glass":      [("sounds/rsb/glass/dsbottle.ogg", "alias")],
    "glass_big":  [(MAIN + "/combatfx/ice/ice_shatter.ogg", "copy")],
    "dirt":       [(MAIN + "/rs_grenade/GBOUNCE", "copy"), (MAIN + "/rs_gh_weapon/gh_grenade/GRNBNCE", "copy")],
    "dirt_big":   [("sounds/rsb/debris/rubble/dsmothud.ogg", "alias")],
    "wood":       [("sounds/rsb/impact_wood/blt_imp_wood_near_01.ogg", "alias"), ("sounds/rsb/impact_wood/blt_imp_wood_near_02.ogg", "alias"),
                   ("sounds/rsb/impact_wood/blt_imp_wood_near_05.ogg", "alias")],
    "brass_rifle": [(MAIN + "/combatfx/casings/DSRIFLC%d.ogg" % i, "copy") for i in (1, 2, 3)]
                  + [(MAIN + "/combatfx/casings/CHGNCAS2", "copy")],
}
LIMIT = 3
SND_BEGIN = "// ---- BEGIN debris landing sounds (tools/import_debris_sounds.py)"
SND_END = "// ---- END debris landing sounds"
ASSET_BEGIN = "<!-- BEGIN debris landing sounds (tools/import_debris_sounds.py) -->"
ASSET_END = "<!-- END debris landing sounds -->"

def sha1(path):
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()

def real_ext(path):
    ext = os.path.splitext(path)[1].lower()
    if ext in (".ogg", ".wav", ".mp3", ".flac"):
        return ext
    p = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=format_name", "-of", "csv=p=0", path],
                       capture_output=True, text=True)
    name = p.stdout.strip().split(",")[0]
    return {"ogg": ".ogg", "wav": ".wav", "mp3": ".mp3", "flac": ".flac"}.get(name) or sys.exit("unknown format: %s (%s)" % (path, name))

def replace_block(text, begin, end, block, nl):
    if begin in text and end in text:
        a = text.index(begin)
        b = text.index(end) + len(end)
        return text[:a] + block + text[b:]
    return text.rstrip("\r\n") + nl + nl + block + nl

snd_lines, asset_lines = [], []
copied = skipped = 0
for group, items in GROUPS.items():
    names = []
    for i, (src, kind) in enumerate(items, 1):
        if kind == "copy":
            if not os.path.isfile(src):
                sys.exit("missing source %s -- nothing written further" % src)
            base = os.path.splitext(os.path.basename(src))[0].lower()
            rel = "sounds/rsb/debris/%s/%s%s" % (group, base, real_ext(src))
            dst = os.path.join(ROOT, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            if os.path.isfile(dst) and sha1(dst) == sha1(src):
                skipped += 1
            else:
                shutil.copyfile(src, dst)
                copied += 1
            asset_lines.append("- `%s` from `%s` (sha1 %s)" % (rel, src.replace("E:/DOOMWork/", ""), sha1(src)))
        else:
            rel = src
            if not os.path.isfile(os.path.join(ROOT, rel)):
                sys.exit("alias target %s is not in the package -- nothing written further" % rel)
        name = "rsb/debris/%s%d" % (group, i)
        names.append(name)
        snd_lines.append("%-28s %s" % (name, rel))
    snd_lines.append("$random rsb/debris/%s { %s }" % (group, " ".join(names)))
    snd_lines.append("$limit rsb/debris/%s %d" % (group, LIMIT))
    snd_lines.append("")

snd_path = os.path.join(ROOT, "SNDINFO.txt")
raw = open(snd_path, "rb").read()
nl = "\r\n" if b"\r\n" in raw else "\n"
block = nl.join([SND_BEGIN,
                 "// One sound for a GROUP of debris pieces landing (a burst, merged with its neighbours); the",
                 "// PARTICLEDEFS `landsound` names these. Picked by measurement: short, quiet, bright for small pieces.",
                 ""] + snd_lines + [SND_END])
open(snd_path, "wb").write(replace_block(raw.decode("utf-8"), SND_BEGIN, SND_END, block, nl).encode("utf-8"))

asset_path = os.path.join(ROOT, "ASSETS.md")
raw = open(asset_path, "rb").read()
anl = "\r\n" if b"\r\n" in raw else "\n"
ablock = anl.join([ASSET_BEGIN, "## Debris landing sounds (sounds/rsb/debris)", "",
                   "Copied unchanged from RS_Main's sound folders (owner-cleared, 2026-09-14). SHA-1 is of the source.", ""]
                  + asset_lines + [ASSET_END])
open(asset_path, "wb").write(replace_block(raw.decode("utf-8"), ASSET_BEGIN, ASSET_END, ablock, anl).encode("utf-8"))

print("debris sounds: %d copied, %d already there, %d groups, %d SNDINFO entries" %
      (copied, skipped, len(GROUPS), sum(len(v) for v in GROUPS.values())))
