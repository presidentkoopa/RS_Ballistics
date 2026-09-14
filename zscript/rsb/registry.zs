// ============================================================================
// THE REGISTRY. Reads every RSBDEFS lump once and holds the profiles for the
// whole session.
//
// A STATIC event handler (registered in MAPINFO), so it exists from startup and
// across every map: profiles are read once, not per level. It also owns the
// once-per-map log memory. What a texture is made of is the engine's (TexMan.GetSurface).
//
// Load order is override order: RSBDEFS lumps are read in the order their
// packages load, and a later profile with the same kind and name replaces an
// earlier one.
// ============================================================================

class RSB_Registry : StaticEventHandler
{
	RSB_DefSet defs;
	int        lumpsRead;
	int        refusals;
	private Array<String> said;                  // once-per-map log keys

	clearscope static RSB_Registry Get()
	{
		return RSB_Registry(StaticEventHandler.Find("RSB_Registry"));
	}

	override void OnRegister()
	{
		Load();
	}

	// Each map: forget what was said, and say what is loaded.
	override void WorldLoaded(WorldEvent e)
	{
		said.Clear();
		if (!defs) Load();
		String style = RSB_Settings.StyleName();
		RSB_Log.Info(String.Format("RS_Ballistics: %d profile(s) from %d RSBDEFS lump(s), %d refused, effects %s, style %s -- %s",
			defs.defs.Size(), lumpsRead, refusals, RSB_Tier.Name(RSB_Tier.Current()),
			(style.Length() > 0) ? style : "default", defs.Describe()));
		if (RSB_Log.Level() >= RSB_Log.LV_TRACE) Dump();
	}

	bool AlreadySaid(String key)
	{
		for (int i = 0; i < said.Size(); i++)
			if (said[i] == key) return true;
		said.Push(key);
		return false;
	}

	// ---- lookups, typed ---------------------------------------------------------
	RSB_RoundDef  FindRound(String pid)  { return defs ? RSB_RoundDef(defs.Find("round", pid))   : null; }
	// NETPLAY: by exact base name only -- never Resolve, so no style, tier or
	// player setting can change what the game knows about a round.
	RSB_BallisticsDef FindBallistics(String pid) { return defs ? RSB_BallisticsDef(defs.Find("ballistics", pid)) : null; }
	RSB_BurstDef  FindBurst(String pid)  { return defs ? RSB_BurstDef(defs.Find("burst", pid))   : null; }
	RSB_EjectaDef FindEjecta(String pid) { return defs ? RSB_EjectaDef(defs.Find("ejecta", pid)) : null; }

	RSB_StyleDef  FindStyle(String pid)  { return defs ? RSB_StyleDef(defs.Find("style", pid))   : null; }

	// Resolved with the player's chosen style (RSB_Settings.StyleName).
	RSB_ImpactDef ResolveImpact(String base, String material, String tierName)
	{
		return defs ? RSB_ImpactDef(defs.Resolve("impact", base, material, tierName, RSB_Settings.StyleName())) : null;
	}
	RSB_FlashDef ResolveFlash(String base, String tierName)
	{
		return defs ? RSB_FlashDef(defs.Resolve("flash", base, "", tierName, RSB_Settings.StyleName())) : null;
	}
	RSB_EjectaDef ResolveEjecta(String base, String tierName)
	{
		return defs ? RSB_EjectaDef(defs.Resolve("ejecta", base, "", tierName, RSB_Settings.StyleName())) : null;
	}
	RSB_WakeDef ResolveWake(String base, String tierName)
	{
		return defs ? RSB_WakeDef(defs.Resolve("wake", base, "", tierName, RSB_Settings.StyleName())) : null;
	}
	RSB_FlameDef ResolveFlame(String base, String tierName)
	{
		return defs ? RSB_FlameDef(defs.Resolve("flame", base, "", tierName, RSB_Settings.StyleName())) : null;
	}
	RSB_RoundLookDef ResolveRoundLook(String base, String tierName)
	{
		return defs ? RSB_RoundLookDef(defs.Resolve("roundlook", base, "", tierName, RSB_Settings.StyleName())) : null;
	}

	// ---- reading ---------------------------------------------------------------
	private void Load()
	{
		defs = new("RSB_DefSet");
		lumpsRead = 0;
		refusals = 0;

		int lump = Wads.FindLump("RSBDEFS", 0);
		while (lump != -1)
		{
			String source = String.Format("%s:%s", Wads.GetContainerName(lump), Wads.GetLumpFullName(lump));
			refusals += RSB_Parser.ParseLump(defs, Wads.ReadLump(lump), source);
			lumpsRead++;
			lump = Wads.FindLump("RSBDEFS", lump + 1);
		}

		refusals += Finish();
		if (lumpsRead == 0)
			RSB_Log.Warn("RS_Ballistics: no RSBDEFS lump was found -- there are no profiles to generate from");
	}

