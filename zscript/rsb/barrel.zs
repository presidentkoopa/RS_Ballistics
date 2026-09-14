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
	RSB_BarrelGlow glowLight;  // the dull light of a barrel run hot, while it glows
	Array<double>  chargeCarry;  // parts of a charge burst owed from the last tic
	RSB_BarrelGlow chargeLight;  // the light gathering at the muzzle while it charges
	double       heat;        // 0 cold; smoking from fd.barrelSmokeFrom, hardest at 1
	int          heatTic;     // the map tic `heat` is current to
	double       carry;       // part of a puff owed from the last tic
	Array<double> exhaustCarry;  // parts of an exhaust burst owed from the last tic
	int          exhaustTic;  // the map tic of the last exhaust call (0 never)
	double       exhaustLow;  // the throttle's recent low, rising back a sixth a tic: snapping open past it blips
	int          exhaustBlipTic;  // the map tic of the last blip
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

		int tier = RSB_Tier.Current();
		LayGlow(b, at, tier);

		double from = fd.barrelSmokeFrom;
		double amount = (from < 1.0) ? clamp((b.heat - from) / (1.0 - from), 0.0, 1.0) : ((b.heat >= from) ? 1.0 : 0.0);
		if (amount <= 0)
		{
			b.carry = 0;
			return;
		}
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

	// A CHARGE: every tic a gun winds up (a BFG's charge), with how far along it is (0..1).
	// The flash profile's charge keys gather at the muzzle -- bursts at rates growing with
	// the charge, a light swelling, the air bending -- and stop when the calls stop (the
	// shot's own flash takes over). Keyed by the gun actor, like the barrel. Looks only.
	static void Charge(Actor gun, String flashProfile, Vector3 at, Vector3 dir, double fraction)
	{
		if (!gun || flashProfile.Length() == 0 || flashProfile ~== "none") return;
		let reg = RSB_Registry.Get();
		if (!reg) return;
		let fd = reg.ResolveFlash(flashProfile, RSB_Tier.Name(RSB_Tier.Current()));
		if (!fd) return;
		if (fd.chargeBursts.Size() == 0 && fd.chargeLightRadius <= 0 && fd.chargeShimmerStrength <= 0) return;
		int tier = RSB_Tier.Current();
		if (tier <= RSB_Tier.T_OFF) return;
		let b = Find(reg, gun, true);
		double f = clamp(fraction, 0.0, 1.0);
		Vector3 bore = (dir.Length() > 0.000001) ? dir.Unit() : (1, 0, 0);
		int now = level.maptime;
		int posSeed = RSB_Hash.OfPos(at);

		double countScale = RSB_Tier.CountScale(tier) * RSB_Settings.FlashSparks();
		while (b.chargeCarry.Size() < fd.chargeBursts.Size()) b.chargeCarry.Push(0);
		for (int i = 0; i < fd.chargeBursts.Size(); i++)
		{
			b.chargeCarry[i] += fd.chargeRates[i] * f / double(TICRATE);
			int n = int(b.chargeCarry[i]);
			b.chargeCarry[i] -= n;
			for (int k = 0; k < min(n, 4); k++)
				RSB_Burst.Fire(reg.FindBurst(fd.chargeBursts[i]), at, bore, bore, countScale, 1.0, RSB_Hash.Seed(now, 700 + i * 8 + k, posSeed));
		}
		if (fd.chargeShimmerStrength > 0 && fd.chargeShimmerRadius > 0 && (now % SHIMMER_EVERY) == 0)
			RSB_Heat.Blast(at, fd.chargeShimmerRadius * (0.4 + 0.6 * f), fd.chargeShimmerStrength * f, SHIMMER_EVERY + 4);
		if (fd.chargeLightRadius > 0 && fd.chargeLightIntensity > 0 && RSB_Settings.FlashLight() > 0)
		{
			if (!b.chargeLight) b.chargeLight = RSB_BarrelGlow(Actor.Spawn("RSB_BarrelGlow", at, NO_REPLACE));
			if (b.chargeLight)
				b.chargeLight.Hold(at, fd.chargeLightColor, fd.chargeLightRadius * (0.3 + 0.7 * f),
					fd.chargeLightIntensity * f * f * RSB_Settings.FlashLight());
		}
	}

	// THE GLOW OF A BARREL RUN HOT (`barrelglow`): past glowFrom heat, a dull light at the
	// muzzle, brighter and wider as the heat climbs to the cap; out as it cools.
	private static void LayGlow(RSB_BarrelHeat b, Vector3 at, int tier)
	{
		let fd = b.fd;
		double hot = 0;
		if (fd.barrelGlowRadius > 0 && fd.barrelGlowIntensity > 0 && tier > RSB_Tier.T_OFF && fd.barrelGlowFrom < HEAT_CAP)
			hot = clamp((b.heat - fd.barrelGlowFrom) / (HEAT_CAP - fd.barrelGlowFrom), 0.0, 1.0);
		if (hot <= 0)
		{
			if (b.glowLight) b.glowLight.Destroy();
			b.glowLight = null;
			return;
		}
		if (!b.glowLight) b.glowLight = RSB_BarrelGlow(Actor.Spawn("RSB_BarrelGlow", at, NO_REPLACE));
		if (b.glowLight)
			b.glowLight.Hold(at, fd.barrelGlowColor, fd.barrelGlowRadius * (0.6 + 0.4 * hot), fd.barrelGlowIntensity * hot);
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
	// RSB_Exhaust keeps its engine's state on the same record.
	static RSB_BarrelHeat Find(RSB_Registry reg, Actor gun, bool make)
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

// AN ENGINE'S EXHAUST: every tic a motor runs (a chainsaw's two-stroke), idle included, the gun
// mod calls
//   RSB_Exhaust.Run(gun, flashProfile, port, dir, throttle)
// with the exhaust port's world position, the way it blows, and the throttle (0 idle .. 1 full;
// 1 while cutting). The flash profile's exhaust keys: puffs at rates from idle to full, one dark
// blip when the throttle snaps open or the engine catches after being off, smoke into the room and
// hot air at the port. A tic without a call is the engine off: nothing to stop. Kept on the gun
// actor's barrel record. Looks only: no RNG, the map clock.
class RSB_Exhaust play
{
	const EVERY = 6;       // tics between room-smoke emits and hot-air columns
	const BLIP_GAP = 12;   // tics at least between blips
	const OFF_AFTER = 8;   // tics without a call that mean the engine stopped

	static void Run(Actor gun, String flashProfile, Vector3 port, Vector3 dir, double throttle)
	{
		if (!gun || flashProfile.Length() == 0 || flashProfile ~== "none") return;
		let reg = RSB_Registry.Get();
		if (!reg) return;
		let fd = reg.ResolveFlash(flashProfile, RSB_Tier.Name(RSB_Tier.Current()));
		if (!fd) return;
		if (fd.exhaustBursts.Size() == 0 && fd.exhaustBlip.Length() == 0 && fd.exhaustSmokeAmount <= 0 && fd.exhaustShimmerStrength <= 0) return;
		int tier = RSB_Tier.Current();
		if (tier <= RSB_Tier.T_OFF) return;
		double smokeMul = RSB_Settings.FlashSmoke();
		if (smokeMul <= 0) return;

		let b = RSB_Barrel.Find(reg, gun, true);
		int now = level.maptime;
		double t = clamp(throttle, 0.0, 1.0);
		double share = fd.exhaustIdle + (1.0 - fd.exhaustIdle) * t;
		Vector3 blow = (dir.Length() > 0.000001) ? dir.Unit() : (0, 0, 1);
		int posSeed = RSB_Hash.OfPos(port);
		double countScale = RSB_Tier.CountScale(tier) * smokeMul;

		// THE ENGINE CATCHING (no call for a while), or THE THROTTLE SNAPPING OPEN past its recent
		// low (a slow roll up never blips): one dark gout.
		bool started = (b.exhaustTic <= 0 || now - b.exhaustTic > OFF_AFTER);
		if (started)
		{
			b.exhaustLow = t;
			b.exhaustCarry.Clear();
		}
		else
			b.exhaustLow = min(t, b.exhaustLow + double(now - b.exhaustTic) / double(EVERY));
		b.exhaustTic = now;
		if (fd.exhaustBlip.Length() > 0 && now - b.exhaustBlipTic >= BLIP_GAP && (started || t - b.exhaustLow >= fd.exhaustBlipRise))
		{
			RSB_Burst.Fire(reg.FindBurst(fd.exhaustBlip), port, blow, blow, countScale, 1.0, RSB_Hash.Seed(now, 761, posSeed));
			b.exhaustBlipTic = now;
			b.exhaustLow = t;
		}

		// THE PUFFS, from the idle rate up to full throttle.
		while (b.exhaustCarry.Size() < fd.exhaustBursts.Size()) b.exhaustCarry.Push(0);
		for (int i = 0; i < fd.exhaustBursts.Size(); i++)
		{
			b.exhaustCarry[i] += fd.exhaustRates[i] * share / double(TICRATE);
			int n = int(b.exhaustCarry[i]);
			b.exhaustCarry[i] -= n;
			for (int k = 0; k < min(n, 4); k++)
				RSB_Burst.Fire(reg.FindBurst(fd.exhaustBursts[i]), port, blow, blow, countScale, 1.0, RSB_Hash.Seed(now, 740 + i * 8 + k, posSeed));
		}

		if ((now % EVERY) != 0) return;
		// SMOKE INTO THE ROOM (engine 13b): a thin haze that builds while it runs, thicker revved.
		if (fd.exhaustSmokeAmount > 0 && fd.exhaustSmokeRadius > 0)
			level.EmitSmoke(port + blow * (fd.exhaustSmokeRadius * 0.5), fd.exhaustSmokeRadius, fd.exhaustSmokeAmount * share * smokeMul,
				fd.exhaustSmokeHeat, blow * fd.exhaustSmokeSpeed, (0, 0, 0), fd.exhaustSmokeSoot);
		// HOT AIR at the port, strongest revved.
		if (fd.exhaustShimmerStrength > 0 && fd.exhaustShimmerRadius > 0)
			RSB_Heat.Blast(port + blow * fd.exhaustShimmerRadius, fd.exhaustShimmerRadius, fd.exhaustShimmerStrength * share, EVERY + 4);
	}
}

// THE DULL GLOW OF A HOT BARREL: a light at the muzzle, moved there each tic the gun is out
// (RSB_Barrel.Muzzle); it goes out on its own once nothing holds it (the gun put away).
// Looks only: +NOINTERACTION, no RNG.
class RSB_BarrelGlow : Actor
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

	private int heldTic;

	States
	{
	Spawn:
		TNT1 A -1;
		Stop;
	}

	void Hold(Vector3 at, Color tint, double radius, double intensity)
	{
		SetOrigin(at, true);
		A_AttachLight("rsb_barrelglow", DynamicLight.PointLight, tint, int(radius), 0,
			DynamicLight.LF_ATTENUATE, (0, 0, 0), 0, 10, 25, 0, intensity);
		heldTic = level.maptime;
	}

	override void Tick()
	{
		if (level.maptime - heldTic > 2)
		{
			A_RemoveLight("rsb_barrelglow");
			Destroy();
			return;
		}
		Super.Tick();
	}
}
