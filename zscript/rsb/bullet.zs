// ============================================================================
// THE BULLET. A real round that flies, from a `round` profile, which pairs:
//
//   ballistics  speed, radius, damage: the round as the GAME knows it. Read
//               exactly as written -- the base profile by name, never a ~style,
//               .material or @tier variant, never a player's choice -- so every
//               machine flies it and scores it the same.
//   roundlook   what it looks and sounds like: sprite, glide, wake, impact, whiz.
//               Resolved on each machine by style, effects tier and the menu's
//               "Round look", because nothing a look does reaches the game.
//
// The menu's Round look changes what FLIES: sprite, glide, wake. Impacts and the
// near-miss sound stay the round's own look, so a rifle still cracks past you.
//
//   glide    FastProjectile clears interpolation every tic, so the sprite would
//            jump a whole tic of travel per frame. Restoring Prev after the move
//            lets the renderer draw it between tics.
//   wake     particles laid along each tic's travel.
//   tracer   every Nth round of a hand (RSB_Registry.NextRoundIndex) flies in a tracer look,
//            which may carry a light that lights what it passes.
//   heat     the air it tears through shimmers behind it (RSB_Heat.AirWake), in
//            one blast slot re-laid each tic, fading once it lands.
//   whiz     a round passing close to the listener's head, fired by someone
//            else, whizzes or cracks.
//   impact   RSB_Impact, by material, style and tier.
//
// THE CONTRACT the fire action relies on (RS_VR_Reload's WM_Gun.LaunchRound and ApplyShotDamage):
//   damageMin, damageMax    set per round by the shooter; 0/0 = the ballistics
//                           profile's damageBase x 1d(damageDice).
//
// NETPLAY. Spawned by the weapon's fire action on every machine. Speed, size and
// damage come only from the ballistics profile, and damage uses a named RNG.
// Every look is resolved locally and changes only what that machine draws and
// plays: the sprite, bINVISIBLE (a drawing flag), interpolation, particles and
// sounds. The whiz is a sound for the local listener.
// ============================================================================

class RSB_Bullet : FastProjectile
{
	Default
	{
		+PRECACHEALWAYS    // loaded with the map, not on its first use: no stutter (engine precache)
		Radius 2;
		Height 2;
		Speed 245;          // map units per tic; Launch sets the live value from the ballistics
		Damage 1;           // replaced outright in DoSpecialDamage
		Projectile;
		+THRUSPECIES
		Species "Player";
		Decal "BulletChip";
	}

	// DECALS: a server rule (RSB_Decals) -- off, this round's lasting mark is the wall damage alone.
	override void BeginPlay()
	{
		Super.BeginPlay();
		RSB_Decals.Apply(self);
		spawnedAt = pos;
	}

	String roundId;
	int    hand;            // 0 main, 1 off -- for the log
	int    shooterNum;      // player number of the shooter, -1 if none
	int    damageMin, damageMax;
	int    roundIndex;      // this hand's round number (1, 2, 3 ...), for tracers; 0 = not counted
	bool   enemy;           // a monster's shot (enemyfire.zs): its looks follow the distance bands

	private Vector3 travel; // last direction of flight; Vel is zeroed before Death
	private bool    announced;
	private Vector3 launchedAt;  // where it first flew from: where its air shimmer can begin
	private bool    launchKnown;
	transient bool  whizzed;   // local presentation: set on one machine only, never saved
	transient int   heatSlot;  // this machine's blast slot for its air shimmer; 0 = none yet
	transient Vector3 spawnedAt;     // where it came into the world (the firing hand)
	transient Vector3 tickFrom;      // where this tic's move began: the last wake starts here when it lands
	transient bool    tickFromKnown;
	transient int     ticksFlown;    // tics it survived: 0 when it lands inside its first move

	// The profiles, re-read after a savegame load.
	transient RSB_RoundDef      roundDef;
	transient RSB_BallisticsDef ballisticsDef;

	// THIS MACHINE'S LOOKS: the round's own, and what flies (the menu's Round look
	// when one is chosen). Local by design; never saved.
	transient bool             looksResolved;
	transient RSB_RoundLookDef lookDef;
	transient RSB_RoundLookDef flightDef;
	transient int              flightSprite;
	transient int              lookBand;     // a monster's round: 0 near, 1 mid (no light or bent air), 2 far (no flight or impact looks)

