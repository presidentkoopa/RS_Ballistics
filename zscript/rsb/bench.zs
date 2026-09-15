// ============================================================================
// BENCHMARKS: fixed effect loads for the engine's performance gate.
//
// Every engine effects item is measured before and after, with the performance
// log on, under a load anyone can repeat. A bench runs for ten seconds, aimed
// from where the player stood when it started -- level, not from the moving
// head -- so the same spot in the same room gives the same load.
//
//   netevent rsb_bench_flame2      two incinerator streams into what is ahead
//   netevent rsb_bench_impacts60   60 impacts a second over the wall and floor ahead
//   netevent rsb_bench_smoke200    about 200 GPU smoke puffs (rsb_smoke_gun) alive, two flashing lights
//   netevent rsb_bench_flashes     about 8 muzzle flashes a second at fixed points ahead (#20 flash shadows)
//   netevent rsb_bench_bfg         a Heavy BFG blast and its 40-ray spray every two seconds (the worst light load)
//
// Each has a Command row on the Preview page. Stand about 256 units from a wall,
// facing it, and keep still. START and END print with the tic, to find the
// window in perflog.txt. Starting a bench ends any bench still running.
//
// NETPLAY. A netevent runs on every machine on the same tic. The driver is
// +NOINTERACTION, every variation is a hash, and nothing touches the game.
// ============================================================================

