#!/usr/bin/env python3
"""
gen_saber_slice.py -- the cut SEAM: a lightsaber leaves a line, not a dot.

WHY THIS EXISTS

The owner, on the slice system: "FRUIT NINJA SHIT AM I RIGHT? STAR WARS LASER NEON FRUIT NINJA
SHIT", and then the sentence that actually designs it: "SLASH SLASH SLASH... KILL". A cut has to
read as a CUT -- a line where the blade went -- and it has to be survivable, so the fourth one is
the payoff and the first three are what make it mean anything.

This is step 1 of SLICE_SYSTEM_PROPOSAL_2026-10-02, and only step 1: the seam, mod-side, with no
splitting at all. The proposal's own sequencing, because it answers the one question nothing
offline can -- does a glowing cauterised line across a monster feel good in a headset -- and
because the finished system needs this seam regardless, so none of it is throwaway.

WHAT A SEAM IS, AS OPPOSED TO A SMEAR

`saber_smear_<hue>` already exists and is the swing: line = 1.3, 4.0, 1.5, 6 -- THICK, very SOFT,
dim, brief. A ribbon of light trailing the blade through the air. That is the right look for a
swish and the wrong one for a wound.

A seam is its opposite, and the numbers say so: THIN and HARD-edged (soft 1.1 against the smear's
4.0) so it reads as an edge rather than a glow, and nearly three times as BRIGHT. The proposal is
specific about why -- the line has to be visible BEFORE anything moves, because that is what sells
`cut` instead of `exploded`.

WHAT A TRAIL CAN AND CANNOT CARRY, AND HOW THAT WAS ESTABLISHED

`ApplyTrail` (parser.zs:2037-2180) accepts exactly SIXTEEN keys, and this is the list, verified:

    beamcolorend  beamjag  beamlight  heat  helix  helixcolor  helixmax  helixmotion
    licks  lightcolor  lights  line  linecolor  linecolorend  linelook  linepulse

NO smoke, no mark, no bursts, no hotspot.

THIS COST SIXTEEN REFUSED PROFILES ON THE FIRST TRY, and the reason is worth writing down because
grepping the parser does NOT protect you. Every block type is a long if-chain of `if (key == "x")`
in the one file, and nothing between the chains marks where one ends -- so a line-range read of
"the trail keys" silently picks up the neighbours. `smokevolume` is real, and it is an IMPACT and
flame key: its body writes `im.`/`fm.`, not `tr.`. That was on screen and read straight past.

THE ONLY RELIABLE DISCRIMINATOR IS WHICH STRUCT THE BODY WRITES TO -- `tr.` for trail. That is
what ACCEPTED below extracts, from the parser itself, every run. A key this script cannot prove
is a trail key does not get written.

WHAT IS DELIBERATELY NOT HERE

The SMOKE and the COOLING MARK -- the seam going white -> orange -> black over about a second with
smoke pouring off both faces. Neither can ride on a trail, per the list above. Both belong on the
impact/hotspot side, where `impact saber_hit_<hue>` already cooks flesh (flesh_cook_steam,
flesh_char_flecks) and `hotspot saber_melt` already lays a glowing groove that cools, gouge mark
and all, for a blade held in a wall. The cut wants a flesh-side twin of that hung off the hit.

Not done here, deliberately: it means editing eight shipped profiles the owner may already like,
and the next step is a headset look at the line on its own. So step 1 is the LINE.

THE LIGHT IS THE BLADE'S COLOUR, and that is a departure from saber_melt worth stating. Its
comment reasons that "the glow is heat, so it is orange-white whatever the blade's colour" -- true
of a cooling groove, and the cooling half above should follow it. But this is the instant of the
cut, the owner asked for LASER NEON, and the proposal asks for the band to be "in the blade's
colour". So the neon is the blade's and the cooling will be heat's.

@EXTREME TWINS ARE NOT WRITTEN HERE. tools/gen_extremes.py owns those for trail, flame and
hotspot; run it after this and it picks these up with everything else. Writing them by hand would
be a second answer to a question that already has one.

IDEMPOTENT, between its markers, for the reason the house learned the hard way: a
search-and-replace patch run twice inserts its output twice, and the anchor still matches.

    python tools/gen_saber_slice.py
"""
import io
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
DEFS = os.path.join(os.path.dirname(HERE), "RSBDEFS.txt")
PARSER = os.path.join(os.path.dirname(HERE), "zscript", "rsb", "parser.zs")


def accepted_trail_keys():
    """The keys ApplyTrail really takes, read out of the parser every run.

    Found by the struct the body assigns to (`tr.`), NOT by the presence of a `key == "x"`
    compare -- the chains for impact, flame and trail all live in this one file with nothing
    between them, which is exactly how an impact key got written into a trail profile.

    Returns None if the parser cannot be read or its shape has changed, and the caller then
    refuses to write rather than guessing. A check that silently passes when it cannot run is
    worse than no check: it reads as evidence.
    """
    try:
        src = io.open(PARSER, encoding="utf-8").read()
    except Exception:
        return None
    lines = src.split("\n")
    ends = [i for i, l in enumerate(lines) if "unknown trail key" in l]
    if len(ends) != 1:
        return None
    end = ends[0]
    start = None
    for i in range(end, -1, -1):
        if re.match(r"^\t(?:private |static |private static )*(?:String|void)\s+\w+\s*\(", lines[i]):
            start = i
            break
    if start is None:
        return None
    body = lines[start:end + 1]
    keys = set()
    for i, l in enumerate(body):
        m = re.search(r'key == "([a-z]+)"', l)
        if not m:
            continue
        for j in range(i, min(i + 14, len(body))):
            a = re.search(r"\b(tr|im|fm|rl|st|hs|ej|rc|wk|fl)\.", body[j])
            if a:
                if a.group(1) == "tr":
                    keys.add(m.group(1))
                break
    return keys or None

