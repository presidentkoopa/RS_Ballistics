#!/usr/bin/env python3
"""
import_surface_sounds.py -- the surface pass's sounds (_staged/SURFACE_PASS_PLAN.md, section 4).

  rsb/impact/electric  a shot panel or screen shorting out: zaps and sparks, copied unchanged
  rsb/impact/pipe      a shot pipe: each metal hit the package ships, with a burst of steam hiss mixed under it
  rsb/debris/tile      tile shards landing, copied unchanged
  rsb/debris/marble    marble chips landing, copied unchanged

Sources are the owner-cleared pools only: RS_Main's sound folders and E:/oldshit/ART SOURCE. Copies go to
sounds/rsb/..., named by their real format; the pipe hits are mixed with ffmpeg (bit-exact, so every run writes the
same bytes). Writes the SNDINFO block and the ASSETS section between their markers, replaced when present, so it
runs again safely. Each FILE gets its $limit: a $limit on a $random name caps nothing (engine #11 notes).

    python tools/import_surface_sounds.py
"""
import hashlib, os, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAIN = "E:/DOOMWork/RS_Main/sounds"
ART = "E:/oldshit/ART SOURCE/SOUNDS"

COPIES = {   # SNDINFO name -> (folder under sounds/rsb, sources)
    "rsb/impact/electric": ("impact_electric", [MAIN + "/ch/ELECTRO8.wav", MAIN + "/ch/PZAPHIT.ogg", MAIN + "/ch/DSDEVZAP.ogg",
                                                MAIN + "/ch/ELECTRO7.ogg", ART + "/hbgore/SPARKS1.ogg"]),
    "rsb/debris/tile":     ("debris/tile", [ART + "/footstep/tilea/tile2_step%d.ogg" % i for i in range(1, 5)]
                            + [ART + "/Doomguy and Marines/DOOMGUY/Sounds/Footsteps sounds/DSTILE%02d.ogg" % i for i in range(1, 7)]),
    "rsb/debris/marble":   ("debris/marble", [ART + "/footstep/tileb/marble_step%d.ogg" % i for i in range(1, 9)]),
}
# The pipe: the package's own metal hits (sounds/rsb/impact_metal), the flamethrower's hiss under each, turn about.
PIPE_HITS = ["sounds/rsb/impact_metal/blt_imp_metal_thick_near_%02d.ogg" % i for i in range(1, 7)]
PIPE_HISS = [ART + "/COMBAT/WEAPONS/Flamethrower/FlamerHiss2.wav", ART + "/COMBAT/WEAPONS/Flamethrower/FlamerHiss1.ogg"]
# The hiss: 25 ms after the clang, at 0.55, fading out over a second from 0.45 s -- a jet of steam about 1.5 s long.
PIPE_FILTER = ("[0:a]aformat=channel_layouts=mono,aresample=44100[m];"
               "[1:a]aformat=channel_layouts=mono,aresample=44100,atrim=0:1.5,asetpts=PTS-STARTPTS,volume=0.55,"
               "afade=t=in:d=0.02,afade=t=out:st=0.45:d=1.05,adelay=25[h];"
               "[m][h]amix=inputs=2:duration=longest:normalize=0")
LIMIT = 2
SND_BEGIN = "// ---- BEGIN surface pass sounds (tools/import_surface_sounds.py)"
SND_END = "// ---- END surface pass sounds"
ASSET_BEGIN = "<!-- BEGIN surface pass sounds (tools/import_surface_sounds.py) -->"
ASSET_END = "<!-- END surface pass sounds -->"


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
    sys.exit("unknown format: %s" % path)


def replace_block(text, begin, end, block, nl):
    if begin in text and end in text:
        a = text.index(begin)
        b = text.index(end) + len(end)
        return text[:a] + block + text[b:]
    return text.rstrip("\r\n") + nl + nl + block + nl


def short(src):
    return src.replace("E:/DOOMWork/", "").replace("E:/oldshit/", "")


