// ============================================================================
// THE SMOKING BARREL. A gun that has just fired a string of shots smokes: a thin
// ribbon curling up off the muzzle that follows the gun as it moves and thins as the
// barrel cools, with the air bending over it (Max Payne, John Woo).
//
// From the gun's `flash` profile:
//   barrelheat     heat a shot adds, heat lost a second, the heat it starts smoking at
//                  (1 = smoking its hardest)
//   barrelsmoke    the PARTICLEDEFS ribbon, puffs a tic at full heat
//   barrelshimmer  radius, strength of the hot air over it
//
// THE CALLER, a gun mod, makes two calls, keyed by the gun actor itself:
//   RSB_Barrel.Shot(gun, flashProfile)   on each shot, beside RSB_Flash.Fire
//   RSB_Barrel.Muzzle(gun, at, dir)      every tic the gun is out, fired or not
// Nothing smokes until both are made. A gun that stops calling Muzzle (holstered)
// stops smoking and keeps cooling, so it is still warm if it comes straight back out.
//
// NETPLAY: presentation only. Heat is kept per gun actor (never the console player),
// counted from the calls and cooled by the map clock; no RNG, nothing the game reads.
// SLOW MOTION: heat cools and smoke is laid by the map clock (level.maptime).
// ============================================================================

class RSB_BarrelHeat
{
	Actor        gun;
	RSB_FlashDef fd;
	double       heat;        // 0 cold; smoking from fd.barrelSmokeFrom, hardest at 1
	int          heatTic;     // the map tic `heat` is current to
	double       carry;       // part of a puff owed from the last tic
}

class RSB_Barrel play
{
	const MAX_BARRELS = 16;
	const HEAT_CAP = 2.0;
	const SHIMMER_EVERY = 6;  // tics between fresh shimmer columns (each lives longer, so they overlap)

	// A SHOT from `gun`, with the flash profile it fired.
	static void Shot(Actor gun, String flashProfile)
	{
		if (!gun || flashProfile.Length() == 0 || flashProfile ~== "none") return;
		let reg = RSB_Registry.Get();
		if (!reg) return;
		let fd = reg.ResolveFlash(flashProfile, RSB_Tier.Name(RSB_Tier.Current()));
		if (!fd || fd.barrelPerShot <= 0) return;
		let b = Find(reg, gun, true);
		b.fd = fd;
		Cool(b);
		b.heat = min(HEAT_CAP, b.heat + fd.barrelPerShot);
	}

	// EVERY TIC the gun is out: where its muzzle is and which way its bore points.
	static void Muzzle(Actor gun, Vector3 at, Vector3 dir)
	{
		if (!gun) return;
		let reg = RSB_Registry.Get();
		if (!reg) return;
		let b = Find(reg, gun, false);
		if (!b || !b.fd) return;
		Cool(b);
		let fd = b.fd;

		double from = fd.barrelSmokeFrom;
		double amount = (from < 1.0) ? clamp((b.heat - from) / (1.0 - from), 0.0, 1.0) : ((b.heat >= from) ? 1.0 : 0.0);
		if (amount <= 0)
		{
			b.carry = 0;
			return;
		}
		int tier = RSB_Tier.Current();
		if (tier <= RSB_Tier.T_OFF) return;
		double smokeMul = RSB_Settings.FlashSmoke();
		if (smokeMul <= 0) return;

		Vector3 bore = (dir.Length() > 0.000001) ? dir.Unit() : (0, 0, 1);
		Vector3 rise = ((0, 0, 1) * 0.85 + bore * 0.15).Unit();
		int posSeed = RSB_Hash.OfPos(at);

		// THE RIBBON: puffs off the muzzle, fewer and slower as it cools.
		if (fd.barrelSmokeParticle.Length() > 0 && fd.barrelSmokePerTic > 0)
		{
			b.carry += amount * fd.barrelSmokePerTic * RSB_Tier.CountScale(tier) * smokeMul;
			int n = int(b.carry);
			b.carry -= n;
			if (n > 0)
			{
				// The handle is a hash of the name, the same everywhere: cached, never tested.
				if (fd.barrelSmokeHandle == 0) fd.barrelSmokeHandle = level.ParticleDefinition(fd.barrelSmokeParticle);
				level.SpawnParticles(fd.barrelSmokeHandle, at + bore * 0.5, rise, min(n, 8), 18.0, 3.0 + 7.0 * amount, 0.5,
					1.2 + 1.0 * amount, 0.35, Color(255, 255, 255, 255), 1.0, 0.7 + 0.5 * amount,
					RSB_Hash.Seed(level.maptime, 331, posSeed));
			}
		}

		// THE HOT AIR over it: a fresh narrow column every few tics, each outliving the gap.
		if (fd.barrelShimmerStrength > 0 && fd.barrelShimmerRadius > 0 && (level.maptime % SHIMMER_EVERY) == 0)
			RSB_Heat.Along(at, rise, fd.barrelShimmerRadius * 5.0, fd.barrelShimmerRadius,
				fd.barrelShimmerStrength * amount, SHIMMER_EVERY + 4);
	}

	// Heat lost since it was last brought up to date, by the map clock.
	private static void Cool(RSB_BarrelHeat b)
	{
		int now = level.maptime;
		if (b.fd && b.heatTic > 0 && now > b.heatTic)
			b.heat = max(0.0, b.heat - b.fd.barrelCool * double(now - b.heatTic) / double(TICRATE));
		b.heatTic = now;
	}

	// This gun's barrel; a new one when `make` (the oldest given up past MAX_BARRELS).
	private static RSB_BarrelHeat Find(RSB_Registry reg, Actor gun, bool make)
	{
		for (int i = reg.barrels.Size() - 1; i >= 0; i--)
		{
			let b = reg.barrels[i];
			if (!b || !b.gun)
			{
				reg.barrels.Delete(i);
				continue;
			}
			if (b.gun == gun) return b;
		}
		if (!make) return null;
		if (reg.barrels.Size() >= MAX_BARRELS) reg.barrels.Delete(0);
		let nb = new("RSB_BarrelHeat");
		nb.gun = gun;
		reg.barrels.Push(nb);
		return nb;
	}
}
