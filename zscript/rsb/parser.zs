// ============================================================================
// READING RSBDEFS.
//
// Line-oriented, the reload system's grammar: a header `<kind> <name>`, then
// `key = value, value` lines, then `end`. `#` starts a comment; keys are
// case-insensitive.
//
// ------------------------------------------------ A REFUSAL, NOT A WARNING
//
// An unknown key, the wrong number of values, a word where a number belongs, a
// header with no `end` before the next one: each refuses THAT profile, naming
// the lump, the line and the reason. The other profiles still load. A typo must
// never leave a setting at its default with nothing said -- whoever wrote it
// would be debugging an effect that never received their number.
//
// Whether a profile is COMPLETE -- a round states its speed, names an impact
// that exists -- is decided after every lump has been read
// (RSB_Registry.Finish), because a later package may supply the impact.
// ============================================================================

class RSB_Parser
{
	// Reads one lump into the set. Returns how many profiles it refused.
	static int ParseLump(RSB_DefSet set, String text, String source)
	{
		Array<String> lines;
		text.Split(lines, "\n");

		RSB_Def cur = null;
		bool refused = false;   // the open profile was refused: skip to its `end`
		int refusals = 0;

		for (int ln = 0; ln < lines.Size(); ln++)
		{
			String raw = lines[ln];
			int hash = raw.IndexOf("#");
			if (hash >= 0) raw = raw.Left(hash);
			raw.Replace("\t", " ");
			raw.Replace("\r", "");
			raw.StripLeftRight();
			if (raw.Length() == 0) continue;

			int eq = raw.IndexOf("=");
			if (eq < 0)
			{
				Array<String> words;
				raw.Split(words, " ", TOK_SKIPEMPTY);
				String head = words[0].MakeLower();

				if (head == "end")
				{
					if (cur && !refused)
					{
						if (set.Put(cur))
							RSB_Log.Trace(String.Format("%s line %d: %s %s replaces an earlier profile of that name",
								source, cur.lineNo, cur.kind, cur.id));
					}
					else if (!cur && !refused)
					{
						Refuse(source, ln + 1, "", "", "`end` with no profile open");
						refusals++;
					}
					cur = null;
					refused = false;
					continue;
				}

				// A header. A profile still open never reached its `end`.
				if (cur && !refused)
				{
					Refuse(source, cur.lineNo, cur.kind, cur.id, "no `end` before the next profile");
					refusals++;
				}
				cur = null;
				refused = false;

				if (words.Size() != 2)
				{
					Refuse(source, ln + 1, head, "", "a header is `<kind> <name>`, two words and nothing else");
					refusals++;
					refused = true;
					continue;
				}
				cur = NewDef(head);
				if (!cur)
				{
					Refuse(source, ln + 1, head, words[1], "unknown kind -- round, wake, impact or flash");
					refusals++;
					refused = true;
					continue;
				}
				cur.kind   = head;
				cur.id     = words[1];
				cur.source = source;
				cur.lineNo = ln + 1;
				continue;
			}

			// key = value, value
			if (refused) continue;
			if (!cur)
			{
				Refuse(source, ln + 1, "", "", "a key outside any profile");
				refusals++;
				continue;
			}
			String key = raw.Left(eq);
			key.StripLeftRight();
			key = key.MakeLower();
			String val = raw.Mid(eq + 1);
			Array<String> parts;
			val.Split(parts, ",", TOK_SKIPEMPTY);
			for (int p = 0; p < parts.Size(); p++)
			{
				String one = parts[p];
				one.StripLeftRight();
				parts[p] = one;
			}

			String why = Apply(cur, key, parts);
			if (why != "")
			{
				Refuse(source, ln + 1, cur.kind, cur.id, why);
				refusals++;
				cur = null;
				refused = true;
			}
		}

		if (cur && !refused)
		{
			Refuse(source, cur.lineNo, cur.kind, cur.id, "the lump ended before its `end`");
			refusals++;
		}
		return refusals;
	}

	private static void Refuse(String source, int atLine, String kind, String pid, String why)
	{
		String what = (kind.Length() > 0) ? String.Format("%s %s", kind, pid) : "this line";
		RSB_Log.Err(String.Format("%s line %d: %s REFUSED -- %s", source, atLine, what, why));
	}

