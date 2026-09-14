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
		return landed;
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
		if (!looked) { looked = true; lookDef = RSB_ProjectileLook.Look("rocket"); }
		landed = RSB_ProjectileLook.AfterMove(self, lookDef, before, travel, landed);
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
