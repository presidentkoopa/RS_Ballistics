// ============================================================================
// READING RSBDEFS.
//
// Line-oriented: a header `<kind> <name>`, then `key = value, value` lines,
// then `end`. `#` starts a comment; keys are case-insensitive.
//
// ------------------------------------------------ A REFUSAL, NOT A WARNING
//
// An unknown key, the wrong number of values, a word where a number belongs, a
// header with no `end` before the next one: each refuses THAT profile, naming
// the lump, the line and the reason. The other profiles still load. A typo must
// never leave a setting at its default with nothing said.
//
// Whether a profile is COMPLETE -- a round states its speed, an impact's bursts
// exist -- is decided after every lump has been read (RSB_Registry.Finish),
// because a later package may supply what it names.
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
					Refuse(source, ln + 1, head, words[1], (head ~== "material") ? "material blocks are gone: textures get their surface from SURFACES lumps now (RS_Ballistics' SURFACES.txt)" : "unknown kind -- style, burst, impact, round, ballistics, roundlook, wake, flash, flame or ejecta");
					refusals++;
					refused = true;
					continue;
				}
				// NETPLAY: ballistics are what the game knows, the same on every
				// machine, so they have no variants a local setting could pick.
				if (head == "ballistics" && (words[1].IndexOf("~") >= 0 || words[1].IndexOf("@") >= 0 || words[1].IndexOf(".") >= 0))
				{
					Refuse(source, ln + 1, head, words[1], "ballistics have no ~style, .material or @tier variants -- they are the same on every machine");
					refusals++;
					cur = null;
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
			d.ballistics = "";
			d.roundLook = "";
			return d;
		}
		if (kind == "ballistics")
		{
			let d = new("RSB_BallisticsDef");
			d.speed = -1;
			d.radius = -1;
			d.damageBase = -1;
			d.damageDice = -1;
			return d;
		}
		if (kind == "roundlook")
		{
			let d = new("RSB_RoundLookDef");
			d.lookKind = "";
			d.lookName = "";
			d.glide = false;
			d.wake = "none";
			d.impact = "none";
			d.whizRadius = 0;
			d.whizSound = "none";
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
			d.particle = "";
			d.particleHandle = 0;
			return d;
		}
		if (kind == "burst")
		{
			let d = new("RSB_BurstDef");
			d.count = 0;
			d.cone = 30;
			d.speed = 100;
			d.speedJitter = 0.3;
			d.tint = white;
			d.glow = 1;
			d.life = 0.5;
			d.lifeJitter = 0.3;
			d.sizeStart = 1;
			d.sizeEnd = 0.5;
			d.gravity = 0;
			d.drag = 0;
			d.orient = 0;
			d.stretch = 0;
			d.aim = RSB_BurstDef.AIM_NORMAL;
			d.offset = 1.5;
			d.particle = "";
			d.particleHandle = 0;
			return d;
		}
		if (kind == "impact")
		{
			let d = new("RSB_ImpactDef");
			d.markShape = -1;
			d.markRadius = 0;
			d.markLife = 0;
			d.markColor = white;
			d.soundName = "none";
			d.lightRadius = 0;
			d.lightIntensity = 1;
			d.lightTics = 3;
			d.lightColor = Color(255, 255, 200, 150);
			d.glanceDeg = 0;
			d.glanceSound = "none";
			d.glanceBurst = "none";
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
			d.flameScale = 0;
			d.smokeCount = 0;
			d.smokeScale = 0.02;
			d.smokeAlpha = 0.3;
			d.smokeParticle = "";
			d.smokeHandle = 0;
			return d;
		}
		if (kind == "ejecta")
		{
			let d = new("RSB_EjectaDef");
			d.lookKind = "sprite";
			d.lookName = "RSCS";
			d.scale = 0.06;
			d.speedMul = 1.0;
			d.speedJitter = 0.2;
			d.bounceFloor = 0.45;
			d.bounceWall = 0.3;
			d.bounceCount = 4;
			d.gravity = 0.6;
			d.soundName = "none";
			d.hotTics = 0;
			d.lifeTics = 700;
			return d;
		}
		if (kind == "flame")
		{
			let d = new("RSB_FlameDef");
			d.tubeSegments = 0;
			d.tubeStreamShare = 1.0;
			d.tubeIntensity = 1.0;
			d.tubeSwell = 1.0;
			d.tubeHalo = 0.5;
			d.tubeLickScale = 0.05;
			d.tubeLickSpeed = 1.5;
			d.heatNoise = 0.08;
			d.heatRise = 20;
			d.reach = 400;
			d.fuelSpeed = 800;
			d.spread = 2;
			d.landingTics = 2;
			d.markShape = -1;
			d.markRadius = 0;
			d.markLife = 0;
			d.markColor = white;
			d.markTics = 6;
			d.lightRadius = 0;
			d.lightIntensity = 1;
			d.flicker = 0.3;
			d.lightColor = Color(255, 255, 150, 60);
			d.landLightRadius = 0;
			d.landLightIntensity = 1;
			d.loopSound = "none";
			d.startSound = "none";
			d.stopSound = "none";
			d.jets = 1;
			d.jetSpacing = 0;
			d.jetSplay = 0;
			d.sputterBelow = 0;
			d.sputterSound = "none";
			return d;
		}
		if (kind == "style")
		{
			let d = new("RSB_StyleDef");
			d.particlesMul = 1;
			d.glowMul = 1;
			d.lightsMul = 1;
			d.marksMul = 1;
			d.flashMul = 1;
			d.coneMul = 1;
			d.flameMul = 1;
			d.smokeMul = 1;
			d.whizMul = 1;
			return d;
		}
		return null;
	}

	// One key onto a profile. Returns "" or the reason it cannot be applied.
	private static String Apply(RSB_Def d, String key, out Array<String> v)
	{
		let r = RSB_RoundDef(d);
		if (r) return ApplyRound(r, key, v);
		let bl = RSB_BallisticsDef(d);
		if (bl) return ApplyBallistics(bl, key, v);
		let lk = RSB_RoundLookDef(d);
		if (lk) return ApplyRoundLook(lk, key, v);
		let w = RSB_WakeDef(d);
		if (w) return ApplyWake(w, key, v);
		let b = RSB_BurstDef(d);
		if (b) return ApplyBurst(b, key, v);
		let im = RSB_ImpactDef(d);
		if (im) return ApplyImpact(im, key, v);
		let f = RSB_FlashDef(d);
		if (f) return ApplyFlash(f, key, v);
		let e = RSB_EjectaDef(d);
		if (e) return ApplyEjecta(e, key, v);
		let st = RSB_StyleDef(d);
		if (st) return ApplyStyle(st, key, v);
		let fm = RSB_FlameDef(d);
		if (fm) return ApplyFlame(fm, key, v);
		return "internal: a profile of no known kind";
	}

	// ---------------------------------------------------------------- ROUND
	// A pairing: which ballistics, which look.
	private static String ApplyRound(RSB_RoundDef r, String key, out Array<String> v)
	{
		if (key == "ballistics")
		{
			if (v.Size() != 1) return "ballistics is one ballistics profile name";
			r.ballistics = v[0];
			return "";
		}
		if (key == "roundlook")
		{
			if (v.Size() != 1) return "roundlook is one roundlook profile name";
			r.roundLook = v[0];
			return "";
		}
		if (key == "speed" || key == "radius" || key == "damage")
			return String.Format("`%s` belongs in a `ballistics` profile -- a round names only `ballistics` and `roundlook`", key);
		if (key == "look" || key == "glide" || key == "wake" || key == "impact" || key == "whiz")
			return String.Format("`%s` belongs in a `roundlook` profile -- a round names only `ballistics` and `roundlook`", key);
		return String.Format("unknown round key \"%s\" -- a round names `ballistics` and `roundlook`", key);
	}

	// ----------------------------------------------------------- BALLISTICS
	// What the game knows about a round. Read as written on every machine.
	private static String ApplyBallistics(RSB_BallisticsDef bl, String key, out Array<String> v)
	{
		String why;
		if (key == "speed")
		{
			why = Nums(v, 1); if (why != "") return why;
			bl.speed = v[0].ToDouble();
			return (bl.speed > 0) ? "" : "speed must be above 0";
		}
		if (key == "radius")
		{
			why = Nums(v, 1); if (why != "") return why;
			bl.radius = v[0].ToDouble();
			return (bl.radius > 0) ? "" : "radius must be above 0";
		}
		if (key == "damage")
		{
			why = Nums(v, 2); if (why != "") return why;
			bl.damageBase = v[0].ToInt();
			bl.damageDice = v[1].ToInt();
			return (bl.damageBase >= 0 && bl.damageDice >= 1) ? "" : "damage is base (0 or more), dice (1 or more)";
		}
		return String.Format("unknown ballistics key \"%s\" -- speed, radius or damage", key);
	}

	// ------------------------------------------------------------ ROUNDLOOK
	// What a player sees and hears of a round. Presentation only.
	private static String ApplyRoundLook(RSB_RoundLookDef lk, String key, out Array<String> v)
	{
		if (key == "look")
		{
			if (v.Size() == 1 && v[0] ~== "none")
			{
				lk.lookKind = "none";
				lk.lookName = "";
				return "";
			}
			if (v.Size() != 2) return "look is `sprite, <name>`, `model, <name>` or `none`";
			String k = v[0].MakeLower();
			if (k != "sprite" && k != "model") return String.Format("look kind \"%s\" is not sprite, model or none", v[0]);
			if (k == "sprite" && v[1].Length() != 4) return String.Format("sprite \"%s\" is not four letters", v[1]);
			lk.lookKind = k;
			lk.lookName = v[1];
			return "";
		}
		if (key == "glide")
		{
			if (v.Size() != 1) return "glide is yes or no";
			int yn = YesNo(v[0]);
			if (yn < 0) return String.Format("glide \"%s\" is not yes or no", v[0]);
			lk.glide = (yn == 1);
			return "";
		}
		if (key == "wake")
		{
			if (v.Size() != 1) return "wake is one profile name, or none";
			lk.wake = v[0];
			return "";
		}
		if (key == "impact")
		{
			if (v.Size() != 1) return "impact is one profile name, or none";
			lk.impact = v[0];
			return "";
		}
		if (key == "whiz")
		{
			if (v.Size() != 2 || !IsNum(v[0])) return "whiz is radius (map units), sound -- or 0, none";
			lk.whizRadius = v[0].ToDouble();
			lk.whizSound = v[1];
			return (lk.whizRadius >= 0) ? "" : "whiz radius must be 0 or more";
		}
		return String.Format("unknown roundlook key \"%s\" -- look, glide, wake, impact or whiz", key);
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
		if (key == "particle")
		{
			if (v.Size() != 1) return "particle is one PARTICLEDEFS definition name, or none";
			w.particle = (v[0] ~== "none") ? "" : v[0];
			w.particleHandle = 0;
			return "";
		}
		return String.Format("unknown wake key \"%s\"", key);
	}

	// ---------------------------------------------------------------- BURST
	private static String ApplyBurst(RSB_BurstDef b, String key, out Array<String> v)
	{
		String why;
		Color c;
		if (key == "count")
		{
			why = Nums(v, 1); if (why != "") return why;
			b.count = v[0].ToInt();
			return (b.count >= 0) ? "" : "count must be 0 or more";
		}
		if (key == "cone")
		{
			why = Nums(v, 1); if (why != "") return why;
			b.cone = v[0].ToDouble();
			return (b.cone >= 0 && b.cone <= 180) ? "" : "cone is a half-angle from 0 to 180 degrees";
		}
		if (key == "speed")
		{
			why = Nums(v, 2); if (why != "") return why;
			b.speed = v[0].ToDouble();
			b.speedJitter = v[1].ToDouble();
			return (b.speed >= 0 && b.speedJitter >= 0) ? "" : "speed is speed (map units/s), jitter (0..1), both 0 or more";
		}
		if (key == "life")
		{
			why = Nums(v, 2); if (why != "") return why;
			b.life = v[0].ToDouble();
			b.lifeJitter = v[1].ToDouble();
			return (b.life > 0 && b.lifeJitter >= 0) ? "" : "life is seconds (above 0), jitter (0 or more)";
		}
		if (key == "color")
		{
			why = ReadColor(v, c); if (why != "") return why;
			b.tint = c;
			return "";
		}
		if (key == "glow")
		{
			why = Nums(v, 1); if (why != "") return why;
			b.glow = v[0].ToDouble();
			return (b.glow >= 0) ? "" : "glow must be 0 or more";
		}
		if (key == "size")
		{
			why = Nums(v, 2); if (why != "") return why;
			b.sizeStart = v[0].ToDouble();
			b.sizeEnd = v[1].ToDouble();
			return (b.sizeStart >= 0 && b.sizeEnd >= 0) ? "" : "size must be 0 or more";
		}
		if (key == "gravity")
		{
			why = Nums(v, 1); if (why != "") return why;
			b.gravity = v[0].ToDouble();
			return "";
		}
		if (key == "drag")
		{
			why = Nums(v, 1); if (why != "") return why;
			b.drag = v[0].ToDouble();
			return (b.drag >= 0) ? "" : "drag must be 0 or more";
		}
		if (key == "orient")
		{
			if (v.Size() != 1) return "orient is billboard, streak or flake";
			String o = v[0].MakeLower();
			if (o == "billboard") b.orient = 0;
			else if (o == "streak") b.orient = 1;
			else if (o == "flake") b.orient = 2;
			else return String.Format("orient \"%s\" is not billboard, streak or flake", v[0]);
			return "";
		}
		if (key == "stretch")
		{
			why = Nums(v, 1); if (why != "") return why;
			b.stretch = v[0].ToDouble();
			return (b.stretch >= 0) ? "" : "stretch must be 0 or more";
		}
		if (key == "aim")
		{
			if (v.Size() != 1) return "aim is normal, reflect, back, along or up";
			String a = v[0].MakeLower();
			if (a == "normal") b.aim = RSB_BurstDef.AIM_NORMAL;
			else if (a == "reflect") b.aim = RSB_BurstDef.AIM_REFLECT;
			else if (a == "back") b.aim = RSB_BurstDef.AIM_BACK;
			else if (a == "along") b.aim = RSB_BurstDef.AIM_ALONG;
			else if (a == "up") b.aim = RSB_BurstDef.AIM_UP;
			else return String.Format("aim \"%s\" is not normal, reflect, back, along or up", v[0]);
			return "";
		}
		if (key == "offset")
		{
			why = Nums(v, 1); if (why != "") return why;
			b.offset = v[0].ToDouble();
			return "";
		}
		if (key == "particle")
		{
			if (v.Size() != 1) return "particle is one PARTICLEDEFS definition name, or none";
			b.particle = (v[0] ~== "none") ? "" : v[0];
			b.particleHandle = 0;
			return "";
		}
		if (key == "shape")
		{
			if (v.Size() != 1) return "shape is cone or disc";
			String sh = v[0].MakeLower();
			if (sh == "cone") b.shape = RSB_BurstDef.SHAPE_CONE;
			else if (sh == "disc") b.shape = RSB_BurstDef.SHAPE_DISC;
			else return String.Format("shape \"%s\" is not cone or disc", v[0]);
			return "";
		}
		return String.Format("unknown burst key \"%s\"", key);
	}

	// --------------------------------------------------------------- IMPACT
	private static String ApplyImpact(RSB_ImpactDef im, String key, out Array<String> v)
	{
		String why;
		Color c;
		if (key == "bursts")
		{
			im.bursts.Clear();
			if (v.Size() == 1 && v[0] ~== "none") return "";
			if (v.Size() == 0) return "bursts is one or more burst profile names, or none";
			for (int i = 0; i < v.Size(); i++) im.bursts.Push(v[i]);
			return "";
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
		if (key == "light")
		{
			why = Nums(v, 3); if (why != "") return why;
			im.lightRadius = v[0].ToDouble();
			im.lightIntensity = v[1].ToDouble();
			im.lightTics = v[2].ToInt();
			return (im.lightRadius >= 0 && im.lightIntensity >= 0 && im.lightTics >= 1) ? "" : "light is radius (0 or more), intensity (0 or more), tics (1 or more)";
		}
		if (key == "lightcolor")
		{
			why = ReadColor(v, c); if (why != "") return why;
			im.lightColor = c;
			return "";
		}
		if (key == "glance")
		{
			if (v.Size() != 3 || !IsNum(v[0])) return "glance is degrees, sound, burst -- sound and burst may be none";
			im.glanceDeg = v[0].ToDouble();
			im.glanceSound = v[1];
			im.glanceBurst = v[2];
			return (im.glanceDeg >= 0 && im.glanceDeg < 90) ? "" : "glance degrees must be from 0 to below 90";
		}
		if (key == "heat")
		{
			String hw = Nums(v, 3);
			if (hw != "") return hw;
			im.heatRadius = v[0].ToDouble();
			im.heatStrength = v[1].ToDouble();
			im.heatTics = v[2].ToInt();
			return (im.heatRadius >= 0 && im.heatStrength >= 0 && im.heatTics >= 0) ? "" : "heat is radius, strength, tics -- all 0 or more";
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
		if (key == "bursts")
		{
			f.bursts.Clear();
			if (v.Size() == 1 && v[0] ~== "none") return "";
			if (v.Size() == 0) return "bursts is one or more burst profile names, or none";
			for (int i = 0; i < v.Size(); i++) f.bursts.Push(v[i]);
			return "";
		}
		if (key == "flame")
		{
			why = Nums(v, 1); if (why != "") return why;
			f.flameScale = v[0].ToDouble();
			return (f.flameScale >= 0) ? "" : "flame scale must be 0 or more (0 = no flame sprite)";
		}
		if (key == "smoke")
		{
			why = Nums(v, 3); if (why != "") return why;
			f.smokeCount = v[0].ToInt();
			f.smokeScale = v[1].ToDouble();
			f.smokeAlpha = v[2].ToDouble();
			return (f.smokeCount >= 0 && f.smokeScale >= 0 && f.smokeAlpha >= 0 && f.smokeAlpha <= 1) ? "" : "smoke is count (0 or more), scale (0 or more), alpha (0..1)";
		}
		if (key == "smokeparticle")
		{
			if (v.Size() != 1) return "smokeparticle is one PARTICLEDEFS definition name, or none";
			f.smokeParticle = (v[0] ~== "none") ? "" : v[0];
			f.smokeHandle = 0;
			return "";
		}
		if (key == "heat")
		{
			String hw = Nums(v, 4);
			if (hw != "") return hw;
			f.heatRadius = v[0].ToDouble();
			f.heatLength = v[1].ToDouble();
			f.heatStrength = v[2].ToDouble();
			f.heatTics = v[3].ToInt();
			return (f.heatRadius >= 0 && f.heatLength >= 0 && f.heatStrength >= 0 && f.heatTics >= 0) ? "" : "heat is radius, length, strength, tics -- all 0 or more";
		}
		return String.Format("unknown flash key \"%s\"", key);
	}

	// --------------------------------------------------------------- EJECTA
	private static String ApplyEjecta(RSB_EjectaDef e, String key, out Array<String> v)
	{
		String why;
		if (key == "look")
		{
			if (v.Size() != 2) return "look is `sprite, <name>`";
			if (!(v[0] ~== "sprite")) return "ejecta look kind must be sprite";
			if (v[1].Length() != 4) return String.Format("sprite \"%s\" is not four letters", v[1]);
			e.lookKind = "sprite";
			e.lookName = v[1];
			return "";
		}
		if (key == "scale")
		{
			why = Nums(v, 1); if (why != "") return why;
			e.scale = v[0].ToDouble();
			return (e.scale > 0) ? "" : "scale must be above 0";
		}
		if (key == "speed")
		{
			why = Nums(v, 2); if (why != "") return why;
			e.speedMul = v[0].ToDouble();
			e.speedJitter = v[1].ToDouble();
			return (e.speedMul >= 0 && e.speedJitter >= 0) ? "" : "speed is multiplier, jitter -- both 0 or more";
		}
		if (key == "bounce")
		{
			why = Nums(v, 3); if (why != "") return why;
			e.bounceFloor = v[0].ToDouble();
			e.bounceWall = v[1].ToDouble();
			e.bounceCount = v[2].ToInt();
			return (e.bounceFloor >= 0 && e.bounceWall >= 0 && e.bounceCount >= 0) ? "" : "bounce is floor factor, wall factor, bounces -- all 0 or more";
		}
		if (key == "gravity")
		{
			why = Nums(v, 1); if (why != "") return why;
			e.gravity = v[0].ToDouble();
			return (e.gravity >= 0) ? "" : "gravity must be 0 or more";
		}
		if (key == "sound")
		{
			if (v.Size() != 1) return "sound is one SNDINFO name, or none";
			e.soundName = v[0];
			return "";
		}
		if (key == "hot")
		{
			why = Nums(v, 1); if (why != "") return why;
			e.hotTics = v[0].ToInt();
			return (e.hotTics >= 0) ? "" : "hot must be 0 or more tics";
		}
		if (key == "life")
		{
			why = Nums(v, 1); if (why != "") return why;
			e.lifeTics = v[0].ToInt();
			return (e.lifeTics >= 1) ? "" : "life must be 1 or more tics";
		}
		return String.Format("unknown ejecta key \"%s\"", key);
	}

	// ---------------------------------------------------------------- FLAME
	private static String ApplyFlame(RSB_FlameDef fm, String key, out Array<String> v)
	{
		String why;
		Color c;
		if (key == "reach")
		{
			why = Nums(v, 1); if (why != "") return why;
			fm.reach = v[0].ToDouble();
			return (fm.reach > 0) ? "" : "reach must be above 0";
		}
		if (key == "speed")
		{
			why = Nums(v, 1); if (why != "") return why;
			fm.fuelSpeed = v[0].ToDouble();
			return (fm.fuelSpeed > 0) ? "" : "speed (the fuel's, map units a second) must be above 0";
		}
		if (key == "spread")
		{
			why = Nums(v, 1); if (why != "") return why;
			fm.spread = v[0].ToDouble();
			return (fm.spread >= 0 && fm.spread <= 45) ? "" : "spread is 0 to 45 degrees";
		}
		if (key == "stream")
		{
			fm.stream.Clear();
			if (v.Size() == 1 && v[0] ~== "none") return "";
			if (v.Size() == 0) return "stream is one or more burst names, or none";
			for (int i = 0; i < v.Size(); i++) fm.stream.Push(v[i]);
			return "";
		}
		if (key == "landing")
		{
			fm.landing.Clear();
			if (v.Size() == 1 && v[0] ~== "none") return "";
			if (v.Size() == 0) return "landing is one or more burst names, or none";
			for (int i = 0; i < v.Size(); i++) fm.landing.Push(v[i]);
			return "";
		}
		if (key == "pilot")
		{
			fm.pilot.Clear();
			if (v.Size() == 1 && v[0] ~== "none") return "";
			if (v.Size() == 0) return "pilot is one or more burst names, or none";
			for (int i = 0; i < v.Size(); i++) fm.pilot.Push(v[i]);
			return "";
		}
		if (key == "landingtics")
		{
			why = Nums(v, 1); if (why != "") return why;
			fm.landingTics = v[0].ToInt();
			return (fm.landingTics >= 1) ? "" : "landingtics must be 1 or more";
		}
		if (key == "scorch")
		{
			if (v.Size() != 3) return "scorch is shape, radius, life";
			int shape = ShapeId(v[0]);
			if (shape < 0) return String.Format("scorch shape \"%s\" is not a stamp shape (pool, sunburst, ring...)", v[0]);
			if (!IsNum(v[1]) || !IsNum(v[2])) return "scorch radius and life must be numbers";
			fm.markShape = shape;
			fm.markRadius = v[1].ToDouble();
			fm.markLife = v[2].ToInt();
			return (fm.markRadius > 0 && fm.markLife > 0) ? "" : "scorch radius and life must be above 0";
		}
		if (key == "scorchcolor")
		{
			why = ReadColor(v, c); if (why != "") return why;
			fm.markColor = c;
			return "";
		}
		if (key == "scorchtics")
		{
			why = Nums(v, 1); if (why != "") return why;
			fm.markTics = v[0].ToInt();
			return (fm.markTics >= 1) ? "" : "scorchtics must be 1 or more";
		}
		if (key == "light")
		{
			why = Nums(v, 3); if (why != "") return why;
			fm.lightRadius = v[0].ToDouble();
			fm.lightIntensity = v[1].ToDouble();
			fm.flicker = v[2].ToDouble();
			return (fm.lightRadius >= 0 && fm.lightIntensity >= 0 && fm.flicker >= 0 && fm.flicker <= 1) ? "" : "light is radius, intensity (both 0 or more), flicker (0..1)";
		}
		if (key == "lightcolor")
		{
			why = ReadColor(v, c); if (why != "") return why;
			fm.lightColor = c;
			return "";
		}
		if (key == "landlight")
		{
			why = Nums(v, 2); if (why != "") return why;
			fm.landLightRadius = v[0].ToDouble();
			fm.landLightIntensity = v[1].ToDouble();
			return (fm.landLightRadius >= 0 && fm.landLightIntensity >= 0) ? "" : "landlight is radius, intensity -- both 0 or more";
		}
		if (key == "sounds")
		{
			if (v.Size() != 3) return "sounds is loop, start, stop -- SNDINFO names, or none";
			fm.loopSound = v[0];
			fm.startSound = v[1];
			fm.stopSound = v[2];
			return "";
		}
		if (key == "jets")
		{
			why = Nums(v, 3); if (why != "") return why;
			fm.jets = v[0].ToInt();
			fm.jetSpacing = v[1].ToDouble();
			fm.jetSplay = v[2].ToDouble();
			return (fm.jets >= 1 && fm.jets <= 8 && fm.jetSpacing >= 0 && fm.jetSplay >= 0 && fm.jetSplay <= 45) ? ""
				: "jets is count (1-8), spacing (map units, 0 or more), splay (0-45 degrees)";
		}
		if (key == "sputter")
		{
			if (v.Size() != 2 || !IsNum(v[0])) return "sputter is fuel share (0..1), sound -- or 0, none";
			fm.sputterBelow = v[0].ToDouble();
			fm.sputterSound = v[1];
			return (fm.sputterBelow >= 0 && fm.sputterBelow <= 1) ? "" : "sputter's fuel share is 0 to 1";
		}
		if (key == "flameout")
		{
			fm.flameout.Clear();
			if (v.Size() == 1 && v[0] ~== "none") return "";
			if (v.Size() == 0) return "flameout is one or more burst names, or none";
			for (int i = 0; i < v.Size(); i++) fm.flameout.Push(v[i]);
			return "";
		}
		if (key == "cling")
		{
			why = Nums(v, 1); if (why != "") return why;
			fm.cling = v[0].ToDouble();
			return (fm.cling >= 0 && fm.cling <= 2) ? "" : "cling is 0 to 2 seconds";
		}
		if (key == "tube")
		{
			why = Nums(v, 4); if (why != "") return why;
			fm.tubeSegments = v[0].ToInt();
			fm.tubeThick = v[1].ToDouble();
			fm.tubeSoft = v[2].ToDouble();
			fm.tubeStreamShare = v[3].ToDouble();
			return (fm.tubeSegments >= 0 && fm.tubeSegments <= 8 && fm.tubeThick >= 0 && fm.tubeSoft >= 0 && fm.tubeStreamShare >= 0 && fm.tubeStreamShare <= 1) ? ""
				: "tube is segments (0-8), thick, soft (map units, 0 or more), stream share while it draws (0..1)";
		}
		if (key == "tubelook")
		{
			why = Nums(v, 3); if (why != "") return why;
			fm.tubeIntensity = v[0].ToDouble();
			fm.tubeSwell = v[1].ToDouble();
			fm.tubeHalo = v[2].ToDouble();
			return (fm.tubeIntensity >= 0 && fm.tubeSwell >= 0 && fm.tubeSwell <= 16 && fm.tubeHalo >= 0) ? ""
				: "tubelook is intensity (0 or more), swell (0-16, the far end's halo over the nozzle's), halo (0 or more)";
		}
		if (key == "tubecolors")
		{
			if (v.Size() < 6 || v.Size() > 24 || v.Size() % 3 != 0) return "tubecolors is 2 to 8 colours, r, g, b each, the nozzle's first";
			fm.tubeColors.Clear();
			for (int i = 0; i < v.Size(); i++)
			{
				if (!IsNum(v[i])) return "tubecolors values must be numbers";
				int ch = v[i].ToInt();
				if (ch < 0 || ch > 255) return "tubecolors values are 0 to 255";
				fm.tubeColors.Push(ch);
			}
			return "";
		}
		if (key == "tubelicks")
		{
			why = Nums(v, 3); if (why != "") return why;
			fm.tubeLickStrength = v[0].ToDouble();
			fm.tubeLickScale = v[1].ToDouble();
			fm.tubeLickSpeed = v[2].ToDouble();
			return (fm.tubeLickStrength >= 0 && fm.tubeLickStrength <= 2 && fm.tubeLickScale >= 0 && fm.tubeLickScale <= 1) ? ""
				: "tubelicks is strength (0-2), scale (0-1 noise cells per map unit), speed";
		}
		if (key == "heat")
		{
			why = Nums(v, 5); if (why != "") return why;
			fm.heatRadiusStart = v[0].ToDouble();
			fm.heatRadiusEnd = v[1].ToDouble();
			fm.heatStrength = v[2].ToDouble();
			fm.heatNoise = v[3].ToDouble();
			fm.heatRise = v[4].ToDouble();
			return (fm.heatRadiusStart >= 0 && fm.heatRadiusEnd >= 0 && fm.heatStrength >= 0 && fm.heatNoise > 0 && fm.heatNoise <= 1) ? ""
				: "heat is radius at the nozzle, radius at the far end, strength, noise scale (above 0, up to 1), rise";
		}
		if (key == "heatland")
		{
			why = Nums(v, 2); if (why != "") return why;
			fm.heatLandRadius = v[0].ToDouble();
			fm.heatLandStrength = v[1].ToDouble();
			return (fm.heatLandRadius >= 0 && fm.heatLandStrength >= 0) ? "" : "heatland is radius, strength -- both 0 or more";
		}
		return String.Format("unknown flame key \"%s\"", key);
	}

	// ---------------------------------------------------------------- STYLE
	private static String ApplyStyle(RSB_StyleDef st, String key, out Array<String> v)
	{
		if (key == "particles" || key == "glow" || key == "lights" || key == "marks" || key == "flash"
			|| key == "cone" || key == "flame" || key == "smoke" || key == "whiz")
		{
			String why = Nums(v, 1);
			if (why != "") return why;
			double x = v[0].ToDouble();
			if (x < 0) return String.Format("%s must be 0 or more", key);
			if (key == "particles") st.particlesMul = x;
			else if (key == "glow") st.glowMul = x;
			else if (key == "lights") st.lightsMul = x;
			else if (key == "marks") st.marksMul = x;
			else if (key == "flash") st.flashMul = x;
			else if (key == "cone") st.coneMul = x;
			else if (key == "flame") st.flameMul = x;
			else if (key == "smoke") st.smokeMul = x;
			else st.whizMul = x;
			return "";
		}
		return String.Format("unknown style key \"%s\" -- particles, glow, lights, marks, flash, cone, flame, smoke or whiz", key);
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
