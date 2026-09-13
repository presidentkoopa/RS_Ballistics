// ============================================================================
// WHAT A LANDING ROUND DOES. Bursts, a glowing mark, a brief light, a sound and,
// on a glancing hit, a ricochet -- chosen by the surface's material, the
// player's style and effects tier, from RSBDEFS `impact` profiles, and scaled
// by the player's menu settings.
//
// NETPLAY. A round lands on every machine, so this runs on every machine. It
// uses no playsim RNG (particle seeds are hashes of the tic and position), and
// the tier, style and sliders -- how it looks -- are each player's own local
// choice, which is fine because nothing here affects the game. The impact light
// and sound spot are non-interacting actors that touch neither gameplay nor RNG.
// ============================================================================

class RSB_Burst play
{
	// One emission. `normal` is the surface's (or, for a flash, the barrel's)
	// direction; `travel` the round's.
	static void Fire(RSB_BurstDef b, Vector3 at, Vector3 normal, Vector3 travel, double countScale, double glowScale, int seed)
	{
		if (!b) return;
		int n = int(b.count * countScale + 0.5);
		if (n <= 0) return;

		Vector3 dir = normal;
		switch (b.aim)
		{
		case RSB_BurstDef.AIM_REFLECT:
			if (travel != (0, 0, 0)) dir = travel - normal * (2.0 * (travel dot normal));
			break;
		case RSB_BurstDef.AIM_BACK:
			if (travel != (0, 0, 0)) dir = -travel;
			break;
		case RSB_BurstDef.AIM_ALONG:
			if (travel != (0, 0, 0)) dir = travel;
			break;
		case RSB_BurstDef.AIM_UP:
			dir = (0, 0, 1);
			break;
		default:
			break;
		}
		if (dir.Length() < 0.000001) dir = (0, 0, 1);
		dir = dir.Unit();

		if (b.particle.Length() > 0)
		{
			level.SpawnParticles(Handle(b), at + normal * b.offset, dir, n, b.cone, b.speed, b.speedJitter,
				b.life, b.lifeJitter, Color(255, 255, 255, 255), glowScale, 1.0, seed);
			return;
		}
		level.SpawnGpuParticles(at + normal * b.offset, dir, n, b.cone, b.speed, b.speedJitter,
			b.tint, b.glow * glowScale, b.life, b.lifeJitter, b.sizeStart, b.sizeEnd, b.gravity, b.drag,
			b.orient, b.stretch, seed);
	}

	// One emission whose speed and life the caller decides (a flame's stream: the
	// fuel's speed, and the time to where it lands). Everything else is the burst's.
	static void FireCustom(RSB_BurstDef b, Vector3 at, Vector3 dir, double countScale, double speedValue, double lifeValue, double glowScale, int seed)
	{
		if (!b || lifeValue <= 0) return;
		int n = int(b.count * countScale + 0.5);
		if (n <= 0) return;
		if (b.particle.Length() > 0)
		{
			level.SpawnParticles(Handle(b), at + dir * b.offset, dir, n, b.cone, speedValue, b.speedJitter,
				lifeValue, b.lifeJitter, Color(255, 255, 255, 255), glowScale, 1.0, seed);
			return;
		}
		level.SpawnGpuParticles(at + dir * b.offset, dir, n, b.cone, speedValue, b.speedJitter,
			b.tint, b.glow * glowScale, lifeValue, b.lifeJitter, b.sizeStart, b.sizeEnd, b.gravity, b.drag,
			b.orient, b.stretch, seed);
	}

	// The burst's PARTICLEDEFS handle, looked up once. A hash of the name: the same
	// on every machine whether or not the definition loaded here, so it is cached
	// and passed, never tested. An unknown one draws nothing on this machine only.
	private static int Handle(RSB_BurstDef b)
	{
		if (b.particleHandle == 0) b.particleHandle = level.ParticleDefinition(b.particle);
		return b.particleHandle;
	}
}

class RSB_Impact play
{
	// A landing projectile.
	static void Land(Actor mo, String impactBase, Vector3 travel)
	{
		if (!mo || impactBase.Length() == 0 || impactBase ~== "none") return;
		LandOn(mo, RSB_Materials.Probe(mo, travel), impactBase, travel);
	}

