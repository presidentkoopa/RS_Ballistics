// ============================================================================
// THE REGISTRY. Reads every RSBDEFS lump once and holds the profiles for the
// whole session.
//
// A STATIC event handler (registered in MAPINFO), so it exists from startup and
// across every map: profiles are read once, not per level. It also owns the
// once-per-map log memory, cleared as each map starts.
//
// Load order is override order: RSBDEFS lumps are read in the order their
// packages load, and a later profile with the same kind and name replaces an
// earlier one. RS_Ballistics' own examples load first; a weapons package can
// redefine them.
// ============================================================================

class RSB_Registry : StaticEventHandler
{
	RSB_DefSet defs;
	int        lumpsRead;
	int        refusals;
	private Array<String> said;   // once-per-map log keys

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
		RSB_Log.Info(String.Format("RS_Ballistics: %d profile(s) from %d RSBDEFS lump(s), %d refused -- %s",
			defs.defs.Size(), lumpsRead, refusals, defs.Describe()));
		if (RSB_Log.Level() >= RSB_Log.LV_TRACE) Dump();
	}

	bool AlreadySaid(String key)
	{
		for (int i = 0; i < said.Size(); i++)
			if (said[i] == key) return true;
		said.Push(key);
		return false;
	}

	// ---- lookups, typed, for the bullet, the flash and the service ------------
	RSB_RoundDef  FindRound(String pid)  { return defs ? RSB_RoundDef(defs.Find("round", pid))   : null; }
	RSB_WakeDef   FindWake(String pid)   { return defs ? RSB_WakeDef(defs.Find("wake", pid))     : null; }
	RSB_ImpactDef FindImpact(String pid) { return defs ? RSB_ImpactDef(defs.Find("impact", pid)) : null; }
	RSB_FlashDef  FindFlash(String pid)  { return defs ? RSB_FlashDef(defs.Find("flash", pid))   : null; }

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

	// COMPLETENESS, once every lump is in. A round must state its speed, radius,
	// damage and look, and name wake and impact profiles that some lump defines.
	// Checked here rather than in the parser because a later package may supply
	// the impact a round names.
	private int Finish()
	{
		int n = 0;
		for (int i = defs.defs.Size() - 1; i >= 0; i--)
		{
			let r = RSB_RoundDef(defs.defs[i]);
			if (!r) continue;

			String why = "";
			if (r.speed <= 0)
				why = "it never states `speed`";
			else if (r.radius <= 0)
				why = "it never states `radius`";
			else if (r.damageDice < 1)
				why = "it never states `damage`";
			else if (r.lookKind == "")
				why = "it never states `look`";
			else if (!(r.impact ~== "none") && !defs.Find("impact", r.impact))
				why = String.Format("its impact \"%s\" is not defined in any RSBDEFS", r.impact);
			else if (!(r.wake ~== "none") && !defs.Find("wake", r.wake))
				why = String.Format("its wake \"%s\" is not defined in any RSBDEFS", r.wake);

			if (why == "") continue;
			RSB_Log.Err(String.Format("%s line %d: round %s REFUSED -- %s", r.source, r.lineNo, r.id, why));
			defs.defs.Delete(i);
			n++;
		}
		return n;
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
