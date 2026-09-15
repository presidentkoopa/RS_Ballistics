// ============================================================================
// ENEMY FIRE. A monster's hitscan -- a zombieman's pistol, a shotgunner's pellets, a chaingunner's
// burst, the Spider's chaingun, any mod's gun-toting monster -- in RS_Ballistics' rounds (owner,
// 2026-09-15: "can I stop using NoMoreHitscans and we just build the option to toggle hitscans in a
// menu for Ballistics? if off, we dress the hitscans").
//
//   ROUNDS (sv_rsb_enemy_rounds, a server switch, on): the engine's WorldHitscanPreFired cancels the
//   hitscan and the monster fires an RSB_EnemyBullet instead -- from where its shot would have started,
//   along the shot's aim, at the server's enemy round speed, dealing the monster's own rolled damage.
//   Every look of our rounds follows: tracers and their light, a crack past your head, material hits.
//   DRESSED (the switch off): the shot stays an instant hitscan, and WorldHitscanFired lays our tracer
//   light and wake along it, cracks past the listener's head and lands our impact where it struck.
//   DISTANCE (rsb_enemy_fx_range, local): a fight far from you draws lighter (RSB_Settings.EnemyBand).
//
// A melee hitscan (shorter than MISSILERANGE) and every player's shot are left alone. Don't run
// NoMoreHitscans alongside the rounds: the first handler to take a shot wins.
//
// NETPLAY. The round is playsim: the event, its numbers and a server cvar, alike on every machine. The
// dressing and the distance bands are looks, for the machine that draws them.
// ============================================================================

class RSB_EnemyFire : EventHandler
{
	const DRESS_SPEED = 8000.0;   // map units a second: how fast a dressed shot's tracer light flies
	const DRESS_WAKE  = 600.0;    // map units of wake laid from the muzzle along a dressed shot

	// WHICH ROUND a monster fires, by what it is. A mod's monster that subclasses none of these fires the plain one.
	static String RoundFor(Actor mo)
	{
		if (mo is "ShotgunGuy") return "enemy_pellet";
		if (mo is "ChaingunGuy" || mo is "SpiderMastermind") return "enemy_heavy";
		return "enemy_bullet";
	}

	// THE ROUNDS: a monster's hitscan becomes a round, and the hitscan is cancelled.
	override bool WorldHitscanPreFired(WorldEvent e)
	{
		let mo = e.thing;
		if (!mo || mo.player || !mo.bIsMonster || e.AttackDistance < MISSILERANGE) return false;
		if (!RSB_Settings.EnemyRounds()) return false;
		RSB_Bullet.LaunchFrom(mo, RoundFor(mo), mo.Height * 0.5 + 8.0 + e.AttackZ, e.AttackOffsetSide,
			e.AttackAngle, e.AttackPitch, e.Damage, e.DamageType, RSB_Settings.EnemyRoundSpeed());
		// Taken either way: a round that burst on spawning has already struck what was in its way.
		return true;
	}

	// THE DRESSING: an instant monster shot, with the rounds off, gets our looks along its line.
	override void WorldHitscanFired(WorldEvent e)
	{
		let mo = e.thing;
		if (!mo || mo.player || !mo.bIsMonster) return;
		if (RSB_Settings.EnemyRounds() || !RSB_Settings.EnemyDress()) return;
		int tier = RSB_Tier.Current();
		if (tier <= RSB_Tier.T_OFF) return;
		Vector3 from = e.AttackPos;
		Vector3 run = e.DamagePosition - from;
		double len = run.Length();
		if (len < 8.0) return;
		Vector3 dir = run / len;
		int band = RSB_Settings.EnemyBand(from);
		if (band >= 2) return;
		let reg = RSB_Registry.Get();
		if (!reg) return;
		let rd = reg.FindRound(RoundFor(mo));
		let lk = rd ? reg.ResolveRoundLook(rd.roundLook, RSB_Tier.Name(tier)) : null;
		if (!lk) return;

		// THE TRACER LIGHT, flying the shot's line and parked where it struck (a short fading streak).
		if (band == 0 && lk.lightRadius > 0 && lk.lightIntensity > 0)
		{
			double land = len / DRESS_SPEED;
			level.SpawnEffectLight(from, lk.lightColor, lk.lightRadius, lk.lightIntensity, land + 0.1, dir * DRESS_SPEED,
				from - dir * min(96.0, len), 0.0, EFL_IMPORTANT, 0.0, 0.0, land, 0.05, 0.0, 0.0);
		}
		// THE WAKE out of the muzzle along the line.
		RSB_Wake.Lay(lk.wake, from, from + dir * min(len, DRESS_WAKE), dir);
		// A CRACK past the listener's head.
		Crack(lk, from, e.DamagePosition);
		// OUR IMPACT where it struck a surface; a thing it struck bleeds its own way.
		FLineTraceData d;
		if (mo.LineTrace(VectorAngle(dir.x, dir.y), len + 8.0, -asin(clamp(dir.z, -1.0, 1.0)), TRF_ABSPOSITION,
			from.z, from.x, from.y, d) && d.HitType != FLineTraceData.TRACE_HitActor)
		{
			let surf = RSB_Materials.FromTrace(d, dir);
			if (surf && !surf.sky)
			{
				let spot = Actor.SpawnClientSide("RSB_SoundSpot", surf.at, ALLOW_REPLACE);
				if (spot) RSB_Impact.LandOn(spot, surf, lk.impact, dir);
			}
		}
	}

	// The closest the shot's line came to this machine's listener: within the look's whiz reach, it cracks there.
	private void Crack(RSB_RoundLookDef lk, Vector3 from, Vector3 to)
	{
		if (lk.whizRadius <= 0 || lk.whizSound ~== "none" || !RSB_Settings.Whiz()) return;
		double range = lk.whizRadius * RSB_Settings.WhizRange();
		double vol = RSB_Settings.WhizVolume();
		if (range <= 0 || vol <= 0) return;
		let cam = players[consoleplayer].camera;
		if (!cam) return;
		Vector3 ear = cam.pos;
		if (cam.player) ear.z = cam.player.viewz;
		Vector3 seg = to - from;
		double len2 = seg dot seg;
		double t = (len2 > 0) ? clamp(((ear - from) dot seg) / len2, 0.0, 1.0) : 0.0;
		Vector3 closest = from + seg * t;
		if ((ear - closest).Length() > range) return;
		let spot = Actor.SpawnClientSide("RSB_SoundSpot", closest, ALLOW_REPLACE);
		if (spot) spot.A_StartSound(lk.whizSound, CHAN_AUTO, CHANF_OVERLAP, vol);
	}
}
