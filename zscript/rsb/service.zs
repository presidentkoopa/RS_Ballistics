// ============================================================================
// THE SERVICE. The door other packages use by name, without compiling against
// RS_Ballistics' classes:
//
//     let svc = ServiceIterator.Find("RSB_Service").Next();
//
// A package that REQUIRES RS_Ballistics -- the reload system does -- may call
// the RSB_ classes directly instead. This is for packages that want to work
// with or without it.
//
// Stateless: it answers from RSB_Registry.
//
// Requests today (the bullet and the flash add `launch` and `flash` when they
// move into this package):
//
//   GetString("profiles")                      every profile, by kind, one line
//   GetInt("count", kind)                      how many profiles of that kind
//   GetInt("has", name, 0, 0, null, 'kind')    1 if that profile exists
//   GetDouble("recoil.impulse", name)          lb-s a shot puts into the gun -- what pushes an arm
//   GetDouble("recoil.energy", name)           ft-lb -- what stops it
//   GetDouble("recoil.vg", name)               fps the gun goes backwards
//   GetDouble("recoil.climb", name)            degrees up per shot
//   GetInt("recoil.impulse.milli", name)       the same in thousandths, for a caller with no doubles
//   GetInt("casing.hello")                     1: the shared casing cap is here
//   GetInt("casing.keep", "", 0, 0, actor)     puts a casing ACTOR another mod has just thrown
//                                              in the shared cap (Casings: "Casings in the
//                                              world, most"); 1 when kept. Past the cap the
//                                              oldest fade: RS_Ballistics' own by themselves,
//                                              another mod's by Deactivate(null), which its
//                                              class overrides to start its own fade. Looks
//                                              only, on the machine that threw it.
// ============================================================================

class RSB_Service : Service
{
	override String GetString(String request, string stringArg, int intArg, double doubleArg, Object objectArg, Name nameArg)
	{
		let reg = RSB_Registry.Get();
		if (!reg || !reg.defs) return "";
		if (request ~== "profiles") return reg.defs.Describe();
		return "";
	}

	override int GetInt(String request, string stringArg, int intArg, double doubleArg, Object objectArg, Name nameArg)
	{
		let reg = RSB_Registry.Get();
		if (!reg) return 0;
		if (request ~== "casing.hello") return 1;
		if (request ~== "casing.keep")
		{
			let casing = Actor(objectArg);
			if (!casing) return 0;
			reg.KeepCasing(casing);
			return 1;
		}
		if (!reg.defs) return 0;
		// THE SHOT'S PHYSICS IN THOUSANDTHS, for a caller with no double channel (the pattern
		// RS_ThrowService already set). The double form below is the one to prefer.
		if (request ~== "recoil.vg.milli")      return int(round(RecoilNumber(stringArg, 0) * 1000.0));
		if (request ~== "recoil.energy.milli")  return int(round(RecoilNumber(stringArg, 1) * 1000.0));
		if (request ~== "recoil.impulse.milli") return int(round(RecoilNumber(stringArg, 2) * 1000.0));
		if (request ~== "recoil.climb.milli")   return int(round(RecoilNumber(stringArg, 3) * 1000.0));
		if (request ~== "count") return reg.defs.Count(stringArg);
		if (request ~== "has")
		{
			String kind = nameArg;
			return reg.defs.Find(kind, stringArg) ? 1 : 0;
		}
		return 0;
	}

	// WHAT A SHOT DOES TO THE GUN, for a lane that has to move a body with it.
	//
	//   GetDouble("recoil.impulse", "ww2_mg42")   lb-s leaving the muzzle -- what PUSHES an arm
	//   GetDouble("recoil.energy",  "ww2_mg42")   ft-lb -- what STOPS it
	//   GetDouble("recoil.vg",      "ww2_mg42")   fps the gun itself goes backwards
	//   GetDouble("recoil.climb",   "ww2_mg42")   degrees up per shot, which is derived from vg
	//
	// ZERO MEANS NO DATA, NOT NO RECOIL. A BFG, a plasma rifle and a chainsaw have no cartridge, and
	// a consumer reading zero as "this gun does not kick" would quietly stop moving for all of them.
	// Ask for climb in that case: it is stated for every gun whether or not a cartridge exists.
	//
	// The scope is NOT restated on this override -- the base declares GetDouble as `play`, and saying
	// so again is "Attempt to change scope for virtual function".
	override double GetDouble(String request, string stringArg, int intArg, double doubleArg, Object objectArg, Name nameArg)
	{
		if (request ~== "recoil.vg")      return RecoilNumber(stringArg, 0);
		if (request ~== "recoil.energy")  return RecoilNumber(stringArg, 1);
		if (request ~== "recoil.impulse") return RecoilNumber(stringArg, 2);
		if (request ~== "recoil.climb")   return RecoilNumber(stringArg, 3);
		return 0.0;
	}

	private double RecoilNumber(String name, int which)
	{
		let reg = RSB_Registry.Get();
		if (!reg || !reg.defs) return 0.0;
		let rc = RSB_RecoilDef(reg.defs.Find("recoil", name));
		if (!rc) return 0.0;
		if (which == 0) return rc.vg;
		if (which == 1) return rc.energy;
		if (which == 2) return rc.impulse;
		return rc.climb;
	}
}