	// COMPLETENESS, once every lump is in. Checked here rather than in the parser
	// because a later package may supply what a profile names. Bursts first, so an
	// impact refused for a missing burst is gone before rounds are checked.
	private int Finish()
	{
		int n = 0;

		for (int i = defs.defs.Size() - 1; i >= 0; i--)
		{
			String why = "";
			let im = RSB_ImpactDef(defs.defs[i]);
			let fl = RSB_FlashDef(defs.defs[i]);
			if (im)
			{
				why = MissingBurst(im.bursts);
				if (why == "" && !(im.glanceBurst ~== "none") && !FindBurst(im.glanceBurst))
					why = String.Format("its glance burst \"%s\" is not defined in any RSBDEFS", im.glanceBurst);
			}
			else if (fl)
			{
				why = MissingBurst(fl.bursts);
			}
			else
			{
				let fm = RSB_FlameDef(defs.defs[i]);
				if (fm)
				{
					why = MissingBurst(fm.stream);
					if (why == "") why = MissingBurst(fm.landing);
					if (why == "") why = MissingBurst(fm.pilot);
					if (why == "") why = MissingBurst(fm.flameout);
				}
			}
			if (why == "") continue;
			let d = defs.defs[i];
			RSB_Log.Err(String.Format("%s line %d: %s %s REFUSED -- %s", d.source, d.lineNo, d.kind, d.id, why));
			defs.defs.Delete(i);
			n++;
		}

		// Ballistics and round looks next: rounds name them.
		for (int i = defs.defs.Size() - 1; i >= 0; i--)
		{
			String why = "";
			let bl = RSB_BallisticsDef(defs.defs[i]);
			let lk = RSB_RoundLookDef(defs.defs[i]);
			if (bl)
			{
				if (bl.speed <= 0)
					why = "it never states `speed`";
				else if (bl.radius <= 0)
					why = "it never states `radius`";
				else if (bl.damageDice < 1)
					why = "it never states `damage`";
			}
			else if (lk)
			{
				if (lk.lookKind == "")
					why = "it never states `look`";
				else if (!(lk.impact ~== "none") && !defs.Find("impact", lk.impact))
					why = String.Format("its impact \"%s\" has no base profile in any RSBDEFS", lk.impact);
				else if (!(lk.wake ~== "none") && !defs.Find("wake", lk.wake))
					why = String.Format("its wake \"%s\" is not defined in any RSBDEFS", lk.wake);
			}
			if (why == "") continue;
			let d = defs.defs[i];
			RSB_Log.Err(String.Format("%s line %d: %s %s REFUSED -- %s", d.source, d.lineNo, d.kind, d.id, why));
			defs.defs.Delete(i);
			n++;
		}

		// Rounds last: each pairs one ballistics profile with one look, by BASE name.
		for (int i = defs.defs.Size() - 1; i >= 0; i--)
		{
			let r = RSB_RoundDef(defs.defs[i]);
			if (!r) continue;

			String why = "";
			if (r.ballistics.Length() == 0)
				why = "it never states `ballistics`";
			else if (!defs.Find("ballistics", r.ballistics))
				why = String.Format("its ballistics \"%s\" is not defined in any RSBDEFS", r.ballistics);
			else if (r.roundLook.Length() == 0)
				why = "it never states `roundlook`";
			else if (!defs.Find("roundlook", r.roundLook))
				why = String.Format("its roundlook \"%s\" has no base profile in any RSBDEFS", r.roundLook);

			if (why == "") continue;
			RSB_Log.Err(String.Format("%s line %d: round %s REFUSED -- %s", r.source, r.lineNo, r.id, why));
			defs.defs.Delete(i);
			n++;
		}
		return n;
	}

	private String MissingBurst(Array<String> names)
	{
		for (int i = 0; i < names.Size(); i++)
			if (!FindBurst(names[i]))
				return String.Format("its burst \"%s\" is not defined in any RSBDEFS", names[i]);
		return "";
	}

	private void Dump()
	{
		for (int i = 0; i < defs.defs.Size(); i++)
		{
			let d = defs.defs[i];
			RSB_Log.Trace(String.Format("  %s %s  (%s line %d)", d.kind, d.id, d.source, d.lineNo));
		}
	}
}