	States
	{
	Spawn:
		RSBT A -1 Bright;
		Stop;
	Death:
		TNT1 A 0 { Landed(); }
		Stop;
	}

	// CALLED BY THE FIRE ACTION straight after A_FireProjectile. The engine has
	// already spawned the round at the firing hand and aimed it; this names its
	// profile, sets its speed and size from the ballistics, and records who fired.
	static RSB_Bullet Launch(Actor shot, PlayerInfo shooter, int whichHand, String whichRound)
	{
		let b = RSB_Bullet(shot);
		if (!b) return null;     // null when it hit something the moment it spawned
		b.roundId = whichRound;
		b.hand = whichHand;
		b.shooterNum = -1;
		if (shooter && shooter.mo) b.shooterNum = shooter.mo.PlayerNumber();
		let numbering = RSB_Registry.Get();
		b.roundIndex = numbering ? numbering.NextRoundIndex(b.shooterNum, whichHand) : 0;

		let bl = b.Ballistics();
		if (!bl)
		{
			RSB_Log.Once(RSB_Log.LV_ERR, "bullet:noround:" .. whichRound, String.Format(
				"a round was launched as \"%s\", which no RSBDEFS defines with its ballistics -- it flies at its default speed with no effects", whichRound));
			return b;
		}
		double spd = clamp(bl.speed, 1.0, 1000.0);
		if (b.Vel.Length() > 0.000001) b.Vel = b.Vel.Unit() * spd;
		b.Speed = spd;
		if (bl.radius != b.radius) b.A_SetSize(bl.radius, bl.radius);
		return b;
	}

	// A MONSTER'S SHOT AS A ROUND (enemyfire.zs): the shooter fires an RSB_EnemyBullet from where its hitscan would
	// have started, along the hitscan's aim, at `speed` map units a tic, dealing the shot's own rolled damage.
	// Playsim, alike on every machine: the engine's event numbers and a server cvar.
	static RSB_Bullet LaunchFrom(Actor shooter, String whichRound, double spawnHeight, double sideOffset,
		double aimAngle, double aimPitch, int damage, Name damageType, double speed)
	{
		if (!shooter) return null;
		let b = RSB_Bullet(shooter.A_SpawnProjectile("RSB_EnemyBullet", spawnHeight, sideOffset, aimAngle - shooter.angle,
			CMF_AIMDIRECTION, aimPitch));
		if (!b) return null;
		b.roundId = whichRound;
		b.hand = 0;
		b.shooterNum = -1;
		b.enemy = true;
		b.roundIndex = 0;
		b.damageMin = max(1, damage);
		b.damageMax = b.damageMin;
		b.DamageType = damageType;
		double spd = clamp(speed, 1.0, 1000.0);
		if (b.Vel.Length() > 0.000001) b.Vel = b.Vel.Unit() * spd;
		b.Speed = spd;
		let bl = b.Ballistics();
		if (bl && bl.radius != b.radius) b.A_SetSize(bl.radius, bl.radius);
		return b;
	}

	// Not "Round": ZScript names are case-insensitive, and round() is built in.
	RSB_RoundDef RoundProfile()
	{
		if (!roundDef)
		{
			let reg = RSB_Registry.Get();
			if (reg) roundDef = reg.FindRound(roundId);
		}
		return roundDef;
	}

	// THE GAME'S NUMBERS: the base ballistics profile, identical on every machine.
	RSB_BallisticsDef Ballistics()
	{
		if (!ballisticsDef)
		{
			let r = RoundProfile();
			let reg = RSB_Registry.Get();
			if (r && reg) ballisticsDef = reg.FindBallistics(r.ballistics);
		}
		return ballisticsDef;
	}