	// A surface already found. `soundAt` carries the sound: the round itself, or
	// an RSB_SoundSpot placed on the surface.
	static void LandOn(Actor soundAt, RSB_Surface surf, String impactBase, Vector3 travel)
	{
		if (!soundAt || !surf || surf.sky) return;
		if (impactBase.Length() == 0 || impactBase ~== "none") return;
		let reg = RSB_Registry.Get();
		if (!reg) return;

		int tier = RSB_Tier.Current();
		let im = reg.ResolveImpact(impactBase, surf.material, RSB_Tier.Name(tier));
		if (!im)
		{
			RSB_Log.Once(RSB_Log.LV_ERR, "impact:missing:" .. impactBase, String.Format(
				"impact \"%s\" is not defined in any RSBDEFS, but something names it", impactBase));
			return;
		}
		String surfName = (surf.material.Length() > 0) ? surf.material : "default";
		RSB_Log.Once(RSB_Log.LV_INFO, "impact:first:" .. im.id, String.Format(
			"first impact this map using %s (surface %s, effects %s)", im.id, surfName, RSB_Tier.Name(tier)));
		if (RSB_Settings.DebugSurfaces())
			Console.Printf("RSB hit: texture %s -> surface %s -> profile %s",
				(surf.texName.Length() > 0) ? surf.texName : "(none)", surfName, im.id);

		// SOUND AT EVERY TIER: the dial turns the visuals down, not the fight.
		double vol = RSB_Settings.ImpactVolume();
		if (vol > 0 && !(im.soundName ~== "none"))
			soundAt.A_StartSound(im.soundName, CHAN_AUTO, CHANF_OVERLAP, vol);

		bool glancing = false;
		if (im.glanceDeg > 0 && travel != (0, 0, 0) && RSB_Settings.Ricochets())
			glancing = abs(travel dot surf.normal) < sin(im.glanceDeg);
		if (glancing && vol > 0 && !(im.glanceSound ~== "none"))
			soundAt.A_StartSound(im.glanceSound, CHAN_AUTO, CHANF_OVERLAP, vol);

		if (tier <= RSB_Tier.T_OFF || !RSB_Settings.Impacts()) return;

		// A profile written for this tier is used as written; otherwise the tier
		// scales the counts. The player's sliders and style scale on top.
		double countScale = (im.id.IndexOf("@") >= 0) ? 1.0 : RSB_Tier.CountScale(tier);
		countScale *= RSB_Settings.ImpactParticles();
		double glowScale = RSB_Settings.ImpactGlow();
		int posSeed = RSB_Hash.OfPos(surf.at);

		for (int i = 0; i < im.bursts.Size(); i++)
			RSB_Burst.Fire(reg.FindBurst(im.bursts[i]), surf.at, surf.normal, travel, countScale, glowScale,
				RSB_Hash.Seed(level.maptime, i + 1, posSeed));
		if (glancing && !(im.glanceBurst ~== "none"))
			RSB_Burst.Fire(reg.FindBurst(im.glanceBurst), surf.at, surf.normal, travel, countScale, glowScale,
				RSB_Hash.Seed(level.maptime, 97, posSeed));

		if (im.markShape >= 0 && RSB_Settings.Marks())
		{
			int life = int(im.markLife * RSB_Settings.MarkLife() + 0.5);
			if (life > 0)
				level.SpawnSurfaceStamp(im.markShape, surf.at, im.markRadius, im.markColor, life, (0, 0, 0));
		}

		if (im.lightRadius > 0 && RSB_Settings.ImpactLights())
		{
			double strength = im.lightIntensity * RSB_Settings.ImpactLight();
			if (strength > 0)
			{
				let l = RSB_ImpactLight(Actor.Spawn("RSB_ImpactLight", surf.at + surf.normal * 4.0, ALLOW_REPLACE));
				if (l) l.Start(im.lightRadius, strength, im.lightTics, im.lightColor);
			}
		}
	}
}

// A BRIEF LIGHT WHERE A ROUND LANDS: bright on the hit tic, gone a few tics
// later, fading as a square so it reads as a spark, not a lamp.
class RSB_ImpactLight : Actor
{
	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
		+NOTELEPORT
		+DONTSPLASH
		RenderStyle "None";
		Radius 1;
		Height 1;
	}

	// Named to stay clear of Actor's own radius and tics.
	private double lightRange;
	private double lightStrength;
	private int    lightLife;
	private Color  lightTint;
	private int    age;

	States
	{
	Spawn:
		TNT1 A -1;
		Stop;
	}

	void Start(double range, double strength, int life, Color tint)
	{
		lightRange = range;
		lightStrength = strength;
		lightLife = max(1, life);
		lightTint = tint;
		Glow(1.0);
	}

	private void Glow(double k)
	{
		A_AttachLight("rsb_impact", DynamicLight.PointLight, lightTint,
			int(lightRange * (0.5 + 0.5 * k)), 0, DynamicLight.LF_ATTENUATE, (0, 0, 0), 0, 10, 25, 0,
			lightStrength * k * k);
	}

	override void Tick()
	{
		age++;
		if (age >= lightLife)
		{
			A_RemoveLight("rsb_impact");
			Destroy();
			return;
		}
		Glow(1.0 - double(age) / double(lightLife));
		Super.Tick();
	}
}

// A SILENT, INVISIBLE PLACE FOR A SOUND TO COME FROM, for effects with no actor
// of their own at the spot (a preview impact). Gone after three seconds.
class RSB_SoundSpot : Actor
{
	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
		+NOTELEPORT
		+DONTSPLASH
		RenderStyle "None";
		Radius 1;
		Height 1;
	}

	States
	{
	Spawn:
		TNT1 A 105;
		Stop;
	}
}
