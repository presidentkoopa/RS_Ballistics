// ============================================================================
// FLAMETHROWERS, from `flame` profiles: a stream of fire out of a nozzle, fire
// where it lands, scorch, a flickering light and a roar.
//
// HOW A GUN USES IT
//   RSB_Flame.Stream(profile, owner, hand, nozzleAt, dir, carrierVel,
//                    intensity = 1, fuelShare = 1, acrossAxis = (0,0,0))
//       every tic the trigger is held (every other tic works too: the emitter
//       keeps burning between feeds). The first call lights it; it keeps an
//       emitter per (owner, hand). fuelShare is what is left in the canister,
//       0..1: below the profile's `sputter` share the jet coughs. acrossAxis is
//       the gun's sideways axis in the world, for side-by-side `jets` on a
//       rolled gun; zero works it out from the aim.
//   RSB_Flame.StopStream(owner, hand)
//       on release: the profile's `flameout` burst, unless the canister is
//       empty. Optional: an emitter not fed for two tics stops itself.
//   RSB_Flame.Pilot(profile, nozzleAt, dir)
//       every tic while idle, for a pilot light.
// Looks only. What the fire DAMAGES is the gun's business.
//
// THE STREAM IS STATELESS GPU PARTICLES, fired from the nozzle every tic along
// the stream at the fuel's speed. Each tic's particles live exactly as long as
// the fuel takes to reach where the stream lands (a trace along it), so none
// fly on through the wall. Several stream bursts at different speeds, lives and
// colours overlap into a flame that is white at the nozzle, orange through the
// body and dark red at the tip. Around them, THE TUBE: a run of drawn-line
// segments from the nozzle to where the stream lands (the engine's drawn-line
// looks: a colour gradient, a halo widening as it travels, world-space licks),
// so the core reads as one jet. Puffs slide along what they hit (collide =
// plane) and black smoke rises where it lands. Heat shimmer is the engine's
// next item.
//
// NETPLAY. Every actor here is +NOINTERACTION, uses no playsim RNG (the flicker
// and the stream's wander are hashes) and changes nothing a netgame compares.
// ============================================================================

class RSB_Flame play
{
	// The hand number the menu's preview uses, clear of the real hands (0, 1).
	const PREVIEW_HAND = 9;

	// THE TUBE'S DRAWN-LINE SLOTS. Drawn-line indices are caller-managed
	// (LevelLocals.SetDrawnLine), and RS_Ballistics' flames own 1024..1215:
	// TUBE_BLOCKS blocks of TUBE_MAX_SEGMENTS, one block per burning emitter.
	// Low on purpose: the engine walks every slot up to the highest ever written,
	// every frame. Beams (the lasers, the Lance) are a separate system.
	const TUBE_FIRST_SLOT = 1024;
	const TUBE_BLOCKS = 24;
	const TUBE_MAX_SEGMENTS = 8;

	static RSB_FlameEmitter Stream(String whichFlame, Actor who, int hand, Vector3 nozzle, Vector3 aim, Vector3 carrierVel,
		double intensity = 1.0, double fuelShare = 1.0, Vector3 acrossAxis = (0, 0, 0))
	{
		let reg = RSB_Registry.Get();
		if (!reg || !who) return null;

		let e = Find(who, hand);
		if (e && !(e.flameId ~== whichFlame))
		{
			e.BeginStop();   // the gun switched profiles: the old flame goes out
			e = null;
		}
		if (!e)
		{
			let fd = reg.ResolveFlame(whichFlame, RSB_Tier.Name(RSB_Tier.Current()));
			if (!fd)
			{
				RSB_Log.Once(RSB_Log.LV_ERR, "flame:missing:" .. whichFlame, String.Format(
					"flame \"%s\" is not defined in any RSBDEFS", whichFlame));
				return null;
			}
			e = RSB_FlameEmitter(Actor.Spawn("RSB_FlameEmitter", nozzle, ALLOW_REPLACE));
			if (!e) return null;
			e.Begin(whichFlame, fd, who, hand);
		}
		e.Feed(nozzle, aim, carrierVel, intensity, fuelShare, acrossAxis);
		return e;
	}

	static void StopStream(Actor who, int hand)
	{
		let e = Find(who, hand);
		if (e) e.BeginStop();
	}