	// A fresh profile of a kind, with every required field unstated (-1) and every
	// optional effect switched off.
	private static RSB_Def NewDef(String kind)
	{
		Color white = Color(255, 255, 255, 255);
		if (kind == "round")
		{
			let d = new("RSB_RoundDef");
			d.speed = -1;
			d.radius = -1;
			d.damageBase = -1;
			d.damageDice = -1;
			d.lookKind = "";
			d.lookName = "";
			d.glide = false;
			d.wake = "none";
			d.impact = "none";
			return d;
		}
		if (kind == "wake")
		{
			let d = new("RSB_WakeDef");
			d.perStep = 0;
			d.sizeStart = 0;
			d.sizeEnd = 0;
			d.life = 0;
			d.drift = 0;
			d.drag = 0;
			d.gravity = 0;
			d.tint = white;
			d.glow = 1;
			return d;
		}
		if (kind == "impact")
		{
			let d = new("RSB_ImpactDef");
			d.sparkCount = 0;
			d.sparkSpread = 0;
			d.sparkSpeed = 0;
			d.sparkLife = 0;
			d.sparkColor = white;
			d.sparkGlow = 1;
			d.markShape = -1;
			d.markRadius = 0;
			d.markLife = 0;
			d.markColor = white;
			d.soundName = "none";
			return d;
		}
		if (kind == "flash")
		{
			let d = new("RSB_FlashDef");
			d.lightRadius = 0;
			d.lightPunch = 0;
			d.lightTics = 0;
			d.lightColor = white;
			d.coneInner = 0;
			d.coneOuter = 0;
			d.coneLength = 0;
			d.coneDensity = 0;
			d.coneTics = 0;
			d.coreCount = 0;
			d.coreLife = 0;
			return d;
		}
		return null;
	}

	// One key onto a profile. Returns "" or the reason it cannot be applied.
	private static String Apply(RSB_Def d, String key, out Array<String> v)
	{
		let r = RSB_RoundDef(d);
		if (r) return ApplyRound(r, key, v);
		let w = RSB_WakeDef(d);
		if (w) return ApplyWake(w, key, v);
		let im = RSB_ImpactDef(d);
		if (im) return ApplyImpact(im, key, v);
		let f = RSB_FlashDef(d);
		if (f) return ApplyFlash(f, key, v);
		return "internal: a profile of no known kind";
	}

	// ---------------------------------------------------------------- ROUND
	private static String ApplyRound(RSB_RoundDef r, String key, out Array<String> v)
	{
		String why;
		if (key == "speed")
		{
			why = Nums(v, 1); if (why != "") return why;
			r.speed = v[0].ToDouble();
			return (r.speed > 0) ? "" : "speed must be above 0";
		}
		if (key == "radius")
		{
			why = Nums(v, 1); if (why != "") return why;
			r.radius = v[0].ToDouble();
			return (r.radius > 0) ? "" : "radius must be above 0";
		}
		if (key == "damage")
		{
			why = Nums(v, 2); if (why != "") return why;
			r.damageBase = v[0].ToInt();
			r.damageDice = v[1].ToInt();
			return (r.damageBase >= 0 && r.damageDice >= 1) ? "" : "damage is base (0 or more), dice (1 or more)";
		}
		if (key == "look")
		{
			if (v.Size() != 2) return "look is `sprite, <name>` or `model, <name>`";
			String k = v[0].MakeLower();
			if (k != "sprite" && k != "model") return String.Format("look kind \"%s\" is not sprite or model", v[0]);
			if (k == "sprite" && v[1].Length() != 4) return String.Format("sprite \"%s\" is not four letters", v[1]);
			r.lookKind = k;
			r.lookName = v[1];
			return "";
		}
		if (key == "glide")
		{
			if (v.Size() != 1) return "glide is yes or no";
			int yn = YesNo(v[0]);
			if (yn < 0) return String.Format("glide \"%s\" is not yes or no", v[0]);
			r.glide = (yn == 1);
			return "";
		}
		if (key == "wake")
		{
			if (v.Size() != 1) return "wake is one profile name, or none";
			r.wake = v[0];
			return "";
		}
		if (key == "impact")
		{
			if (v.Size() != 1) return "impact is one profile name, or none";
			r.impact = v[0];
			return "";
		}
		return String.Format("unknown round key \"%s\"", key);
	}

