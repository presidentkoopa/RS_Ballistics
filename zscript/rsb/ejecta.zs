// ============================================================================
// EJECTA: SPENT CASINGS AND HULLS, from an `ejecta` profile.
//
// Once the reload system's casing (WM_Casing, since removed), now data. WHAT STAYS IN
// THE RELOAD SYSTEM: the eject port, the direction, when a case comes out, and
// live rounds (which can be caught and loaded). It calls
//   RSB_Ejecta.Throw(profile, at, dir, carrierVel, throwSpeed, seed, shared, casingSound)
// Throw returns the casing, or null when none was spawned.
//
// TWO KINDS OF CASING, CHOSEN BY `shared`. Which one is a netplay question.
//
// shared = false (THE DEFAULT) -- RSB_LocalEjecta, a look on THIS machine only.
//   +NOINTERACTION: never in the blockmap, never activates a line, touches
//   nothing in the playsim, so it may exist on one machine and not on another.
//   It moves itself (a trace along its flight each tic finds floors, walls and
//   ceilings), bounces and lies still. Being local it follows every setting:
//   not spawned when casings are off, the player's style and tier variant,
//   size, hot glow, time on the floor. Its throw speed may come from a user
//   setting.
//   USE IT whenever Throw is not certain to run on every machine for the same
//   shot. Today that is every caller: the reload rigs work only the console
//   player's hands (RS_VR_Reload system.zs, the perPlayer comment), so a casing
//   thrown from a rig is thrown on one machine.
//
// shared = true -- RSB_Ejecta, a real bouncing missile, for a caller that runs
//   on every machine (rigs, once they run per player). The engine's own bounce,
//   so it takes up playsim movement and must exist IDENTICALLY everywhere:
//   - it always spawns, whatever the player's casings switch, tier or style;
//   - its physics and lifetime come from the BASE profile only, never a ~style
//     or @tier variant, which are local choices;
//   - its variation is hashed, never the playsim RNG;
//   - the caller's throw speed must be the same on every machine: a constant,
//     never a user cvar.
//   The player's settings change only how it LOOKS: invisible when casings are
//   off, drawn size, hot glow, and how soon it fades (never later than the
//   profile's lifetime, which is when every machine removes it).
//
// THE LOOK is the profile's sprite, five tumble frames A to E, lying on C -- or, for
// `look = model, <class>`, that casing class's 3D mesh (casings.zs, MODELDEF), which
// tumbles by pitch and roll and lies on its side at the mesh's own height.
// ============================================================================

class RSB_Ejecta : Actor
{
	Default
	{
		Projectile;
		-NOGRAVITY
		-ACTIVATEIMPACT
		-ACTIVATEPCROSS
		+THRUACTORS
		+NOTELEPORT
		+DONTSPLASH
		+USEBOUNCESTATE
		BounceType "Doom";
		BounceFactor 0.45;
		WallBounceFactor 0.3;
		BounceCount 4;
		Gravity 0.6;
		Speed 0;
		Damage 0;
		Radius 1;
		Height 1;
	}

	String ejectaId;
	private int restTics;
	private int hotAge;
	private int hotTics;
	private int lifeTics;
	private int tumbleSeq;
	private int spriteIndex;

	States
	{
	Spawn:
		RSCS ABCDE 2;
		Loop;
	Bounce:
		RSCS A 0 { Tumble(); }
		Goto Spawn;
	Death:
		RSCS C -1;
		Stop;
	}