	static void Pilot(String whichFlame, Vector3 nozzle, Vector3 aim)
	{
		let reg = RSB_Registry.Get();
		if (!reg) return;
		int tier = RSB_Tier.Current();
		if (tier <= RSB_Tier.T_OFF || !RSB_Settings.Flame()) return;
		let fd = reg.ResolveFlame(whichFlame, RSB_Tier.Name(tier));
		if (!fd) return;
		Vector3 d = (aim.Length() > 0.000001) ? aim.Unit() : (1, 0, 0);
		int posSeed = RSB_Hash.OfPos(nozzle);
		for (int i = 0; i < fd.pilot.Size(); i++)
			RSB_Burst.Fire(reg.FindBurst(fd.pilot[i]), nozzle, d, d, RSB_Tier.CountScale(tier), 1.0,
				RSB_Hash.Seed(level.maptime, i + 1, posSeed));
	}

	// The burning (not stopping) emitter of this owner's hand, or null.
	static RSB_FlameEmitter Find(Actor who, int hand)
	{
		if (!who) return null;
		let it = ThinkerIterator.Create("RSB_FlameEmitter");
		RSB_FlameEmitter e;
		while (e = RSB_FlameEmitter(it.Next()))
		{
			if (e.flameOwner == who && e.hand == hand && !e.IsStopping()) return e;
		}
		return null;
	}
}

