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
	//
	// ONTO: the surface it comes off, when there is one. A burst drawn with a
	// PARTICLEDEFS definition that says `collide = plane` then keeps its particles
	// in front of that surface and skids them on the floor in front of it (engine
	// F4). No surface -- a flash, a blast in mid-air -- passes no plane.
	//
	// SIZESCALE: every particle's size x this -- an impact's `scale` (a rifle's cloud
	// is bigger than a pistol's). 1 = as the burst and its definition say.
	//
	// OFFSETSCALE: the burst's offset x this -- a flash's gun size (`sizecvar`), so a backblast
	// offset behind the muzzle stays at the rear of a resized tube.
	//
	// PER-SHOT SHAPE (sparks: RSB_Flash's `sparkvary`, RSB_Impact's hit sparks): SPREADSCALE opens or
	// tightens the cone, SPEEDSCALE and LIFESCALE lengthen or shorten the throw, and LEANDEG tilts the
	// whole emission up to that many degrees off its aim toward a side hashed from LEANSEED -- so each
	// shot's spray leans its own way. All 1 / 0 by default: every other caller is unchanged.
	static void Fire(RSB_BurstDef b, Vector3 at, Vector3 normal, Vector3 travel, double countScale, double glowScale, int seed, RSB_Surface onto = null, double sizeScale = 1.0, double offsetScale = 1.0,
		double spreadScale = 1.0, double speedScale = 1.0, double lifeScale = 1.0, double leanDeg = 0.0, int leanSeed = 0)
	{
		if (!b) return;
		if (IsSmoke(b)) countScale *= RSB_Tier.SmokeScale(RSB_Settings.SmokeLevel());   // the Smoke dial
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
		if (leanDeg > 0) dir = Lean(dir, leanDeg, leanSeed);

		if (b.particle.Length() > 0)
		{
			Vector3 planeAt = (0, 0, 0);
			Vector3 planeNormal = (0, 0, 0);
			double floorAt = -32768;
			if (onto && !onto.air && !onto.sky)
			{
				planeAt = onto.at;
				planeNormal = onto.normal;
				floorAt = FloorBelow(onto.at, onto.normal);
			}
			// Several definitions (`particle = a, b, c`) share the count: chips of several shapes.
			int kinds = 1 + b.moreParticles.Size();
			for (int k = 0; k < kinds; k++)
			{
				int share = n / kinds + ((k < n % kinds) ? 1 : 0);
				if (share <= 0) continue;
				int handle = HandleFor(b, k);
				level.SpawnParticles(handle, at + normal * (b.offset * offsetScale), dir, share, clamp(Spread(b) * spreadScale, 0.0, 180.0), b.speed * speedScale, b.speedJitter,
					b.life * lifeScale, b.lifeJitter, b.tint, glowScale, sizeScale, (k == 0) ? seed : RSB_Hash.Seed(seed, k, 613),
					b.shape, planeAt, planeNormal, floorAt);
			}
			return;
		}
		level.SpawnGpuParticles(at + normal * (b.offset * offsetScale), dir, n, clamp(b.cone * spreadScale, 0.0, 180.0), b.speed * speedScale, b.speedJitter,
			b.tint, b.glow * glowScale, b.life * lifeScale, b.lifeJitter, b.sizeStart * sizeScale, b.sizeEnd * sizeScale, b.gravity, b.drag,
			b.orient, b.stretch, seed);
	}

	// A DIRECTION TILTED up to `maxDeg` (at least a third of it) toward a side hashed from `seed`.
	static Vector3 Lean(Vector3 dir, double maxDeg, int seed)
	{
		double a = RSB_Hash.Between(0.35, 1.0, seed, 3, 911) * maxDeg;
		double phi = RSB_Hash.Between(0.0, 360.0, seed, 5, 911);
		Vector3 up = (abs(dir.z) < 0.9) ? (0, 0, 1) : (1, 0, 0);
		Vector3 u = (up cross dir).Unit();
		Vector3 w = dir cross u;
		return (dir * cos(a) + (u * cos(phi) + w * sin(phi)) * sin(a)).Unit();
	}

	// A SPARK BURST -- hot streaks, specks, stars, embers, powder -- the bursts the per-shot spark
	// variation shapes. Flame, core, petals, plumes, smoke, dust and chunks are not.
	static bool IsSpark(RSB_BurstDef b)
	{
		if (!b) return false;
		if (b.particle.IndexOf("rsb_spark") == 0 || b.particle.IndexOf("rsb_ember") == 0) return true;
		String id = b.id.MakeLower();
		return id.IndexOf("spk_") == 0 || id.IndexOf("spark_") == 0 || id.IndexOf("ember_") == 0
			|| id.IndexOf("flash_sparks") == 0 || id.IndexOf("flash_powder") == 0 || id.IndexOf("flash_embers") == 0;
	}

	// A SMOKE BURST (lit puffs, soot, steam, wisps): its count follows the Smoke dial (Ballistics & Effects -> Smoke).
	static bool IsSmoke(RSB_BurstDef b)
	{
		if (!b) return false;
		return b.particle.IndexOf("rsb_smoke_") == 0 || b.particle.IndexOf("rsb_soot_") == 0 || b.particle.IndexOf("rsb_casing_wisp") == 0;
	}

	// A BURST WHOSE PIECES STAY (3D chunks and debris that rest, collide and patter): kept whatever this machine sees
	// (M1), so turning round shows the rubble, and its landing sounds play.
	static bool Stays(RSB_BurstDef b)
	{
		if (!b) return false;
		return b.particle.IndexOf("rsb_chunk_") == 0 || b.particle.IndexOf("rsb_debris_") == 0;
	}

	// One emission whose speed and life the caller decides (a flame's stream: the
	// fuel's speed, and the time to where it lands). Everything else is the burst's.
	// The plane and floor are the caller's (FloorBelow gives the floor); a zero
	// normal is no plane.
	static void FireCustom(RSB_BurstDef b, Vector3 at, Vector3 dir, double countScale, double speedValue, double lifeValue, double glowScale, int seed,
		Vector3 planeAt = (0, 0, 0), Vector3 planeNormal = (0, 0, 0), double floorAt = -32768)
	{
		if (!b || lifeValue <= 0) return;
		if (IsSmoke(b)) countScale *= RSB_Tier.SmokeScale(RSB_Settings.SmokeLevel());   // the Smoke dial
		int n = int(b.count * countScale + 0.5);
		if (n <= 0) return;
		if (b.particle.Length() > 0)
		{
			level.SpawnParticles(HandleFor(b, 0), at + dir * b.offset, dir, n, Spread(b), speedValue, b.speedJitter,
				lifeValue, b.lifeJitter, b.tint, glowScale, 1.0, seed,
				b.shape, planeAt, planeNormal, floorAt);
			return;
		}
		level.SpawnGpuParticles(at + dir * b.offset, dir, n, b.cone, speedValue, b.speedJitter,
			b.tint, b.glow * glowScale, lifeValue, b.lifeJitter, b.sizeStart, b.sizeEnd, b.gravity, b.drag,
			b.orient, b.stretch, seed);
	}

	// THE FLOOR A SKIDDING PARTICLE STOPS ON: the highest floor at or below a point
	// just in front of the surface, 3D floors included. Map data only -- the same on
	// every machine -- and only ever used for what is drawn.
	static double FloorBelow(Vector3 at, Vector3 normal)
	{
		Vector3 p = at + normal * 2.0;
		Sector sec = level.PointInSector(p.xy);
		if (!sec) return -32768;
		double fz;
		Sector fsec;
		F3DFloor ffloor;
		[fz, fsec, ffloor] = sec.NextLowestFloorAt(p.x, p.y, p.z + 1.0);
		return fz;
	}

	// A cone's spread is its half-angle; a disc's is how far it lifts off the
	// surface, which the engine takes as 0 to 90 degrees.
	private static double Spread(RSB_BurstDef b)
	{
		return (b.shape == RSB_BurstDef.SHAPE_DISC) ? min(b.cone, 90.0) : b.cone;
	}

	// THE HANDLE TO DRAW definition slot k with (0 the first, then `particle = a, b, c`'s further ones). SPARK LIGHTS
	// (Lights -> "Spark lights"): every spark lights by default, the owner's lights answer; "Capped per burst" draws the
	// spark and ember definitions' `_capped` twins, a few stronger lights a burst (optimization plan M5). Looks only.
	private static int HandleFor(RSB_BurstDef b, int k)
	{
		int handle = (k == 0) ? Handle(b) : MoreHandle(b, k - 1);
		if (!RSB_Settings.SparkLightsCapped()) return handle;
		while (b.cappedState.Size() <= k)
		{
			b.cappedState.Push(0);
			b.cappedHandles.Push(0);
		}
		if (b.cappedState[k] == 0)
		{
			String name = (k == 0) ? b.particle : b.moreParticles[k - 1];
			if (HasCappedTwin(name))
			{
				b.cappedHandles[k] = level.ParticleDefinition(name .. "_capped");
				b.cappedState[k] = 1;
			}
			else b.cappedState[k] = 2;
		}
		return (b.cappedState[k] == 1) ? b.cappedHandles[k] : handle;
	}

	// The spark and ember definitions PARTICLEDEFS gives a `_capped` twin (keep in step with its capped section).
	static bool HasCappedTwin(String particle)
	{
		return particle ~== "rsb_spark_spray" || particle ~== "rsb_spark_streak" || particle ~== "rsb_spark_photo"
			|| particle ~== "rsb_spark_impact" || particle ~== "rsb_spark_ricochet" || particle ~== "rsb_spark_star"
			|| particle ~== "rsb_spark_speck" || particle ~== "rsb_spark_sparkler" || particle ~== "rsb_spark_ember"
			|| particle ~== "rsb_ember_metal";
	}

	// The burst's PARTICLEDEFS handle, looked up once. A hash of the name: the same
	// on every machine whether or not the definition loaded here, so it is cached
	// and passed, never tested. An unknown one draws nothing on this machine only.
	private static int Handle(RSB_BurstDef b)
	{
		if (b.particleHandle == 0) b.particleHandle = level.ParticleDefinition(b.particle);
		return b.particleHandle;
	}

	// One of a burst's further definitions (`particle = a, b, c`): looked up once, as Handle.
	private static int MoreHandle(RSB_BurstDef b, int i)
	{
		while (b.moreHandles.Size() <= i) b.moreHandles.Push(0);
		if (b.moreHandles[i] == 0) b.moreHandles[i] = level.ParticleDefinition(b.moreParticles[i]);
		return b.moreHandles[i];
	}
}