	// casingSound: a sound for this casing's bounces instead of the profile's -- a
	// gun card's own pick. "" keeps the profile's.
	static Actor Throw(String whichEjecta, Vector3 at, Vector3 aim, Vector3 carrierVel, double throwSpeed, int seed, bool shared = false, String casingSound = "")
	{
		let reg = RSB_Registry.Get();
		if (!reg) return null;
		let ed = reg.FindEjecta(whichEjecta);   // the base profile: see `shared = true` above
		if (!ed)
		{
			RSB_Log.Once(RSB_Log.LV_ERR, "ejecta:missing:" .. whichEjecta, String.Format(
				"ejecta \"%s\" is not defined in any RSBDEFS", whichEjecta));
			return null;
		}
		Vector3 d = (aim.Length() > 0.000001) ? aim.Unit() : (0, 0, 1);
		PortSmoke(ed, at, d, seed);
		if (!shared) return RSB_LocalEjecta.Toss(reg, whichEjecta, at, d, carrierVel, throwSpeed, seed, casingSound);

		let c = RSB_Ejecta(Actor.Spawn("RSB_Ejecta", at, ALLOW_REPLACE));
		if (!c) return null;

		c.ejectaId = whichEjecta;
		c.spriteIndex = SpriteOf(ed);
		c.bINVISIBLE = !RSB_Settings.Casings();                 // look only
		c.A_SetScale(ed.scale * RSB_Settings.CasingSize());     // look only: scale is not size
		c.bouncefactor = ed.bounceFloor;
		c.wallbouncefactor = ed.bounceWall;
		c.bouncecount = ed.bounceCount;
		c.Gravity = ed.gravity;
		if (casingSound.Length() > 0) c.BounceSound = casingSound;
		else if (!(ed.soundName ~== "none")) c.BounceSound = ed.soundName;
		c.hotTics = RSB_Settings.CasingHot() ? ed.hotTics : 0;
		c.lifeTics = ed.lifeTics;
		c.bBRIGHT = c.hotTics > 0;

		double mul = RSB_Hash.Between(ed.speedMul - ed.speedJitter, ed.speedMul + ed.speedJitter,
			seed, level.maptime, RSB_Hash.OfPos(at));
		c.Vel = d * (throwSpeed * max(0.0, mul)) + carrierVel;
		c.angle = VectorAngle(d.x, d.y);
		return c;
	}

	// GUN SMOKE OUT OF THE PORT as the case leaves (the profile's `portsmoke`): lit, never
	// glowing, scaled by the effects level and the Muzzle smoke setting. With the case,
	// whether or not casings are drawn -- it is smoke, not brass.
	static void PortSmoke(RSB_EjectaDef ed, Vector3 at, Vector3 d, int seed)
	{
		if (!ed || ed.portSmokeCount <= 0 || ed.portSmokeParticle.Length() == 0) return;
		int tier = RSB_Tier.Current();
		if (tier <= RSB_Tier.T_OFF) return;
		int n = int(ed.portSmokeCount * RSB_Tier.CountScale(tier) * RSB_Settings.FlashSmoke() + 0.5);
		if (n <= 0) return;
		// The handle is a hash of the name, the same everywhere: cached, never tested.
		if (ed.portSmokeHandle == 0) ed.portSmokeHandle = level.ParticleDefinition(ed.portSmokeParticle);
		level.SpawnParticles(ed.portSmokeHandle, at + d * 0.5, d, min(n, 16), 40.0, 10.0, 0.6,
			1.0, 0.35, Color(255, 255, 255, 255), 1.0, 1.0, RSB_Hash.Seed(seed, level.maptime, RSB_Hash.OfPos(at)));
	}

	// The profile's sprite, or -1 to keep RSCS. A sprite only exists once some
	// actor's states use it; one that does not is reported once.
	static int SpriteOf(RSB_EjectaDef ed)
	{
		if (ed.lookKind ~== "model") return -1;   // a model casing draws its mesh, not a sprite
		if (ed.lookName ~== "RSCS") return -1;
		int s = GetSpriteIndex(ed.lookName);
		if (s < 0)
			RSB_Log.Once(RSB_Log.LV_WARN, "ejecta:sprite:" .. ed.lookName, String.Format(
				"ejecta %s: sprite %s is not loaded (no actor's states use it) -- drawn as RSCS", ed.id, ed.lookName));
		return s;
	}

	private void Tumble()
	{
		tumbleSeq++;
		angle += RSB_Hash.Between(-60.0, 60.0, level.maptime, tumbleSeq, RSB_Hash.OfPos(pos));
	}

	override void Tick()
	{
		// FRESH BRASS SHOWS IN THE DARK: fullbright for its first tics, which also
		// spares it the world darkness (HWSprite::DrawSprite exempts fullbright).
		if (bBRIGHT)
		{
			hotAge++;
			if (hotAge > hotTics) bBRIGHT = false;
		}

		if (InStateSequence(CurState, ResolveState("Death")))
		{
			restTics++;
			// REMOVED on the profile's lifetime, the same tic on every machine.
			if (restTics > lifeTics)
			{
				Destroy();
				return;
			}
			// FADED from view sooner if this player's slider says so -- a look only.
			if (restTics > int(lifeTics * clamp(RSB_Settings.CasingLife(), 0.0, 1.0)))
			{
				A_SetRenderStyle(Alpha, STYLE_Translucent);
				Alpha = max(0.0, Alpha - 0.05);
			}
		}
		Super.Tick();
		if (!bDestroyed && spriteIndex >= 0) sprite = spriteIndex;   // the states name RSCS
	}
}

