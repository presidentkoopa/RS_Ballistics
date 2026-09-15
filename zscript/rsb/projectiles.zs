// ============================================================================
// THE REST OF THE ARSENAL WEARS RS_BALLISTICS LOOKS.
//
// RSB_PlasmaBall, RSB_Rocket, RSB_BFGBall ARE the engine's PlasmaBall, Rocket and
// BFGBall -- speed, damage, radius, flags, sprites, explosion and every state
// inherited untouched, so `is PlasmaBall` still holds -- plus a look from a
// `roundlook` profile: a GPU trail along the flight (its `wake`) and an
// RS_Ballistics impact where it dies (its `impact`), shown on a wall, a floor, or
// a monster in mid-air. A gun fires one by naming it in WM_Gun.ShotClass.
//
// RSB_RailPuff and RSB_SawPuff ARE BulletPuffs -- ordinary playsim actors spawned
// by A_RailAttack and A_Saw where they hit a wall -- whose vanilla sprite is
// hidden and whose spawn plays an RS_Ballistics impact there.
//
// NETPLAY. The same gameplay actors on every machine; what is added only draws
// and plays. The death a projectile reacts to is the playsim's own state change,
// identical everywhere. No playsim RNG anywhere in this file (particle seeds are
// hashes), no consoleplayer, and nothing reads a look back. A player's effects
// level and style change only what their own machine shows.
// ============================================================================

// A PROJECTILE THAT WEARS A LOOK: the three steps any projectile class can call.
class RSB_ProjectileLook play
{
	// Which way it flies, read BEFORE its move (Vel is zero once it has died).
	static Vector3 Heading(Actor mo, Vector3 last)
	{
		return (mo.Vel != (0, 0, 0)) ? mo.Vel.Unit() : last;
	}

	// The look, resolved on this machine (style, effects level).
	static RSB_RoundLookDef Look(String lookId)
	{
		let reg = RSB_Registry.Get();
		if (!reg) return null;
		let lk = reg.ResolveRoundLook(lookId, RSB_Tier.Name(RSB_Tier.Current()));
		if (!lk)
			RSB_Log.Once(RSB_Log.LV_ERR, "projlook:missing:" .. lookId, String.Format(
				"projectile look \"%s\" is not defined in any RSBDEFS -- it flies with no RS_Ballistics look", lookId));
		return lk;
	}

	// AFTER its move: this tic's trail, or -- the first tic it is dying -- its
	// impact, in mid-air too. Returns whether it has landed.
	static bool AfterMove(Actor mo, RSB_RoundLookDef lk, Vector3 before, Vector3 travel, bool landed)
	{
		if (!mo || !lk) return landed;
		if (Actor.InStateSequence(mo.CurState, mo.FindState("Death")))
		{
			if (!landed) RSB_Impact.Land(mo, lk.impact, travel, true);
			return true;
		}
		RSB_Wake.Lay(lk.wake, before, mo.pos, travel);
		if (lk.carveAmount > 0 && lk.carveRadius > 0)
			level.CarveSmoke(before, mo.pos, lk.carveRadius, lk.carveAmount);
		FlightSmoke(lk, before, mo.pos);
		Motor(mo, lk, travel);
		return landed;
	}

	// SMOKE INTO THE ROOM along its flight (a look's `smoke`, engine 13b/13e): a capsule over the
	// step BEHIND this one -- last tic's carve has passed there, so the trail hangs where the
	// tunnel was, not inside the one torn this tic. By the effects level, like every room smoke.
	static void FlightSmoke(RSB_RoundLookDef lk, Vector3 before, Vector3 now)
	{
		if (!lk || lk.smokeAmount <= 0 || lk.smokeRadius <= 0) return;
		int tier = RSB_Tier.Current();
		if (tier <= RSB_Tier.T_OFF) return;
		Vector3 step = now - before;
		if (step == (0, 0, 0)) return;
		level.EmitSmoke(before - step, lk.smokeRadius, lk.smokeAmount * RSB_Tier.SmokeScale(tier), lk.smokeHeat, (0, 0, 0), before, lk.smokeSoot);
	}

