// ============================================================================
// THE MUZZLE FLASH, from a `flash` profile: a strobing light, lit air in a cone,
// bursts at the bore, a flame sprite and a puff of smoke -- each scaled by the
// player's menu settings and style.
//
// Once the reload system's own flash (WM_MuzzleFlash, since removed), now data:
//
//   THE STROBE. One over-bright tic on the shot, fading over lightTics, then
//   dark: a real muzzle flash is over in a millisecond, and a light that holds
//   reads as a lamp. Re-attaching the light under the same name updates it that
//   tic.
//
//   THE CONE lights the AIR (PPVolumetricBeam) and resolves per eye, so it has
//   depth in stereo, which no billboard has. It falls off as a cube.
//
// Spawned by the firing hand's rig through RSB_Flash.Fire, which gives the beam
// slot (one per hand) and the carrier's velocity for the smoke.
//
// NETPLAY. A flash is presentation for the machine that draws it: no RNG, no
// interaction, nothing a netgame compares.
// ============================================================================

class RSB_Flash : Actor
{
	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
		+NOTELEPORT
		+DONTSPLASH
		RenderStyle "Add";
		Alpha 1.0;
		Radius 1;
		Height 1;
	}

	String  flashId;
	Vector3 dir;
	int     slot;
	private int    age;
	private int    life;
	private bool   strobeLit;
	private bool   coneOn;
	private double punchMul;
	private double rangeMul;
	private double densityMul;
	transient RSB_FlashDef flashDef;

	States
	{
	Spawn:
		RSMF B 1 Bright;
		RSMF C 1 Bright;
		RSMF D 1 Bright;
		RSMF E -1 Bright;
		Stop;
	}

	static RSB_Flash Fire(String whichFlash, Vector3 at, Vector3 aim, int beamSlot, Vector3 carrierVel)
	{
		let reg = RSB_Registry.Get();
		if (!reg) return null;
		int tier = RSB_Tier.Current();
		let fd = reg.ResolveFlash(whichFlash, RSB_Tier.Name(tier));
		if (!fd)
		{
			RSB_Log.Once(RSB_Log.LV_ERR, "flash:missing:" .. whichFlash, String.Format(
				"flash \"%s\" is not defined in any RSBDEFS", whichFlash));
			return null;
		}
		let f = RSB_Flash(Actor.Spawn("RSB_Flash", at, ALLOW_REPLACE));
		if (!f) return null;
		f.flashId = whichFlash;
		f.flashDef = fd;
		f.dir = (aim.Length() > 0.000001) ? aim.Unit() : (1, 0, 0);
		f.slot = beamSlot;
		f.Ignite(tier, carrierVel);
		return f;
	}

	private void Ignite(int tier, Vector3 carrierVel)
	{
		let fd = flashDef;
		life = max(3, fd.coneTics);
		life = max(life, fd.lightTics);

		double flameSize = fd.flameScale * RSB_Settings.FlashFlameSize();
		if (tier <= RSB_Tier.T_OFF || flameSize <= 0 || !RSB_Settings.FlashFlame()) bINVISIBLE = true;
		else A_SetScale(flameSize);

		if (tier <= RSB_Tier.T_OFF) return;

		punchMul = RSB_Settings.FlashLight();
		rangeMul = RSB_Settings.FlashSize();
		densityMul = RSB_Settings.FlashConeDensity();

		if (fd.lightRadius > 0 && fd.lightTics > 0 && punchMul > 0 && rangeMul > 0) StrobeLight(1.0);
		coneOn = fd.coneLength > 0 && fd.coneTics > 0 && RSB_Settings.FlashCone() && densityMul > 0;
		if (coneOn) Beam(1.0);

		let reg = RSB_Registry.Get();
		double countScale = (fd.id.IndexOf("@") >= 0) ? 1.0 : RSB_Tier.CountScale(tier);
		int posSeed = RSB_Hash.OfPos(pos);
		if (reg)
		{
			double sparkScale = countScale * RSB_Settings.FlashSparks();
			for (int i = 0; i < fd.bursts.Size(); i++)
				RSB_Burst.Fire(reg.FindBurst(fd.bursts[i]), pos, dir, dir, sparkScale, 1.0,
					RSB_Hash.Seed(level.maptime, i + 1, posSeed));
		}

		// HEAT SHIMMER out of the muzzle (RSB_Heat): a column of hot air along the shot.
		if (fd.heatStrength > 0)
			RSB_Heat.Along(pos, dir, fd.heatLength, fd.heatRadius, fd.heatStrength, fd.heatTics);

		int puffs = int(fd.smokeCount * countScale * RSB_Settings.FlashSmoke() + 0.5);
		// GPU SMOKE (stage 2d: lit, alpha-blended, soft) when the profile names a
		// definition: puffs drifting out of the bore, rising and hanging. The handle
		// is a hash of the name, the same everywhere, so it is cached, never tested.
		if (fd.smokeParticle.Length() > 0)
		{
			if (puffs > 0)
			{
				if (fd.smokeHandle == 0) fd.smokeHandle = level.ParticleDefinition(fd.smokeParticle);
				level.SpawnParticles(fd.smokeHandle, pos + dir * 1.0, dir, puffs * 2, 30.0, 14.0, 0.6,
					1.8, 0.35, Color(255, 255, 255, 255), 1.0, 1.0, RSB_Hash.Seed(level.maptime, 77, posSeed));
			}
			puffs = 0;   // no sprite puffs as well
		}
		for (int i = 0; i < puffs; i++)
		{
			let s = Actor.Spawn("RSB_Smoke", pos + dir * 0.5, ALLOW_REPLACE);
			if (!s) continue;
			s.A_SetScale(fd.smokeScale);
			s.Alpha = fd.smokeAlpha;
			Vector3 drift = (RSB_Hash.Between(-0.15, 0.15, level.maptime, i, posSeed),
				RSB_Hash.Between(-0.15, 0.15, level.maptime, i + 31, posSeed), 0.15);
			s.Vel = dir * 0.5 + drift + carrierVel * 0.5;
		}

		RSB_Log.Once(RSB_Log.LV_INFO, "flash:first:" .. fd.id, String.Format(
			"first flash this map using %s: light %d x%.2f, punch %.2f x%.2f, %d tics; cone %s; %d burst(s); %d smoke",
			fd.id, int(fd.lightRadius), rangeMul, fd.lightPunch, punchMul, fd.lightTics,
			coneOn ? "on" : "off", fd.bursts.Size(), puffs));
	}

	private void StrobeLight(double k)
	{
		let fd = flashDef;
		int range = int(fd.lightRadius * rangeMul * (0.6 + 0.4 * k));
		A_AttachLight("rsb_muzzle", DynamicLight.PointLight, fd.lightColor,
			range, 0, DynamicLight.LF_ATTENUATE, (0, 0, 0), 0, 10, 25, 0, fd.lightPunch * punchMul * k * k);
		strobeLit = true;
	}

	private void Beam(double f)
	{
		let fd = flashDef;
		Color c = fd.lightColor;
		Level.SetVolumetricBeam(pos, dir,
			Color(255, int(c.r * f), int(c.g * f), int(c.b * f)),
			fd.coneInner, fd.coneOuter, fd.coneLength * f, fd.coneDensity * densityMul * f,
			3.0, 0.5, 0.05, 0.6, slot);
	}

	override void Tick()
	{
		let fd = flashDef;
		if (!fd)
		{
			Destroy();   // a savegame load: a flash is a tic or two, not worth restoring
			return;
		}
		age++;
		if (age > life)
		{
			Destroy();
			return;
		}

		if (strobeLit)
		{
			if (age >= fd.lightTics)
			{
				A_RemoveLight("rsb_muzzle");
				strobeLit = false;
			}
			else
			{
				StrobeLight(1.0 - double(age) / double(fd.lightTics));
			}
		}

		if (coneOn)
		{
			double f = 1.0 - (double(age) / double(fd.coneTics + 1));
			if (f <= 0)
			{
				Level.ClearVolumetricBeam(slot);
				coneOn = false;
			}
			else
			{
				Beam(f * f * f);
			}
		}
		Super.Tick();
	}

	override void OnDestroy()
	{
		A_RemoveLight("rsb_muzzle");
		if (coneOn) Level.ClearVolumetricBeam(slot);
		Super.OnDestroy();
	}
}

// A PUFF OF BARREL SMOKE. Authored sprites, not particles: GPU particles are
// additive glow until lit smoke lands in the engine (ENGINE_SUPPORT_LIST.md #7).
class RSB_Smoke : Actor
{
	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
		+NOTELEPORT
		+DONTSPLASH
		RenderStyle "Translucent";
		Alpha 0.3;
		Radius 1;
		Height 1;
	}

	States
	{
	Spawn:
		RSSK ABCDEF 4;
		Stop;
	}

	override void Tick()
	{
		// Work first, then advance the state: the last state destroys the actor
		// inside Super.Tick(), and nothing may touch it after that.
		Vel *= 0.9;
		Vel.Z += 0.012;
		A_SetScale(Scale.X * 1.03);
		Alpha -= 0.012;
		if (Alpha <= 0)
		{
			Destroy();
			return;
		}
		Super.Tick();
	}
}