// A CASING ON THIS MACHINE ONLY. See `shared = false` above.
class RSB_LocalEjecta : Actor
{
	Default
	{
		+PRECACHEALWAYS    // loaded with the map, not on its first use: no stutter (engine precache)
		+CLIENTSIDE        // a look on this machine only: the engine's client-side thinkers, never the playsim's
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
		+NOTELEPORT
		+DONTSPLASH
		Radius 1;
		Height 1;
	}

	const SETTLE_SPEED     = 1.0;    // map units a tic: slower off the floor than this, it lies still
	const QUIET_SPEED      = 1.5;    // slower than this, a bounce makes no sound
	const FLOOR_GRIP       = 0.7;    // horizontal speed kept through a floor bounce
	const FLOOR_CHECK_TICS = 8;      // how often a lying casing checks the floor is still there
	const MAX_FLIGHT_TICS  = 350;    // one that never lands (out over a pit) fades anyway
	const FADE_STEP        = 0.05;

	String ejectaId;
	private Vector3 flight;          // map units a tic. Vel stays zero, so the engine's mover leaves it alone.
	private double  bounceFloor;
	private double  bounceWall;
	private int     bouncesLeft;
	private String  bounceSnd;
	private int     hotTics;
	private int     fadeFrom;        // tics on the floor
	private int     age;
	private int     restAge;
	private int     tumbleSeq;
	private bool    resting;
	private bool    fading;
	private double  pitchSpin;       // a 3D casing's tumble, degrees a tic (a sprite ignores pitch and roll)
	private double  rollSpin;
	private int     wispTics;        // the hot case trails a thin wisp this many tics (the profile's `wisp`)
	private int     wispHandle;
	private bool    forceFade;       // over the casing cap: fade now (RSB_Registry.KeepCasing)
	private int     lastTic;         // level.maptime at its last tick: a casing that slept catches up on waking
	private int     tickStep;        // tics since that tick
	private int     floorCheckIn;    // tics until a lying casing checks its floor again

	// How high the casing's centre sits above the floor when it lies still: 0 for a
	// sprite (its art sits on its origin); a model casing gives its mesh's lying radius.
	virtual double RestHeight() { return 0.0; }

	States
	{
	Spawn:
		RSCS A -1;
		Stop;
	}

	static RSB_LocalEjecta Toss(RSB_Registry reg, String whichEjecta, Vector3 at, Vector3 d, Vector3 carrierVel, double throwSpeed, int seed, String casingSound = "")
	{
		if (!RSB_Settings.Casings()) return null;
		let ed = reg.ResolveEjecta(whichEjecta, RSB_Tier.Name(RSB_Tier.Current()));
		if (!ed) return null;
		// A MODEL casing is its own class (MODELDEF is per class); a sprite casing is this one.
		class<RSB_LocalEjecta> spawnClass = "RSB_LocalEjecta";
		if (ed.lookKind ~== "model")
		{
			Name modelName = ed.lookName;
			class<RSB_LocalEjecta> mc = (class<RSB_LocalEjecta>)(modelName);
			if (mc) spawnClass = mc;
			else RSB_Log.Once(RSB_Log.LV_WARN, "ejecta:model:" .. ed.lookName, String.Format(
				"ejecta %s: %s is not a casing model class (an RSB_LocalEjecta) -- thrown as a sprite", ed.id, ed.lookName));
		}
		let c = RSB_LocalEjecta(Actor.SpawnClientSide(spawnClass, at, ALLOW_REPLACE));
		if (!c) return null;
		c.lastTic = level.maptime - 1;

		c.ejectaId = whichEjecta;
		int s = RSB_Ejecta.SpriteOf(ed);
		if (s >= 0) c.sprite = s;
		c.A_SetScale(ed.scale * RSB_Settings.CasingSize());
		c.bounceFloor = ed.bounceFloor;
		c.bounceWall = ed.bounceWall;
		c.bouncesLeft = ed.bounceCount;
		c.Gravity = ed.gravity;
		c.bounceSnd = (casingSound.Length() > 0) ? casingSound : ed.soundName;
		c.hotTics = RSB_Settings.CasingHot() ? ed.hotTics : 0;
		c.bBRIGHT = c.hotTics > 0;
		c.fadeFrom = int(max(1, ed.lifeTics) * clamp(RSB_Settings.CasingLife(), 0.0, 1.0));
		c.tumbleSeq = seed;
		if (ed.wispTics > 0 && ed.wispParticle.Length() > 0 && RSB_Settings.FlashSmoke() > 0)
		{
			// The handle is a hash of the name, the same everywhere: cached, never tested.
			if (ed.wispHandle == 0) ed.wispHandle = level.ParticleDefinition(ed.wispParticle);
			c.wispHandle = ed.wispHandle;
			c.wispTics = ed.wispTics;
		}
		// THE TUMBLE, hashed: end over end at 18-42 degrees a tic either way, a slower roll.
		int tumbleHash = RSB_Hash.OfPos(at);
		c.pitchSpin = RSB_Hash.Between(18.0, 42.0, seed, 3, tumbleHash) * ((RSB_Hash.Frac(seed, 5, tumbleHash) < 0.5) ? -1.0 : 1.0);
		c.rollSpin = RSB_Hash.Between(-35.0, 35.0, seed, 7, tumbleHash);
		c.pitch = RSB_Hash.Between(-60.0, 60.0, seed, 9, tumbleHash);

		double mul = RSB_Hash.Between(ed.speedMul - ed.speedJitter, ed.speedMul + ed.speedJitter,
			seed, level.maptime, RSB_Hash.OfPos(at));
		c.flight = d * (throwSpeed * max(0.0, mul)) + carrierVel;
		reg.KeepCasing(c);
		c.angle = VectorAngle(d.x, d.y);
		return c;
	}