	// THIS MACHINE'S LOOKS, once per round (again after a savegame load).
	private void ResolveLooks()
	{
		if (looksResolved) return;
		looksResolved = true;
		lookBand = enemy ? RSB_Settings.EnemyBand(pos) : 0;
		flightSprite = -1;
		let r = RoundProfile();
		let reg = RSB_Registry.Get();
		if (!r || !reg) return;

		String tierName = RSB_Tier.Name(RSB_Tier.Current());
		lookDef = reg.ResolveRoundLook(r.roundLook, tierName);
		flightDef = lookDef;
		// A TRACER: every Nth round of a hand (the look's `tracer`) flies in the tracer's look --
		// twice as often at extreme, half as often at plain (RSB_Tier.TracerEvery).
		int tracerEvery = lookDef ? RSB_Tier.TracerEvery(lookDef.tracerEvery, RSB_Tier.Current()) : 0;
		if (lookDef && tracerEvery > 0 && roundIndex > 0 && (roundIndex % tracerEvery) == 0)
		{
			let tracerDef = reg.ResolveRoundLook(lookDef.tracerLook, tierName);
			if (tracerDef) flightDef = tracerDef;
		}
		String pick = RSB_Settings.RoundLook();
		if (pick.Length() > 0)
		{
			let chosen = reg.ResolveRoundLook(pick, tierName);
			if (chosen) flightDef = chosen;
			else RSB_Log.Once(RSB_Log.LV_WARN, "roundlook:missing:" .. pick, String.Format(
				"Round look \"%s\" is not defined in any RSBDEFS -- rounds keep their own look", pick));
		}
		if (!flightDef) return;

		bINVISIBLE = (flightDef.lookKind == "none");
		if (flightDef.lookKind == "sprite" && !(flightDef.lookName ~== "RSBT"))
		{
			flightSprite = GetSpriteIndex(flightDef.lookName);
			if (flightSprite < 0)
				RSB_Log.Once(RSB_Log.LV_WARN, "roundlook:sprite:" .. flightDef.lookName, String.Format(
					"round look %s: sprite %s is not loaded (no actor's states use it) -- drawn as RSBT", flightDef.id, flightDef.lookName));
		}

		// A LIGHT IN FLIGHT (the look's `light`): a burning tracer lights what it passes -- an engine effect
		// light flying with the round (`lightlook` streak, comet or head), or a point light riding it (attached).
		if (flightDef.lightRadius > 0 && flightDef.lightIntensity > 0 && RSB_Tier.Current() > RSB_Tier.T_OFF && lookBand == 0)
		{
			if (flightDef.lightLook != RSB_RoundLookDef.LIGHTLOOK_ATTACHED)
				FlightEffectLight(flightDef);
			else
				A_AttachLight("rsb_flight", DynamicLight.PointLight, flightDef.lightColor, int(flightDef.lightRadius), 0,
					DynamicLight.LF_ATTENUATE, (0, 0, 0), 0, 10, 25, 0, flightDef.lightIntensity);
		}
	}

	// THE TRACER'S EFFECT LIGHT (the look's `lightlook`): spawned once, flying at the round's speed and parked
	// where a straight trace says the round lands (rounds fly straight). Presentation only: the trace reads
	// the level and changes nothing.
	const TRACER_LIGHT_REACH = 8192.0;
	private void FlightEffectLight(RSB_RoundLookDef lk)
	{
		double perSecond = Vel.Length() * TICRATE;
		if (perSecond <= 0) return;
		Vector3 dir = Vel.Unit();
		double dist = TRACER_LIGHT_REACH;
		FLineTraceData d;
		if (LineTrace(VectorAngle(dir.x, dir.y), TRACER_LIGHT_REACH, -asin(clamp(dir.z, -1.0, 1.0)),
			TRF_ABSPOSITION | TRF_THRUSPECIES, pos.z, pos.x, pos.y, d))
			dist = d.Distance;
		double land = dist / perSecond;
		if (lk.lightLook == RSB_RoundLookDef.LIGHTLOOK_STREAK)          // a short fading streak
			level.SpawnEffectLight(pos, lk.lightColor, lk.lightRadius, lk.lightIntensity, land + 0.1, dir * perSecond,
				pos - dir * min(96.0, dist), 0.0, EFL_IMPORTANT, 0.0, 0.0, land, 0.05, 0.0, 0.0);
		else if (lk.lightLook == RSB_RoundLookDef.LIGHTLOOK_COMET)      // a long comet tail
			level.SpawnEffectLight(pos, lk.lightColor, lk.lightRadius, lk.lightIntensity, land + 1.0, dir * perSecond,
				(0, 0, 0), 0.0, EFL_IMPORTANT, 0.0, 0.0, land, 0.3, 0.7, 0.2);
		else                                                              // a glow at the head
			level.SpawnEffectLight(pos, lk.lightColor, lk.lightRadius, lk.lightIntensity, land + 1.0, dir * perSecond,
				(0, 0, 0), 0.0, EFL_IMPORTANT, 0.0, 0.0, land, 0.05);
	}

