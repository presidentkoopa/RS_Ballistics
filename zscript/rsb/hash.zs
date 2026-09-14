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
//   1 plain    fewer particles
//   2 normal   the profiles as written
//   3 heavy    more
//   4 extreme  much more
//
// A profile written for a tier -- `impact bullet@heavy` -- is used as written
// at that tier. Otherwise the untiered profile is used and its particle counts
// are scaled by CountScale.
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
		case T_EXTREME: return 3.0;
		}
		return 1.0;
	}
}