for src in [s for _, (_, ss) in COPIES.items() for s in ss] + PIPE_HISS:
    if not os.path.isfile(src):
        sys.exit("missing source %s -- nothing written" % src)
for rel in PIPE_HITS:
    if not os.path.isfile(os.path.join(ROOT, rel)):
        sys.exit("missing package sound %s -- nothing written" % rel)

snd_lines, asset_lines = [], []
copied = skipped = mixed = 0
for group, (folder, sources) in COPIES.items():
    names = []
    for i, src in enumerate(sources, 1):
        rel = "sounds/rsb/%s/%s%s" % (folder, os.path.splitext(os.path.basename(src))[0].lower(), real_ext(src))
        dst = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.isfile(dst) and sha1(dst) == sha1(src):
            skipped += 1
        else:
            shutil.copyfile(src, dst)
            copied += 1
        asset_lines.append("- `%s` from `%s` (sha1 %s)" % (rel, short(src), sha1(src)))
        name = "%s%d" % (group, i)
        names.append(name)
        snd_lines += ["%-28s %s" % (name, rel), "$limit %s %d" % (name, LIMIT)]
    snd_lines += ["$random %s { %s }" % (group, " ".join(names)), ""]

names = []
for i, hit in enumerate(PIPE_HITS, 1):
    hiss = PIPE_HISS[(i - 1) % len(PIPE_HISS)]
    rel = "sounds/rsb/impact_pipe/pipe_hit%d.ogg" % i
    dst = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    p = subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", os.path.join(ROOT, hit), "-i", hiss, "-filter_complex", PIPE_FILTER,
                        "-c:a", "libvorbis", "-q:a", "5", "-fflags", "+bitexact", "-flags:a", "+bitexact", dst],
                       capture_output=True, text=True)
    if p.returncode != 0:
        sys.exit("ffmpeg failed on %s: %s" % (rel, p.stderr.strip()))
    mixed += 1
    asset_lines.append("- `%s` mixed by this tool from the package's `%s` and `%s` (sha1 %s)" % (rel, hit, short(hiss), sha1(hiss)))
    name = "rsb/impact/pipe%d" % i
    names.append(name)
    snd_lines += ["%-28s %s" % (name, rel), "$limit %s %d" % (name, LIMIT)]
snd_lines += ["$random rsb/impact/pipe { %s }" % " ".join(names), ""]

snd_path = os.path.join(ROOT, "SNDINFO.txt")
raw = open(snd_path, "rb").read()
nl = "\r\n" if b"\r\n" in raw else "\n"
block = nl.join([SND_BEGIN,
                 "// The surface pass: a shot panel or screen shorting, a shot pipe venting steam, tile and marble pieces",
                 "// landing (PARTICLEDEFS `landsound`). RSBDEFS impacts `<family>.tech|screen|pipe` name the first two.",
                 ""] + snd_lines + [SND_END])
open(snd_path, "wb").write(replace_block(raw.decode("utf-8"), SND_BEGIN, SND_END, block, nl).encode("utf-8"))

asset_path = os.path.join(ROOT, "ASSETS.md")
raw = open(asset_path, "rb").read()
anl = "\r\n" if b"\r\n" in raw else "\n"
ablock = anl.join([ASSET_BEGIN, "## Surface pass sounds (sounds/rsb/impact_electric, impact_pipe, debris/tile, debris/marble)", "",
                   "Copied unchanged from RS_Main's sound folders and E:/oldshit/ART SOURCE (the owner-cleared pools), or mixed",
                   "from them (the pipe hits: ffmpeg, filter in tools/import_surface_sounds.py). SHA-1 is of the source.", ""]
                  + asset_lines + [ASSET_END])
open(asset_path, "wb").write(replace_block(raw.decode("utf-8"), ASSET_BEGIN, ASSET_END, ablock, anl).encode("utf-8"))

print("surface sounds: %d copied, %d already there, %d pipe hits mixed" % (copied, skipped, mixed))