class RSB_Bench : Actor
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

	const BENCH_TICS  = 350;   // ten seconds
	const FLAME_HAND  = 20;    // clear of the real hands (0, 1) and the preview's (9)
	const SMOKE_ALIVE = 200;
	const SMOKE_LIFE_TICS = 70;   // each GPU smoke puff lives two seconds
	const LIGHT_EVERY = 12;

	const KIND_FLAME2    = 1;
	const KIND_IMPACTS60 = 2;
	const KIND_SMOKE200  = 3;
	const KIND_FLASHES   = 4;
	const KIND_BFG       = 5;

	const FLASH_EVERY = 9;     // tics: two flashes each time, about 8 a second
	const FLASH_SLOT  = 12;    // cone slots 12..15, one a point: clear of the hands (0, 1) and the preview (9)
	const BFG_EVERY   = 70;    // a Heavy BFG's blast and spray every two seconds
	const BFG_RAYS    = 40;    // Doom's A_BFGSpray count

	int kind;
	int playerNum;
	private int     age;
	private int     impactDebt;
	private Vector3 eye;
	private double  yaw;
	private int     smokeDef;   // rsb_smoke_gun's handle: a hash of the name, looked up once

	States
	{
	Spawn:
		TNT1 A -1;
		Stop;
	}

	static String KindName(int k)
	{
		if (k == KIND_FLAME2) return "flame2";
		if (k == KIND_IMPACTS60) return "impacts60";
		if (k == KIND_SMOKE200) return "smoke200";
		if (k == KIND_FLASHES) return "flashes";
		if (k == KIND_BFG) return "bfg";
		return "?";
	}

	// True when the event was a bench, handled or not.
	static bool Begin(ConsoleEvent e)
	{
		int which = 0;
		if (e.Name ~== "rsb_bench_flame2") which = KIND_FLAME2;
		else if (e.Name ~== "rsb_bench_impacts60") which = KIND_IMPACTS60;
		else if (e.Name ~== "rsb_bench_smoke200") which = KIND_SMOKE200;
		else if (e.Name ~== "rsb_bench_flashes") which = KIND_FLASHES;
		else if (e.Name ~== "rsb_bench_bfg") which = KIND_BFG;
		if (which == 0) return false;
		if (e.Player < 0 || e.Player >= MAXPLAYERS || !playeringame[e.Player]) return true;
		let pmo = players[e.Player].mo;
		if (!pmo) return true;

		let it = ThinkerIterator.Create("RSB_Bench");
		RSB_Bench running;
		while (running = RSB_Bench(it.Next()))
			running.Finish();

		let b = RSB_Bench(Actor.Spawn("RSB_Bench", pmo.pos, ALLOW_REPLACE));
		if (!b) return true;
		b.kind = which;
		b.playerNum = e.Player;
		b.eye = pmo.pos + (0, 0, players[e.Player].viewz - pmo.pos.z);
		b.yaw = pmo.angle;
		Console.Printf("RSB bench %s: START at tic %d -- ten seconds, keep still", KindName(which), level.maptime);
		return true;
	}

	void Finish()
	{
		if (kind == KIND_FLAME2)
		{
			let pmo = Watcher();
			if (pmo)
			{
				RSB_Flame.StopStream(pmo, FLAME_HAND);
				RSB_Flame.StopStream(pmo, FLAME_HAND + 1);
			}
		}
		Console.Printf("RSB bench %s: END at tic %d", KindName(kind), level.maptime);
		Destroy();
	}

	private Actor Watcher()
	{
		if (playerNum < 0 || playerNum >= MAXPLAYERS || !playeringame[playerNum]) return null;
		return players[playerNum].mo;
	}

	// A direction from the start: yaw and pitch offsets in degrees, pitch down positive.
	private Vector3 Aim(double yawOff, double pitchOff)
	{
		double a = yaw + yawOff;
		return (cos(a) * cos(pitchOff), sin(a) * cos(pitchOff), -sin(pitchOff));
	}

	override void Tick()
	{
		age++;
		let pmo = Watcher();
		if (age > BENCH_TICS || !pmo)
		{
			Finish();
			return;
		}
		if (kind == KIND_FLAME2) Flames(pmo);
		else if (kind == KIND_IMPACTS60) Impacts(pmo);
		else if (kind == KIND_SMOKE200) Smoke();
		else if (kind == KIND_FLASHES) Flashes();
		else if (kind == KIND_BFG) Bfg(pmo);
		Super.Tick();
	}

	private void Flames(Actor pmo)
	{
		Vector3 right = (sin(yaw), -cos(yaw), 0);
		for (int i = 0; i < 2; i++)
		{
			double sgn = (i == 0) ? -1.0 : 1.0;
			Vector3 dir = Aim(sgn * 6.0, 4.0);
			Vector3 nozzleAt = eye + right * (sgn * 12.0) - (0, 0, 12) + dir * 16.0;
			RSB_Flame.Stream("incinerator", pmo, FLAME_HAND + i, nozzleAt, dir, (0, 0, 0), 1.0);
		}
	}

	private void Impacts(Actor pmo)
	{
		impactDebt += 60;
		while (impactDebt >= TICRATE)
		{
			impactDebt -= TICRATE;
			Vector3 dir = Aim(RSB_Hash.Between(-25.0, 25.0, age, impactDebt, 31),
				RSB_Hash.Between(-5.0, 35.0, age, impactDebt, 37));
			FLineTraceData d;
			if (!pmo.LineTrace(VectorAngle(dir.x, dir.y), 2048.0, -asin(clamp(dir.z, -1.0, 1.0)),
				TRF_ABSPOSITION | TRF_THRUACTORS, eye.z, eye.x, eye.y, d))
				continue;
			let surf = RSB_Materials.FromTrace(d, dir);
			if (!surf || surf.sky) continue;
			let spot = Actor.SpawnClientSide("RSB_SoundSpot", surf.at, ALLOW_REPLACE);
			if (spot) RSB_Impact.LandOn(spot, surf, "bullet", dir);
		}
	}

	// THE FLASH LOAD (#20): every FLASH_EVERY tics two muzzle flashes -- the pistol's and the Super
	// Shotgun's by turns -- at two of four fixed points 128 units apart, 64 units above the floor where
	// the bench started, 256 units ahead, aimed away. About 8 flashes a second with real lights, for
	// the shadow map's cost (perflog: shadowmap, scene.opaque + scene.translucent, load dlights).
	private void Flashes()
	{
		if ((age % FLASH_EVERY) != 1) return;
		Vector3 right = (sin(yaw), -cos(yaw), 0);
		Vector3 fwd = Aim(0.0, 0.0);
		int pass = age / FLASH_EVERY;
		for (int i = 0; i < 2; i++)
		{
			int point = (pass % 2) + i * 2;   // points 0 and 2, then 1 and 3
			Vector3 at = pos + (0, 0, 64) + fwd * 256.0 + right * (-192.0 + 128.0 * point);
			String which = (((pass + i) % 2) == 0) ? "pistol" : "shotgun_ssg";
			RSB_Flash.Fire(which, at, fwd, FLASH_SLOT + point, (0, 0, 0));
		}
	}

	// A HEAVY BFG'S LIGHTS (#20 and #21's reference load): every BFG_EVERY tics the Heavy BFG's blast
	// where the middle of the view lands, then BFG_RAYS hashed rays over the 90 degrees ahead -- each a
	// ray trail and a strike, as RSB_BFGExtraHeavy lays them.
	private void Bfg(Actor pmo)
	{
		if ((age % BFG_EVERY) != 1) return;
		int burst = age / BFG_EVERY;
		for (int i = -1; i < BFG_RAYS; i++)
		{
			Vector3 dir = (i < 0) ? Aim(0.0, 5.0)
				: Aim(-45.0 + 90.0 * (i + RSB_Hash.Frac(burst, i, 61)) / BFG_RAYS, RSB_Hash.Between(-5.0, 20.0, burst, i, 67));
			FLineTraceData d;
			if (!pmo.LineTrace(VectorAngle(dir.x, dir.y), 4096.0, -asin(clamp(dir.z, -1.0, 1.0)),
				TRF_ABSPOSITION | TRF_THRUACTORS, eye.z, eye.x, eye.y, d))
				continue;
			let surf = RSB_Materials.FromTrace(d, dir);
			if (!surf || surf.sky) continue;
			let spot = Actor.SpawnClientSide("RSB_SoundSpot", surf.at, ALLOW_REPLACE);
			if (!spot) continue;
			if (i < 0)
			{
				RSB_Impact.LandOn(spot, surf, "bfg_heavy", dir);
				continue;
			}
			RSB_Impact.LandOn(spot, surf, "bfg_spray_heavy", dir);
			RSB_Trail.Lay("bfg_ray_heavy", pmo, eye, surf.at);
		}
	}

	// ABOUT SMOKE_ALIVE GPU SMOKE PUFFS ALIVE -- stage 2d's lit, alpha-blended, soft
	// particles, the path RS_Ballistics' gunsmoke draws through. Each lives
	// SMOKE_LIFE_TICS, so SMOKE_ALIVE / SMOKE_LIFE_TICS are spawned a tic.
	private void Smoke()
	{
		if (smokeDef == 0) smokeDef = level.ParticleDefinition("rsb_smoke_gun");
		Vector3 right = (sin(yaw), -cos(yaw), 0);
		Vector3 ahead = eye + Aim(0.0, 0.0) * 128.0 - (0, 0, 16);
		int perTic = (SMOKE_ALIVE + SMOKE_LIFE_TICS - 1) / SMOKE_LIFE_TICS;
		for (int i = 0; i < perTic; i++)
		{
			Vector3 at = ahead + right * RSB_Hash.Between(-64.0, 64.0, age, i, 41)
				+ (0, 0, RSB_Hash.Between(-24.0, 40.0, age, i, 43));
			level.SpawnParticles(smokeDef, at, (0, 0, 1), 1, 40.0, 8.0, 0.5,
				SMOKE_LIFE_TICS / double(TICRATE), 0.2, Color(255, 255, 255, 255), 1.0, 1.0,
				RSB_Hash.Seed(age, i + 1, 59));
		}
		if ((age % LIGHT_EVERY) == 0)
		{
			for (int j = 0; j < 2; j++)
			{
				Vector3 lp = ahead + right * ((j == 0) ? -48.0 : 48.0);
				let l = RSB_ImpactLight(Actor.SpawnClientSide("RSB_ImpactLight", lp, ALLOW_REPLACE));
				if (l) l.Start(200.0, 2.0, 4, Color(255, 255, 170, 90));
			}
		}
	}
}
