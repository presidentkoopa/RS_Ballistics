// ============================================================================
// EJECTA: SPENT CASINGS AND HULLS, from an `ejecta` profile.
//
// The reload system's WM_Casing, moved here and driven by data. A projectile,
// because the engine's own bounce is exactly right for a casing: it rattles off
// the floor, skips off a wall and settles. THRUACTORS so it never hits anything,
// and no impact activation so a casing can never press a switch.
//
// WHAT STAYS IN THE RELOAD SYSTEM: the eject port, the direction, when a case
// comes out, and live rounds (which can be caught and loaded). It calls
// RSB_Ejecta.Throw with a profile name, position, direction, the carrier's
// velocity and its throw speed. Throw returns null when the player has casings
// switched off.
//
// NETPLAY -- A CASING IS A REAL MISSILE, SO IT MUST EXIST IDENTICALLY EVERYWHERE.
// It bounces through the world and takes up playsim movement, so whether one
// spawns, how it moves and when it is removed must not depend on anything local.
// Throw therefore:
//   - always spawns, whatever the player's casings switch, tier or style says;
//   - takes its physics (speed, bounce, gravity) and its lifetime from the BASE
//     profile only -- never a ~style or @tier variant, which are local choices;
//   - uses hashes for the speed variation and the tumble, never the playsim RNG.
// The player's settings change only how it LOOKS: invisible when casings are
// off, drawn size, hot glow, and how soon it fades from view (never later than
// the profile's lifetime, which is when every machine removes it).
// The caller must call Throw on every machine for the same shot.
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

	static RSB_Ejecta Throw(String whichEjecta, Vector3 at, Vector3 aim, Vector3 carrierVel, double throwSpeed, int seed)
	{
		let reg = RSB_Registry.Get();
		if (!reg) return null;
		let ed = reg.FindEjecta(whichEjecta);   // the base profile: see NETPLAY above
		if (!ed)
		{
			RSB_Log.Once(RSB_Log.LV_ERR, "ejecta:missing:" .. whichEjecta, String.Format(
				"ejecta \"%s\" is not defined in any RSBDEFS", whichEjecta));
			return null;
		}
		let c = RSB_Ejecta(Actor.Spawn("RSB_Ejecta", at, ALLOW_REPLACE));
		if (!c) return null;

		c.ejectaId = whichEjecta;
		c.bINVISIBLE = !RSB_Settings.Casings();                 // look only
		c.A_SetScale(ed.scale * RSB_Settings.CasingSize());     // look only: scale is not size
		c.bouncefactor = ed.bounceFloor;
		c.wallbouncefactor = ed.bounceWall;
		c.bouncecount = ed.bounceCount;
		c.Gravity = ed.gravity;
		if (!(ed.soundName ~== "none")) c.BounceSound = ed.soundName;
		c.hotTics = RSB_Settings.CasingHot() ? ed.hotTics : 0;
		c.lifeTics = ed.lifeTics;
		c.bBRIGHT = c.hotTics > 0;

		Vector3 d = (aim.Length() > 0.000001) ? aim.Unit() : (0, 0, 1);
		double mul = RSB_Hash.Between(ed.speedMul - ed.speedJitter, ed.speedMul + ed.speedJitter,
			seed, level.maptime, RSB_Hash.OfPos(at));
		c.Vel = d * (throwSpeed * max(0.0, mul)) + carrierVel;
		c.angle = VectorAngle(d.x, d.y);
		return c;
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
	}
}
