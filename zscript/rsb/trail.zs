// ============================================================================
// TRAILS: what a beam leaves in the air from the muzzle to where it hit, from a
// `trail` profile. First user: the railgun (a Quake 2 railgun trail).
//
//   THE CORE   one drawn line, muzzle to hit, its colour and halo from the profile,
//              fading over `line`'s tics while its halo swells and its edges waver
//              (the engine's drawn-line looks), then cleared.
//   THE HELIX  a corkscrew of GPU particles round the line, each drifting outward
//              and dimming, so the spiral loosens and breaks up.
//   LIGHTS     a few brief lights along the path.
//   HEAT       a faint shimmer along it (RSB_Heat's blast slots).
//
// HOW A GUN USES IT:  RSB_Trail.Lay(profile, shooter, from, to), once per shot, with
// the muzzle and the hit point. The shot itself (its damage, its puff) is the gun's.
// A gun drawing the engine's own rail spiral as well shows two trails: switch that
// one off.
//
// SLOTS: drawn lines 1216-1279 are RS_Ballistics' trails (assigned by the build
// lane), used in turn; a new trail takes the oldest line.
//
// NETPLAY. Drawing only: +NOINTERACTION, no RNG (the helix phase is a hash), nothing
// read back. Laid from the shot on whichever machines fire it.
// ============================================================================

class RSB_Trail play
{
	const FIRST_SLOT = 1216;
	const SLOTS = 64;

	static void Lay(String whichTrail, Actor shooter, Vector3 from, Vector3 to)
	{
		// A SHOT THAT DRAWS NO BEAM, stated. Same reason as the ejecta hatch above it.
		if (whichTrail.Length() == 0 || whichTrail ~== "none") return;
		let reg = RSB_Registry.Get();
		if (!reg || !RSB_Settings.Trails()) return;
		int tier = RSB_Tier.Current();
		if (tier <= RSB_Tier.T_OFF) return;
		let td = reg.ResolveTrail(whichTrail, RSB_Tier.Name(tier));
		if (td) RSB_Registry.Tally("trail", whichTrail);
		if (!td)
		{
			RSB_Log.Once(RSB_Log.LV_ERR, "trail:missing:" .. whichTrail, String.Format(
				"trail \"%s\" is not defined in any RSBDEFS, but something lays it", whichTrail));
			return;
		}
		Vector3 run = to - from;
		double len = run.Length();
		if (len < 1.0) return;
		Vector3 u = run / len;

		// THE CORE LINE, faded by its own non-interacting actor.
		if (td.lineIntensity > 0)
		{
			let line = RSB_TrailLine(Actor.SpawnClientSide("RSB_TrailLine", from, ALLOW_REPLACE));
			if (line) line.Start(td, reg.NextTrailSlot(), from, to);
		}

		// THE HELIX. A basis square to the line, a phase from the shot's position.
		if (td.helixParticle.Length() > 0 && td.helixSpacing > 0)
		{
			if (td.helixHandle == 0) td.helixHandle = level.ParticleDefinition(td.helixParticle);
			Vector3 p1 = (abs(u.z) < 0.95) ? (u cross (0, 0, 1)) : (u cross (1, 0, 0));
			p1 = p1.Unit();
			Vector3 p2 = u cross p1;
			int posSeed = RSB_Hash.OfPos(from);
			double phase = RSB_Hash.Between(0.0, 360.0, level.maptime, 7, posSeed);
			int motes = int(min(len / td.helixSpacing, double(td.helixMax)) * RSB_Tier.CountScale(tier) + 0.5);
			motes = clamp(motes, 0, td.helixMax * 3);
			for (int k = 0; k < motes; k++)
			{
				double t = (k + 0.5) * len / motes;
				double a = phase + t / 100.0 * td.helixTurns * 360.0;
				Vector3 radial = p1 * cos(a) + p2 * sin(a);
				level.SpawnParticles(td.helixHandle, from + u * t + radial * td.helixRadius, radial, 1, 10.0,
					td.helixDrift, 0.3, td.helixLife, td.helixLifeJitter, td.helixColor, 1.0, 1.0,
					RSB_Hash.Seed(level.maptime, k + 1, posSeed));
			}
		}

		// THE BEAM LIGHTS THE ROOM IT CROSSES. The engine's segment light: a start, an end, and every
		// wall between them lit as one shape -- no beads, and one light where `lights` would spend
		// sixteen. With `beamjag` it is a CHAIN of them following the bolt's own wander, so the room is
		// lit by the shape of the arc instead of by a cylinder through it, and each link carries its own
		// colour: white-hot at the muzzle, violet where it lands.
		if (td.beamRadius > 0 && td.beamIntensity > 0 && RSB_Settings.ImpactLights())
		{
			double life = td.beamTics / 35.0;
			double bright = td.beamIntensity * RSB_Settings.ImpactLight() * RSB_Tier.LightScale(tier);
			int segs = clamp(td.beamSegments, 1, 12);
			// A PERPENDICULAR PAIR to push the links off the axis, built the same way the helix builds
			// its own so a bolt and its motes wander in the same space.
			Vector3 p1 = (abs(u.z) < 0.9) ? (u cross (0, 0, 1)) : (u cross (1, 0, 0));
			p1 = p1.Unit();
			Vector3 p2 = u cross p1;
			int posSeed = RSB_Hash.OfPos(from);
			Vector3 prev = from;
			double prevShare = 1.0;
			for (int i = 1; i <= segs; i++)
			{
				double t = double(i) / double(segs);
				Vector3 at = from + u * (len * t);
				// The LAST point is where the bolt actually landed, so it never wanders: an arc that
				// misses what it struck reads as a bug however pretty the rest of it is.
				if (i < segs && td.beamJag > 0)
				{
					double a = RSB_Hash.Between(0.0, 360.0, level.maptime, 100 + i, posSeed);
					double r = RSB_Hash.Between(0.3, 1.0, level.maptime, 200 + i, posSeed) * td.beamJag;
					at += (p1 * cos(a) + p2 * sin(a)) * r;
				}
				double share = 1.0 - (1.0 - td.beamEnd) * t;
				Color c = td.lightColor;
				if (segs > 1)
				{
					// Each link takes the colour at its own midpoint, so the gradient is along the arc.
					double m = (t + (i - 1.0) / double(segs)) * 0.5;
					c = Color(255,
						int(td.lightColor.r + (td.beamColorEnd.r - td.lightColor.r) * m),
						int(td.lightColor.g + (td.beamColorEnd.g - td.lightColor.g) * m),
						int(td.lightColor.b + (td.beamColorEnd.b - td.lightColor.b) * m));
				}
				level.SpawnEffectLight(prev, c, td.beamRadius, bright * prevShare, life, (0, 0, 0),
					at, 0.0, EFL_IMPORTANT, 0.0, 0.0, life, 0.0, 0.0,
					(prevShare > 0.001) ? clamp(share / prevShare, 0.0, 1.0) : 1.0);
				prev = at;
				prevShare = share;
			}
		}

		// LIGHTS along the path, brief.
		if (td.lightCount > 0 && td.lightRadius > 0 && RSB_Settings.ImpactLights())
		{
			for (int i = 0; i < td.lightCount; i++)
			{
				Vector3 at = from + u * (len * (i + 0.5) / td.lightCount);
				let l = RSB_ImpactLight(Actor.SpawnClientSide("RSB_ImpactLight", at, ALLOW_REPLACE));
				if (l) l.Start(td.lightRadius, td.lightIntensity * RSB_Settings.ImpactLight(), td.lightTics, td.lightColor);
			}
		}

		// HEAT along it.
		if (td.heatStrength > 0)
			RSB_Heat.Along(from, u, len, td.heatRadius, td.heatStrength, td.heatTics);
	}
}

