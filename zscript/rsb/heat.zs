// ============================================================================
// HEAT SHIMMER. The engine bends what is seen through hot air (heat sources,
// engine 1dc83016fe: LevelLocals.SetHeatSource). RS_Ballistics sets the sources
// its effects make: a flame's plume and the ball of heat where it lands
// (flamer.zs), a blast where a rocket, BFG ball or plasma bolt lands (an impact's
// `heat`), the blast out of a muzzle (a flash's `heat`) and the air a round tears
// through (a round look's `heat`).
//
// SLOTS 16-47 ARE RS_BALLISTICS' (assigned by the build lane; other mods own the
// rest of the 64):
//   16-31  flames, two each (the plume, the landing), eight flames at once
//   32-47  blasts, used in turn; each fades itself out over its life
// NEVER ClearHeatSource(-1): that clears every mod's slots.
//
// Nothing draws until the player turns on Developer options -> "Heat shimmer";
// how strong it looks is the engine's "Heat shimmer strength" slider, read live.
//
// NETPLAY. Presentation only: setters, nothing read back, no RNG. Which blast
// slot a machine uses may differ between machines and changes nothing.
// ============================================================================

class RSB_Heat play
{
	const FLAME_FIRST  = 16;
	const FLAME_BLOCKS = 8;    // two slots each: 16..31
	const BLAST_FIRST  = 32;
	const BLAST_SLOTS  = 16;   // 32..47

	// A BALL OF HOT AIR at `at`, rising a little, fading over `tics`.
	static void Blast(Vector3 at, double radius, double strength, int tics)
	{
		if (radius <= 0 || strength <= 0 || tics <= 0) return;
		level.SetHeatSource(NextBlastSlot(), at, at + (0, 0, radius * 0.6), radius * 0.8, radius,
			strength, 0.08, 24.0, tics);
	}

	// A BLAST ALONG A LINE from `from`, `length` along `dir`, narrow where it
	// starts: a muzzle's.
	static void Along(Vector3 from, Vector3 dir, double length, double radius, double strength, int tics)
	{
		if (radius <= 0 || strength <= 0 || tics <= 0 || length <= 0) return;
		level.SetHeatSource(NextBlastSlot(), from, from + dir * length, radius * 0.5, radius,
			strength, 0.1, 20.0, tics);
	}

	// A BLAST SLOT OF ITS OWN for something that re-lays its heat each tic -- a round's
	// air shimmer -- taken in turn with the blasts, so the oldest is the one given up.
	static int ClaimBlast()
	{
		return NextBlastSlot();
	}

	// THE AIR A ROUND TEARS THROUGH: a narrow line from `from` (behind it, where the air
	// has spread wider) to `to` (the round), laid again each tic in the round's own slot
	// and fading over `tics` once it stops being laid.
	static void AirWake(int slot, Vector3 from, Vector3 to, double radius, double strength, int tics)
	{
		if (slot < BLAST_FIRST || slot >= BLAST_FIRST + BLAST_SLOTS) return;
		if (radius <= 0 || strength <= 0 || tics <= 0) return;
		level.SetHeatSource(slot, from, to, radius, radius * 0.35, strength, 0.12, 4.0, tics);
	}

	// Blasts take their slots in turn, so the one overwritten is the oldest,
	// the nearest to faded.
	private static int NextBlastSlot()
	{
		let reg = RSB_Registry.Get();
		if (!reg) return BLAST_FIRST;
		int slot = BLAST_FIRST + reg.heatBlastNext;
		reg.heatBlastNext = (reg.heatBlastNext + 1) % BLAST_SLOTS;
		return slot;
	}
}
