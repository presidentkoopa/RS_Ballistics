#!/usr/bin/env python3
"""
gen_extremes.py -- the kinds that never got an @extreme twin: trail, flame, hotspot.

OFF -> EXTREME has to mean something for EVERY kind. It already does for flashes (66 twins) and
impacts (109), and it works for everything through the global tier scalars -- counts, lights, sizes,
smoke and mark life all rise with rsb_tier whether or not a profile has a hand-authored variant. But
a beam, a flamethrower and a fire were getting the global lift and nothing else, while a muzzle flash
got both. So the top setting made a gun louder and left the fire it started exactly as it was.

  trail    7 profiles, 0 twins
  flame    6 profiles, 0 twins
  hotspot  33 profiles, 0 twins

RECOIL IS DELIBERATELY NOT HERE and never will be. Recoil decides WHERE BULLETS GO, and rsb_tier is a
per-player look setting -- a kick that followed it would be a gameplay difference between two people
in the same game. That is the netplay rule, not an oversight.

MORE, NEVER LONGER. An extreme variant raises what you SEE -- brightness, thickness, count, radius,
reach -- and leaves every duration alone. Lengthening things was tried on the flashes and the owner
saw it immediately: a flash that outlives its own shot stops reading as a flash.

    python tools/gen_extremes.py
"""
import io, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFS = os.path.join(os.path.dirname(HERE), "RSBDEFS.txt")
BEGIN = "# ---- BEGIN EXTREMES FOR TRAIL, FLAME AND HOTSPOT (tools/gen_extremes.py) ----"
END = "# ---- END EXTREMES FOR TRAIL, FLAME AND HOTSPOT ----"

# key -> what a top setting does to it. Anything absent is left EXACTLY alone, which is how the
# durations stay put without having to list them.
LOUDER = {
    # trail: the beam itself
    "line":       (1.45, "thicker, brighter"),
    "halo":       (1.5, None),
    "swell":      (1.3, None),
    "licks":      (1.4, None),
    "helix":      (1.35, None),
    "jag":        (1.3, None),
    "glow":       (1.4, None),
    # flame: the stream and what it throws
    "reach":      (1.18, "a longer tongue"),
    "spread":     (1.15, None),
    "light":      (1.35, None),
    "landlight":  (1.35, None),
    "cling":      (1.25, None),
    "tubelook":   (1.25, None),
    "heatland":   (1.3, None),
    "smokevolume": (1.4, None),
    # hotspot: how hard it burns
    "shimmer":    (1.4, None),
    "throb":      (1.0, None),          # a beat, not a size: left alone on purpose
    "merge":      (1.15, None),
    "mark":       (1.25, "a wider mark"),
}
# bursts and their rates: more of them, everywhere they appear
RATE_KEYS = ("bursts", "stream", "landing", "pilot", "chargebursts")
RATE_MUL = 1.45
NEVER = ("sound", "sounds", "markcolor", "lightcolor", "tubecolors", "scorchcolor", "ride",
         "damage", "scorchtics", "landingtics", "heat")

# SOME COMPONENTS HAVE CEILINGS, and multiplying walks straight through them. soot is 0..1; a lick's
# strengths are 0..2 and its scale 0..1. The parser refuses the whole profile when they are exceeded,
# which is right -- and is how this was caught: five profiles dead on a green boot.
#
# key -> {component index: ceiling}. The WW2 generator learned the same lesson and REFUSES TO WRITE
# rather than emit a value it knows is out of range; this does the same.
CEIL = {
    "smokevolume": {3: 1.0},
    "licks":       {0: 2.0, 1: 2.0, 2: 1.0},
    "tubelicks":   {0: 1.0},
    "cling":       {0: 1.0},
}


def scale_nums(val, mul, key=""):
    """Every number in a comma list, scaled -- integers kept integer so a tic count stays a tic,
    and any component with a ceiling held under it."""
    caps = CEIL.get(key, {})
    out = []
    for i, part in enumerate(val.split(",")):
        t = part.strip()
        cap = caps.get(i)
        m = re.fullmatch(r"-?\d+", t)
        if m:
            v = max(1, int(round(int(t) * mul)))
            if cap is not None and v > cap:
                v = cap
            out.append(str(v) if isinstance(v, int) else ("%.3f" % v))
            continue
        m = re.fullmatch(r"-?\d*\.\d+", t)
        if m:
            v = float(t) * mul
            if cap is not None and v > cap:
                v = cap
            out.append("%.3f" % v)
            continue
        out.append(t)
    return ", ".join(out)


def bump_rates(val):
    """`name 8, other 5` -> the same names at higher rates. A bare name list is returned unchanged."""
    parts = [p.strip() for p in val.split(",")]
    out = []
    for p in parts:
        m = re.fullmatch(r"(\S+)\s+([\d.]+)", p)
        if m:
            n = float(m.group(2)) * RATE_MUL
            out.append("%s %s" % (m.group(1), ("%d" % round(n)) if n >= 1 else ("%.2f" % n)))
        else:
            out.append(p)
    return ", ".join(out)


def twin(kind, name, note, body):
    out = ["%s %s@extreme   # %s%s" % (kind, name, note, " -- AT EXTREME" if note else "AT EXTREME")]
    for ln in body:
        m = re.match(r"^(\s*)([a-z]+)(\s*=\s*)(.+?)\s*$", ln)
        if not m:
            out.append(ln)
            continue
        pad, key, eq, val = m.groups()
        comment = ""
        if "#" in val:
            val, comment = val.split("#", 1)
            val = val.rstrip()
            comment = "   #" + comment
        if key in NEVER:
            out.append(ln)
        elif key in RATE_KEYS:
            out.append("%s%s%s%s%s" % (pad, key, eq, bump_rates(val), comment))
        elif key in LOUDER:
            out.append("%s%s%s%s%s" % (pad, key, eq, scale_nums(val, LOUDER[key][0], key), comment))
        else:
            out.append(ln)
    out.append("end")
    out.append("")
    return out


def main():
    text = io.open(DEFS, encoding="utf-8", newline="").read()
    nl = "\r\n" if "\r\n" in text else "\n"
    if BEGIN in text:
        i, j = text.index(BEGIN), text.index(END) + len(END) + len(nl)
        text = text[:i] + text[j:]

    made, cur, body, head = [], None, [], None
    for raw in text.replace("\r\n", "\n").split("\n"):
        s = raw.rstrip()
        m = re.match(r"^(trail|flame|hotspot)[ \t]+(\S+)\s*(?:#(.*))?$", s)
        if m and "=" not in s:
            if m.group(2).endswith("@extreme") or "~" in m.group(2) or "." in m.group(2):
                cur = None
                continue
            cur, head, body = m.group(1), (m.group(2), (m.group(3) or "").strip()), []
            continue
        if cur is None:
            continue
        if s.strip() == "end":
            made += twin(cur, head[0], head[1], body)
            cur = None
            continue
        body.append(s)

    block = nl.join([BEGIN, ""] + made + [END, ""])
    anchor = "# ---- END NEW SETS"
    if anchor not in text:
        raise SystemExit("no anchor")
    io.open(DEFS, "w", encoding="utf-8", newline="").write(text.replace(anchor, block + anchor, 1))
    kinds = {}
    for l in made:
        m = re.match(r"^(trail|flame|hotspot) ", l)
        if m:
            kinds[m.group(1)] = kinds.get(m.group(1), 0) + 1
    print("%d extreme twins written: %s" % (sum(kinds.values()),
          ", ".join("%d %s" % (v, k) for k, v in sorted(kinds.items()))))


if __name__ == "__main__":
    main()