// ONE BURNING STREAM: the nozzle light and the loop sound live on it; a child
// light follows where the stream lands.
class RSB_FlameEmitter : Actor
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

	const FADE_TICS = 8;

	String flameId;
	Actor  flameOwner;
	int    hand;

	private Vector3 nozzle;
	private Vector3 aimDir;
	private Vector3 carrier;
	private double  strength;
	private int     lastFed;
	private int     fadeTics;
	private bool    stopping;
	private int     burnSeq;
	private double  fuelLeft;
	private Vector3 acrossHint;
	private bool    sputterOut;   // this tic the coughing jet is out
	private RSB_FlameLight landLight;
	int     tubeBlock;            // this emitter's block of tube slots; -1 none
	private int     tubeLaid;     // tube segments drawn at the last lay
	private Vector3 tubeStart;
	private Vector3 tubeEnd;
	transient RSB_FlameDef flameDef;

	States
	{
	Spawn:
		TNT1 A -1;
		Stop;
	}

	bool IsStopping() { return stopping; }

	void Begin(String whichFlame, RSB_FlameDef fd, Actor who, int whichHand)
	{
		flameId = whichFlame;
		flameDef = fd;
		flameOwner = who;
		hand = whichHand;
		strength = 1.0;
		fuelLeft = 1.0;
		lastFed = level.maptime;
		tubeBlock = -1;

		double vol = RSB_Settings.FlameVolume();
		if (vol > 0)
		{
			if (!(fd.startSound ~== "none")) A_StartSound(fd.startSound, CHAN_AUTO, CHANF_OVERLAP, vol);
			if (!(fd.loopSound ~== "none")) A_StartSound(fd.loopSound, CHAN_BODY, CHANF_LOOPING, vol);
		}
		RSB_Log.Once(RSB_Log.LV_INFO, "flame:first:" .. fd.id, String.Format(
			"first flame this map using %s: reach %d, fuel %d units a second, %d stream burst(s)",
			fd.id, int(fd.reach), int(fd.fuelSpeed), fd.stream.Size()));
	}

	void Feed(Vector3 at, Vector3 aim, Vector3 carrierVel, double intensity, double fuelShare, Vector3 acrossAxis)
	{
		nozzle = at;
		aimDir = (aim.Length() > 0.000001) ? aim.Unit() : (1, 0, 0);
		carrier = carrierVel;
		strength = clamp(intensity, 0.0, 2.0);
		fuelLeft = clamp(fuelShare, 0.0, 1.0);
		acrossHint = acrossAxis;
		lastFed = level.maptime;
		SetOrigin(at, true);
	}

	void BeginStop()
	{
		if (stopping) return;
		stopping = true;
		fadeTics = FADE_TICS;
		A_StopSound(CHAN_BODY);
		let fd = flameDef;
		double vol = RSB_Settings.FlameVolume();
		if (fd && vol > 0 && !(fd.stopSound ~== "none")) A_StartSound(fd.stopSound, CHAN_AUTO, CHANF_OVERLAP, vol);
		if (fuelLeft > 0.02) FlameOut(1.0);   // an empty canister has nothing left to throw
		DropLandLight();
	}

	override void Tick()
	{
		let fd = flameDef;
		if (!fd)
		{
			Destroy();   // a savegame load: a flame is fed every tic, and it will be again
			return;
		}
		if (stopping)
		{
			fadeTics--;
			if (fadeTics <= 0)
			{
				Destroy();
				return;
			}
			NozzleLight(double(fadeTics) / double(FADE_TICS));
			if (tubeLaid > 0) LayTube(tubeStart, tubeEnd, double(fadeTics) / double(FADE_TICS));
			Super.Tick();
			return;
		}
		// Not fed this tic or the one before: the gun stopped without saying so.
		if (level.maptime - lastFed > 2)
		{
			BeginStop();
			Super.Tick();
			return;
		}
		Burn();
		Super.Tick();
	}

	override void OnDestroy()
	{
		A_RemoveLight("rsb_flame");
		A_StopSound(CHAN_BODY);
		DropLandLight();
		ClearTube();
		tubeBlock = -1;
		Super.OnDestroy();
	}

	private void DropLandLight()
	{
		if (landLight)
		{
			landLight.Destroy();
			landLight = null;
		}
	}

	// THE LAST GOUT OF FIRE: the profile's `flameout` bursts out of the nozzle,
	// on release, and smaller each time a coughing jet catches again.
	private void FlameOut(double amount)
	{
		let fd = flameDef;
		let reg = RSB_Registry.Get();
		if (!fd || !reg || fd.flameout.Size() == 0) return;
		int tier = RSB_Tier.Current();
		if (tier <= RSB_Tier.T_OFF || !RSB_Settings.Flame()) return;
		double countScale = RSB_Tier.CountScale(tier) * RSB_Settings.FlameParticles() * amount;
		int seed = RSB_Hash.OfPos(nozzle);
		for (int i = 0; i < fd.flameout.Size(); i++)
			RSB_Burst.Fire(reg.FindBurst(fd.flameout[i]), nozzle, aimDir, aimDir, countScale, 1.0,
				RSB_Hash.Seed(level.maptime, 300 + i, seed));
	}

	private double Flicker(double amount, int channel)
	{
		return 1.0 - amount + amount * RSB_Hash.Frac(level.maptime, burnSeq, channel);
	}

	private void NozzleLight(double fade)
	{
		let fd = flameDef;
		double mul = RSB_Settings.FlameLight();
		if (!fd || fd.lightRadius <= 0 || mul <= 0 || RSB_Tier.Current() <= RSB_Tier.T_OFF || !RSB_Settings.Flame())
		{
			A_RemoveLight("rsb_flame");
			return;
		}
		double k = Flicker(fd.flicker, 7) * fade;
		A_AttachLight("rsb_flame", DynamicLight.PointLight, fd.lightColor,
			int(fd.lightRadius * (0.75 + 0.25 * k)), 0, DynamicLight.LF_ATTENUATE, (0, 0, 0), 0, 10, 25, 0,
			fd.lightIntensity * mul * strength * k);
	}

	// ---- THE TUBE -----------------------------------------------------------
	// Drawing only: level drawn lines in this emitter's own slots, cleared when it
	// goes. No RNG; the licks are the engine's world-space noise.

	private bool TubeOn()
	{
		let fd = flameDef;
		return fd && fd.tubeSegments > 0 && fd.tubeColors.Size() >= 6 && RSB_Settings.Flame() && RSB_Settings.FlameTube();
	}

	// The lowest block no other emitter holds. Thinker order is the same on every
	// machine, and nothing but drawing reads the answer.
	private int ClaimTubeBlock()
	{
		for (int blk = 0; blk < RSB_Flame.TUBE_BLOCKS; blk++)
		{
			bool taken = false;
			let it = ThinkerIterator.Create("RSB_FlameEmitter");
			RSB_FlameEmitter other;
			while (other = RSB_FlameEmitter(it.Next()))
			{
				if (other != self && other.tubeBlock == blk)
				{
					taken = true;
					break;
				}
			}
			if (!taken) return blk;
		}
		return -1;
	}

	// A straight run of segments from startAt to endAt. Each segment's colour runs
	// to the next point's between the profile's stops (gradient), its halo grows by
	// an equal share of `swell`, and every segment licks with the same turbulence,
	// which is in world space, so the joins stay whole. Inner joins take no taper
	// and no flare, or they would pinch and flash. `fade` dims it as a flame stops;
	// intensity is not blended along a line, so the tip's fall-off is in the colours.
	private void LayTube(Vector3 startAt, Vector3 endAt, double fade)
	{
		let fd = flameDef;
		if (!TubeOn() || fade <= 0)
		{
			ClearTube();
			return;
		}
		if (tubeBlock < 0) tubeBlock = ClaimTubeBlock();
		if (tubeBlock < 0) return;   // every block is burning: this flame goes without
		int segs = min(fd.tubeSegments, RSB_Flame.TUBE_MAX_SEGMENTS);
		int firstSlot = RSB_Flame.TUBE_FIRST_SLOT + tubeBlock * RSB_Flame.TUBE_MAX_SEGMENTS;
		double swellEach = (fd.tubeSwell > 0) ? fd.tubeSwell ** (1.0 / segs) : 1.0;
		double lineIntensity = fd.tubeIntensity * strength * fade;
		Vector3 run = endAt - startAt;
		for (int k = 0; k < segs; k++)
		{
			double t0 = double(k) / segs;
			double t1 = double(k + 1) / segs;
			int slot = firstSlot + k;
			level.SetDrawnLine(slot, startAt + run * t0, startAt + run * t1, fd.tubeThick,
				fd.tubeSoft * (swellEach ** k), TubeColor(fd, t0), lineIntensity);
			level.SetDrawnLineLook(slot, 1.0, fd.tubeHalo, 0.0, 0.0, 0.0, 0.0);
			level.SetDrawnLineGradient(slot, TubeColor(fd, t1), swellEach);
			level.SetDrawnLineTurbulence(slot, fd.tubeLickStrength, fd.tubeLickScale, fd.tubeLickSpeed);
		}
		for (int extra = segs; extra < tubeLaid; extra++) level.ClearDrawnLine(firstSlot + extra);
		tubeLaid = segs;
	}

	private void ClearTube()
	{
		if (tubeBlock < 0) return;
		int firstSlot = RSB_Flame.TUBE_FIRST_SLOT + tubeBlock * RSB_Flame.TUBE_MAX_SEGMENTS;
		for (int k = 0; k < RSB_Flame.TUBE_MAX_SEGMENTS; k++) level.ClearDrawnLine(firstSlot + k);
		tubeLaid = 0;
	}

	// The colour at t (0 the nozzle .. 1 the far end), between evenly spaced stops.
	private static Color TubeColor(RSB_FlameDef fd, double t)
	{
		int stops = fd.tubeColors.Size() / 3;
		double pos = clamp(t, 0.0, 1.0) * (stops - 1);
		int lo = min(int(pos), stops - 2);
		double mixAmt = pos - lo;
		int cr = int(fd.tubeColors[lo * 3] + (fd.tubeColors[lo * 3 + 3] - fd.tubeColors[lo * 3]) * mixAmt + 0.5);
		int cg = int(fd.tubeColors[lo * 3 + 1] + (fd.tubeColors[lo * 3 + 4] - fd.tubeColors[lo * 3 + 1]) * mixAmt + 0.5);
		int cb = int(fd.tubeColors[lo * 3 + 2] + (fd.tubeColors[lo * 3 + 5] - fd.tubeColors[lo * 3 + 2]) * mixAmt + 0.5);
		return Color(255, cr, cg, cb);
	}

	private void Burn()
	{
		let fd = flameDef;
		let reg = RSB_Registry.Get();
		burnSeq++;
		int tier = RSB_Tier.Current();
		bool visuals = reg != null && tier > RSB_Tier.T_OFF && RSB_Settings.Flame();

		// THE STREAM WANDERS within `spread`: a hash per tic, never the RNG.
		// `across`, not `side`: ZScript is case-insensitive and Side is a type.
		Vector3 across = (abs(aimDir.z) < 0.95) ? (aimDir cross (0, 0, 1)) : (aimDir cross (1, 0, 0));
		if (acrossHint.Length() > 0.000001)
		{
			// The gun's own sideways axis, squared up to the aim.
			Vector3 h = acrossHint - aimDir * (acrossHint dot aimDir);
			if (h.Length() > 0.000001) across = h;
		}
		across = across.Unit();
		Vector3 up = across cross aimDir;
		double wobble = tan(clamp(fd.spread, 0.0, 45.0));
		Vector3 dir = aimDir
			+ across * (RSB_Hash.Between(-1.0, 1.0, level.maptime, burnSeq, 11) * wobble)
			+ up * (RSB_Hash.Between(-1.0, 1.0, level.maptime, burnSeq, 12) * wobble);
		dir = dir.Unit();

		// WHERE IT LANDS: a trace along the stream, from the owner so it never
		// stops on the one holding the gun.
		Actor traceFrom = flameOwner ? flameOwner : Actor(self);
		FLineTraceData d;
		double landDist = fd.reach;
		bool landed = false;
		if (traceFrom.LineTrace(VectorAngle(dir.x, dir.y), fd.reach, -asin(clamp(dir.z, -1.0, 1.0)),
			TRF_ABSPOSITION, nozzle.z, nozzle.x, nozzle.y, d))
		{
			if (d.HitType != FLineTraceData.TRACE_HasHitSky)
			{
				landDist = max(1.0, d.Distance);
				landed = true;
			}
		}

		// RUNNING DRY: below the profile's `sputter` share of fuel the jet coughs --
		// out on more tics the emptier it gets (a hash, not the RNG), the roar
		// dropping while it is out, a pop and a hiss each time it catches again.
		bool wasOut = sputterOut;
		sputterOut = false;
		if (fd.sputterBelow > 0 && fuelLeft < fd.sputterBelow)
			sputterOut = RSB_Hash.Frac(level.maptime, burnSeq, 71) > 0.2 + 0.7 * (fuelLeft / fd.sputterBelow);
		double vol = RSB_Settings.FlameVolume();
		if (sputterOut != wasOut) A_SoundVolume(CHAN_BODY, sputterOut ? vol * 0.25 : vol);
		if (wasOut && !sputterOut && vol > 0 && !(fd.sputterSound ~== "none"))
			A_StartSound(fd.sputterSound, CHAN_AUTO, CHANF_OVERLAP, vol);

		NozzleLight(sputterOut ? 0.25 : 1.0);
		if (!visuals || sputterOut)
		{
			DropLandLight();
			ClearTube();
			return;
		}
		if (wasOut) FlameOut(0.5);

		// WHAT IT LANDS ON. A wall or a floor is a plane the stream and the landing
		// bursts slide along (PARTICLEDEFS `collide = plane`) instead of passing
		// into; a monster is no surface, and the stream wraps round it as before.
		RSB_Surface surf = landed ? RSB_Materials.FromTrace(d, dir) : null;
		Vector3 planeAt = (0, 0, 0);
		Vector3 planeNormal = (0, 0, 0);
		double landFloor = -32768;
		if (surf)
		{
			planeAt = surf.at;
			planeNormal = surf.normal;
			landFloor = RSB_Burst.FloorBelow(surf.at, surf.normal);
		}

		// THE STREAM. A written tier variant is used as written; otherwise the tier
		// scales the counts, and the player's slider and style scale on top. Side by
		// side `jets` share the count between them.
		// While the tube draws, the stream keeps the profile's `tube` share: the tube is the core.
		double countScale = (fd.id.IndexOf("@") >= 0) ? 1.0 : RSB_Tier.CountScale(tier);
		countScale *= RSB_Settings.FlameParticles() * strength;
		int jets = max(1, fd.jets);
		double perJet = countScale / jets * (TubeOn() ? fd.tubeStreamShare : 1.0);
		double splay = tan(clamp(fd.jetSplay, 0.0, 45.0));
		double fuelSpd = max(1.0, fd.fuelSpeed);
		double travelSecs = landDist / fuelSpd;
		Vector3 carried = carrier * 35.0;   // map units a tic -> a second
		int posSeed = RSB_Hash.OfPos(nozzle);
		for (int j = 0; j < jets; j++)
		{
			double place = j - (jets - 1) * 0.5;
			Vector3 jetAt = nozzle + across * (place * fd.jetSpacing);
			Vector3 jetDir = (dir + across * (splay * place)).Unit();
			for (int i = 0; i < fd.stream.Size(); i++)
			{
				let b = reg.FindBurst(fd.stream[i]);
				if (!b) continue;
				Vector3 v = jetDir * (fuelSpd * b.speed) + carried;
				double spd = v.Length();
				if (spd < 0.001) continue;
				// The average particle dies where the stream lands. Jitter (+/-) lets the
				// fastest go a little past: behind a wall the depth test hides them; on
				// a monster it reads as flame wrapping round it. On a surface, a puff
				// drawn with a definition lives the profile's `cling` longer, sliding
				// along the surface instead of into it.
				double life = travelSecs * b.life;
				if (landed) life = min(life, landDist / spd + ((surf && b.particle.Length() > 0) ? fd.cling : 0.0));
				RSB_Burst.FireCustom(b, jetAt, v / spd, perJet, spd, life, 1.0,
					RSB_Hash.Seed(level.maptime, burnSeq * 16 + i, posSeed + j * 977), planeAt, planeNormal, landFloor);
			}
		}

		// THE TUBE, from the nozzle to where the stream lands, or as far as it reaches.
		tubeStart = nozzle;
		tubeEnd = nozzle + dir * landDist;
		LayTube(tubeStart, tubeEnd, 1.0);

		if (!landed)
		{
			DropLandLight();
			return;
		}

		// FIRE WHERE IT LANDS.
		Vector3 at = d.HitLocation;
		Vector3 n = -dir;
		if (surf)
		{
			at = surf.at;
			n = surf.normal;
		}
		if (fd.landingTics > 0 && (burnSeq % fd.landingTics) == 0)
		{
			int landSeed = RSB_Hash.OfPos(at);
			for (int i = 0; i < fd.landing.Size(); i++)
				RSB_Burst.Fire(reg.FindBurst(fd.landing[i]), at, n, dir, countScale, 1.0,
					RSB_Hash.Seed(level.maptime, 200 + i, landSeed), surf);
		}
		if (surf && fd.markShape >= 0 && fd.markTics > 0 && (burnSeq % fd.markTics) == 0 && RSB_Settings.Marks())
		{
			int markLife = int(fd.markLife * RSB_Settings.MarkLife() + 0.5);
			if (markLife > 0)
				level.SpawnSurfaceStamp(fd.markShape, at, fd.markRadius, fd.markColor, markLife, (0, 0, 0));
		}

		double lightMul = RSB_Settings.FlameLight();
		if (fd.landLightRadius > 0 && lightMul > 0)
		{
			Vector3 lp = at + n * 8.0;
			if (!landLight) landLight = RSB_FlameLight(Actor.Spawn("RSB_FlameLight", lp, ALLOW_REPLACE));
			if (landLight)
			{
				double k = Flicker(fd.flicker, 21);
				landLight.Glow(lp, fd.landLightRadius * (0.8 + 0.2 * k), fd.landLightIntensity * lightMul * strength * k, fd.lightColor);
			}
		}
		else
		{
			DropLandLight();
		}
	}
}

