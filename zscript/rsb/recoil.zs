// ============================================================================
// GAMEPLAY RECOIL. A VR hand cannot be pushed, so a gun's kick turns where its
// ROUNDS go: each shot adds a climb and a sideways drift, the next rounds leave
// the gun turned by the kick so far, and it recovers once the trigger rests. The
// first shot of a run is dead on. Profiles: RSBDEFS `recoil`, by base name only.
// The plan: _staged/RECOIL_PLAN.md (approved by the build lane).
//
// THE CALLER, the gun (WM_Gun, its sheet's `recoilprofile`), once a shot before its
// rounds leave, with four values it keeps on itself between shots (and saves):
//   [yaw, pitch, bloom] = RSB_Recoil.Step(profile, owner, kickPitch, kickYaw, lastTic, runShot);
// then RSB_Recoil.Turn(round, yaw, pitch) on each round before its scatter, and bloom
// added to the spread.
// FOR THE ARM AND THE PROP (render only): View() -- the kick as it stands this tic, so
// the drawn gun points where the next round goes -- and ViewJolt(), the per-shot jolt.
//
// NETPLAY: GAMEPLAY. Decided in the weapon's own action on every machine, from the map
// clock, the shot count, crouching and the owner's speed: no RNG, never the console
// player. `sv_rsb_recoil` is a server cvar, one rule for the whole game. Profiles have no
// ~style, .material or @tier variants (the parser refuses them): those follow local settings.
// SLOW MOTION: recovery runs on the map clock.
// ============================================================================

class RSB_Recoil play
{
	// Gameplay recoil for this game: the server's rule.
	clearscope static bool Enabled()
	{
		let c = CVar.FindCVar("sv_rsb_recoil");
		return c ? c.GetBool() : true;
	}

	// A recoil profile by its base name; null for none, "" or one no RSBDEFS defines.
	clearscope static RSB_RecoilDef Profile(String name)
	{
		if (name.Length() == 0 || name ~== "none") return null;
		let reg = RSB_Registry.Get();
		if (!reg || !reg.defs) return null;
		return RSB_RecoilDef(reg.defs.Find("recoil", name));
	}

	// ONE SHOT. Returns the turn this shot's rounds take (yaw, pitch, in degrees) and the
	// extra spread, then moves the gun's kick on for its next shot. Off, or no profile:
	// dead on, and the kick is forgotten.
	static double, double, double Step(String profile, Actor shooter, out double kickPitch, out double kickYaw, out int lastTic, out int runShot)
	{
		int now = level.maptime;
		let rd = Enabled() ? Profile(profile) : null;
		if (!rd)
		{
			kickPitch = 0;
			kickYaw = 0;
			runShot = 0;
			lastTic = now;
			return 0, 0, 0;
		}
		Recover(rd, now, kickPitch, kickYaw, lastTic, runShot);
		double shotYaw = kickYaw;
		double shotPitch = kickPitch;

		// THE KICK THIS SHOT ADDS, steadied by bracing: a climb, and a fixed left-right walk
		// by shot number (the same every time, so it can be learned).
		double brace = Brace(rd, shooter);
		kickPitch = min(rd.maxPitch, kickPitch + rd.climb * brace);
		if (rd.drift > 0 && rd.driftPeriod > 0)
			kickYaw = clamp(kickYaw + rd.drift * sin(360.0 * runShot / rd.driftPeriod) * brace, -rd.maxYaw, rd.maxYaw);
		runShot++;
		lastTic = now;
		return shotYaw, shotPitch, rd.bloom * shotPitch;
	}

	// RECOVERY since the last shot, once past the delay: both axes back toward dead on
	// together. Fully recovered, the next shot starts a new run.
	clearscope static void Recover(RSB_RecoilDef rd, int now, out double kickPitch, out double kickYaw, int lastTic, out int runShot)
	{
		bool longAgo = (lastTic <= 0 || now < lastTic);
		int dt = longAgo ? 0 : now - lastTic;
		if (!longAgo && dt <= rd.recoverDelay) return;
		double mag = sqrt(kickPitch * kickPitch + kickYaw * kickYaw);
		double back = longAgo ? mag : rd.recoverRate * double(dt - rd.recoverDelay) / double(TICRATE);
		if (mag <= back)
		{
			kickPitch = 0;
			kickYaw = 0;
			runShot = 0;
			return;
		}
		double keep = (mag - back) / mag;
		kickPitch *= keep;
		kickYaw *= keep;
	}

	// BRACING, from what every machine knows: crouched, and standing still. Hand input is
	// not networked yet, so a two-handed grip does not count (yet).
	static double Brace(RSB_RecoilDef rd, Actor shooter)
	{
		if (!rd || !shooter) return 1.0;
		double b = 1.0;
		if (shooter.player && shooter.player.crouchfactor < 0.75) b *= rd.braceCrouch;
		if (shooter.Vel.XY.Length() < 2.0) b *= rd.braceStill;
		return b;
	}

	// ONE ROUND TURNED by the kick: its velocity rotated sideways by yaw and up by pitch
	// (degrees), its speed kept -- the way the gun's own scatter turns it.
	static void Turn(Actor shot, double yawDeg, double pitchDeg)
	{
		if (!shot || (yawDeg == 0 && pitchDeg == 0)) return;
		double spd = shot.Vel.Length();
		if (spd < 0.000001) return;
		Vector3 dir = shot.Vel / spd;
		double yaw  = VectorAngle(dir.X, dir.Y) + yawDeg;
		double elev = clamp(atan2(dir.Z, dir.XY.Length()) + pitchDeg, -89.0, 89.0);
		double ce = cos(elev);
		shot.Vel = (ce * cos(yaw), ce * sin(yaw), sin(elev)) * spd;
		shot.angle = yaw;
		shot.pitch = -elev;
	}

	// FOR THE ARM AND THE PROP (render only): the gun's kick recovered to this tic, (pitch,
	// yaw) in degrees. While gameplay recoil is on the drawn gun carries this whatever the
	// visual slider says, so it never points somewhere the rounds do not go. 0 when off.
	clearscope static double, double View(String profile, double kickPitch, double kickYaw, int lastTic)
	{
		let rd = Enabled() ? Profile(profile) : null;
		if (!rd) return 0, 0;
		int runShot = 0;
		Recover(rd, level.maptime, kickPitch, kickYaw, lastTic, runShot);
		return kickPitch, kickYaw;
	}

	// THE PER-SHOT JOLT the arm and the prop show (render only): back (map units), rise and
	// roll (degrees), and the tics it takes -- times the player's "Recoil kick (visual)". The
	// server's switch is ALL recoil (the owner): off, no jolt either.
	clearscope static double, double, double, int ViewJolt(String profile)
	{
		let rd = Enabled() ? Profile(profile) : null;
		if (!rd) return 0, 0, 0, 0;
		double k = ViewScale();
		return rd.viewBack * k, rd.viewRise * k, rd.viewRoll * k, rd.viewTics;
	}

	// The player's "Recoil kick (visual)", 0-2. Looks only.
	clearscope static double ViewScale()
	{
		let c = CVar.GetCVar("rsb_recoil_view", players[consoleplayer]);
		return c ? clamp(c.GetFloat(), 0.0, 2.0) : 1.0;
	}
}
