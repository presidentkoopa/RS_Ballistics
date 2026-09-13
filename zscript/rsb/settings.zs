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

	static double ImpactGlow()
	{
		let st = Style();
		return max(0.0, Cvf("rsb_impact_glow", 1.0) * (st ? st.glowMul : 1.0));
	}

	static bool ImpactLights() { return Cvb("rsb_impact_lights", true); }

	static double ImpactLight()
	{
		let st = Style();
		return max(0.0, Cvf("rsb_impact_light", 1.0) * (st ? st.lightsMul : 1.0));
	}

	static bool Marks() { return Cvb("rsb_marks", true); }

	static double MarkLife()
	{
		let st = Style();
		return max(0.0, Cvf("rsb_mark_life", 1.0) * (st ? st.marksMul : 1.0));
	}

	static bool Ricochets() { return Cvb("rsb_ricochets", true); }

	static double ImpactVolume() { return clamp(Cvf("rsb_impact_volume", 1.0), 0.0, 1.0); }

	// ---- muzzle flash ----------------------------------------------------------
	static double FlashLight()
	{
		let st = Style();
		return max(0.0, Cvf("rsb_flash_light", 1.0) * (st ? st.flashMul : 1.0));
	}

	static double FlashSize() { return max(0.0, Cvf("rsb_flash_size", 1.0)); }

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
		return max(0.0, Cvf("rsb_flash_flame_size", 1.0) * (st ? st.flameMul : 1.0));
	}

	static double FlashSparks()
	{
		let st = Style();
		return max(0.0, Cvf("rsb_flash_sparks", 1.0) * (st ? st.particlesMul : 1.0));
	}

	static double FlashSmoke()
	{
		let st = Style();
		return max(0.0, Cvf("rsb_flash_smoke", 1.0) * (st ? st.smokeMul : 1.0));
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
		return max(0.0, Cvf("rsb_flame_light", 1.0) * (st ? st.lightsMul : 1.0));
	}

	static double FlameVolume() { return clamp(Cvf("rsb_flame_volume", 1.0), 0.0, 1.0); }

	static String PreviewFlame() { return Cvs("rsb_preview_flame", "incinerator"); }

	// ---- diagnostics and preview ------------------------------------------------
	static bool DebugSurfaces() { return Cvb("rsb_debug_surfaces", false); }

	static String PreviewImpact() { return Cvs("rsb_preview_impact", "bullet"); }
	static String PreviewFlash()  { return Cvs("rsb_preview_flash", "pistol"); }
	static String PreviewEjecta() { return Cvs("rsb_preview_ejecta", "brass_45"); }
}