BEGIN = "# ---- BEGIN SABER SLICE SEAMS (tools/gen_saber_slice.py) ----"
END = "# ---- END SABER SLICE SEAMS ----"

# The eight blade hues and their colours, taken from the shipped `trail saber_smear_<hue>`
# profiles rather than retyped -- the saber's own RS_SaberColors.HueFor order (blue, green, red,
# purple, yellow, orange, cyan, white). A ninth blade would be added there first.
HUES = [
    ("blue",   (110, 165, 255)),
    ("green",  ( 90, 255, 110)),
    ("red",    (255,  55,  45)),
    ("purple", (190,  90, 255)),
    ("yellow", (255, 225,  80)),
    ("orange", (255, 140,  40)),
    ("cyan",   ( 80, 245, 255)),
    ("white",  (235, 240, 255)),
]

# THE SEAM. One shape for every hue; only the colour changes, exactly as the smear does.
#
#   line         thick 0.9   a wound is narrow
#                soft  1.1   HARD edge -- the smear's 4.0 is why it reads as a glow
#                bright 4.2  against the smear's 1.5: this is the neon
#                fade  10    about a third of a second at full, then gone
#   linecolorend the far end runs white-hot, so the seam looks hotter where the blade left
#   linelook     a tight halo (0.35 against 0.6) -- a glow that stays near the line
#   beamlight    the cut face lights the room, which the proposal asks for by name: a seam
#                glowing in a dark corridor. Far end at 0.55 so the entry is the brighter.
#   heat         the shimmer rising off it
#   smokevolume  radius, amount, heat, soot -- off the cut, sooty rather than clean steam
SEAM = """trail saber_slice_{hue}   # the cut seam: a hard bright line where the blade went through
  line         = 0.9, 1.1, 4.2, 10
  linecolor    = {r}, {g}, {b}
  linecolorend = 255, 248, 235
  linelook     = 0.35, 1.2
  beamlight    = 72, 2.4, 10, 0.55
  lightcolor   = {r}, {g}, {b}
  heat         = 26, 0.75, 26
end"""


def build():
    out = [BEGIN,
           "#",
           "# Generated. Edit tools/gen_saber_slice.py and re-run it; edits here are overwritten.",
           "# The cut seam, per blade hue. See that script for what a seam is and what is not in it.",
           "#"]
    for hue, (r, g, b) in HUES:
        out.append("")
        out.append(SEAM.format(hue=hue, r=r, g=g, b=b))
    out.append("")
    out.append(END)
    return "\n".join(out) + "\n"


def main():
    # PROVE EVERY KEY AGAINST THE PARSER BEFORE WRITING ANYTHING. Sixteen profiles were refused at
    # load once because a key that is real elsewhere is not real here, and a refused profile is
    # silent in a compile check and a green boot -- the pack builds, the game runs, the feature
    # simply does not exist.
    ok = accepted_trail_keys()
    if ok is None:
        raise SystemExit("gen_saber_slice: could not read the trail keys out of %s -- refusing to "
                         "write profiles I cannot prove the parser accepts." % PARSER)
    emitted = set()
    for ln in SEAM.split("\n"):
        m = re.match(r"\s*([a-z]+)\s*=", ln)
        if m:
            emitted.add(m.group(1))
    bad = sorted(emitted - ok)
    if bad:
        raise SystemExit("gen_saber_slice: %s is not a trail key (ApplyTrail accepts: %s).\n"
                         "  A key can be real on impact or flame and refused here -- the parser's "
                         "chains share one file." % (", ".join(bad), ", ".join(sorted(ok))))
    print("gen_saber_slice: %d keys checked against ApplyTrail, all accepted" % len(emitted))

    s = io.open(DEFS, encoding="utf-8").read()
    block = build()

    if BEGIN in s:
        if END not in s:
            raise SystemExit("gen_saber_slice: found %s with no %s -- refusing to guess where the "
                             "block ends. Fix RSBDEFS.txt by hand." % (BEGIN, END))
        head, rest = s.split(BEGIN, 1)
        _, tail = rest.split(END, 1)
        s2 = head + block.rstrip("\n") + tail
        what = "replaced"
    else:
        s2 = s.rstrip("\n") + "\n\n" + block
        what = "appended"

    if s2 == s:
        print("gen_saber_slice: already up to date, %d seams" % len(HUES))
        return
    io.open(DEFS, "w", encoding="utf-8").write(s2)
    print("gen_saber_slice: %s %d seams (%s)" % (what, len(HUES), ", ".join(h for h, _ in HUES)))
    print("  now run tools/gen_extremes.py so these get their @extreme twins")


if __name__ == "__main__":
    main()
