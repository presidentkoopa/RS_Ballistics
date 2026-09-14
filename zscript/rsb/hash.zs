// ============================================================================
// COSMETIC VARIATION THAT NEVER TOUCHES THE PLAYSIM RNG, AND THE EFFECTS DIAL.
//
// NETPLAY (owner hard rule): a bare frandom() -- or a named random[] -- is
// playsim state. Effects run where only some machines see them, or at counts a
// local setting chooses, so any draw there desyncs a netgame. A look that only
// needs to vary is a HASH of numbers the caller already has: the tic, a
// counter, a position. Same answer on any machine; nothing changes on the
// others.
//
// NOT FOR ANYTHING THAT DECIDES AN OUTCOME. Damage stays on named RNGs in the
// fire path, which runs on every machine.
// ============================================================================

class RSB_Hash
{
	// 0..1 from three integers: spatial-hash primes, then an xorshift.
	static double Frac(int a, int b, int c)
	{
		return double(Mix(a, b, c) & 0xFFFF) / 65535.0;
	}

	static double Between(double lo, double hi, int a, int b, int c)
	{
		return lo + (hi - lo) * Frac(a, b, c);
	}

	// A PER-SHOT WOBBLE: 1 plus or minus up to `amount` (0 = always 1), so each shot or
	// hit comes out a little bigger or smaller than the one before.
	static double Wobble(double amount, int a, int b, int c)
	{
		if (amount <= 0) return 1.0;
		return 1.0 + Between(-amount, amount, a, b, c);
	}

	// A particle seed. Never 0: SpawnGpuParticles reads 0 as "pick your own".
	static int Seed(int a, int b, int c)
	{
		int h = Mix(a, b, c);
		return (h == 0) ? 1 : h;
	}

	// A position folded to one integer, for seeding.
	static int OfPos(Vector3 p)
	{
		return int(p.x * 16) ^ (int(p.y * 16) << 1) ^ (int(p.z * 16) << 2);
	}

	private static int Mix(int a, int b, int c)
	{
		int h = a * 73856093;
		h ^= b * 19349663;
		h ^= c * 83492791;
		h ^= h << 13;
		h ^= h >>> 17;
		h ^= h << 5;
		return h;
	}
}

// THE EFFECTS DIAL. One setting per player, local, cosmetic: it never changes
// damage, speed or anything else a netgame compares.
//
//   0 off      no visuals (sounds still play)
//   1 plain    fewer particles, dimmer, thinner smoke
//   2 normal   a little under heavy
//   3 heavy    the recommended level: what every profile is tuned at
//   4 extreme  EVERYTHING turned way up (the owner: "EXTREMEEEEEE")
//
// A profile written for a tier -- `flash pistol_9mm@extreme` -- replaces the untiered one at
// that tier: it can do things the others never do. Either way the level scales far more
// than particle counts: lights, sizes, room smoke, shoves, heat shimmer, how long marks
// stay, glow and how often tracers fly (the ladder below).
class RSB_Tier
{
	const T_OFF     = 0;
	const T_PLAIN   = 1;
	const T_NORMAL  = 2;
	const T_HEAVY   = 3;
	const T_EXTREME = 4;

	static int Current()
	{
		let c = CVar.GetCVar("rsb_tier", players[consoleplayer]);
		return c ? clamp(c.GetInt(), T_OFF, T_EXTREME) : T_NORMAL;
	}

	static String Name(int t)
	{
		switch (t)
		{
		case T_OFF:     return "off";
		case T_PLAIN:   return "plain";
		case T_HEAVY:   return "heavy";
		case T_EXTREME: return "extreme";
		}
		return "normal";
	}

	static double CountScale(int t)
	{
		switch (t)
		{
		case T_OFF:     return 0.0;
		case T_PLAIN:   return 0.4;
		case T_HEAVY:   return 1.8;
		case T_EXTREME: return 4.0;
		}
		return 1.0;
	}

	// THE LADDER BEYOND COUNTS. Heavy is what every profile is tuned at, so heavy is x1 on
	// every rung; plain and normal trim, extreme goes big. Off is 0 (nothing draws anyway).
	private static double Ladder(int t, double plain, double normal, double heavy, double extreme)
	{
		switch (t)
		{
		case T_OFF:     return 0.0;
		case T_PLAIN:   return plain;
		case T_NORMAL:  return normal;
		case T_HEAVY:   return heavy;
		}
		return extreme;
	}

	static double LightScale(int t) { return Ladder(t, 0.6, 0.85, 1.0, 1.5); }   // every effect light's brightness
	static double SizeScale(int t)  { return Ladder(t, 0.85, 0.95, 1.0, 1.3); }  // muzzle light reach, flash flame size
	static double SmokeScale(int t) { return Ladder(t, 0.4, 0.7, 1.0, 1.7); }    // room smoke and smoke puffs
	static double PushScale(int t)  { return Ladder(t, 0.5, 0.8, 1.0, 1.5); }    // blasts shoving the room's smoke
	static double HeatScale(int t)  { return Ladder(t, 0.5, 0.8, 1.0, 1.6); }    // heat shimmer strength
	static double MarkScale(int t)  { return Ladder(t, 0.5, 0.75, 1.0, 2.5); }   // how long surface marks stay
	static double GlowScale(int t)  { return Ladder(t, 0.8, 0.9, 1.0, 1.3); }    // hot particles' glow

	// A look's tracer every N rounds: twice as often at extreme, half as often at plain.
	static int TracerEvery(int every, int t)
	{
		if (every <= 0) return every;
		if (t >= T_EXTREME) return max(1, every / 2);
		if (t <= T_PLAIN) return every * 2;
		return every;
	}
}