	override void Tick()
	{
		if (isFrozen()) return;
		// THE MAP CLOCK, not a count of ticks: a casing that slept (below) catches up on its age.
		int now = level.maptime;
		tickStep = now - lastTic;
		if (tickStep <= 0) return;
		lastTic = now;
		age += tickStep;
		if (bBRIGHT && age > hotTics) bBRIGHT = false;
		if (resting) restAge += tickStep;

		if (forceFade || restAge > fadeFrom || age > MAX_FLIGHT_TICS + fadeFrom)
		{
			if (!fading)
			{
				fading = true;
				A_SetRenderStyle(Alpha, STYLE_Translucent);
			}
			Alpha -= FADE_STEP;
			if (Alpha <= 0.0)
			{
				Destroy();
				return;
			}
		}

		if (resting) Lie();
		else Fly();
		if (bDestroyed) return;
		if (age <= wispTics && !resting) Wisp();
		Super.Tick();
		// A CASING LYING STILL SLEEPS (engine thinker sleep, in the client-side collection): nothing happens to it
		// between floor checks, so it wakes only for the next check or its fade. FadeOut wakes it early.
		if (!bDestroyed && resting && !fading && !forceFade && !bBRIGHT)
		{
			int nap = min(FLOOR_CHECK_TICS, fadeFrom - restAge + 1);
			if (nap > 1) Sleep(nap);
		}
	}

	// A BLAST NEARBY (a flash's `blastkick`): a casing within `reach` of `from` is thrown off it, harder the
	// closer, lying or flying. A sleeping casing wakes.
	void Shove(Vector3 from, double reach, double strength)
	{
		if (fading || reach <= 0 || strength <= 0) return;
		Vector3 away = pos - from;
		double dist = away.Length();
		if (dist >= reach || dist < 0.001) return;
		double k = 1.0 - dist / reach;
		away /= dist;
		flight += (away + (0, 0, 0.6)).Unit() * (strength * k);
		resting = false;
		bouncesLeft = max(bouncesLeft, 1);
		Wake();
	}

	// OVER THE CASING CAP (RSB_Registry.KeepCasing): start fading now, flying or lying.
	void FadeOut()
	{
		forceFade = true;
		Wake();   // a sleeping casing fades now, not at its next floor check
	}

	// THE HOT CASE'S WISP: one thin, lit mote a tic where it is, thinning as it cools.
	private void Wisp()
	{
		double cooling = 1.0 - 0.5 * double(age) / double(max(1, wispTics));
		level.SpawnParticles(wispHandle, pos, (0, 0, 1), 1, 180.0, 1.5, 0.5, 0.8, 0.3,
			Color(255, 255, 255, 255), 1.0, cooling, RSB_Hash.Seed(tumbleSeq, age, 173));
	}