	// THE MOTOR (a look's `motor`): a burst out of its tail each tic it flies.
	static void Motor(Actor mo, RSB_RoundLookDef lk, Vector3 travel)
	{
		if (!mo || !lk || (lk.motorBurst.Length() == 0 && lk.motorMaybe.Size() == 0) || travel == (0, 0, 0)) return;
		int tier = RSB_Tier.Current();
		if (tier <= RSB_Tier.T_OFF) return;
		let reg = RSB_Registry.Get();
		if (!reg) return;
		int posSeed = RSB_Hash.OfPos(mo.pos);
		if (lk.motorBurst.Length() > 0)
			RSB_Burst.Fire(reg.FindBurst(lk.motorBurst), mo.pos, travel, travel, RSB_Tier.CountScale(tier), 1.0,
				RSB_Hash.Seed(level.maptime, 211, posSeed));
		// Some tics more (`motormaybe`): arcs crackling round a ball, say.
		for (int i = 0; i < lk.motorMaybe.Size(); i++)
		{
			if (RSB_Hash.Frac(level.maptime, 223 + i * 2, posSeed) >= lk.motorMaybeChance[i]) continue;
			RSB_Burst.Fire(reg.FindBurst(lk.motorMaybe[i]), mo.pos, travel, travel, RSB_Tier.CountScale(tier), 1.0,
				RSB_Hash.Seed(level.maptime, 227 + i, posSeed));
		}
	}

	// A LOOK TAKING OVER MID-FLIGHT (its `onset`): that flash where the projectile is -- an
	// RPG's sustainer lighting. An onset flash should have no cone (it has no beam slot).
	const ONSET_BEAM_SLOT = 7;
	static void Onset(Actor mo, RSB_RoundLookDef lk, Vector3 travel)
	{
		if (!mo || !lk || lk.onsetFlash.Length() == 0) return;
		RSB_Flash.Fire(lk.onsetFlash, mo.pos, (travel != (0, 0, 0)) ? travel : (1, 0, 0), ONSET_BEAM_SLOT, mo.Vel);
	}

	// THE AIR IT TEARS THROUGH (a look's `heat`), as a round's (RSB_Bullet.LayAirHeat): bent air
	// over the last heatReach units behind it, in one blast slot of its own. Returns the slot.
	static int AirHeat(Actor mo, RSB_RoundLookDef lk, Vector3 launchedAt, int slot)
	{
		if (!mo || !lk || lk.heatStrength <= 0 || lk.heatRadius <= 0) return slot;
		if (RSB_Tier.Current() <= RSB_Tier.T_OFF) return slot;
		Vector3 path = mo.pos - launchedAt;
		double len = path.Length();
		if (len < 1.0) return slot;
		Vector3 dir = path / len;
		if (slot == 0) slot = RSB_Heat.ClaimBlast();
		RSB_Heat.AirWake(slot, mo.pos - dir * min(len, lk.heatReach), mo.pos, lk.heatRadius, lk.heatStrength, lk.heatTics);
		return slot;
	}
}

class RSB_PlasmaBall : PlasmaBall
{
	// NO LAUNCH SOUND of its own: the gun's card plays the fire sound (the owner's
	// Sound Selection pick), and Doom's SeeSound (weapons/plasmaf) on spawn doubled it.
	Default
	{
		+PRECACHEALWAYS    // loaded with the map, not on its first use: no stutter (engine precache)
		SeeSound "";
	}

	// DECALS: a server rule (RSB_Decals) -- off, this round's lasting mark is the wall damage alone.
	override void BeginPlay()
	{
		Super.BeginPlay();
		RSB_Decals.Apply(self);
	}

	private Vector3 travel;
	private bool    landed;      // follows the playsim's own death: the same everywhere
	transient bool             looked;
	transient RSB_RoundLookDef lookDef;

	// WHICH ROUND LOOK ITS FLIGHT AND HIT WEAR: a subclass names its own (a gun's own bolt).
	virtual String FlightLook()
	{
		return "plasma_ball";
	}

	override void Tick()
	{
		Vector3 before = pos;
		travel = RSB_ProjectileLook.Heading(self, travel);
		Super.Tick();
		if (bDestroyed) return;
		if (!looked) { looked = true; lookDef = RSB_ProjectileLook.Look(FlightLook()); }
		landed = RSB_ProjectileLook.AfterMove(self, lookDef, before, travel, landed);
	}
}

// THE PLASMA CARBINE'S BOLT: the same plasma ball to the game; to the eye a tighter, hotter
// streak with a smaller core, and sharper hits.
class RSB_PlasmaBallCarbine : RSB_PlasmaBall
{
	override String FlightLook()
	{
		return "plasma_carbine";
	}
}

