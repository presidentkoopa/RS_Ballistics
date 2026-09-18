// ============================================================================
// THE PLAYER'S SETTINGS. Every menu control, read in one place, with the chosen
// style's multipliers folded in.
//
// All user cvars: looks only, each player's own. Nothing here may change damage,
// speed or anything a netgame compares.
//
// Every cvar is named here as a literal so tools/menu_lint.py can see it read.
// ============================================================================

class RSB_Settings play
{
	static double Cvf(String n, double d)
	{
		let c = CVar.GetCVar(n, players[consoleplayer]);
		return c ? c.GetFloat() : d;
	}

	static bool Cvb(String n, bool d)
	{
		let c = CVar.GetCVar(n, players[consoleplayer]);
		return c ? c.GetBool() : d;
	}

	static String Cvs(String n, String d)
	{
		let c = CVar.GetCVar(n, players[consoleplayer]);
		return c ? c.GetString() : d;
	}

	// ---- style ------------------------------------------------------------------

	// The chosen style's name, or "" for the default look. A style no RSBDEFS
	// defines is reported once and treated as the default.
	static String StyleName()
	{
		String s = Cvs("rsb_style", "");
		s.StripLeftRight();
		if (s.Length() == 0) return "";
		let reg = RSB_Registry.Get();
		if (!reg || !reg.FindStyle(s))
		{
			RSB_Log.Once(RSB_Log.LV_WARN, "style:missing:" .. s, String.Format(
				"style \"%s\" is not defined in any RSBDEFS -- using the default look", s));
			return "";
		}
		return s;
	}

	static RSB_StyleDef Style()
	{
		String s = StyleName();
		if (s.Length() == 0) return null;
		let reg = RSB_Registry.Get();
		return reg ? reg.FindStyle(s) : null;
	}

	// ---- impacts ----------------------------------------------------------------
	static bool Impacts() { return Cvb("rsb_impacts", true); }

	static double ImpactParticles()
	{
		let st = Style();
		return max(0.0, Cvf("rsb_impact_particles", 1.0) * (st ? st.particlesMul : 1.0));
	}

	// THE EFFECTS LEVEL folds in here too (RSB_Tier's ladder): heavy is what every profile is
	// tuned at, so heavy is x1; plain and normal trim, extreme goes big.
	static double ImpactGlow()
	{
		let st = Style();
		return max(0.0, Cvf("rsb_impact_glow", 1.0) * (st ? st.glowMul : 1.0) * RSB_Tier.GlowScale(RSB_Tier.Current()));
	}

	static bool ImpactLights() { return Cvb("rsb_impact_lights", true); }

	static double ImpactLight()
	{
		let st = Style();
		return max(0.0, Cvf("rsb_impact_light", 1.0) * (st ? st.lightsMul : 1.0) * RSB_Tier.LightScale(RSB_Tier.Current()));
	}

	static bool Marks() { return Cvb("rsb_marks", true); }

	static double MarkLife()
	{
		let st = Style();
		return max(0.0, Cvf("rsb_mark_life", 1.0) * (st ? st.marksMul : 1.0) * RSB_Tier.MarkScale(RSB_Tier.Current()));
	}

	static bool Ricochets() { return Cvb("rsb_ricochets", true); }

	static double ImpactVolume() { return clamp(Cvf("rsb_impact_volume", 1.0), 0.0, 1.0); }

	// ---- muzzle flash ----------------------------------------------------------
	static double FlashLight()
	{
		let st = Style();
		return max(0.0, Cvf("rsb_flash_light", 1.0) * (st ? st.flashMul : 1.0) * RSB_Tier.LightScale(RSB_Tier.Current()));
	}

	static double FlashSize() { return max(0.0, Cvf("rsb_flash_size", 1.0) * RSB_Tier.SizeScale(RSB_Tier.Current())); }

	static bool FlashCone() { return Cvb("rsb_flash_cone", true); }

	static double FlashConeDensity()
	{
		let st = Style();
		return max(0.0, Cvf("rsb_flash_cone_density", 1.0) * (st ? st.coneMul : 1.0));
	}

	static bool FlashFlame() { return Cvb("rsb_flash_flame", true); }

	static double FlashFlameSize()
	{
		let st = Style();
		return max(0.0, Cvf("rsb_flash_flame_size", 1.0) * (st ? st.flameMul : 1.0) * RSB_Tier.SizeScale(RSB_Tier.Current()));
	}

	static double FlashSparks()
	{
		let st = Style();
		return max(0.0, Cvf("rsb_flash_sparks", 1.0) * (st ? st.particlesMul : 1.0));
	}

