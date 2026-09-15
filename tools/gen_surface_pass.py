#!/usr/bin/env python3
"""
gen_surface_pass.py -- the surface pass (_staged/SURFACE_PASS_PLAN.md): what tech panels, screens, lights, pipes,
brick, marble and tile do when a round hits them. DATA ONLY. Writes three generated sections, each between markers
and replaced when run again:

  SURFACES.txt      the seven surfaces' texture rules, after the first five, so a later rule takes the textures
                    back from metal and glass
  PARTICLEDEFS.txt  the new 3D debris pieces (tools/gen_chunks.py builds their models)
  RSBDEFS.txt       the new bursts and a `<family>.<surface>` impact for every bullet family, before the Extreme roster

Owner picks, 2026-09-15: tech, electrical and pipes; lights and screens; brick, marble and tile. "Keep counts, add new
kinds": each surface variant is cloned from the family's own stone, metal or glass hit (same scale, vary, damage size,
sound family), its stone pieces swap to the surface's, and the surface's new kinds are added. Lights and screens get the
pop and sparks only (flicker and dimming are parked for the glow lanes). Blasts, energy and saws keep their base hits.
No Extreme variants (owner, 2026-09-15): at the Extreme level a new surface uses its plain variant (Resolve takes
base.material before base@tier).

    python tools/gen_surface_pass.py
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FAMILIES = ["bullet", "pistol", "pistol_9mm", "pistol_45", "magnum", "rifle", "chaingun_556", "machinegun_762",
            "buckshot", "buckshot_magnum"]
X_MARK = "# ---------------------------------------------------------------- EXTREME: THE VANILLA ROSTER"


def read(path):
    raw = open(path, "rb").read()
    return raw.decode("utf-8").replace("\r\n", "\n"), ("\r\n" if b"\r\n" in raw else "\n")


def write(path, text, nl):
    open(path, "wb").write(text.replace("\n", nl).encode("utf-8"))


def strip_section(text, begin, end):
    if begin not in text:
        return text
    if end not in text:
        sys.exit("%s has its begin marker but no end -- nothing written" % begin)
    a, b = text.index(begin), text.index(end) + len(end)
    while text[b:b + 1] == "\n":
        b += 1
    return text[:a] + text[b:]


def put_section(text, begin, end, body, before=None):
    block = begin + "\n" + body.rstrip("\n") + "\n" + end + "\n\n"
    text = strip_section(text, begin, end)
    if before:
        if text.count(before) != 1:
            sys.exit("anchor %r found %d times -- nothing written" % (before[:50], text.count(before)))
        i = text.index(before)
        return text[:i] + block + text[i:]
    return text.rstrip("\n") + "\n\n" + block


def items(v):
    return [x.strip() for x in v.split(",") if x.strip()]


def fnum(x):
    return ("%.3f" % x).rstrip("0").rstrip(".")


def rgb(c):
    return "%d, %d, %d" % tuple(c)


# ============================================================================ SURFACES
SURFACES_BEGIN = "// ---- BEGIN surface pass (tools/gen_surface_pass.py)"
SURFACES_END = "// ---- END surface pass"
SURFACE_RULES = [   # in this order: a later rule wins (BRICKLIT and TEKLITE are lights, not brick or tech)
    ("brick", "fired brick", ['"BRICK*"', '"BIGBRIK*"', '"BRNBIG*"', '"BRNSMAL*"', '"BRNPOIS*"', '"ZZWOLF*"', '"SW?BRIK"'],
     ['"FLAT8"', '"RROCK14"']),
    ("marble", "marble and carved stone", ['"MARBLE*"', '"MARBFAC*"', '"MARBFACE"', '"MARBGRAY"', '"MARBLOD1"', '"GSTONE*"',
     '"GSTFONT*"', '"GSTGARG"', '"GSTLION"', '"GSTSATYR"', '"GSTVINE*"', '"SW?MARB"', '"SW?GSTON"', '"SW?GARG"', '"SW?LION"',
     '"SW?SATYR"'], ['"DEM1_*"', '"FLOOR7_2"', '"GATE1"', '"GATE2"', '"GATE3"']),
    ("tile", "tiled floors (check in the headset)", [], ['"FLAT20"', '"FLAT5"', '"FLOOR5_*"', '"FLAT9"', '"FLAT18"']),
    ("pipe", "pipes (they vent steam)", ['"PIPE1"', '"PIPE2"', '"PIPE4"', '"PIPE6"', '"PIPES"', '"PIPEWAL*"', '"BROWNPIP"',
     '"SW?PIPE"'], []),
    ("tech", "tech panels and wiring (they short out)", ['"COMP2"', '"COMPBLUE"', '"COMPOHSO"', '"COMPSPAN"', '"COMPTILE"',
     '"TEKWALL*"', '"TEKGREN*"', '"TEKBRON*"', '"SPACEW*"', '"MIDSPACE"', '"SW?BRCOM"', '"SW?COMM"', '"SW?COMP"', '"SW?TEK"',
     '"SW?BLUE"'], ['"COMP01"']),
    ("screen", "screens and consoles", ['"COMPSTA1"', '"COMPSTA2"', '"COMPTALL"', '"COMPUTE*"', '"COMPWERD"', '"PLANET1"',
     '"EXITSIGN"', '"SW?EXIT"'], ['"CONS1_1"', '"CONS1_5"', '"CONS1_7"']),
    ("light", "light fixtures (the pop and sparks only)", ['"LITE2"', '"LITE3"', '"LITE4"', '"LITE5"', '"LITE96"', '"LITEBLU*"',
     '"LITEMET"', '"LITERED"', '"LITESTON"', '"TEKLITE"', '"TEKLITE2"', '"BRICKLIT"'],
     ['"TLITE6_1"', '"TLITE6_4"', '"TLITE6_5"', '"TLITE6_6"', '"FLOOR1_7"', '"FLAT2"', '"FLAT17"', '"FLAT22"', '"CEIL1_2"',
      '"CEIL1_3"', '"CEIL3_4"', '"CEIL3_6"', '"GRNLITE1"']),
]


def surfaces_body():
    out = ["// THE SURFACE PASS (owner picks 2026-09-15). After metal, wood, glass, liquid and dirt, so these take their",
           "// textures back (TEK*, COMP*, PIPE*, LITE*). Read from Doom 1 and Doom 2's IWADs; floors checked by eye on",
           "// rendered sheets. Lava cracks and liquids stay with the liquids pass.", ""]
    for name, note, walls, flats in SURFACE_RULES:
        out.append("surface %s   // %s" % (name, note))
        out.append("{")
        for i in range(0, len(walls), 8):
            out.append("\twalls = " + ", ".join(walls[i:i + 8]))
        for i in range(0, len(flats), 8):
            out.append("\tflats = " + ", ".join(flats[i:i + 8]))
        out += ["}", ""]
    return "\n".join(out)


# ============================================================================ PARTICLEDEFS
PDEFS_BEGIN = "// ---- BEGIN surface pass debris (tools/gen_surface_pass.py)"
PDEFS_END = "// ---- END surface pass debris"
# (definition stem, model folder/shape, count, texture fallback, gravity, drag, spin, restitution, friction, restlife,
#  landsound, landvolume, landpitch)
CHUNKS = [
    ("tech_board", "tech/board", 3, '"RSCHA0", 4, 14, loop', 600, 0.8, 720, 0.3, 0.5, 60, '"rsb/debris/chips"', 0.22, "1.35, 1.6"),
    ("tech_wire", "tech/wire", 2, '"RSCHA0", 4, 14, loop', 650, 0.9, 900, 0.25, 0.6, 60, '"rsb/debris/chips"', 0.12, "1.5, 1.8"),
    ("light_bulb", "light/bulb", 3, '"RSGSA0", 4, 16, loop', 550, 0.8, 900, 0.2, 0.25, 45, '"rsb/debris/glass", "rsb/debris/glass_big"', 0.3, "1.2, 1.5"),
    ("brick_chunk", "brick/chunk", 4, '"RSCHA0", 4, 14, loop', 650, 0.6, 540, 0.22, 0.65, 60, '"rsb/debris/rubble", "rsb/debris/chips"', 0.38, "0.85, 1.05"),
    ("marble_chip", "marble/chip", 4, '"RSCHA0", 4, 14, loop', 620, 0.6, 600, 0.3, 0.45, 60, '"rsb/debris/marble"', 0.35, "1.0, 1.25"),
    ("tile_shard", "tile/shard", 4, '"RSCHA0", 4, 14, loop', 600, 0.7, 700, 0.25, 0.4, 60, '"rsb/debris/tile"', 0.35, "1.05, 1.3"),
]


def chunk_names(stem):
    for c in CHUNKS:
        if c[0] == stem:
            return ["rsb_chunk_%s%d" % (stem, i) for i in range(1, c[2] + 1)]
    sys.exit("no chunk %s" % stem)


def pdefs_body():
    out = ["// THE SURFACE PASS: each new surface throws its own 3D pieces (models from tools/gen_chunks.py, one white skin",
           "// tinted by the burst's colour). Lit, never glowing; they collide, rest and patter like the first five.", ""]
    for stem, shape, count, tex, grav, drag, spin, rest, fric, restlife, land, vol, pitch in CHUNKS:
        for i in range(1, count + 1):
            out += ["particle rsb_chunk_%s%d" % (stem, i), "{",
                    '\tmesh     = "models/debris/%s%d.md3", "models/debris/chunk.png"' % (shape, i),
                    "\tlit      = 1",
                    "\temissive = 0 @0, 0 @1",
                    "\tcolor    = 255 255 255 @0, 255 255 255 @1",
                    "\tsize     = 1.2 @0, 1.2 @1",
                    "\tgravity  = %d" % grav,
                    "\tdrag     = %s" % fnum(drag),
                    "\tspin     = -%d, %d" % (spin, spin),
                    "\tcollide  = level",
                    "\talpha    = 1 @0, 1 @1",
                    "\ttexture  = %s" % tex,
                    "\torient   = flake",
                    "\trestitution = %s" % fnum(rest),
                    "\tfriction    = %s" % fnum(fric),
                    "\trestlife    = %d" % restlife,
                    "\trestfade    = 2.0",
                    "\tlandsound   = %s" % land,
                    "\tlandvolume  = %s" % fnum(vol),
                    "\tlandpitch   = %s" % pitch,
                    "}", ""]
    return "\n".join(out)


# ============================================================================ RSBDEFS
RSB_BEGIN = "# ---------------------------------------------------------------- SURFACE PASS (generated: tools/gen_surface_pass.py)"
RSB_END = "# ---------------------------------------------------------------- END SURFACE PASS"

# Stone pieces swap to the surface's: chunks by name and colour, dust by tint (the burst colour multiplies the definition's).
STONE = {
    "brick":  {"chunks": chunk_names("brick_chunk"), "chunk": (150, 80, 62), "dust": (196, 138, 112)},
    "marble": {"chunks": chunk_names("marble_chip"), "chunk": (225, 222, 212), "dust": (236, 234, 228)},
    "tile":   {"chunks": chunk_names("tile_shard"), "chunk": (205, 208, 212), "dust": (222, 222, 218)},
}

NEW_BURSTS = [
    ("arcs_electric", "a shot panel shorting out: white-blue arcs crawling where it struck (rsb_arc)",
     {"count": "3", "cone": "70", "speed": "20, 0.5", "life": "0.3, 0.35", "color": "170, 200, 255", "offset": "2", "particle": "rsb_arc"}),
    ("arc_electric_one", "a shot screen shorting: one arc across it (rsb_arc)",
     {"count": "1", "cone": "60", "speed": "15, 0.5", "life": "0.25, 0.3", "color": "150, 220, 200", "offset": "2", "particle": "rsb_arc"}),
    ("wisp_electric", "burnt insulation: a thin wisp of grey smoke off a shot panel (rsb_smoke_gun: lit, never glowing)",
     {"count": "1", "cone": "25", "speed": "25, 0.5", "life": "1.6, 0.35", "aim": "normal", "offset": "1", "color": "150, 150, 155",
      "particle": "rsb_smoke_gun"}),
    ("bits_board", "bits of circuit board knocked off a panel (3D chunks, lit, never glowing)",
     {"count": "3", "cone": "55", "speed": "150, 0.5", "life": "1.1, 0.4", "color": "46, 96, 56",
      "particle": ", ".join(chunk_names("tech_board"))}),
    ("bits_wire", "scraps of copper wire torn out of a panel (3D chunks, lit, never glowing)",
     {"count": "2", "cone": "60", "speed": "170, 0.5", "life": "1.1, 0.4", "color": "184, 112, 62",
      "particle": ", ".join(chunk_names("tech_wire"))}),
    ("bulb_glass", "a light's cover popping: curved shards of bulb glass (3D chunks)",
     {"count": "14", "cone": "70", "speed": "170, 0.5", "life": "1.0, 0.4", "color": "225, 230, 235",
      "particle": ", ".join(chunk_names("light_bulb"))}),
    ("steam_jet_pipe", "a shot pipe venting: a jet of white steam straight out of the hole (rsb_smoke_gun: lit, never glowing)",
     {"count": "5", "cone": "10", "speed": "260, 0.4", "life": "1.1, 0.5", "aim": "normal", "offset": "2", "color": "235, 238, 242",
      "particle": "rsb_smoke_gun"}),
    ("steam_hang_pipe", "the steam hanging in front of a shot pipe after the jet (rsb_smoke_gun: lit, never glowing)",
     {"count": "2", "cone": "45", "speed": "35, 0.5", "life": "2.2, 0.3", "aim": "normal", "offset": "3", "color": "230, 232, 235",
      "particle": "rsb_smoke_gun"}),
    ("bits_pipe", "torn flecks of pipe metal (3D chunks, lit, never glowing)",
     {"count": "2", "cone": "50", "speed": "170, 0.5", "life": "1.1, 0.4", "color": "140, 140, 146",
      "particle": "rsb_chunk_metal_shard1, rsb_chunk_metal_strip1"}),
]


def parse_blocks(text):
    blocks = {}
    kind = bid = None
    for line in text.split("\n"):
        s = line.split("#", 1)[0].rstrip()
        if not s.strip():
            continue
        m = re.match(r"^(\w+)\s+(\S+)$", s)
        if m and not line[:1].isspace() and m.group(1) != "end":
            kind, bid = m.group(1), m.group(2)
            blocks[(kind, bid)] = {}
            continue
        if s.strip() == "end":
            kind = None
            continue
        if kind and "=" in s:
            k, v = s.split("=", 1)
            blocks[(kind, bid)][k.strip().lower()] = v.strip()
    return blocks


def emit(out, header, kv, note=""):
    out.append(header + (("   # " + note) if note else ""))
    w = max(len(k) for k in kv)
    for k, v in kv.items():
        out.append("  %-*s = %s" % (w, k, v))
    out += ["end", ""]


def burst_names(kv):
    names = [] if kv.get("bursts", "none") == "none" else items(kv["bursts"])
    return names + [it.split()[0] for it in items(kv.get("maybe", ""))]


def swap(kv, mapping):
    if kv.get("bursts", "none") != "none":
        kv["bursts"] = ", ".join(mapping.get(n, n) for n in items(kv["bursts"]))
    if "maybe" in kv:
        kv["maybe"] = ", ".join("%s %s" % (mapping.get(it.split()[0], it.split()[0]), it.split()[1]) for it in items(kv["maybe"]))


def add(kv, names):
    cur = [] if kv.get("bursts", "none") == "none" else items(kv["bursts"])
    for n in names:
        if n not in cur:
            cur.append(n)
    kv["bursts"] = ", ".join(cur)


def add_maybe(kv, pairs):
    cur = items(kv.get("maybe", ""))
    have = {it.split()[0] for it in cur}
    for n, c in pairs:
        if n not in have:
            cur.append("%s %s" % (n, fnum(c)))
    kv["maybe"] = ", ".join(cur)


def damage(v, brush=None, radius=1.0, depth=1.0, soot=None, soot_mul=1.0):
    p = items(v)
    if len(p) < 5:
        sys.exit("damage %r is not brush, radius, depth, soot, heat[, ...]" % v)
    if brush:
        p[0] = brush
    p[1] = fnum(float(p[1]) * radius)
    p[2] = fnum(float(p[2]) * depth)
    p[3] = fnum(soot if soot is not None else float(p[3]) * soot_mul)
    return ", ".join(p)


def rsbdefs_body(blocks):
    bursts, impacts = [], []
    for bid, note, kv in NEW_BURSTS:
        if ("burst", bid) in blocks:
            sys.exit("burst %s already exists outside the generated section -- nothing written" % bid)
        emit(bursts, "burst " + bid, dict(kv), note)

    stone_maps = {s: {} for s in STONE}
    for fam in FAMILIES:
        for need in (fam, fam + ".metal", fam + ".glass"):
            if ("impact", need) not in blocks:
                sys.exit("no impact %s -- nothing written" % need)
        for name in burst_names(blocks[("impact", fam)]):
            b = blocks.get(("burst", name))
            if b is None or "concrete" not in name:
                continue
            parts = items(b.get("particle", ""))
            for surf, s in STONE.items():
                if name in stone_maps[surf]:
                    continue
                kv = dict(b)
                if any(p.startswith("rsb_chunk_concrete") for p in parts):
                    kv["particle"] = ", ".join(s["chunks"])
                    kv["color"] = rgb(s["chunk"])
                elif any(p.startswith("rsb_dust_concrete") for p in parts):
                    base = [float(x) for x in items(kv["color"])] if "color" in kv else [255.0, 255.0, 255.0]
                    kv["color"] = rgb([round(base[i] * s["dust"][i] / 255.0) for i in range(3)])
                else:
                    continue
                newid = name.replace("concrete", surf)
                if ("burst", newid) in blocks:
                    sys.exit("burst %s already exists outside the generated section -- nothing written" % newid)
                stone_maps[surf][name] = newid
                emit(bursts, "burst " + newid, kv, "%s's %s, off %s" % (name, "pieces" if "chunk" in kv["particle"] else "dust", surf))

    for fam in FAMILIES:
        stone, metal, glass = (dict(blocks[("impact", fam + x)]) for x in ("", ".metal", ".glass"))

        kv = dict(stone)
        swap(kv, stone_maps["brick"])
        emit(impacts, "impact %s.brick" % fam, kv, "brick: its own chunks and red-brown dust")

        kv = dict(stone)
        swap(kv, stone_maps["marble"])
        for k in ("damage", "glancedamage"):
            if k in kv:
                kv[k] = damage(kv[k], soot_mul=0.5)
        emit(impacts, "impact %s.marble" % fam, kv, "marble: white chips and fine white dust, a cleaner hole")

        kv = dict(stone)
        swap(kv, stone_maps["tile"])
        if "damage" in kv:
            kv["damage"] = damage(kv["damage"], brush="crack", radius=0.8, depth=0.5, soot_mul=0.5)
        emit(impacts, "impact %s.tile" % fam, kv, "tile: shards and fine dust, a small crack")

        kv = dict(metal)
        add(kv, ["arcs_electric", "bits_board", "bits_wire"])
        add_maybe(kv, [("wisp_electric", 0.5)])
        kv["light"], kv["lightcolor"], kv["sound"] = "60, 1.6, 3", "170, 200, 255", "rsb/impact/electric"
        if "damage" in kv:
            kv["damage"] = damage(kv["damage"], brush="hole_punch", soot=0.3)
        emit(impacts, "impact %s.tech" % fam, kv, "tech: the panel's sparks, arcs shorting, board and wire bits, a blink of blue-white")

        kv = dict(metal)
        add(kv, ["steam_jet_pipe", "bits_pipe"])
        add_maybe(kv, [("steam_hang_pipe", 0.6)])
        kv["sound"] = "rsb/impact/pipe"
        emit(impacts, "impact %s.pipe" % fam, kv, "pipe: the metal hit, a jet of steam and its hiss")

        kv = dict(glass)
        add(kv, ["spark_hot", "arc_electric_one"])
        add_maybe(kv, [("bits_board", 0.6)])
        kv["light"], kv["lightcolor"] = "50, 1.4, 2", "150, 220, 200"
        emit(impacts, "impact %s.screen" % fam, kv, "screen: glass, a spark burst, one arc, a green-white blink")

        kv = dict(glass)
        swap(kv, {"glint_glass": "bulb_glass"})
        add(kv, ["bulb_glass", "spark_spray"])
        kv["light"], kv["lightcolor"] = "90, 2.2, 2", "255, 245, 220"
        emit(impacts, "impact %s.light" % fam, kv, "light: the pop -- bulb glass, a spark spray, one bright blink (no flicker)")

    head = ["# THE SURFACE PASS (owner picks 2026-09-15): tech panels short out, screens crack and arc, lights pop, pipes vent",
            "# steam, brick, marble and tile break into their own pieces. Every bullet family's variants, cloned from its own",
            "# stone, metal or glass hit: the same counts and sizes, new kinds added. SURFACES.txt names the textures.",
            "# Generated -- edit tools/gen_surface_pass.py and run it again, not these blocks.", ""]
    return "\n".join(head + bursts + impacts), len(NEW_BURSTS) + sum(len(m) for m in stone_maps.values()), len(FAMILIES) * 7


def main():
    s_text, s_nl = read(os.path.join(ROOT, "SURFACES.txt"))
    p_text, p_nl = read(os.path.join(ROOT, "PARTICLEDEFS.txt"))
    r_text, r_nl = read(os.path.join(ROOT, "RSBDEFS.txt"))

    base = strip_section(r_text, RSB_BEGIN, RSB_END)
    if X_MARK not in base:
        sys.exit("no Extreme roster marker in RSBDEFS -- nothing written")
    body, nbursts, nimpacts = rsbdefs_body(parse_blocks(base[:base.index(X_MARK)]))

    s_out = put_section(s_text, SURFACES_BEGIN, SURFACES_END, surfaces_body())
    p_out = put_section(p_text, PDEFS_BEGIN, PDEFS_END, pdefs_body())
    r_out = put_section(r_text, RSB_BEGIN, RSB_END, body, before=X_MARK)

    write(os.path.join(ROOT, "SURFACES.txt"), s_out, s_nl)
    write(os.path.join(ROOT, "PARTICLEDEFS.txt"), p_out, p_nl)
    write(os.path.join(ROOT, "RSBDEFS.txt"), r_out, r_nl)
    print("surface pass: %d surfaces, %d debris definitions, %d bursts, %d impacts" %
          (len(SURFACE_RULES), sum(c[2] for c in CHUNKS), nbursts, nimpacts))


if __name__ == "__main__":
    main()