class RSB_Rocket : Rocket
{
	// NO LAUNCH SOUND of its own: the gun's card plays the fire sound (the owner's
	// Sound Selection pick), and Doom's SeeSound (weapons/rocklf) on spawn doubled it.
	Default
	{
		+PRECACHEALWAYS    // loaded with the map, not on its first use: no stutter (engine precache)
		SeeSound "";
	}

	// DECALS: a server rule (RSB_Decals) -- off, this round's lasting mark is the wall damage alone.
	override void BeginPlay()
	{
		Super.BeginPlay();
		RSB_Decals.Apply(self);
	}

	const SPIN = 14;   // degrees a tic about its length: the model (MODELDEF, USEACTORROLL) spins as it flies

	private Vector3 travel;
	private bool    landed;
	private int     flightAge;     // tics since launch: which look it flies in (FlightLook)
	private Vector3 launchedAt;    // where its air shimmer can begin
	private bool    launchKnown;
	transient bool             looked;
	transient String           lookName;
	transient RSB_RoundLookDef lookDef;
	transient int              heatSlot;

	// WHICH ROUND LOOK IT FLIES IN at this age. One look for the whole flight here; an RPG's
	// rocket (RSB_RocketRPG) boosts first, then its sustainer lights (the look's `onset`).
	virtual String FlightLook(int age)
	{
		return "rocket";
	}

	override void Tick()
	{
		Vector3 before = pos;
		travel = RSB_ProjectileLook.Heading(self, travel);
		if (!launchKnown)
		{
			launchKnown = true;
			launchedAt = pos;
		}
		Super.Tick();
		if (bDestroyed) return;
		flightAge++;
		String want = FlightLook(flightAge);
		if (!looked || !(want ~== lookName))
		{
			bool midFlight = looked;
			looked = true;
			lookName = want;
			lookDef = RSB_ProjectileLook.Look(want);
			if (midFlight && !landed) RSB_ProjectileLook.Onset(self, lookDef, travel);
		}
		// THE MODEL flies nose first and spins (MODELDEF models/rocket). Looks only.
		if (Vel != (0, 0, 0)) pitch = -VectorAngle(Vel.xy.Length(), Vel.z);
		roll += SPIN;
		landed = RSB_ProjectileLook.AfterMove(self, lookDef, before, travel, landed);
		if (!landed) heatSlot = RSB_ProjectileLook.AirHeat(self, lookDef, launchedAt, heatSlot);
	}
}

// AN RPG'S ROCKET: the same rocket to the game; to the eye it leaves on its booster -- a thin
// smoke thread -- and its sustainer lights a few metres out with a flash and a hard flame.
class RSB_RocketRPG : RSB_Rocket
{
	const BOOST_TICS = 10;   // about 6 m at the rocket's speed

	override String FlightLook(int age)
	{
		return (age < BOOST_TICS) ? "rocket_rpg_boost" : "rocket_rpg";
	}
}

// Doom's BFGBall has no SeeSound (the BFG9000's A_BFGSound is the weapon's), so the gun's
// card fire sound is already the only one: nothing to silence here.
class RSB_BFGBall : BFGBall
{
	// Loaded with the map, not on its first use: no stutter (engine precache).
	Default
	{
		+PRECACHEALWAYS
	}

	// DECALS: a server rule (RSB_Decals) -- off, this round's lasting mark is the wall damage alone.
	override void BeginPlay()
	{
		Super.BeginPlay();
		RSB_Decals.Apply(self);
	}

	private Vector3 travel;
	private bool    landed;
	private Vector3 launchedAt;    // where its air shimmer can begin
	private bool    launchKnown;
	transient bool             looked;
	transient RSB_RoundLookDef lookDef;
	transient int              heatSlot;

	// WHICH ROUND LOOK IT WEARS, and WHICH ACTOR ITS SPRAY LEAVES on what the rays strike: a
	// subclass names its own (the Heavy BFG's).
	virtual String FlightLook()
	{
		return "bfg_ball";
	}

	virtual class<Actor> SprayClass()
	{
		return "RSB_BFGExtra";
	}

	// THE BFGBALL'S OWN DEATH, frame for frame, its spray leaving RSB_BFGExtra (a BFGExtra to
	// the game: the same damage type and flags, so the rays hurt exactly as Doom's).
	States
	{
	Death:
		BFE1 AB 8 Bright;
		BFE1 C 8 Bright { A_BFGSpray(SprayClass()); }
		BFE1 DEF 8 Bright;
		Stop;
	}