// A WAKE: what anything that flies sheds along one tic's travel -- a round, a
// plasma ball, a rocket. Particles laid evenly from where it was to where it is,
// drifting back along its flight. A `particle` wake draws each mote with a
// PARTICLEDEFS definition (a rocket's lit smoke); otherwise inline glow.
class RSB_Wake play
{
	static void Lay(String wakeId, Vector3 before, Vector3 after, Vector3 travel)
	{
		// WHAT THIS MACHINE CAN SEE (M1, M2; looks only): no wake this tic when both ends are behind the view; past the
		// range, every other tic.
		int seen = RSB_Settings.ViewBand(after);
		if (seen == RSB_Settings.VIEW_BEHIND)
		{
			if (RSB_Settings.ViewBand(before) == RSB_Settings.VIEW_BEHIND) return;
		}
		else if (seen == RSB_Settings.VIEW_FAR && (level.maptime % 2) == 1) return;
		if (wakeId.Length() == 0 || wakeId ~== "none") return;
		int tier = RSB_Tier.Current();
		if (tier <= RSB_Tier.T_OFF) return;
		let reg = RSB_Registry.Get();
		if (!reg) return;
		let w = reg.ResolveWake(wakeId, RSB_Tier.Name(tier));
		if (!w || (w.perStep <= 0 && w.spacing <= 0)) return;

		Vector3 seg = after - before;
		// `spacing` lays by distance, as dense at any speed -- and in slow motion, where a
		// round moves only a little each tic; `perstep` lays a count each tic.
		double laid = (w.spacing > 0) ? seg.Length() / w.spacing : double(w.perStep);
		double smokeMul = (w.particle.IndexOf("rsb_smoke_") == 0) ? RSB_Tier.SmokeScale(RSB_Settings.SmokeLevel()) : 1.0;   // a smoke trail follows the Smoke dial
		int n = clamp(int(laid * RSB_Tier.CountScale(tier) * RSB_Settings.Wake() * smokeMul + 0.5), 0, (w.spacing > 0) ? 96 : 32);
		Vector3 back = (travel != (0, 0, 0)) ? -travel : (0, 0, 1);
		int posSeed = RSB_Hash.OfPos(after);
		// The handle is a hash of the name, the same everywhere: cached, never tested.
		if (w.particle.Length() > 0 && w.particleHandle == 0) w.particleHandle = level.ParticleDefinition(w.particle);
		for (int k = 0; k < n; k++)
		{
			double t = (k + 0.5) / n;
			int seed = RSB_Hash.Seed(level.maptime, k + 1, posSeed);
			if (w.particle.Length() > 0)
				level.SpawnParticles(w.particleHandle, before + seg * t, back, 1, 180.0, w.drift, 0.5,
					w.life, 0.3, w.tint, w.glow, 1.0, seed);
			else
				level.SpawnGpuParticles(before + seg * t, back, 1, 180.0, w.drift, 0.5, w.tint, w.glow,
					w.life, 0.3, w.sizeStart, w.sizeEnd, w.gravity, w.drag, 0, 0, seed);
		}
	}
}

