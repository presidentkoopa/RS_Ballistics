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
// EVERY SHOT ITS OWN. A profile's `vary` wobbles the light, flame, cone, sparks and
// smoke; `maybe` bursts fire on some shots; `surge` now and then makes a whole shot
// bigger; the flame sprite turns to a new angle each shot. All hashed from the tic and
// the muzzle's position.
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
	private double coneMul;
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

		// EVERY SHOT ITS OWN: hashed from the tic and where the muzzle is, so no two
		// shots match and nothing touches the playsim RNG.
		int shotTic = level.maptime;
		int posSeed = RSB_Hash.OfPos(pos);
		double surge = (fd.surgeChance > 0 && RSB_Hash.Frac(shotTic, 401, posSeed) < fd.surgeChance) ? fd.surgeScale : 1.0;
		double vLight  = RSB_Hash.Wobble(fd.varyLight, shotTic, 403, posSeed) * surge;
		double vFlame  = RSB_Hash.Wobble(fd.varyFlame, shotTic, 405, posSeed) * surge;
		double vCone   = RSB_Hash.Wobble(fd.varyCone, shotTic, 407, posSeed) * surge;
		double vSparks = RSB_Hash.Wobble(fd.varySparks, shotTic, 409, posSeed) * surge;
		double vSmoke  = RSB_Hash.Wobble(fd.varySmoke, shotTic, 411, posSeed) * surge;
		// A THROB (`throb`): light and cone swell and ease on a beat by the map clock.
		if (fd.throbTics > 0)
		{
			double beat = (1.0 - fd.throbDepth) + fd.throbDepth * (0.5 + 0.5 * sin(shotTic * 360.0 / fd.throbTics));
			vLight *= beat;
			vCone *= beat;
		}

		double flameSize = fd.flameScale * RSB_Settings.FlashFlameSize() * vFlame;
		if (tier <= RSB_Tier.T_OFF || flameSize <= 0 || !RSB_Settings.FlashFlame()) bINVISIBLE = true;
		else
		{
			// Not a stamp: the star stretches a little and turns to a new angle each shot.
			double stretch = fd.varyFlame * 0.5;
			A_SetScale(flameSize * RSB_Hash.Wobble(stretch, shotTic, 413, posSeed),
				flameSize * RSB_Hash.Wobble(stretch, shotTic, 415, posSeed));
			if (fd.flameRoll)
			{
				bROLLSPRITE = true;
				roll = RSB_Hash.Between(0.0, 360.0, shotTic, 417, posSeed);
			}
		}

		if (tier <= RSB_Tier.T_OFF) return;

		punchMul = RSB_Settings.FlashLight() * vLight;
		rangeMul = RSB_Settings.FlashSize() * (0.75 + 0.25 * vLight);
		densityMul = RSB_Settings.FlashConeDensity() * vCone;
		coneMul = 0.85 + 0.15 * vCone;

		if (fd.lightRadius > 0 && fd.lightTics > 0 && punchMul > 0 && rangeMul > 0) StrobeLight(1.0);
		coneOn = fd.coneLength > 0 && fd.coneTics > 0 && RSB_Settings.FlashCone() && densityMul > 0;
		if (coneOn) Beam(1.0);

		let reg = RSB_Registry.Get();
		// A GUN'S SIZE (`sizecvar`): offsets along the bore follow the gun's size slider. The flash
		// is the local rig's, so the local player's slider is the right one to read.
		double sizeMul = 1.0;
		if (fd.sizeCvar.Length() > 0) sizeMul = max(0.05, RSB_Settings.Cvf(fd.sizeCvar, 1.0));

		double countScale = (fd.id.IndexOf("@") >= 0) ? 1.0 : RSB_Tier.CountScale(tier);
		if (reg)
		{
			double sparkScale = countScale * RSB_Settings.FlashSparks() * vSparks;
			for (int i = 0; i < fd.bursts.Size(); i++)
				RSB_Burst.Fire(reg.FindBurst(fd.bursts[i]), pos, dir, dir, sparkScale, 1.0,
					RSB_Hash.Seed(shotTic, i + 1, posSeed), null, 1.0, sizeMul);
			// Bursts only some shots throw: powder specks, a wider spray.
			for (int i = 0; i < fd.maybeBursts.Size(); i++)
			{
				if (RSB_Hash.Frac(shotTic, 421 + i * 2, posSeed) >= fd.maybeChance[i]) continue;
				RSB_Burst.Fire(reg.FindBurst(fd.maybeBursts[i]), pos, dir, dir, sparkScale, 1.0,
					RSB_Hash.Seed(shotTic, 61 + i, posSeed), null, 1.0, sizeMul);
			}
		}

		// HEAT SHIMMER out of the muzzle (RSB_Heat): a column of hot air along the shot.
		if (fd.heatStrength > 0)
			RSB_Heat.Along(pos, dir, fd.heatLength, fd.heatRadius, fd.heatStrength * surge, fd.heatTics);
		// THE BACKBLAST'S HOT AIR (`backheat`): a column out of the rear of the tube, behind.
		if (fd.backHeatStrength > 0)
			RSB_Heat.Along(pos - dir * (fd.backHeatOffset * sizeMul), -dir, fd.backHeatLength * sizeMul, fd.backHeatRadius, fd.backHeatStrength * surge, fd.backHeatTics);

		// THE GROUND KICK (`groundkick`): a big gun's blast raises the floor under and just
		// ahead of it -- dust rolling out, water thrown up -- the impact chosen by the
		// floor's surface, when the floor is within reach below the muzzle.
		if (fd.kickImpact.Length() > 0 && fd.kickReach > 0)
		{
			Vector3 groundDir = (dir.x, dir.y, 0);
			Vector3 kickFrom = pos;
			if (groundDir.Length() > 0.001)
			{
				groundDir = groundDir.Unit();
				if (level.IsPointInLevel(pos + groundDir * (fd.kickAlong * sizeMul))) kickFrom = pos + groundDir * (fd.kickAlong * sizeMul);
			}
			let ground = RSB_Materials.FloorUnder(self, kickFrom, fd.kickReach);
			if (ground) RSB_Impact.LandOn(self, ground, fd.kickImpact, groundDir);
		}

		int puffs = int(fd.smokeCount * countScale * RSB_Settings.FlashSmoke() * vSmoke + 0.5);
		// GPU SMOKE (stage 2d: lit, alpha-blended, soft) when the profile names a
		// definition: puffs drifting out of the bore, rising and hanging. The handle
		// is a hash of the name, the same everywhere, so it is cached, never tested.
		if (fd.smokeParticle.Length() > 0)
		{
			if (puffs > 0)
			{
				if (fd.smokeHandle == 0) fd.smokeHandle = level.ParticleDefinition(fd.smokeParticle);
				level.SpawnParticles(fd.smokeHandle, pos + dir * 1.0, dir, puffs * 2, 30.0, 14.0, 0.6,
					1.8, 0.35, Color(255, 255, 255, 255), 1.0, 1.0, RSB_Hash.Seed(shotTic, 77, posSeed));
			}
			puffs = 0;   // no sprite puffs as well
		}
		for (int i = 0; i < puffs; i++)
		{
			let s = Actor.Spawn("RSB_Smoke", pos + dir * 0.5, ALLOW_REPLACE);
			if (!s) continue;
			s.A_SetScale(fd.smokeScale);
			s.Alpha = fd.smokeAlpha;
			Vector3 drift = (RSB_Hash.Between(-0.15, 0.15, shotTic, i, posSeed),
				RSB_Hash.Between(-0.15, 0.15, shotTic, i + 31, posSeed), 0.15);
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
			fd.coneInner, fd.coneOuter, fd.coneLength * f * coneMul, fd.coneDensity * densityMul * f,
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

// A PUFF OF BARREL SMOKE as an authored sprite: the fallback for a flash profile
// with no `smokeparticle`. Every gun flash RS_Ballistics ships names one
// (rsb_smoke_gun, lit GPU smoke since stage 2d), so these draw only for a
// profile another package writes without it.
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