	override void Tick()
	{
		Vector3 before = pos;
		travel = RSB_ProjectileLook.Heading(self, travel);
		if (!launchKnown)
		{
			launchKnown = true;
			launchedAt = pos;
		}
		Super.Tick();
		if (bDestroyed) return;
		if (!looked) { looked = true; lookDef = RSB_ProjectileLook.Look(FlightLook()); }
		landed = RSB_ProjectileLook.AfterMove(self, lookDef, before, travel, landed);
		if (!landed) heatSlot = RSB_ProjectileLook.AirHeat(self, lookDef, launchedAt, heatSlot);
	}
}

// THE HEAVY BFG'S BALL: the same BFGBall to the game; to the eye a bigger, brighter core,
// more arcs, a heavier trail, blast and rays.
class RSB_BFGBallHeavy : RSB_BFGBall
{
	override String FlightLook()
	{
		return "bfg_heavy";
	}

	override class<Actor> SprayClass()
	{
		return "RSB_BFGExtraHeavy";
	}
}

// WHAT A BFG RAY LEAVES on what it strikes: Doom's BFGExtra (its flash sprite, damage type and
// flags, so the ray's damage is Doom's), plus a green ray drawn from the shooter to it and a
// flare where it strikes. +PUFFGETSOWNER only hands it the shooter (A_BFGSpray sets its
// target), which nothing in the game reads.
class RSB_BFGExtra : BFGExtra
{
	Default
	{
		+PRECACHEALWAYS    // loaded with the map, not on its first use: no stutter (engine precache)
		+PUFFGETSOWNER
	}

	private bool rayed;

	virtual String RayTrail()
	{
		return "bfg_ray";
	}

	virtual String StrikeImpact()
	{
		return "bfg_spray";
	}

	override void Tick()
	{
		// Its first tic, when A_BFGSpray has handed it the shooter.
		if (!rayed)
		{
			rayed = true;
			RSB_Impact.LandOn(self, RSB_Materials.InAir(pos, (0, 0, -1)), StrikeImpact(), (0, 0, -1));
			if (target) RSB_Trail.Lay(RayTrail(), target, target.pos + (0, 0, target.Height * 0.6), pos);
		}
		Super.Tick();
	}
}

class RSB_BFGExtraHeavy : RSB_BFGExtra
{
	override String RayTrail()
	{
		return "bfg_ray_heavy";
	}

	override String StrikeImpact()
	{
		return "bfg_spray_heavy";
	}
}

// A HITSCAN HIT THAT WEARS AN IMPACT. PUFFGETSOWNER gives it its shooter, for the
// direction the hit came from; the vanilla puff sprite is not drawn.
class RSB_HitPuff : BulletPuff
{
	Default
	{
		+PUFFGETSOWNER
		RenderStyle "None";
	}

	// The `impact` profile this puff plays. Subclasses name theirs.
	virtual String ImpactProfile() { return "bullet"; }

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		Vector3 travel = (0, 0, -1);
		if (target)
		{
			double fromZ = target.player ? target.player.viewz : target.pos.z + target.height * 0.5;
			Vector3 d = pos - (target.pos.xy, fromZ);
			if (d.Length() > 0.001) travel = d.Unit();
		}
		RSB_Impact.Land(self, ImpactProfile(), travel);
	}
}

class RSB_RailPuff : RSB_HitPuff
{
	override String ImpactProfile() { return "rail"; }
}

class RSB_SawPuff : RSB_HitPuff
{
	override String ImpactProfile() { return "saw"; }
}

// A HEAVY CHAINSAW'S CUT: the same puff to the game; to the eye a heavier cut (impact saw_heavy).
// A gun names it as its saw's puff (the reload system's WM_Gun saw puff).
class RSB_SawPuffHeavy : RSB_HitPuff
{
	override String ImpactProfile() { return "saw_heavy"; }
}

// A LASER BURNING A SURFACE: pass it as a laser attack's puff (A_RailAttack or
// LineAttack). Plays the `laser_burn` impact where the beam hit. First user: the
// Unmaker (WM_Unmaker).
class RSB_LaserPuff : RSB_HitPuff
{
	override String ImpactProfile() { return "laser_burn"; }
}
