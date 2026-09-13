// ============================================================================
// RS_BALLISTICS' DIAGNOSTIC LAYER.
//
// The same shape as the reload system's WM_Log, with its own cvar (rsb_log) and
// its own once-per-map memory (on RSB_Registry). This package is only ever seen
// working through a headset, so what comes back out is text, and the text has
// to be worth reading.
//
//   0  off
//   1  ERROR   something is refused or broken
//   2  WARN  + suspicious but survivable
//   3  INFO  + profiles loaded, the first use of each
//   4  TRACE + everything, including a dump of every profile
//
// LV_ PREFIXES on the constants because ZScript is case-insensitive: a constant
// ERR and a method Err() would be the same identifier.
// ============================================================================

class RSB_Log
{
	const LV_OFF   = 0;
	const LV_ERR   = 1;
	const LV_WARN  = 2;
	const LV_INFO  = 3;
	const LV_TRACE = 4;

	static int Level()
	{
		let c = CVar.GetCVar("rsb_log", players[consoleplayer]);
		return c ? c.GetInt() : LV_INFO;
	}

	private static String Tag(int lvl)
	{
		if (lvl <= LV_ERR)  return "\c[Red]RSB ERROR\c-";
		if (lvl == LV_WARN) return "\c[Gold]RSB warn\c-";
		if (lvl == LV_INFO) return "\c[Orange]RSB\c-";
		return "\c[DarkGray]RSB ..\c-";
	}

	static void Say(int lvl, String msg)
	{
		if (Level() < lvl) return;
		Console.Printf("%s %s", Tag(lvl), msg);
	}

	static void Err(String m)   { Say(LV_ERR,   m); }
	static void Warn(String m)  { Say(LV_WARN,  m); }
	static void Info(String m)  { Say(LV_INFO,  m); }
	static void Trace(String m) { Say(LV_TRACE, m); }

	// SAID ONCE PER MAP, by key. A complaint inside a tic function runs 35 times
	// a second, and 35 copies push the line that mattered off the console. The
	// memory lives on RSB_Registry because ZScript has no static mutable state;
	// with no registry, it is said anyway -- better loud than lost.
	play static void Once(int lvl, String key, String msg)
	{
		if (Level() < lvl) return;
		let r = RSB_Registry.Get();
		if (r && r.AlreadySaid(key)) return;
		Say(lvl, msg);
	}
}
