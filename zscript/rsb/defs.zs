// ============================================================================
// PROFILES. What RSBDEFS lumps describe, once parsed.
//
// Plain data: nothing here spawns or draws. The bullet, the flash and the impact
// read these. Required fields start at -1 so a profile that never stated them is
// refused by RSB_Registry.Finish instead of running on zeroes; optional effects
// start switched off (a count of 0, a mark shape of -1, a sound of "none").
//
// FIELD NAMES AVOID ZSCRIPT'S TYPE KEYWORDS. The language is case-insensitive,
// and `name`, `sound` and `color` are types: a field called `name` or `sound`
// is a compile error waiting to happen. Hence id, soundName, tint.
// ============================================================================

class RSB_Def abstract
{
	String kind;     // round, wake, impact, flash
	String id;       // the profile's name as written; matched case-insensitively
	String source;   // the lump it came from
	int    lineNo;   // its header line
}

// A ROUND: what flies.
class RSB_RoundDef : RSB_Def
{
	double speed;        // map units per tic
	double radius;       // map units
	int    damageBase;
	int    damageDice;   // damage = damageBase x 1d(damageDice)
	String lookKind;     // "sprite" or "model"
	String lookName;     // a four-letter sprite, or a MODELDEF model name
	bool   glide;        // smoothed between tics
	String wake;         // a wake profile, or "none"
	String impact;       // an impact profile, or "none"
}

// A WAKE: what a round sheds as it flies.
class RSB_WakeDef : RSB_Def
{
	int    perStep;      // particles each time the round moves a sub-step
	double sizeStart;    // diameter, map units
	double sizeEnd;
	double life;         // seconds
	double drift;        // map units per second
	double drag;         // 1/s
	double gravity;      // map units per second^2
	Color  tint;
	double glow;
}

// AN IMPACT: what happens where a round lands on a surface.
class RSB_ImpactDef : RSB_Def
{
	int    sparkCount;
	double sparkSpread;  // degrees
	double sparkSpeed;   // map units per second
	double sparkLife;    // seconds
	Color  sparkColor;
	double sparkGlow;
	int    markShape;    // a STAMP_* id; -1 = no mark
	double markRadius;   // map units
	int    markLife;     // tics
	Color  markColor;
	String soundName;    // an SNDINFO name, or "none"
}

// A FLASH: the muzzle's light, its lit-air cone and its hot core.
class RSB_FlashDef : RSB_Def
{
	double lightRadius;  // map units
	double lightPunch;   // brightness on the shot tic
	int    lightTics;
	Color  lightColor;
	double coneInner;    // degrees
	double coneOuter;    // degrees
	double coneLength;   // map units
	double coneDensity;
	int    coneTics;
	int    coreCount;
	double coreLife;     // seconds
}

// EVERY PROFILE READ, of every kind. A later profile with the same kind and id
// replaces an earlier one, so a package loaded later can override a look.
class RSB_DefSet
{
	Array<RSB_Def> defs;

	RSB_Def Find(String kind, String id)
	{
		for (int i = 0; i < defs.Size(); i++)
			if (defs[i].kind ~== kind && defs[i].id ~== id) return defs[i];
		return null;
	}

	// True when it replaced an earlier profile of the same kind and id.
	bool Put(RSB_Def d)
	{
		for (int i = 0; i < defs.Size(); i++)
		{
			if (defs[i].kind ~== d.kind && defs[i].id ~== d.id)
			{
				defs[i] = d;
				return true;
			}
		}
		defs.Push(d);
		return false;
	}

	int Count(String kind)
	{
		int n = 0;
		for (int i = 0; i < defs.Size(); i++)
			if (defs[i].kind ~== kind) n++;
		return n;
	}

	// One line naming every profile by kind, for logs and the service.
	String Describe()
	{
		Array<String> kinds;
		kinds.Push("round");
		kinds.Push("wake");
		kinds.Push("impact");
		kinds.Push("flash");

		String s = "";
		for (int k = 0; k < kinds.Size(); k++)
		{
			String ids = "";
			for (int i = 0; i < defs.Size(); i++)
			{
				if (!(defs[i].kind ~== kinds[k])) continue;
				if (ids.Length() > 0) ids = ids .. ", ";
				ids = ids .. defs[i].id;
			}
			if (s.Length() > 0) s = s .. " | ";
			s = s .. kinds[k] .. "s: " .. ((ids.Length() > 0) ? ids : "none");
		}
		return s;
	}
}
