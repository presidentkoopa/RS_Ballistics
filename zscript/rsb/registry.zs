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
	int        heatBlastNext;   // RSB_Heat: the next blast slot, in turn (drawing only)
	int        trailNext;       // RSB_Trail: the next drawn-line slot for a trail, in turn (drawing only)
	Array<RSB_BarrelHeat> barrels;   // RSB_Barrel: heat per gun (drawing only; cleared each map)
	Array<int>             roundCounts;   // RSB_Bullet: rounds each player's hand has fired, for tracers (drawing only)
	Array<Actor>           casings;       // casings in the world, oldest first: the shared casing cap -- ours and any mod's that asked (RSB_Service casing.keep); cleared each map
	Array<RSB_Hotspot>     hotspots;      // live hotspots, oldest first (hotspot.zs; cleared each map)
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
		barrels.Clear();
		casings.Clear();
		hotspots.Clear();
		// THE ROOM SMOKE'S LOOK (engine 13b): not in savegames, so set on every map and load.
		level.SetSmokeLook(Color(255, 140, 138, 134), 1.0, 0.8, 0.4, 0.15, 1.0);
		if (!defs) Load();
		String style = RSB_Settings.StyleName();
		RSB_Log.Info(String.Format("RS_Ballistics: %d profile(s) from %d RSBDEFS lump(s), %d refused, effects %s, style %s -- %s",
			defs.defs.Size(), lumpsRead, refusals, RSB_Tier.Name(RSB_Tier.Current()),
			(style.Length() > 0) ? style : "default", defs.Describe()));
		if (RSB_Log.Level() >= RSB_Log.LV_TRACE) Dump();
	}

	// THE NEXT ROUND'S NUMBER for a player's hand (1, 2, 3 ...), for tracers (a round look's
	// `tracer`); 0 for a round no player fired. Counted in the fire action, which runs on
	// every machine, so every machine numbers the rounds alike.
	int NextRoundIndex(int playerNum, int hand)
	{
		if (playerNum < 0 || playerNum >= MAXPLAYERS) return 0;
		int k = playerNum * 2 + clamp(hand, 0, 1);
		while (roundCounts.Size() <= k) roundCounts.Push(0);
		roundCounts[k]++;
		return roundCounts[k];
	}

	// THE SHARED CASING CAP (Casings: "Casings in the world, most"): a new casing joins the
	// list -- RS_Ballistics' own, or another mod's through RSB_Service casing.keep; past the
	// cap the oldest start fading. Looks only, on this machine.
	void KeepCasing(Actor c)
	{
		if (!c) return;
		casings.Push(c);
		int cap = RSB_Settings.CasingMax();
		if (casings.Size() <= cap) return;
		for (int i = casings.Size() - 1; i >= 0; i--)
			if (!casings[i]) casings.Delete(i);
		while (casings.Size() > cap)
		{
			let oldest = casings[0];
			casings.Delete(0);
			// Ours fade as they always have. Another mod's casing hears Deactivate, which its
			// class overrides to start its own fade; only actors that asked are ever told.
			let ours = RSB_LocalEjecta(oldest);
			if (ours) ours.FadeOut();
			else if (oldest) oldest.Deactivate(null);
		}
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
	RSB_TrailDef ResolveTrail(String base, String tierName)
	{
		return defs ? RSB_TrailDef(defs.Resolve("trail", base, "", tierName, RSB_Settings.StyleName())) : null;
	}

	RSB_HotspotDef ResolveHotspot(String base, String tierName)
	{
		return defs ? RSB_HotspotDef(defs.Resolve("hotspot", base, "", tierName, RSB_Settings.StyleName())) : null;
	}
	// Trails take their drawn lines in turn; the new trail takes the oldest.
	int NextTrailSlot()
	{
		int s = RSB_Trail.FIRST_SLOT + trailNext;
		trailNext = (trailNext + 1) % RSB_Trail.SLOTS;
		return s;
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
				if (why == "") why = MissingBurst(im.maybeBursts);
				if (why == "" && im.hotspot.Length() > 0 && !defs.Find("hotspot", im.hotspot))
					why = String.Format("its hotspot \"%s\" is not defined in any RSBDEFS", im.hotspot);
				if (why == "" && !(im.glanceBurst ~== "none") && !FindBurst(im.glanceBurst))
					why = String.Format("its glance burst \"%s\" is not defined in any RSBDEFS", im.glanceBurst);
			}
			else if (fl)
			{
				why = MissingBurst(fl.bursts);
				if (why == "") why = MissingBurst(fl.maybeBursts);
				if (why == "") why = MissingBurst(fl.chargeBursts);
				if (why == "" && fl.kickImpact.Length() > 0 && !defs.Find("impact", fl.kickImpact))
					why = String.Format("its groundkick impact \"%s\" has no base profile in any RSBDEFS", fl.kickImpact);
			}
			else
			{
				let hs = RSB_HotspotDef(defs.defs[i]);
				if (hs) why = MissingBurst(hs.bursts);
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
				else if (lk.tracerEvery > 0 && !defs.Find("roundlook", lk.tracerLook))
					why = String.Format("its tracer look \"%s\" has no base profile in any RSBDEFS", lk.tracerLook);
				else if (lk.motorBurst.Length() > 0 && !FindBurst(lk.motorBurst))
					why = String.Format("its motor burst \"%s\" is not defined in any RSBDEFS", lk.motorBurst);
				else if (MissingBurst(lk.motorMaybe) != "")
					why = MissingBurst(lk.motorMaybe);
				else if (lk.onsetFlash.Length() > 0 && !defs.Find("flash", lk.onsetFlash))
					why = String.Format("its onset flash \"%s\" has no base profile in any RSBDEFS", lk.onsetFlash);
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