	// ----------------------------------------------------------------- WAKE
	private static String ApplyWake(RSB_WakeDef w, String key, out Array<String> v)
	{
		String why;
		Color c;
		if (key == "perstep")
		{
			why = Nums(v, 1); if (why != "") return why;
			w.perStep = v[0].ToInt();
			return (w.perStep >= 0) ? "" : "perstep must be 0 or more";
		}
		if (key == "size")
		{
			why = Nums(v, 2); if (why != "") return why;
			w.sizeStart = v[0].ToDouble();
			w.sizeEnd = v[1].ToDouble();
			return (w.sizeStart >= 0 && w.sizeEnd >= 0) ? "" : "size must be 0 or more";
		}
		if (key == "life")
		{
			why = Nums(v, 1); if (why != "") return why;
			w.life = v[0].ToDouble();
			return (w.life > 0) ? "" : "life must be above 0";
		}
		if (key == "drift")
		{
			why = Nums(v, 1); if (why != "") return why;
			w.drift = v[0].ToDouble();
			return "";
		}
		if (key == "drag")
		{
			why = Nums(v, 1); if (why != "") return why;
			w.drag = v[0].ToDouble();
			return (w.drag >= 0) ? "" : "drag must be 0 or more";
		}
		if (key == "gravity")
		{
			why = Nums(v, 1); if (why != "") return why;
			w.gravity = v[0].ToDouble();
			return "";
		}
		if (key == "color")
		{
			why = ReadColor(v, c); if (why != "") return why;
			w.tint = c;
			return "";
		}
		if (key == "glow")
		{
			why = Nums(v, 1); if (why != "") return why;
			w.glow = v[0].ToDouble();
			return (w.glow >= 0) ? "" : "glow must be 0 or more";
		}
		return String.Format("unknown wake key \"%s\"", key);
	}

	// --------------------------------------------------------------- IMPACT
	private static String ApplyImpact(RSB_ImpactDef im, String key, out Array<String> v)
	{
		String why;
		Color c;
		if (key == "sparks")
		{
			why = Nums(v, 3); if (why != "") return why;
			im.sparkCount = v[0].ToInt();
			im.sparkSpread = v[1].ToDouble();
			im.sparkSpeed = v[2].ToDouble();
			return (im.sparkCount >= 0 && im.sparkSpread >= 0 && im.sparkSpeed >= 0) ? "" : "sparks count, spread and speed must be 0 or more";
		}
		if (key == "sparklife")
		{
			why = Nums(v, 1); if (why != "") return why;
			im.sparkLife = v[0].ToDouble();
			return (im.sparkLife >= 0) ? "" : "sparklife must be 0 or more";
		}
		if (key == "sparkcolor")
		{
			why = ReadColor(v, c); if (why != "") return why;
			im.sparkColor = c;
			return "";
		}
		if (key == "sparkglow")
		{
			why = Nums(v, 1); if (why != "") return why;
			im.sparkGlow = v[0].ToDouble();
			return (im.sparkGlow >= 0) ? "" : "sparkglow must be 0 or more";
		}
		if (key == "mark")
		{
			if (v.Size() != 3) return "mark is shape, radius, life";
			int shape = ShapeId(v[0]);
			if (shape < 0) return String.Format("mark shape \"%s\" is not pool, bar, gouge, ring, hexfield, hexring, spiral, boxring, star, sunburst, grid, invert or box", v[0]);
			if (!IsNum(v[1]) || !IsNum(v[2])) return "mark radius and life must be numbers";
			im.markShape = shape;
			im.markRadius = v[1].ToDouble();
			im.markLife = v[2].ToInt();
			return (im.markRadius > 0 && im.markLife > 0) ? "" : "mark radius and life must be above 0";
		}
		if (key == "markcolor")
		{
			why = ReadColor(v, c); if (why != "") return why;
			im.markColor = c;
			return "";
		}
		if (key == "sound")
		{
			if (v.Size() != 1) return "sound is one SNDINFO name, or none";
			im.soundName = v[0];
			return "";
		}
		return String.Format("unknown impact key \"%s\"", key);
	}