// THE LIGHT WHERE A STREAM LANDS, moved and re-lit by its emitter every tic.
class RSB_FlameLight : Actor
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
		TNT1 A -1;
		Stop;
	}

	void Glow(Vector3 at, double range, double strength, Color tint)
	{
		SetOrigin(at, true);
		A_AttachLight("rsb_flameland", DynamicLight.PointLight, tint, int(range), 0,
			DynamicLight.LF_ATTENUATE, (0, 0, 0), 0, 10, 25, 0, strength);
	}

	override void OnDestroy()
	{
		A_RemoveLight("rsb_flameland");
		Super.OnDestroy();
	}
}

// THE MENU'S FLAMETHROWER PREVIEW: feeds a stream from the player's eye for a
// couple of seconds, then lets it go out.
class RSB_FlamePreview : Actor
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

	int    playerNum;
	int    ticsLeft;
	String flameId;
	bool   runDry;   // the fuel runs from 30% to empty over the preview

	States
	{
	Spawn:
		TNT1 A -1;
		Stop;
	}

	override void Tick()
	{
		Actor pmo = null;
		if (playerNum >= 0 && playerNum < MAXPLAYERS && playeringame[playerNum]) pmo = players[playerNum].mo;
		ticsLeft--;
		if (!pmo || ticsLeft < 0)
		{
			if (pmo) RSB_Flame.StopStream(pmo, RSB_Flame.PREVIEW_HAND);
			Destroy();
			return;
		}
		double ang = pmo.angle;
		double pit = pmo.pitch;
		Vector3 fwd = (cos(ang) * cos(pit), sin(ang) * cos(pit), -sin(pit));
		Vector3 right = (sin(ang), -cos(ang), 0);
		Vector3 eye = pmo.pos + (0, 0, players[playerNum].viewz - pmo.pos.z);
		Vector3 nozzleAt = eye + fwd * 18.0 + right * 6.0 - (0, 0, 10);
		double fuelShare = runDry ? 0.3 * double(max(ticsLeft, 0)) / 70.0 : 1.0;
		RSB_Flame.Stream(flameId, pmo, RSB_Flame.PREVIEW_HAND, nozzleAt, fwd, pmo.Vel, 1.0, fuelShare);
		Super.Tick();
	}
}
