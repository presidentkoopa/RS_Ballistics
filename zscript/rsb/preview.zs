// ============================================================================
// PREVIEW: SEE AN EFFECT WITHOUT FIRING A GUN.
//
// The menu's preview rows send netevents; this fires the chosen impact where the
// player is looking, a muzzle flash in front of them, or a casing thrown to
// their side. It is the way to judge styles, the dial and the sliders before any
// weapon fires RS_Ballistics rounds.
//
//   netevent rsb_preview_impact
//   netevent rsb_preview_flash
//   netevent rsb_preview_casing
//   netevent rsb_preview_all
//   netevent rsb_preview_flame       the chosen flame for two seconds
//   netevent rsb_preview_flame_dry   the same, running out of fuel (sputter)
//   netevent rsb_bench_*             benchmarks: bench.zs
//
// NETPLAY. A netevent runs on every machine on the same tic, so the preview is
// the same everywhere; nothing here uses RNG or affects the game. Which profile
// each machine previews comes from its own local settings, which is only a look.
// ============================================================================

class RSB_Preview : EventHandler
{
	// Beam slot for the preview flash: clear of the torch (0) and the two hands'
	// flash slots the reload rig uses (4 and 5).
	const PREVIEW_BEAM_SLOT = 6;

	override void NetworkProcess(ConsoleEvent e)
	{
		if (RSB_Bench.Begin(e)) return;   // rsb_bench_*: bench.zs

		// WHAT WAS ACTUALLY DRAWN THIS MAP (`rsb_shotreport`), as opposed to what resolves.
		//
		// This package can already prove a profile exists, that its name resolves, that the pack
		// loaded it and that nothing was refused -- and every one of those has been true while the
		// thing itself drew NOTHING. A gun wearing a profile that resolves to silence is the defect
		// this package keeps paying for, and the only cure is counting effects where they happen.
		//
		// Diagnostics: local, never read back, no gameplay. `rsb_shotreport clear` starts again.
		if (e.Name ~== "rsb_shotreport" || e.Name ~== "rsb_shotreport_clear")
		{
			let reg = RSB_Registry.Get();
			if (!reg) return;
			if (e.Name ~== "rsb_shotreport_clear")
			{
				reg.tallyKey.Clear();
				reg.tallyCount.Clear();
				Console.Printf("\c[Orange]RSB\c- shot report cleared");
				return;
			}
			if (reg.tallyKey.Size() == 0)
			{
				Console.Printf("\c[Orange]RSB\c- shot report: NOTHING HAS BEEN DRAWN THIS MAP. "
					.. "Not one flash, casing, round, trail or impact.");
				return;
			}
			Console.Printf("\c[Orange]RSB\c- shot report -- what actually drew this map:");
			int total = 0;
			for (int i = 0; i < reg.tallyKey.Size(); i++)
			{
				Console.Printf("   %5d x %s", reg.tallyCount[i], reg.tallyKey[i]);
				total += reg.tallyCount[i];
			}
			Console.Printf("   %d effects across %d kinds of thing.", total, reg.tallyKey.Size());
			return;
		}

		bool impact = e.Name ~== "rsb_preview_impact";
		bool flash  = e.Name ~== "rsb_preview_flash";
		bool casing = e.Name ~== "rsb_preview_casing";
		bool flameOn = e.Name ~== "rsb_preview_flame";
		bool flameDry = e.Name ~== "rsb_preview_flame_dry";
		if (e.Name ~== "rsb_preview_all")
		{
			impact = true;
			flash = true;
			casing = true;
		}
		if (!impact && !flash && !casing && !flameOn && !flameDry) return;
		if (e.Player < 0 || e.Player >= MAXPLAYERS || !playeringame[e.Player]) return;
		let pmo = players[e.Player].mo;
		if (!pmo) return;

		double eyeZ = players[e.Player].viewz - pmo.pos.z;
		Vector3 eye = pmo.pos + (0, 0, eyeZ);
		double ang = pmo.angle;
		double pit = pmo.pitch;
		Vector3 fwd = (cos(ang) * cos(pit), sin(ang) * cos(pit), -sin(pit));
		Vector3 right = (sin(ang), -cos(ang), 0);

		if (impact)
		{
			FLineTraceData d;
			if (pmo.LineTrace(ang, 4096.0, pit, TRF_THRUACTORS, eyeZ, 0, 0, d))
			{
				let surf = RSB_Materials.FromTrace(d, fwd);
				if (surf && !surf.sky)
				{
					let spot = Actor.SpawnClientSide("RSB_SoundSpot", surf.at, ALLOW_REPLACE);
					if (spot) RSB_Impact.LandOn(spot, surf, RSB_Settings.PreviewImpact(), fwd);
				}
				else
				{
					RSB_Log.Info("preview: that is sky or a monster -- look at a wall, floor or ceiling");
				}
			}
			else
			{
				RSB_Log.Info("preview: nothing within 4096 units where you are looking");
			}
		}

		if (flash)
		{
			RSB_Flash.Fire(RSB_Settings.PreviewFlash(), eye + fwd * 20.0 - (0, 0, 6), fwd, PREVIEW_BEAM_SLOT, pmo.Vel, pmo.PlayerNumber(), 2);
		}

		if (casing)
		{
			Vector3 toss = right + (0, 0, 0.6);
			RSB_Ejecta.Throw(RSB_Settings.PreviewEjecta(), eye + fwd * 14.0 + right * 6.0 - (0, 0, 8),
				toss, pmo.Vel, 4.0, level.maptime);
		}

		if (flameOn || flameDry)
		{
			let drv = RSB_FlamePreview(Actor.Spawn("RSB_FlamePreview", eye, ALLOW_REPLACE));
			if (drv)
			{
				drv.playerNum = e.Player;
				drv.ticsLeft = 70;
				drv.flameId = RSB_Settings.PreviewFlame();
				drv.runDry = flameDry;
			}
		}
	}
}
