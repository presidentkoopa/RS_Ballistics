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
// NETPLAY. Thrown for the console player's gun only, so nothing here may draw
// from the playsim RNG: the speed variation and the tumble are hashes.
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
		if (!RSB_Settings.Casings()) return null;
		let reg = RSB_Registry.Get();
		if (!reg) return null;
		let ed = reg.ResolveEjecta(whichEjecta, RSB_Tier.Name(RSB_Tier.Current()));
		if (!ed)
		{
			RSB_Log.Once(RSB_Log.LV_ERR, "ejecta:missing:" .. whichEjecta, String.Format(
				"ejecta \"%s\" is not defined in any RSBDEFS", whichEjecta));
			return null;
		}
		let c = RSB_Ejecta(Actor.Spawn("RSB_Ejecta", at, ALLOW_REPLACE));
		if (!c) return null;

		c.ejectaId = whichEjecta;
		c.A_SetScale(ed.scale * RSB_Settings.CasingSize());
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
			if (restTics > int(lifeTics * RSB_Settings.CasingLife()))
			{
				A_SetRenderStyle(Alpha, STYLE_Translucent);
				Alpha -= 0.05;
				if (Alpha <= 0)
				{
					Destroy();
					return;
				}
			}
		}
		Super.Tick();
	}
}