	// THE SMOKE DIAL (Ballistics & Effects -> Smoke; the owner, 2026-09-15): the engine's r_smoke_preset, 0 off .. 4 extreme,
	// renderer-read -- it sets the engine's smoke drawing the instant it moves. Every RS_Ballistics smoke amount and smoke
	// burst follows it too (RSB_Tier.SmokeScale). Looks only, this machine's.
	static int SmokeLevel()
	{
		let c = CVar.FindCVar("r_smoke_preset");
		return c ? clamp(c.GetInt(), RSB_Tier.T_OFF, RSB_Tier.T_EXTREME) : RSB_Tier.T_HEAVY;
	}

	static double FlashSmoke()
	{
		let st = Style();
		return max(0.0, Cvf("rsb_flash_smoke", 1.0) * (st ? st.smokeMul : 1.0) * RSB_Tier.SmokeScale(RSB_Settings.SmokeLevel()));
	}

	// Gunshot tails (a flash's `tail`): the room answering each shot, x this.
	static double TailVolume() { return max(0.0, Cvf("rsb_tail_volume", 1.0)); }
	// SLOW MOTION, THE MUZZLE FLASH'S CLOCK (engine build 13). A flash is three tics. On the world
	// clock at a fifth speed it becomes a fifteen-tic flash hanging off the barrel -- which is either
	// the best thing in the game or plainly broken, and that is a headset question, not a keyboard one.
	// True (the default) keeps the flash on the real clock, so it snaps exactly as it does at full
	// speed; the powder and sparks it throws are world particles either way and still hang in the air.
	static bool SlowMoFlashReal() { return Cvb("rsb_slowmo_flash", true); }

	// Muzzle spice: powder burns on close walls, the blast kicking what is near, the shockwave.
	static bool FlashPowderBurns() { return Cvb("rsb_flash_powderburns", true); }
	static bool FlashBlastKick() { return Cvb("rsb_flash_blastkick", true); }
	static bool FlashShockwave() { return Cvb("rsb_flash_shockwave", true); }

	// ENEMY FIRE (enemyfire.zs): the rounds and their speed are the server's rules; the dressing and the distance are yours.
	static bool EnemyRounds()
	{
		let c = CVar.FindCVar("sv_rsb_enemy_rounds");
		return c ? c.GetBool() : true;
	}

	static double EnemyRoundSpeed()
	{
		let c = CVar.FindCVar("sv_rsb_enemy_round_speed");
		return c ? clamp(c.GetFloat(), 8.0, 1000.0) : 80.0;
	}

	static bool EnemyDress() { return Cvb("rsb_enemy_dress", true); }
	static double EnemyFxRange() { return max(0.0, Cvf("rsb_enemy_fx_range", 2048.0)); }

	// How far a monster's shot is from this machine's view: 0 near, 1 past half the range (no light or bent air),
	// 2 past the range (no flight or impact looks). A range of 0 draws every fight in full.
	static int EnemyBand(Vector3 at)
	{
		double range = EnemyFxRange();
		if (range <= 0) return 0;
		let cam = players[consoleplayer].camera;
		if (!cam) return 0;
		double d = (at - cam.pos).Length();
		if (d > range) return 2;
		return (d > range * 0.5) ? 1 : 0;
	}

	// ---- what this machine can see (Engine docs/EFFECTS_OPTIMIZATION_PLAN.md, M1 and M2) ------------------------
	// NETPLAY: viewer-based skipping and LOD may only choose look-only, client-side spawns (SpawnClientSide actors,
	// particles, effect lights, volumes). Anything a playsim actor does (rounds, puffs, damage, sounds other machines
	// rely on) must stay identical everywhere, whatever the local camera sees.
	const VIEW_FULL   = 0;            // in view, or near: everything
	const VIEW_FAR    = 1;            // past the lighter-effects range: fewer pieces, no maybe bursts, small lights skipped
	const VIEW_BEHIND = 2;            // behind this machine's view and not near: no short-lived pieces, small lights, marks
	const VIEW_NEAR   = 128.0;        // closer than this (flat) is always in full: your own muzzle, a wall beside you
	const VIEW_BEHIND_COS = -0.342;   // more than 110 degrees off where the view faces (a headset sees about 100 across)
	const VIEW_BIG_LIGHT  = 150.0;    // a light this wide or wider still reaches what you face: never skipped
	const LOD_COUNT       = 0.5;      // past the range, every burst's count times this

	static bool ViewCull() { return Cvb("rsb_view_cull", true); }
	static double LodRange() { return max(0.0, Cvf("rsb_lod_range", 1536.0)); }

