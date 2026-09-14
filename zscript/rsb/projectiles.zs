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
		Motor(mo, lk, travel);
		return landed;
	}

	// THE MOTOR (a look's `motor`): a burst out of its tail each tic it flies.
	static void Motor(Actor mo, RSB_RoundLookDef lk, Vector3 travel)
	{
		if (!mo || !lk || lk.motorBurst.Length() == 0 || travel == (0, 0, 0)) return;
		int tier = RSB_Tier.Current();
		if (tier <= RSB_Tier.T_OFF) return;
		let reg = RSB_Registry.Get();
		if (!reg) return;
		RSB_Burst.Fire(reg.FindBurst(lk.motorBurst), mo.pos, travel, travel, RSB_Tier.CountScale(tier), 1.0,
			RSB_Hash.Seed(level.maptime, 211, RSB_Hash.OfPos(mo.pos)));
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
		SeeSound "";
	}

	private Vector3 travel;
	private bool    landed;      // follows the playsim's own death: the same everywhere
	transient bool             looked;
	transient RSB_RoundLookDef lookDef;

	override void Tick()
	{
		Vector3 before = pos;
		travel = RSB_ProjectileLook.Heading(self, travel);
		Super.Tick();
		if (bDestroyed) return;
		if (!looked) { looked = true; lookDef = RSB_ProjectileLook.Look("plasma_ball"); }
		landed = RSB_ProjectileLook.AfterMove(self, lookDef, before, travel, landed);
	}
}

class RSB_Rocket : Rocket
{
	// NO LAUNCH SOUND of its own: the gun's card plays the fire sound (the owner's
	// Sound Selection pick), and Doom's SeeSound (weapons/rocklf) on spawn doubled it.
	Default
	{
		SeeSound "";
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
	private Vector3 travel;
	private bool    landed;
	transient bool             looked;
	transient RSB_RoundLookDef lookDef;

	override void Tick()
	{
		Vector3 before = pos;
		travel = RSB_ProjectileLook.Heading(self, travel);
		Super.Tick();
		if (bDestroyed) return;
		if (!looked) { looked = true; lookDef = RSB_ProjectileLook.Look("bfg_ball"); }
		landed = RSB_ProjectileLook.AfterMove(self, lookDef, before, travel, landed);
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

// A LASER BURNING A SURFACE: pass it as a laser attack's puff (A_RailAttack or
// LineAttack). Plays the `laser_burn` impact where the beam hit. First user: the
// Unmaker (WM_Unmaker).
class RSB_LaserPuff : RSB_HitPuff
{
	override String ImpactProfile() { return "laser_burn"; }
}