class RSB_Impact play
{
	const HIT_SPARK_LEAN = 10.0;   // degrees a hit's spark bursts may lean off their aim, per hit

	// A landing projectile. inAirToo: a projectile that must show its impact even
	// with no surface to land on -- a rocket bursting on a monster or in the air --
	// gets it where it is, facing back along its flight, with no mark.
	static void Land(Actor mo, String impactBase, Vector3 travel, bool inAirToo = false)
	{
		if (!mo || impactBase.Length() == 0 || impactBase ~== "none") return;
		RSB_Surface surf = null;
		if (mo.bMISSILE && mo.BlockingMobj)
		{
			// A PROJECTILE THAT HIT A THING lands ON it, never on the wall a trace would find
			// behind it: material "flesh" when the thing bleeds (an impact's `.flesh` variant),
			// no mark. Only a missile: a corpse's stale BlockingMobj must not hide its floor.
			surf = RSB_Materials.InAir(mo.pos, travel);
			if (!mo.BlockingMobj.bNOBLOOD) surf.material = "flesh";
		}
		else
		{
			surf = RSB_Materials.Probe(mo, travel);
		}
		if (inAirToo && !surf) surf = RSB_Materials.InAir(mo.pos, travel);
		LandOn(mo, surf, impactBase, travel);
	}