	// ONE TIC OF FLIGHT: fall, then trace the move and bounce off what it meets.
	private void Fly()
	{
		// FALL. Not GetGravity(): this actor is +NOGRAVITY (so the engine's mover leaves it alone),
		// and GetGravity() returns 0 for every +NOGRAVITY actor -- which left casings drifting on
		// their throw line, bouncing off ceilings and settling slowly (owner, 2026-09-14).
		flight.z -= Gravity * level.gravity * CurSector.gravity * 0.00125;
		frame = (age / 2) % 5;
		pitch += pitchSpin;
		roll += rollSpin;
		double spd = flight.Length();
		if (spd < 0.0001) return;
		Vector3 dir = flight / spd;

		FLineTraceData d;
		bool hit = LineTrace(VectorAngle(dir.x, dir.y), spd + 0.5, -asin(clamp(dir.z, -1.0, 1.0)),
			TRF_ABSPOSITION | TRF_THRUACTORS, pos.z, pos.x, pos.y, d);
		if (hit && d.HitType == FLineTraceData.TRACE_HasHitSky)
		{
			Destroy();
			return;
		}
		if (hit && d.HitType == FLineTraceData.TRACE_HitWall)
		{
			Vector3 n = -dir;
			if (d.HitLine)
			{
				Vector2 dl = d.HitLine.delta;
				Vector3 ln = (dl.y, -dl.x, 0);
				if (ln.Length() > 0.000001)
				{
					n = ln.Unit();
					if ((n dot flight) > 0) n = -n;
				}
			}
			flight -= n * (2.0 * (flight dot n));
			flight.x *= bounceWall;
			flight.y *= bounceWall;
			SetOrigin(d.HitLocation + n * 1.0, true);
			Bounced(spd);
			return;
		}
		if (hit && d.HitType == FLineTraceData.TRACE_HitFloor)
		{
			SetOrigin(d.HitLocation, true);
			HitFloor(d.HitLocation.z, spd);
			return;
		}
		if (hit && d.HitType == FLineTraceData.TRACE_HitCeiling)
		{
			flight.z = -abs(flight.z) * bounceWall;
			SetOrigin(d.HitLocation - (0, 0, 1), true);
			Bounced(spd);
			return;
		}

		SetOrigin(pos + flight, true);
		if (pos.z < floorz) HitFloor(floorz, spd);   // a trace can slip past a seam
	}

	private void HitFloor(double fz, double spdBefore)
	{
		bouncesLeft--;
		flight.z = abs(flight.z) * bounceFloor;
		flight.x *= FLOOR_GRIP;
		flight.y *= FLOOR_GRIP;
		if (flight.z < SETTLE_SPEED || bouncesLeft < 0)
		{
			resting = true;
			flight = (0, 0, 0);
			frame = 2;   // C: lying on its side
			pitch = 0;   // a model casing lies along the floor
			SetOrigin((pos.x, pos.y, fz + RestHeight() * Scale.X), true);
		}
		else
		{
			SetOrigin((pos.x, pos.y, fz + 0.1), true);
		}
		Bounced(spdBefore);
	}

	private void Bounced(double spdBefore)
	{
		tumbleSeq++;
		pitchSpin *= -0.65;   // a hit turns the tumble over and takes some of it
		rollSpin *= 0.75;
		angle += RSB_Hash.Between(-60.0, 60.0, level.maptime, tumbleSeq, RSB_Hash.OfPos(pos));
		if (spdBefore > QUIET_SPEED && !(bounceSnd ~== "none"))
			A_StartSound(bounceSnd, CHAN_AUTO, CHANF_OVERLAP, clamp(spdBefore / 6.0, 0.25, 1.0));
	}

	// LYING STILL: a lift carries it up; a floor that drops lets it fall.
	private void Lie()
	{
		floorCheckIn -= tickStep;
		if (floorCheckIn > 0) return;
		floorCheckIn = FLOOR_CHECK_TICS;
		double fz = GetZAt(flags: GZF_3DRESTRICT);
		double restZ = fz + RestHeight() * Scale.X;
		if (restZ > pos.z + 0.01) SetOrigin((pos.x, pos.y, restZ), true);
		else if (restZ < pos.z - 1.0) resting = false;
	}
}
