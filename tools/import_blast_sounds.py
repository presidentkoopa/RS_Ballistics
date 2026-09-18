#!/usr/bin/env python3
"""
import_blast_sounds.py -- the blast layer: what an explosion sounds like, and the room answering it.

RS_Ballistics had a sound for every bullet hit and no sound of its own for a BLAST. A rocket or a
charge borrowed whatever its actor played and nothing rolled off the walls afterwards. This brings
four groups out of RS_Main's combat effects (owner, 2026-09-14: "RS_Main is fair game"):

  rsb/blast/small   a sharp crack, about a second      a flashbang, a stun charge
  rsb/blast/med     a body with a snap, about two      a frag, a rocket, a grenade
  rsb/blast/big     a deep, long boom, three to four   a demolition charge (C4)
  rsb/blast/roll    THE ROOM ANSWERING a blast, with 180 ms of silence at its head so it arrives
                    after the crack, the way a real one rolls back off the walls

The roll is the point. A near blast is a crack plus the roll; a far one is mostly roll, because the
crack attenuates faster than the low rumble does -- so distance changes the *shape* of an explosion,
not just its volume, with no per-listener code (an impact's `tail`, RSB_Impact).

EVERY FILE IS RE-ENCODED, never copied: sources are 22, 44 and 48 kHz, some of them stereo, and a
stereo sound cannot be positioned in the world -- GZDoom plays it flat. ffmpeg downmixes to one
channel and writes Vorbis q6, keeping the source's sample rate. The roll also gets its silent head.

    python tools/import_blast_sounds.py            # write what is missing, never overwrite
    python tools/import_blast_sounds.py --check    # say what would be written, write nothing
    python tools/import_blast_sounds.py --force    # re-encode everything

SNDINFO gets the four $random groups between its markers; ASSETS.md records every source and its
SHA-1. Both blocks are rewritten in place when they are already there, so a re-run is safe.
"""
import argparse
import hashlib
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
OUTDIR = os.path.join(PKG, "sounds", "rsb", "blast")
SRC = "E:/DOOMWork/RS_Main/sounds/combatfx/explosions"

# group -> (what it is, head silence in ms, [source file names])
#
# Looked at and NOT taken: BFGEXPL1-4 (an energy blast -- the BFG's own hit already brings its
# sound, and nothing else asks for one yet), DISTEXP2 and DISTEXP4 (the same roll as 1 and 3 with
# less body), the ricochet, tracer and impact sets (we ship 16 ricochets, 24 whizzes, 24 cracks and
# the whole surface pass).
GROUPS = [
    ("small", "a sharp crack: a flashbang, a stun charge", 0,
     ["PLEXP1", "PLEXP2", "PLEXP3"]),
    ("med", "a blast with a snap on it: a frag, a rocket, a grenade", 0,
     ["BA_EXP01.ogg", "BA_EXP02", "BA_EXP03", "REXP01.ogg", "REXP02.ogg"]),
    ("big", "a deep, long boom: a demolition charge", 0,
     ["Explode1.wav", "Explode2.wav", "RLANEXPL"]),
    ("roll", "the room answering a blast, arriving 180 ms after it", 180,
     ["DISTEXP1", "DISTEXP3", "DISTEXP5"]),
]
LIMIT = 3

SND_BEGIN = "// ---- BEGIN blast sounds (tools/import_blast_sounds.py)"
SND_END = "// ---- END blast sounds"
ASSET_BEGIN = "<!-- BEGIN blast sounds (tools/import_blast_sounds.py) -->"
ASSET_END = "<!-- END blast sounds -->"


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


def encode(src, dst, delay_ms):
    cmd = ["ffmpeg", "-y", "-v", "error", "-i", src, "-ac", "1"]
    if delay_ms > 0:
        cmd += ["-af", "adelay=%d" % delay_ms]
    cmd += ["-c:a", "libvorbis", "-q:a", "6", dst]
    subprocess.run(cmd, check=True)


def duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                          "-of", "default=nw=1:nk=1", path], check=True, capture_output=True, text=True)
    return float(out.stdout.strip())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    if not shutil.which("ffmpeg") or not shutil.which("ffprobe"):
        sys.exit("ffmpeg and ffprobe have to be on PATH")
    if not os.path.isdir(SRC):
        sys.exit("no source folder: " + SRC)

    if not args.check:
        os.makedirs(OUTDIR, exist_ok=True)

    snd, assets = [SND_BEGIN, ""], [ASSET_BEGIN, ""]
    wrote = skipped = 0
    for group, what, delay_ms, files in GROUPS:
        names = []
        snd.append("// %s" % what)
        for i, fn in enumerate(files, 1):
            src = os.path.join(SRC, fn)
            if not os.path.isfile(src):
                sys.exit("missing source: " + src)
            out_name = "%s%d.ogg" % (group, i)
            dst = os.path.join(OUTDIR, out_name)
            if args.check:
                print("%-14s %s  <- %s" % ("would write" if (args.force or not os.path.isfile(dst))
                                           else "have", out_name, fn))
            elif args.force or not os.path.isfile(dst):
                encode(src, dst, delay_ms)
                print("%-14s %s  <- %s  (%.2fs)" % ("wrote", out_name, fn, duration(dst)))
                wrote += 1
            else:
                skipped += 1
            logical = "rsb/blast/%s%d" % (group, i)
            names.append(logical)
            snd.append("%-28s sounds/rsb/blast/%s" % (logical, out_name))
            snd.append("$limit %s %d" % (logical, LIMIT))
            how = ("ffmpeg mono Vorbis q6 with %d ms of silence at the head" % delay_ms) if delay_ms \
                else "ffmpeg mono Vorbis q6"
            assets.append("- `sounds/rsb/blast/%s` %s from `RS_Main/sounds/combatfx/explosions/%s` (sha1 %s)"
                          % (out_name, how, fn, sha1(src)))
        snd.append("$random rsb/blast/%s { %s }" % (group, " ".join(names)))
        snd.append("")
    snd.append(SND_END)
    assets.append("")
    assets.append(ASSET_END)

    if args.check:
        print("\n-- SNDINFO block --")
        print("\n".join(snd))
        return

    for path, begin, end, block in ((os.path.join(PKG, "SNDINFO.txt"), SND_BEGIN, SND_END, snd),
                                    (os.path.join(PKG, "ASSETS.md"), ASSET_BEGIN, ASSET_END, assets)):
        with open(path, "r", encoding="utf-8", newline="") as f:
            text = f.read()
        nl = "\r\n" if "\r\n" in text else "\n"
        body = nl.join(block)
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write(replace_block(text, begin, end, body, nl))
        print("updated " + os.path.basename(path))
    print("%d written, %d already there" % (wrote, skipped))


main()