	// A surface already found. `soundAt` carries the sound: the round itself, or
	// an RSB_SoundSpot placed on the surface.
	// WHICH WAY A DAMAGE BRUSH LIES (`damage ..., along`): its +x unrotated, along the round's travel
	// (a gouge, a cut), or up the wall (wood grain). Up on a floor is square to it: unrotated.
	const DAMAGE_ALONG_NONE   = 0;
	const DAMAGE_ALONG_TRAVEL = 1;
	const DAMAGE_ALONG_UP     = 2;

	// ONE PAINT of lasting damage (engine #17): a DAMAGEDEFS brush into the surface's damage tiles.
	// Presentation only -- the engine queues it (128 a tic) and nothing reads it back.
	static void PaintDamage(RSB_Surface surf, Vector3 travel, String brush, double radius, double depth,
		double soot, double heat, double wet, int along)
	{
		if (!surf || surf.air || surf.sky) return;
		Vector3 axis = (0, 0, 0);
		if (along == DAMAGE_ALONG_TRAVEL) axis = travel;
		else if (along == DAMAGE_ALONG_UP) axis = (0, 0, 1);
		PaintDamageAt(surf.at, surf.normal, axis, brush, radius, depth, soot, heat, wet);
	}

	// The same paint at a point on a surface and its facing (a hotspot, a flame's landing), the brush's
	// +x along `axis` ((0,0,0) unrotated). The radius is kept inside the engine's 0.5 .. 64.
	static void PaintDamageAt(Vector3 at, Vector3 normal, Vector3 axis, String brush, double radius, double depth,
		double soot, double heat, double wet)
	{
		if (radius <= 0 || brush.Length() == 0 || normal == (0, 0, 0)) return;
		level.PaintSurfaceDamage(at, normal, Name(brush), clamp(radius, 0.5, 64.0), depth, soot, heat, wet, axis);
	}