	override void Tick()
	{
		ResolveLooks();

		// Remember which way it flies BEFORE moving: the move can end in Death,
		// and by then Vel is already zero.
		if (Vel != (0, 0, 0)) travel = Vel.Unit();
		Vector3 before = pos;
		tickFrom = before;
		tickFromKnown = true;
		if (!launchKnown)
		{
			launchKnown = true;
			launchedAt = pos;
		}

		if (!announced)
		{
			announced = true;
			let r = RoundProfile();
			RSB_Log.Once(RSB_Log.LV_INFO, "bullet:spawn", String.Format(
				"first round this map: %s (ballistics %s, look %s), %s hand, %.0f units a tic", roundId,
				(r != null) ? r.ballistics : "?", (flightDef != null) ? flightDef.id : "?",
				(hand == 0) ? "main" : "off", Vel.Length()));
		}

		Super.Tick();
		if (bDestroyed) return;
		if (flightSprite >= 0) sprite = flightSprite;

		if (flightDef && flightDef.glide && RSB_Settings.Glide())
		{
			double moved = (pos - before).Length();
			// Not across a teleport or portal jump.
			if (moved > 0 && moved <= Speed * 1.5 + 1.0) Prev = before;
		}
		LayWake(before);
		LayAirHeat();
		Whiz(before);
		ticksFlown++;
	}

	// DAMAGE: the shooter's damageMin-damageMax when set; otherwise the ballistics
	// profile's base x 1d(dice); without one, the vanilla pistol's 5 x 1d3. This
	// runs after the engine's own missile roll, so the value returned replaces it.
	override int DoSpecialDamage(Actor victim, int damage, Name damagetype)
	{
		int dealt;
		if (damageMin > 0)
		{
			// The shooter's damage as given: a range rolls once; a single value takes no roll (enemy fire hands over
			// the monster's already-rolled shot, so no machine makes a random call the hitscan would not have).
			dealt = (damageMax > damageMin) ? random[RSBBullet](damageMin, damageMax) : damageMin;
		}
		else
		{
			// A `ballistics` WITH NO `damage` LINE is a real and deliberate case, not a mistake: a profile
			// that exists for its LOOK while the gun mod owns the damage (the WW2 set, whose numbers are
			// Brutal Wolfenstein's and live in the weapons sheet). Unset is -1, and -1 * random(1, -1) is
			// nonsense with a reversed range -- so an unset profile falls back to the same default as no
			// profile at all rather than dealing garbage to whoever wires it without reading.
			let bl = Ballistics();
			if (bl && bl.damageBase > 0 && bl.damageDice > 0)
				dealt = bl.damageBase * random[RSBBullet](1, bl.damageDice);
			else dealt = 5 * random[RSBBullet](1, 3);
		}
		return Super.DoSpecialDamage(victim, dealt, damagetype);
	}

	private void Landed()
	{
		ResolveLooks();
		LayAirHeat();   // the air it tore through shimmers, whatever it hit
		// THE LAST STRETCH (owner: trails missing at a close wall). A round that lands dies inside its tic's move, so Tick
		// never lays the wake of the tic it hit in -- and one that hits within its FIRST tic (a wall closer than one tic's
		// travel, about 7 m) was never drawn in flight at all. Lay that last wake here, and draw a first-tic hit's flight.
		Vector3 lastFrom = tickFromKnown ? tickFrom : spawnedAt;
		LayWake(lastFrom);
		if (ticksFlown == 0) FlightStreak(lastFrom);
		if (BlockingMobj != null) return;   // an actor bleeds; its own mod decides how
		if (lookBand >= 2) return;           // a far fight: no impact looks
		if (lookDef) RSB_Impact.Land(self, lookDef.impact, travel);
	}

