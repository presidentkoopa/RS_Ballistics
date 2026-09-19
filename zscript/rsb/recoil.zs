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
		// A GUN THAT NAMES NO RECOIL PROFILE HAS NO KICK AT ALL, and seventeen across the Vanilla and
		// Vanilla+ sets are in exactly that state. `recoil default` is the house recipe for them.
		//
		// BEHIND A SERVER CVAR, NOW ON. It shipped off for one pass while the owner was playing those
		// guns; he sent the decision back to this lane and it is open. Server-scope so every machine
		// agrees: this decides where bullets go, and a per-player answer to that is a desync.
		//
		// `none` still means none. A profile that deliberately says so is not an omission and does not
		// get the house recipe.
		if (name ~== "none") return null;
		let reg = RSB_Registry.Get();
		if (!reg || !reg.defs) return null;
		if (name.Length() == 0)
		{
			// READ THE SERVER CVAR DIRECTLY, the way Enabled() above does. This function is clearscope --
			// ViewJolt and View are clearscope and call it -- and RSB_Settings' accessors are play, so
			// going through one is a compile error. FindCVar with no player asks the SERVER's value,
			// which is the right question anyway: this decides where bullets go and cannot be per-player.
			let c = CVar.FindCVar("sv_rsb_recoil_default");
			if (!c || !c.GetBool()) return null;
			return RSB_RecoilDef(reg.defs.Find("recoil", "default"));
		}
		return RSB_RecoilDef(reg.defs.Find("recoil", name));
	}

	// ONE SHOT. Returns the turn this shot's rounds take (yaw, pitch, in degrees) and the
	// extra spread, then moves the gun's kick on for its next shot. Off, or no profile:
	// dead on, and the kick is forgotten.
	// THE GUN'S WEIGHT RIGHT NOW, in pounds, or 0 when it is not known.
	//
	// Two halves from two packages, which is the whole point of the split: RS_VR_Reload owns what the
	// hand is holding and how many rounds are in it, this package owns what one round weighs. Neither
	// holds the other's number and neither can go stale against it.
	//
	// REACHED BY STRING, NEVER BY CLASS NAME. A hard reference to a class in another pk3 broke the
	// whole game three times in RS_Grenade; this package must keep working with the reload system
	// absent, which it does -- no service, no live weight, stated climb stands.
	//
	// `has` IS ASKED FIRST AND ITS ANSWER IS NOT THE DOUBLE. 80 of 155 shipped guns state no weight,
	// because the weapons lane refused to invent eighty numbers to fill a column. The double reads 0.0
	// for those, and 0.0 means DO NOT APPLY WEIGHT -- never "this gun is weightless".
	private static double LiveWeightLb(RSB_RecoilDef rd, Actor shooter, int hand)
	{
		if (hand < 0 || !shooter || !rd) return 0;
		let it = ServiceIterator.Find("RS_WeaponWeightService");
		if (!it) return 0;
		Service sv = null;
		Service s;
		// EXACT name: ServiceIterator.Find matches on SUBSTRING, so a near-miss can answer first.
		while (s = it.Next())
			if (s.GetClassName() == 'RS_WeaponWeightService') { sv = s; break; }
		if (!sv) return 0;
		if (sv.GetInt("weapon.weight.has", "", hand, 0, shooter) != 1) return 0;
		double lb = sv.GetDouble("weapon.weight.lbs", "", hand, 0, shooter);
		if (lb <= 0) return 0;
		// AND THE AMMUNITION, which is ours: a PPSh is 10.30 lb empty and 12.00 with its drum in.
		//
		// WITHOUT IT THIS RETURNS NOTHING RATHER THAN THE EMPTY WEIGHT, and that is the important half.
		// The stated climb was authored at the LOADED weight, so scaling it against an empty one would
		// make every weighted gun kick harder for ever -- a systematic change dressed as a feature. A
		// gun that does not name its cartridge simply keeps the kick it was written with.
		if (rd.cartridge.Length() == 0) return 0;
		let reg = RSB_Registry.Get();
		let bl = (reg && reg.defs) ? RSB_BallisticsDef(reg.defs.Find("ballistics", rd.cartridge)) : null;
		if (!bl || bl.roundGrains <= 0) return 0;
		int rounds = sv.GetInt("weapon.weight.rounds", "", hand, 0, shooter);
		if (rounds > 0) lb += rounds * bl.roundGrains / 7000.0;
		return lb;
	}

	// WHAT THIS PROFILE'S STATED CLIMB WAS AUTHORED AT, in pounds, recovered from its own shot line.
	// climb is proportional to Vg and Vg is impulse x g / weight, so the weight falls straight out of
	// the two numbers already stated -- no new data, and no need to know the action multiplier at the
	// shot. A profile with no shot line returns 0 and keeps its stated climb.
	private static double AuthoredLb(RSB_RecoilDef rd)
	{
		return (rd && rd.vg > 0.0001 && rd.impulse > 0) ? (rd.impulse * 32.174 / rd.vg) : 0;
	}

	static double, double, double Step(String profile, Actor shooter, out double kickPitch, out double kickYaw, out int lastTic, out int runShot, int hand = -1)
	{
		// THE REAL CLOCK, not the world one (slow motion, engine build 13). Recoil recovery is the gun
		// settling in YOUR hands, and your gun cycles at full speed while the world crawls -- so a string
		// fired in slow motion climbs and settles exactly as it does at full speed. With no slow motion
		// running level.realtime == level.maptime, so nothing changes until it is switched on.
		int now = level.realtime;
		let rd = Enabled() ? Profile(profile) : null;
		if (!rd)
		{
			kickPitch = 0;
			kickYaw = 0;
			runShot = 0;
			lastTic = now;
			return 0, 0, 0;
		}
		// `kick = none`: the WEAPON owns where its shots go. Nothing is returned and nothing
		// accumulates, so a weapon with its own kick model is not silently composed with this one. The
		// view jolt is untouched -- ViewJolt reads the profile's own `view` and never comes through
		// here, so the prop still shoves.
		if (rd.kickOwned)
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
		// THE KICK THIS GUN HAS RIGHT NOW, not the one it was written with. A lighter gun is pushed
		// harder by the same shot, so climb scales by authored weight over live weight -- and AT A FULL
		// MAGAZINE THOSE ARE THE SAME NUMBER, so nothing changes until you start shooting. A PPSh's
		// drum is a seventh of the gun: it climbs 16% harder empty than full, off one figure, with no
		// second system and nothing typed.
		//
		// INERT UNTIL A CALLER PASSES ITS HAND (`hand` defaults to -1), until the gun states a
		// `cartridge`, and until the reload system publishes a weight for it. Any of those missing and
		// the stated climb stands exactly as before -- which is what makes this reviewable one gun at
		// a time instead of all of them at once.
		double climb = rd.climb;
		// THE CVAR READ DIRECTLY, as Enabled() and Profile() above do: this is a SERVER rule, because
		// it decides where bullets go and a per-player answer to that is a desync.
		let wc = CVar.FindCVar("sv_rsb_recoil_weight");
		if (hand >= 0 && wc && wc.GetBool())
		{
			double live = LiveWeightLb(rd, shooter, hand);
			double made = AuthoredLb(rd);
			if (live > 0.05 && made > 0.05)
			{
				double scale = clamp(made / live, 0.4, 2.5);
				climb = rd.climb * scale;
				// IT SAYS SO, ONCE PER PROFILE PER MAP. This feature is INVISIBLE when it works: the
				// difference is a few per cent of climb on a gun you are already fighting. So the first
				// time it actually applies it states what it found -- which gun, both weights, and the
				// scale -- because "silently did nothing" and "silently worked" look identical, and this
				// package has paid for that confusion often enough.
				RSB_Log.Once(RSB_Log.LV_INFO, "recoil:weight:" .. rd.id, String.Format(
					"%s kicks by its LIVE weight: authored at %.2f lb, holding %.2f lb -- climb %.2f x %.2f = %.2f",
					rd.id, made, live, rd.climb, scale, climb));
			}
		}
		kickPitch = min(rd.maxPitch, kickPitch + climb * brace);
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
		Recover(rd, level.realtime, kickPitch, kickYaw, lastTic, runShot);   // the real clock, as in Step
		return kickPitch, kickYaw;
	}

	// THE PER-SHOT JOLT the arm and the prop show (render only): back (map units), rise and
	// roll (degrees), and the tics it takes -- times the player's "Recoil kick (visual)". The
	// server's switch is ALL recoil (the owner): off, no jolt either.
	// ============================================================================================
	// THESE TWO MOVE THE GUN. THEY MUST NEVER MOVE THE CAMERA.
	//
	// The names say "view" and they are a trap: what comes back is the kick the DRAWN GUN carries,
	// and the only consumer applies it to the prop's FollowHandOfs -- the gun slides back in the
	// hand. Nothing here has ever reached the player's pitch and nothing may.
	//
	// THE OWNER RULED ON THIS DIRECTLY: "is doing torso recoil going to fuck up my pov? i dont need
	// to get sick." In VR the camera IS the headset, so a jolt we compute fights his inner ear --
	// the one failure in this whole system that can physically hurt him, and no amount of
	// correctness in the recoil model buys it back. The engine already agrees: A_Recoil carries the
	// comment "We don't want to adjust the player's camera - that could make them sick", and
	// vr_recoil defaults to false.
	//
	// So recoil is a TORQUE and it is spent on things he LOOKS AT, never on the thing he looks
	// THROUGH: the gun's aim about the grip (climb), the shoulder and torso load, the drawn spine.
	// There is no double count between this and the body lane's torso recoil, because the view's
	// share is zero rather than small.
	//
	// A flatscreen mode could want a real view kick one day. That is a NEW function, gated on VR
	// being off, with its own cvar defaulting off. It is not this one relaxed.
	// ============================================================================================
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