// THE CORE LINE OF ONE TRAIL: one drawn-line slot, faded every tic, cleared at the
// end. Its intensity is blended between tics by the engine, so the fade is smooth.
class RSB_TrailLine : Actor
{
	Default
	{
		+CLIENTSIDE        // a look for this machine: the engine's client-side thinkers, never the playsim's
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
		+NOTELEPORT
		+DONTSPLASH
		RenderStyle "None";
		Radius 1;
		Height 1;
	}

	int slot;
	private int age;
	private int fadeTics;
	private Vector3 startAt;
	private Vector3 endAt;
	transient RSB_TrailDef trailDef;

	States
	{
	Spawn:
		TNT1 A -1;
		Stop;
	}

	void Start(RSB_TrailDef td, int useSlot, Vector3 a, Vector3 b)
	{
		// The oldest trail still holding this slot lets go of it first.
		let it = ThinkerIterator.Create("RSB_TrailLine", Thinker.MAX_STATNUM + 1, true);
		RSB_TrailLine other;
		while (other = RSB_TrailLine(it.Next()))
		{
			if (other != self && other.slot == useSlot) other.LetGo();
		}
		trailDef = td;
		slot = useSlot;
		startAt = a;
		endAt = b;
		age = 0;
		fadeTics = max(1, td.lineFadeTics);
		Draw();
	}

	void LetGo()
	{
		slot = -1;
		Destroy();
	}

	override void Tick()
	{
		if (!trailDef || slot < 0)
		{
			Destroy();   // a savegame load: drawn lines are not saved either
			return;
		}
		age++;
		if (age >= fadeTics)
		{
			Destroy();
			return;
		}
		Draw();
	}

	// f runs 0 (just fired) to 1 (gone): the core thins, the halo swells, the edges
	// waver more, and the brightness falls off as a square.
	private void Draw()
	{
		let td = trailDef;
		double f = double(age) / fadeTics;
		double k = (1.0 - f) * (1.0 - f);
		// THE BEAT (`linepulse`), on the MAP clock so a held beam breathes steadily rather than
		// restarting with every shot -- at thirty-five shots a second an age-based beat would just be
		// noise. As the core dims the far halo swells to take its place, so the near colour and the far
		// one trade dominance down the beam instead of the whole thing blinking.
		double beat = 1.0, swell = 1.0;
		if (td.pulseTics > 0)
		{
			double phase = 0.5 + 0.5 * sin(360.0 * double(level.maptime % td.pulseTics) / double(td.pulseTics));
			beat = (1.0 - td.pulseDepth) + td.pulseDepth * phase;
			swell = 1.0 + td.pulseSwell * (1.0 - phase);
		}
		level.SetDrawnLine(slot, startAt, endAt, td.lineThick * (1.0 - 0.6 * f), td.lineSoft * (1.0 + td.lineSwell * f),
			td.lineColor, td.lineIntensity * k * beat);
		level.SetDrawnLineLook(slot, 1.0, td.lineHalo, 0.0, 0.0, 0.0, 0.0);
		if (td.lineColorEndSet) level.SetDrawnLineGradient(slot, td.lineColorEnd, swell);
		double lick = td.licksStart + (td.licksEnd - td.licksStart) * f;
		if (lick > 0) level.SetDrawnLineTurbulence(slot, lick, td.lickScale, td.lickSpeed);
	}

	override void OnDestroy()
	{
		if (slot >= 0) level.ClearDrawnLine(slot);
		Super.OnDestroy();
	}
}