	// ---------------------------------------------------------------- FLASH
	private static String ApplyFlash(RSB_FlashDef f, String key, out Array<String> v)
	{
		String why;
		Color c;
		if (key == "light")
		{
			why = Nums(v, 3); if (why != "") return why;
			f.lightRadius = v[0].ToDouble();
			f.lightPunch = v[1].ToDouble();
			f.lightTics = v[2].ToInt();
			return (f.lightRadius >= 0 && f.lightPunch >= 0 && f.lightTics >= 0) ? "" : "light radius, punch and tics must be 0 or more";
		}
		if (key == "lightcolor")
		{
			why = ReadColor(v, c); if (why != "") return why;
			f.lightColor = c;
			return "";
		}
		if (key == "cone")
		{
			why = Nums(v, 4); if (why != "") return why;
			f.coneInner = v[0].ToDouble();
			f.coneOuter = v[1].ToDouble();
			f.coneLength = v[2].ToDouble();
			f.coneDensity = v[3].ToDouble();
			return (f.coneInner >= 0 && f.coneOuter >= 0 && f.coneLength >= 0 && f.coneDensity >= 0) ? "" : "cone values must be 0 or more";
		}
		if (key == "conetics")
		{
			why = Nums(v, 1); if (why != "") return why;
			f.coneTics = v[0].ToInt();
			return (f.coneTics >= 0) ? "" : "conetics must be 0 or more";
		}
		if (key == "core")
		{
			why = Nums(v, 2); if (why != "") return why;
			f.coreCount = v[0].ToInt();
			f.coreLife = v[1].ToDouble();
			return (f.coreCount >= 0 && f.coreLife >= 0) ? "" : "core count and life must be 0 or more";
		}
		return String.Format("unknown flash key \"%s\"", key);
	}

	// ---------------------------------------------------------------- VALUES

	// Exactly `need` values, every one a number.
	private static String Nums(out Array<String> v, int need)
	{
		if (v.Size() != need)
			return String.Format("wants %d value%s, got %d", need, (need == 1) ? "" : "s", v.Size());
		for (int i = 0; i < v.Size(); i++)
			if (!IsNum(v[i])) return String.Format("\"%s\" is not a number", v[i]);
		return "";
	}

	// Digits, with at most a sign and a decimal point -- ToDouble would read a
	// word as 0 and say nothing.
	private static bool IsNum(String s)
	{
		int n = s.Length();
		if (n == 0) return false;
		bool digit = false;
		for (int i = 0; i < n; i++)
		{
			int ch = s.ByteAt(i);
			if (ch >= 48 && ch <= 57) { digit = true; continue; }   // 0-9
			if (ch == 46 || ch == 45 || ch == 43) continue;           // . - +
			return false;
		}
		return digit;
	}

	// Three numbers, 0-255, into a local the caller copies onto its field.
	private static String ReadColor(out Array<String> v, out Color into)
	{
		String why = Nums(v, 3);
		if (why != "") return why;
		int rr = clamp(v[0].ToInt(), 0, 255);
		int gg = clamp(v[1].ToInt(), 0, 255);
		int bb = clamp(v[2].ToInt(), 0, 255);
		into = Color(255, rr, gg, bb);
		return "";
	}

	// 1 yes, 0 no, -1 neither.
	private static int YesNo(String s)
	{
		s = s.MakeLower();
		if (s == "yes" || s == "on" || s == "true") return 1;
		if (s == "no" || s == "off" || s == "false") return 0;
		return -1;
	}

	// The engine's surface stamp shapes (func_surfacestamps.fp STAMP_*). -1 if
	// the name is none of them.
	private static int ShapeId(String s)
	{
		s = s.MakeLower();
		if (s == "pool")     return 0;
		if (s == "bar")      return 1;
		if (s == "gouge")    return 2;
		if (s == "ring")     return 3;
		if (s == "hexfield") return 4;
		if (s == "hexring")  return 5;
		if (s == "spiral")   return 6;
		if (s == "boxring")  return 7;
		if (s == "star")     return 8;
		if (s == "sunburst") return 9;
		if (s == "grid")     return 10;
		if (s == "invert")   return 11;
		if (s == "box")      return 12;
		return -1;
	}
}
