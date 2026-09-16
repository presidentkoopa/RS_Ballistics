#!/usr/bin/env python3
"""
gen_breach_profiles.py -- RS_Ballistics effects for RS_Modern's BREACH IQM guns (the owner, 2026-09-15: every new gun gets
its own effects; muzzle flash, smoke and tracers are RS_Ballistics', never the source mod's sprites).

One id per gun across all four kinds (round, flash, ejecta, recoil), as pistol_9mm does:
  glock17  glock17_sup  kimber1911  mk18  mk18_sup  hk416_sup  mcx_sup  g36c_sup  mp5  benelli_m4
Plus data-only impacts `flashbang` and `c4` for when throwables get play code (the owner decides how they are thrown).

Each gun starts from its nearest existing profile, then gets its own character. Rounds reuse the existing BALLISTICS, so
there is no gameplay change: damage stays the gun sheet's. Pistols stay the showpiece; rifles, the SMG and the shotgun
stay disciplined. The suppressed guns get their own look: a faint flash, a puff of gas out of the can, gas blown back
out of the port, a quieter room tail and a can that heats. Writes one generated section before the Extreme roster,
replaced when run again. No Extreme variants (the owner): at Extreme each uses its base.

    python tools/gen_breach_profiles.py
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
X_MARK = "# ---------------------------------------------------------------- EXTREME: THE VANILLA ROSTER"
BEGIN = "# ---------------------------------------------------------------- BREACH (RS_Modern's IQM guns; generated: tools/gen_breach_profiles.py)"
END = "# ---------------------------------------------------------------- END BREACH"


def read(path):
    raw = open(path, "rb").read()
    return raw.decode("utf-8").replace("\r\n", "\n"), ("\r\n" if b"\r\n" in raw else "\n")


def strip_section(text):
    if BEGIN not in text:
        return text
    if END not in text:
        sys.exit("BREACH begin marker without its end -- nothing written")
    a, b = text.index(BEGIN), text.index(END) + len(END)
    while text[b:b + 1] == "\n":
        b += 1
    return text[:a] + text[b:]


def parse_blocks(text):
    blocks, kind, bid = {}, None, None
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


out = []


def emit(header, kv, note):
    out.append(header + "   # " + note)
    w = max(len(k) for k in kv)
    for k, v in kv.items():
        out.append("  %-*s = %s" % (w, k, v))
    out.extend(["end", ""])


def main():
    path = os.path.join(ROOT, "RSBDEFS.txt")
    text, nl = read(path)
    base = strip_section(text)
    if X_MARK not in base:
        sys.exit("no Extreme roster marker -- nothing written")
    blocks = parse_blocks(base[:base.index(X_MARK)])

    def clone(kind, src, newid, note, set=None, drop=()):
        if (kind, src) not in blocks:
            sys.exit("no %s %s to start from -- nothing written" % (kind, src))
        if (kind, newid) in blocks:
            sys.exit("%s %s already exists outside the generated section -- nothing written" % (kind, newid))
        kv = dict(blocks[(kind, src)])
        for k in drop:
            kv.pop(k, None)
        for k, v in (set or {}).items():
            kv[k] = v
        emit("%s %s" % (kind, newid), kv, note)

    def fresh(kind, newid, note, kv):
        if (kind, newid) in blocks:
            sys.exit("%s %s already exists outside the generated section -- nothing written" % (kind, newid))
        emit("%s %s" % (kind, newid), dict(kv), note)

    out.append("# BREACH: RS_Modern's IQM guns (the owner, 2026-09-15). One id per gun for round, flash, ejecta and recoil.")
    out.append("# Rounds reuse the existing ballistics (no gameplay change). Generated -- edit tools/gen_breach_profiles.py.")
    out.append("")

    # ---- bursts the suppressed looks and the flashbang need
    fresh("burst", "sup_gas_puff", "a suppressor's breath: a small grey puff out of the can each shot (rsb_smoke_gun: lit, never glowing)",
          {"count": "2", "cone": "30", "speed": "45, 0.5", "life": "1.1, 0.3", "offset": "2", "color": "200, 200, 200", "particle": "rsb_smoke_gun"})
    fresh("burst", "sup_gas_puff_rifle", "a rifle can's breath: a fuller puff of grey gas (rsb_smoke_gun: lit, never glowing)",
          {"count": "3", "cone": "35", "speed": "70, 0.5", "life": "1.3, 0.3", "offset": "3", "color": "205, 205, 205", "particle": "rsb_smoke_gun"})
    fresh("burst", "flashbang_core", "a flashbang going off: a spray of white-hot stars (rsb_spark_star)",
          {"count": "24", "cone": "90", "speed": "260, 0.6", "life": "0.3, 0.3", "color": "255, 255, 255", "particle": "rsb_spark_star"})
    fresh("burst", "flashbang_smoke", "a flashbang's cloud: a thick white-grey smoke rolling out (rsb_smoke_gun: lit, never glowing)",
          {"count": "8", "cone": "70", "speed": "90, 0.5", "life": "3.0, 0.3", "aim": "normal", "offset": "6", "color": "235, 235, 235",
           "particle": "rsb_smoke_gun"})

    # ---- rounds and their looks (ballistics reused: damage is the gun sheet's)
    looks = [
        ("glock17", "pistol_9mm", "pistol_9mm", "the Glock 17's 9mm: the showpiece pistol's look", None, ()),
        ("glock17_sup", "pistol_9mm", "pistol_9mm", "the suppressed Glock's 9mm: no bent air behind it, a thinner tunnel through smoke",
         {"carve": "5, 0.7", "whiz": "56, rsb/whiz"}, ("heat",)),
        ("kimber1911", "pistol_45", "pistol_45", "the Kimber 1911's .45: the showpiece .45 look", None, ()),
        ("mk18", "rifle_556", "rifle_556", "the MK18's 5.56 out of a short barrel: it cracks past you", None, ()),
        ("mk18_sup", "rifle_556", "rifle_556", "the suppressed MK18's 5.56: still supersonic, still a crack", {"carve": "4, 0.6"}, ()),
        ("hk416_sup", "rifle_556", "rifle_556", "the suppressed HK416's 5.56", {"carve": "4, 0.6"}, ()),
        ("mcx_sup", "rifle_556", "rifle_556", "the suppressed MCX's 5.56", {"carve": "4, 0.6"}, ()),
        ("g36c_sup", "rifle_556", "rifle_556", "the suppressed G36C's 5.56", {"carve": "4, 0.6"}, ()),
        ("mp5", "smg_9mm", "pistol_9mm", "the MP5's 9mm: the SMG's plainer look, so full auto stays disciplined", None, ()),
        ("benelli_m4", "buckshot", "buckshot", "the Benelli M4's buckshot", None, ()),
    ]
    for gid, look, bal, note, sets, drops in looks:
        clone("roundlook", look, gid, note, sets, drops)
        fresh("round", gid, "the %s round: %s ballistics (no gameplay change), its own look" % (gid, bal),
              {"ballistics": bal, "roundlook": gid})

    # ---- muzzle flashes
    clone("flash", "pistol_9mm", "glock17", "THE GLOCK 17: the showpiece 9mm -- a sharp white snap, a turning star, powder some shots")
    clone("flash", "pistol_45", "kimber1911", "THE KIMBER 1911: the showpiece .45 -- a rounder, oranger bloom that hangs a tic longer")
    clone("flash", "rifle", "mk18", "THE MK18: a 10.3-inch barrel's loud flash -- a hard crown of fire, heavy streaks, the room lit white",
          {"light": "260, 3.8, 2", "cone": "16, 46, 130, 7", "flame": "0.08", "bursts": "flash_core, flash_petals, spk_heavy_streaks",
           "maybe": "powder_clump 0.2, spk_specks 0.3", "tail": "rsb/tail/br, 0.9", "blastkick": "kick_puff, 64, 3",
           "shockwave": "16, 0.45, 3", "exposure": "0.4, 112", "hearing": "0.45, 128", "smokevolume": "14, 1.0, 0.4, 80, 8"})
    fresh("flash", "glock17_sup", "THE SUPPRESSED GLOCK: almost no flash -- a faint glow at the can, a puff of gas, a quiet room",
          {"light": "70, 0.9, 1", "lightcolor": "255, 214, 170", "bursts": "sup_gas_puff", "maybe": "spk_specks 0.12",
           "smoke": "1, 0.02, 0.25", "smokeparticle": "rsb_smoke_gun", "vary": "light 0.3, smoke 0.4",
           "barrelheat": "0.2, 0.2, 0.35", "barrelsmoke": "rsb_smoke_barrel, 2.2", "barrelshimmer": "2.5, 0.4",
           "smokevolume": "10, 0.8, 0.3, 40, 8", "tail": "rsb/tail/pistol, 0.3", "powdervary": "0.3"})
    sup_rifle = {"light": "90, 1.1, 1", "lightcolor": "255, 214, 170", "bursts": "sup_gas_puff_rifle", "maybe": "spk_specks 0.15",
                 "smoke": "1, 0.022, 0.25", "smokeparticle": "rsb_smoke_gun", "vary": "light 0.3, smoke 0.4",
                 "barrelheat": "0.1, 0.18, 0.35", "barrelsmoke": "rsb_smoke_barrel, 1.8", "barrelshimmer": "3, 0.45",
                 "smokevolume": "12, 0.9, 0.35, 50, 10", "tail": "rsb/tail/br, 0.35", "powdervary": "0.3"}
    for gid, tweak, note in [
        ("mk18_sup", {"light": "110, 1.3, 1", "maybe": "spk_specks 0.25"},
         "THE SUPPRESSED MK18: a short barrel leaks a little more fire round the can"),
        ("hk416_sup", {}, "THE SUPPRESSED HK416: a faint glow, a puff of gas out of the can, a quiet room"),
        ("mcx_sup", {"light": "60, 0.8, 1", "maybe": "spk_specks 0.08", "tail": "rsb/tail/br, 0.25"},
         "THE SUPPRESSED MCX: the quietest -- barely a glow, a soft puff"),
        ("g36c_sup", {"light": "100, 1.2, 1"}, "THE SUPPRESSED G36C: a faint glow, a puff of gas, a quiet room"),
    ]:
        kv = dict(sup_rifle)
        kv.update(tweak)
        fresh("flash", gid, note, kv)
    clone("flash", "smg", "mp5", "THE MP5: quick small flashes, so a burst strobes -- disciplined", {"light": "170, 2.7, 1"})
    clone("flash", "shotgun", "benelli_m4", "THE BENELLI M4: a semi-auto 12-gauge -- the shotgun's gout, shot after shot")

    # ---- brass
    clone("ejecta", "brass_9mm", "glock17", "the Glock's 9mm brass")
    clone("ejecta", "brass_9mm", "glock17_sup", "the suppressed Glock's brass: the can blows gas back out of the port",
          {"portsmoke": "rsb_smoke_port, 4", "wisp": "rsb_casing_wisp, 20"})
    clone("ejecta", "brass_45", "kimber1911", "the 1911's .45 brass")
    clone("ejecta", "brass_556", "mk18", "the MK18's 5.56 brass")
    for gid in ("mk18_sup", "hk416_sup", "mcx_sup", "g36c_sup"):
        clone("ejecta", "brass_556", gid, "5.56 brass out of a suppressed rifle: gas blown back out of the port",
              {"portsmoke": "rsb_smoke_port, 3", "wisp": "rsb_casing_wisp, 14"})
    clone("ejecta", "brass_9mm", "mp5", "the MP5's 9mm brass")
    clone("ejecta", "hull_12ga", "benelli_m4", "the Benelli's 12-gauge hulls")

    # ---- recoil (gameplay: base names only)
    clone("recoil", "pistol_9mm", "glock17", "the Glock 17: snappy; aimed fire is dead on, only a mag dump climbs")
    clone("recoil", "pistol_9mm", "glock17_sup", "the suppressed Glock: the can's weight softens the snap",
          {"climb": "1.0", "view": "1.0, 5, 1.2, 7"})
    clone("recoil", "pistol_45", "kimber1911", "the 1911: a bigger push; fast follow-ups walk up")
    rifle = {"climb": "0.8", "drift": "0.35, 5", "recover": "10, 5", "max": "5, 2", "bloom": "0.1", "view": "1.2, 4, 1, 6"}
    clone("recoil", "chaingun_556", "mk18", "the MK18: a short 5.56 carbine -- a sharp push, full auto walks up", rifle)
    for gid, climb, note in [("mk18_sup", "0.7", "the suppressed MK18: the can tames the push a little"),
                             ("hk416_sup", "0.65", "the suppressed HK416: a heavier gun, a smoother push"),
                             ("mcx_sup", "0.6", "the suppressed MCX: the softest shooter"),
                             ("g36c_sup", "0.7", "the suppressed G36C")]:
        kv = dict(rifle)
        kv["climb"] = climb
        kv["view"] = "1.0, 3.5, 0.9, 6"
        clone("recoil", "chaingun_556", gid, note, kv)
    clone("recoil", "chaingun_556", "mp5", "the MP5: a 9mm SMG -- a low, even push, controllable in bursts",
          {"climb": "0.45", "drift": "0.2, 5", "recover": "10, 5", "max": "3.5, 1.5", "bloom": "0.08", "view": "0.8, 3, 0.8, 5"})
    clone("recoil", "shotgun_bullpup", "benelli_m4", "the Benelli M4: a semi-auto 12-gauge -- it climbs if rushed",
          {"climb": "4.5", "view": "3, 12, 2.5, 12"})

    # ---- thrown charges: effects only, for when throwables get play code (no damage here: damage is the thrower's)
    fresh("impact", "flashbang", "A FLASHBANG going off: a blinding white flash, a bang that rings the ears, a white cloud (no damage)",
          {"bursts": "flashbang_core, flashbang_smoke, spk_specks", "light": "600, 8, 6", "lightcolor": "255, 255, 255",
           "sound": blocks[("impact", "rocket")].get("sound", "none"), "smokevolume": "48, 1.2, 0.5", "push": "128, 300",
           "damage": "scorch, 10, 0, 0.35, 0", "exposure": "6, 192, 1.5", "hearing": "4, 256, 1.5"})
    clone("impact", "rocket_rpg", "c4", "C4: a heavy charge -- the RPG's blast, bigger: a wider fireball, a deeper crater, a harder shove",
          {"heat": "110, 2.3, 44", "light": "620, 5.5, 14", "smokevolume": "110, 2.2, 4.0, 0.7", "push": "420, 1100",
           "damage": "crater, 40, 0.8, 1, 0", "scale": "1.5, 1.3", "exposure": "3.5, 512", "hearing": "3.5, 448"})

    body = "\n".join(out).rstrip("\n")
    block = BEGIN + "\n" + body + "\n" + END + "\n\n"
    i = base.index(X_MARK)
    new = base[:i] + block + base[i:]
    open(path, "wb").write(new.replace("\n", nl).encode("utf-8"))
    print("breach: %d blocks written" % sum(1 for l in out if l == "end"))


if __name__ == "__main__":
    main()
