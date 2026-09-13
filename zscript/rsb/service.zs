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
		if (!reg || !reg.defs) return 0;
		if (request ~== "count") return reg.defs.Count(stringArg);
		if (request ~== "has")
		{
			String kind = nameArg;
			return reg.defs.Find(kind, stringArg) ? 1 : 0;
		}
		return 0;
	}
}