	// Spark lights (Lights page): 0 every spark lights (the owner's lights answer, the default), 1 capped per burst (M5).
	static bool SparkLightsCapped() { return Cvf("rsb_spark_lights", 0.0) >= 1.0; }

	// Where `at` is for THIS machine's view: its camera (in VR the head's turn drives the view angle). Behind wins
	// over far. With both switches off, always VIEW_FULL.
	static int ViewBand(Vector3 at)
	{
		let cam = players[consoleplayer].camera;
		if (!cam) return VIEW_FULL;
		Vector3 off = at - cam.pos;
		double flat = off.xy.Length();
		if (flat > VIEW_NEAR && ViewCull())
		{
			Vector2 look = (cos(cam.angle), sin(cam.angle));
			if ((off.xy / flat) dot look < VIEW_BEHIND_COS) return VIEW_BEHIND;
		}
		double range = LodRange();
		if (range > 0 && off.Length() > range) return VIEW_FAR;
		return VIEW_FULL;
	}

	// ---- rounds in flight ------------------------------------------------------
	static bool Glide() { return Cvb("rsb_glide", true); }

	// "" = each round's own look; otherwise a roundlook profile for what flies.
	// A look only: ballistics never read a setting.
	static String RoundLook() { return Cvs("rsb_round_look", ""); }

	static double Wake()
	{
		let st = Style();
		return max(0.0, Cvf("rsb_wake", 1.0) * (st ? st.particlesMul : 1.0));
	}

	static bool Whiz() { return Cvb("rsb_whiz", true); }

	static double WhizRange()
	{
		let st = Style();
		return max(0.0, Cvf("rsb_whiz_range", 1.0) * (st ? st.whizMul : 1.0));
	}

	static double WhizVolume() { return clamp(Cvf("rsb_whiz_volume", 1.0), 0.0, 1.0); }

	// ---- casings ---------------------------------------------------------------
	static bool Casings() { return Cvb("rsb_casings", true); }

	static double CasingSize() { return max(0.05, Cvf("rsb_casing_size", 1.0)); }

	static bool CasingHot() { return Cvb("rsb_casing_hot", true); }

	static double CasingLife() { return max(0.0, Cvf("rsb_casing_life", 1.0)); }
	// The most local casings in the world at once; past it the oldest fade (RSB_Registry.KeepCasing).
	static int CasingMax() { return clamp(int(Cvf("rsb_casing_max", 300.0)), 10, 4000); }

	// ---- flamethrowers ---------------------------------------------------------
	static bool Flame() { return Cvb("rsb_flame", true); }

	static double FlameParticles()
	{
		let st = Style();
		return max(0.0, Cvf("rsb_flame_particles", 1.0) * (st ? st.particlesMul : 1.0));
	}

	static double FlameLight()
	{
		let st = Style();
		return max(0.0, Cvf("rsb_flame_light", 1.0) * (st ? st.lightsMul : 1.0) * RSB_Tier.LightScale(RSB_Tier.Current()));
	}

	static double FlameVolume() { return clamp(Cvf("rsb_flame_volume", 1.0), 0.0, 1.0); }

	// The flame's drawn-line core, for a profile with a `tube`. Off, the stream
	// keeps all of its particles.
	static bool FlameTube() { return Cvb("rsb_flame_tube", true); }

	// Energy weapon trails (a `trail` profile: the railgun's core and corkscrew).
	static bool Trails() { return Cvb("rsb_trails", true); }

	static String PreviewFlame() { return Cvs("rsb_preview_flame", "incinerator"); }

	// ---- diagnostics and preview ------------------------------------------------
	static bool DebugSurfaces() { return Cvb("rsb_debug_surfaces", false); }

	static String PreviewImpact() { return Cvs("rsb_preview_impact", "bullet"); }
	static String PreviewFlash()  { return Cvs("rsb_preview_flash", "pistol"); }
	static String PreviewEjecta() { return Cvs("rsb_preview_ejecta", "brass_45"); }
}

// ============================================================================
// DECALS ON OUR ROUNDS: a server rule, one for the whole game (sv_rsb_decals, off by default).
// Off, a round's lasting mark is the wall damage (engine #17); on, the vanilla decals come too.
// DECALS ARE PLAYSIM THINKERS, so this never follows a player's own r_damage (netplay).
// ============================================================================
class RSB_Decals play
{
	static bool Enabled()
	{
		let c = CVar.FindCVar("sv_rsb_decals");
		return c ? c.GetBool() : false;
	}

	// At spawn (BeginPlay), before anything can leave a decal.
	static void Apply(Actor mo)
	{
		if (mo && !Enabled()) mo.DecalGenerator = null;
	}
}