	private void LayWake(Vector3 before)
	{
		if (lookBand >= 2) return;
		if (flightDef) RSB_Wake.Lay(flightDef.wake, before, pos, travel);
		// CARVING THE ROOM'S SMOKE (engine 13b, the look's `carve`): a tunnel along this tic's flight.
		if (flightDef && flightDef.carveAmount > 0 && flightDef.carveRadius > 0)
			level.CarveSmoke(before, pos, flightDef.carveRadius, flightDef.carveAmount);
		if (flightDef) RSB_ProjectileLook.FlightSmoke(flightDef, before, pos);
	}

	// A FIRST-TIC HIT'S FLIGHT, DRAWN: one bright streak racing from where the round left to where it struck in a couple of
	// frames -- what its own sprite would have shown had it lived to be drawn. Not for an invisible look, a far enemy band
	// or effects off. Looks only: a hashed seed, nothing read back.
	private void FlightStreak(Vector3 from)
	{
		if (!flightDef || flightDef.lookKind == "none" || lookBand >= 1 || RSB_Tier.Current() <= RSB_Tier.T_OFF) return;
		Vector3 path = pos - from;
		double len = path.Length();
		if (len < 8.0) return;
		Vector3 dir = path / len;
		double streakLife = 0.05;   // seconds from the muzzle to the wall: about four headset frames
		level.SpawnGpuParticles(from, dir, 1, 0.0, len / streakLife, 0.0, Color(255, 255, 214, 150), 2.0, streakLife, 0.0,
			1.2, 0.8, 0.0, 0.0, 1, 0.02, RSB_Hash.Seed(level.maptime, roundIndex + 7, RSB_Hash.OfPos(pos)));
	}

	// THE AIR IT TEARS THROUGH (its flight look's `heat`): bent air over the last heatReach
	// units behind it, in one blast slot of its own, laid again each tic and fading once
	// it stops. Looks only: a slot, nothing read back.
	private void LayAirHeat()
	{
		if (!flightDef || flightDef.heatStrength <= 0 || flightDef.heatRadius <= 0 || !launchKnown) return;
		if (lookBand >= 1) return;
		if (RSB_Tier.Current() <= RSB_Tier.T_OFF) return;
		if (RSB_Settings.ViewBand(pos) != RSB_Settings.VIEW_FULL) return;   // M1, M2: bent air no one here can see (looks only)
		Vector3 path = pos - launchedAt;
		double len = path.Length();
		if (len < 1.0) return;
		Vector3 dir = path / len;
		if (heatSlot == 0) heatSlot = RSB_Heat.ClaimBlast();
		RSB_Heat.AirWake(heatSlot, pos - dir * min(len, flightDef.heatReach), pos,
			flightDef.heatRadius, flightDef.heatStrength, flightDef.heatTics);
	}

	// THE CLOSEST THIS TIC'S TRAVEL CAME TO THE LISTENER'S HEAD. Once per round,
	// never for the listener's own shots. The round's OWN look decides the sound.
	private void Whiz(Vector3 before)
	{
		if (whizzed) return;
		if (!lookDef || lookDef.whizRadius <= 0 || lookDef.whizSound ~== "none") return;
		if (shooterNum == consoleplayer) return;
		if (!RSB_Settings.Whiz()) return;
		double range = lookDef.whizRadius * RSB_Settings.WhizRange();
		double vol = RSB_Settings.WhizVolume();
		if (range <= 0 || vol <= 0) return;
		let cam = players[consoleplayer].camera;
		if (!cam) return;

		Vector3 ear = cam.pos;
		if (cam.player) ear.z = cam.player.viewz;
		Vector3 seg = pos - before;
		double len2 = seg dot seg;
		double t = 0;
		if (len2 > 0) t = clamp(((ear - before) dot seg) / len2, 0.0, 1.0);
		Vector3 closest = before + seg * t;
		if ((ear - closest).Length() > range) return;

		whizzed = true;
		A_StartSound(lookDef.whizSound, CHAN_AUTO, CHANF_OVERLAP, vol);
	}
}

// A MONSTER'S ROUND (enemyfire.zs): an RSB_Bullet that does not pass through players -- RSB_Bullet's
// +THRUSPECIES with Species "Player" is how a player's rounds spare other players, and a monster's must not.
class RSB_EnemyBullet : RSB_Bullet
{
	Default
	{
		-THRUSPECIES
		Species "RSB_EnemyBullet";
		+ABSDAMAGE          // no engine dice on the missile's damage: DoSpecialDamage gives the monster's rolled shot
	}
}