	// AN IMPACT'S VOLUMES (engine #15): each named definition this machine draws, facing out of the surface, scaled by
	// the effects level and the hit's wobble.
	static void SpawnVolumes(RSB_ImpactDef im, Vector3 at, Vector3 facing, int tier, int hitTic, int posSeed)
	{
		if (tier <= RSB_Tier.T_OFF) return;
		while (im.volumeHandles.Size() < im.volumeNames.Size())
			im.volumeHandles.Push(LevelLocals.EmissiveVolumeDefinition(Name(im.volumeNames[im.volumeHandles.Size()])));
		double scale = RSB_Tier.SizeScale(tier) * RSB_Hash.Wobble(im.varyVolume, hitTic, 531, posSeed);
		for (int i = 0; i < im.volumeHandles.Size(); i++)
		{
			if (LevelLocals.EmissiveVolumeEnabled(im.volumeHandles[i]))
				level.SpawnEmissiveVolume(im.volumeHandles[i], at, facing, scale, RSB_Tier.GlowScale(tier));
		}
	}

	static void LandOn(Actor soundAt, RSB_Surface surf, String impactBase, Vector3 travel)
	{
		if (!soundAt || !surf || surf.sky) return;

		// SHOOTING THE LIGHTS OUT (lights.zs) FIRST, ABOVE EVERYTHING, and that position is the whole
		// point rather than tidiness. It is the only GAMEPLAY thing in this function: a darkened sector
		// is level state, saved and shared, and it has to be decided identically on every machine.
		// Everything below reads the local effects dial -- `RSB_Tier.Current()` is this player's
		// `rsb_tier`, and which profile resolves depends on it -- so a break placed after any of it
		// would be a gameplay decision standing on a per-player setting. It is not even gated by the
		// impact profile existing: a lamp goes out whether or not anyone has effects turned on.
		RSB_Lights.ShootOut(surf);

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

		// THE ROOM ANSWERING A BLAST (`tail`): the roll off the walls, on its own channel so the crack
		// keeps ringing under it. The delay is in the files (rsb/blast/roll carries 180 ms of silence),
		// so this needs no timer and no per-listener work: the crack attenuates faster than the rumble,
		// which is what makes a far blast read as far.
		if (vol > 0 && im.tailSound.Length() > 0)
		{
			double tailVol = vol * im.tailVolume * RSB_Settings.TailVolume();
			if (tailVol > 0)
				soundAt.A_StartSound(im.tailSound, CHAN_AUTO, CHANF_OVERLAP, min(tailVol, 1.0));
		}

		bool glancing = false;
		if (im.glanceDeg > 0 && travel != (0, 0, 0) && RSB_Settings.Ricochets())
			glancing = abs(travel dot surf.normal) < sin(im.glanceDeg);
		if (glancing && vol > 0 && !(im.glanceSound ~== "none"))
			soundAt.A_StartSound(im.glanceSound, CHAN_AUTO, CHANF_OVERLAP, vol);

		// A HOTSPOT (`hotspot`): a sustained beam's hits feed one spot that heats up (hotspot.zs).
		// Fed at every effects level, so its sound plays even with the visuals off.
		if (im.hotspot.Length() > 0) RSB_Hotspot.Feed(im.hotspot, surf);

		// RINGING EARS (engine build 4, `hearing`) at every effects level, like the sound: every machine calls it alike and
		// the engine weighs it against its own listener and how enclosed the space is. Off until the player turns it on.
		if (im.hearingStrength > 0)
			level.HearingImpulse(surf.at + surf.normal * 8.0, im.hearingStrength, im.hearingReach, im.hearingRecovery);

		if (tier <= RSB_Tier.T_OFF || !RSB_Settings.Impacts()) return;

		// WHAT THIS MACHINE CAN SEE (M1, M2; RSB_Settings.ViewBand, looks only): behind the view, the short-lived pieces,
		// small lights, marks and bent air are not spawned; past the range, fewer pieces and no maybe or glance bursts.
		// Sounds, the hotspot, lasting damage, pieces that stay, volumes, the room smoke and blast shoves are kept.
		int seen = RSB_Settings.ViewBand(surf.at);

		// The level scales the counts -- a profile written for a level too (what it adds is on
		// top of the level's own ladder). The player's sliders and style scale on top.
		double countScale = RSB_Tier.CountScale(tier);
		countScale *= RSB_Settings.ImpactParticles();
		countScale *= im.countScale;   // the profile's `scale`: how hard this class of round bites
		if (seen == RSB_Settings.VIEW_FAR) countScale *= RSB_Settings.LOD_COUNT;
		double glowScale = RSB_Settings.ImpactGlow();
		int posSeed = RSB_Hash.OfPos(surf.at);

		// EVERY HIT ITS OWN (the profile's `vary` and `maybe`), hashed from the tic and the spot.
		int hitTic = level.maptime;
		countScale *= RSB_Hash.Wobble(im.varyCount, hitTic, 501, posSeed);
		// WHAT THE LIQUID ITSELF DOES (Ballistics -> Liquids): the column out of water, the jet out of a
		// burst pipe, the lumps thrown out of lava. Only these materials, and only the liquid's share --
		// the round still strikes, the metal still sparks and the hole is still punched with this at zero.
		if (surf.material == "liquid" || surf.material == "pipe" || surf.material == "lava")
			countScale *= RSB_Settings.LiquidSplash();
		double sizeScale = im.sizeScale * RSB_Hash.Wobble(im.varySize, hitTic, 503, posSeed);
		double lightWobble = RSB_Hash.Wobble(im.varyLight, hitTic, 505, posSeed);

		// HIT SPARKS VARY TOO (lighter than a muzzle's `sparkvary`): this hit's spark bursts lean up to
		// HIT_SPARK_LEAN degrees off their aim toward a hashed side, and their spread, speed and size vary
		// per hit. Chips, dust, splashes and energy keep their shape.
		int hitLeanSeed = RSB_Hash.Seed(hitTic, 521, posSeed);
		double hSpread = RSB_Hash.Wobble(0.3, hitTic, 523, posSeed);
		double hSpeed  = RSB_Hash.Wobble(0.35, hitTic, 525, posSeed);
		double hSize   = RSB_Hash.Wobble(0.25, hitTic, 527, posSeed);

		for (int i = 0; i < im.bursts.Size(); i++)
		{
			let bd = reg.FindBurst(im.bursts[i]);
			if (seen == RSB_Settings.VIEW_BEHIND && !RSB_Burst.Stays(bd)) continue;
			bool sp = RSB_Burst.IsSpark(bd);
			RSB_Burst.Fire(bd, surf.at, surf.normal, travel, countScale, glowScale, RSB_Hash.Seed(hitTic, i + 1, posSeed), surf,
				sp ? sizeScale * hSize : sizeScale, 1.0, sp ? hSpread : 1.0, sp ? hSpeed : 1.0, 1.0, sp ? HIT_SPARK_LEAN : 0.0, hitLeanSeed);
		}
		for (int i = 0; i < im.maybeBursts.Size(); i++)
		{
			if (RSB_Hash.Frac(hitTic, 511 + i * 2, posSeed) >= im.maybeChance[i]) continue;
			let bd = reg.FindBurst(im.maybeBursts[i]);
			if (seen != RSB_Settings.VIEW_FULL && !RSB_Burst.Stays(bd)) continue;
			bool sp = RSB_Burst.IsSpark(bd);
			RSB_Burst.Fire(bd, surf.at, surf.normal, travel, countScale, glowScale, RSB_Hash.Seed(hitTic, 41 + i, posSeed), surf,
				sp ? sizeScale * hSize : sizeScale, 1.0, sp ? hSpread : 1.0, sp ? hSpeed : 1.0, 1.0, sp ? HIT_SPARK_LEAN : 0.0, hitLeanSeed);
		}
		if (glancing && seen == RSB_Settings.VIEW_FULL && !(im.glanceBurst ~== "none"))
		{
			let bd = reg.FindBurst(im.glanceBurst);
			bool sp = RSB_Burst.IsSpark(bd);
			RSB_Burst.Fire(bd, surf.at, surf.normal, travel, countScale, glowScale, RSB_Hash.Seed(hitTic, 97, posSeed), surf,
				sp ? sizeScale * hSize : sizeScale, 1.0, sp ? hSpread : 1.0, sp ? hSpeed : 1.0, 1.0, sp ? HIT_SPARK_LEAN : 0.0, hitLeanSeed);
		}

		if (im.markShape >= 0 && !surf.air && RSB_Settings.Marks() && seen != RSB_Settings.VIEW_BEHIND)
		{
			int life = int(im.markLife * RSB_Settings.MarkLife() + 0.5);
			if (life > 0)
				level.SpawnSurfaceStamp(im.markShape, surf.at, im.markRadius, im.markColor, life, (0, 0, 0));
		}

		// LASTING DAMAGE (engine #17, `damage`; `glancedamage` when it glances): a hole, gouge, crater or
		// scorch that stays for the map. The glowing stamp above is the brief heat; this is the wound.
		// The WET share of a paint is the Liquids dial's (a wet mark is a liquid, a hole is not), so
		// turning liquids down leaves the wound and takes away only the damp.
		double wetMul = RSB_Settings.LiquidWet();
		if (glancing && im.glanceDamageRadius > 0)
			PaintDamage(surf, travel, im.glanceDamageBrush, im.glanceDamageRadius, im.glanceDamageDepth, im.glanceDamageSoot,
				im.glanceDamageHeat, im.glanceDamageWet * wetMul, im.glanceDamageAlong);
		else if (im.damageRadius > 0)
			PaintDamage(surf, travel, im.damageBrush, im.damageRadius, im.damageDepth, im.damageSoot,
				im.damageHeat, im.damageWet * wetMul, im.damageAlong);

		// A BLAST RIPPLE (`ripple`): the air bending in a ring where it went off. Anchored to the WORLD,
		// not to a hand -- it happened out there. Look only, so it is called straight from here on
		// whichever machines see it, with no network event: nothing in the game reads it back.
		if (im.rippleRadius > 0 && RSB_Settings.FlashShockwave())
			level.SpawnShockwave(surf.at + surf.normal * 6.0, im.rippleRadius,
				im.rippleStrength * RSB_Tier.HeatScale(tier), im.rippleTics,
				im.rippleThickness, im.rippleChroma, 0, null);

		// EMISSIVE VOLUMES (engine #15, `volume`): a blast as glowing gas where it lands, in the world.
		if (im.volumeNames.Size() > 0) SpawnVolumes(im, surf.at + surf.normal * 8.0, surf.normal, tier, hitTic, posSeed);

		if (im.lightRadius > 0 && RSB_Settings.ImpactLights() && (seen == RSB_Settings.VIEW_FULL || im.lightRadius >= RSB_Settings.VIEW_BIG_LIGHT))
		{
			double strength = im.lightIntensity * RSB_Settings.ImpactLight() * lightWobble;
			if (strength > 0)
			{
				let l = RSB_ImpactLight(Actor.SpawnClientSide("RSB_ImpactLight", surf.at + surf.normal * 4.0, ALLOW_REPLACE));
				if (l) l.Start(im.lightRadius * (0.8 + 0.2 * lightWobble), strength, im.lightTics, im.lightColor);
			}
		}

		// SMOKE INTO THE ROOM and A BLAST'S SHOVE (engine 13b, `smokevolume`, `push`).
		// Both follow the effects level (RSB_Tier: heavy x1, extreme up).
		if (im.smokeVolAmount > 0)
			level.EmitSmoke(surf.at + surf.normal * (im.smokeVolRadius * 0.5), im.smokeVolRadius, im.smokeVolAmount * RSB_Tier.SmokeScale(RSB_Settings.SmokeLevel()), im.smokeVolHeat, surf.normal * 20.0, (0, 0, 0), im.smokeVolSoot);
		// FLASH BLINDNESS (engine build 4, `exposure`): the blast's light, weighed by each machine against its own camera
		// (distance, facing, walls, darkness). Not thinned by the view band: the engine does its own facing.
		if (im.exposureStrength > 0)
			level.ExposureImpulse(surf.at + surf.normal * 16.0, im.exposureStrength, im.exposureReach, im.exposureRecovery, im.exposureTint);
		if (im.pushRadius > 0 && im.pushStrength > 0)
			level.PushEffectImpulse(surf.at, im.pushRadius, im.pushStrength * RSB_Tier.PushScale(tier));

		// HEAT SHIMMER where it lands (RSB_Heat): a ball of hot air that fades on its own.
		if (im.heatStrength > 0 && seen != RSB_Settings.VIEW_BEHIND)
			RSB_Heat.Blast(surf.at + surf.normal * (im.heatRadius * 0.4), im.heatRadius, im.heatStrength, im.heatTics);
	}
}

// A BRIEF LIGHT WHERE A ROUND LANDS: bright on the hit tic, gone a few tics
// later, fading as a square so it reads as a spark, not a lamp.
class RSB_ImpactLight : Actor
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

	States
	{
	Spawn:
		TNT1 A 105;
		Stop;
	}
}
