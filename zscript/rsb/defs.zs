// ============================================================================
// PROFILES. What RSBDEFS lumps describe, once parsed.
//
// Plain data: nothing here spawns or draws. Required fields start at -1 so a
// profile that never stated them is refused by RSB_Registry.Finish instead of
// running on zeroes; optional effects start switched off.
//
// THIS IS THE PROTOTYPE OF THE ENGINE'S EFFECT FORMAT (ENGINE_SUPPORT_LIST.md,
// "Where everything lives"): the engine is to read effect definitions from a
// lump like this one, the way it reads GLDEFS and DECALDEF. Keep the kinds and
// keys general -- named for what they make, never for a gun.
//
// VARIANTS. A profile's id may carry a style, a surface material and an effects
// tier, in that order: <base>[~style][.material][@tier]
//
//     impact bullet                        the default
//     impact bullet.metal                  on metal
//     impact bullet@heavy                  at the heavy tier
//     impact bullet~cinematic              in the cinematic style
//     impact bullet~cinematic.metal@heavy  all three
//
// RSB_DefSet.Resolve picks the most specific that exists. Material outranks
// style, so a style never wipes out what a surface looks like unless it says
// so for that surface.
//
// FIELD NAMES AVOID ZSCRIPT'S TYPE KEYWORDS. The language is case-insensitive,
// and `name`, `sound` and `color` are types. Hence id, soundName, tint.
// ============================================================================

class RSB_Def abstract
{
	String kind;     // round, wake, burst, impact, flash, ejecta, material
	String id;       // as written, variant suffixes included; matched case-insensitively
	String source;   // the lump it came from
	int    lineNo;   // its header line
}

// A ROUND: what flies.
// THE ROUND A GUN NAMES pairs how it flies and hits with how it looks, so a look
// can be restyled per player without ever touching the game.
class RSB_RoundDef : RSB_Def
{
	String ballistics;   // a ballistics profile, by base name
	String roundLook;    // a roundlook profile, by base name
}

// BALLISTICS: the round as the GAME knows it. Identical on every machine: read by
// base name only (the parser refuses ~style, .material and @tier variants), and
// no player setting reaches it.
class RSB_BallisticsDef : RSB_Def
{
	double speed;        // map units per tic
	double radius;       // map units
	int    damageBase;
	int    damageDice;   // damage = damageBase x 1d(damageDice), unless the shooter sets damageMin/Max
}

// A ROUND LOOK: what a PLAYER sees and hears of a round. Presentation only,
// resolved on each machine by style, effects tier and the menu's Round look.
class RSB_RoundLookDef : RSB_Def
{
	String lookKind;     // "sprite", "model" or "none"
	String lookName;
	bool   glide;        // smoothed between tics
	String wake;         // a wake profile, or "none"
	String impact;       // an impact profile's base name, or "none"
	double whizRadius;   // a round passing this close to the listener's head whizzes; 0 = never
	String whizSound;
}

// A WAKE: what a round sheds as it flies.
class RSB_WakeDef : RSB_Def
{
	int    perStep;      // particles laid along each tic's travel
	double sizeStart;
	double sizeEnd;
	double life;         // seconds
	double drift;        // map units per second
	double drag;
	double gravity;
	Color  tint;
	double glow;
}

// A BURST: one GPU particle emission. The building block impacts and flashes
// list -- sparks, embers, chips, dust, splinters, glints, splashes.
class RSB_BurstDef : RSB_Def
{
	const AIM_NORMAL  = 0;   // out of the surface
	const AIM_REFLECT = 1;   // the round's travel mirrored off the surface
	const AIM_BACK    = 2;   // back the way the round came
	const AIM_ALONG   = 3;   // the way the round (or the barrel) points
	const AIM_UP      = 4;

	int    count;
	double cone;         // half-angle, degrees
	double speed;        // map units per second
	double speedJitter;  // 0..1
	Color  tint;
	double glow;         // brightness; additive
	double life;         // seconds
	double lifeJitter;
	double sizeStart;    // diameter, map units
	double sizeEnd;
	double gravity;      // map units per second^2
	double drag;         // 1/s
	int    orient;       // 0 billboard, 1 streak, 2 flake
	double stretch;      // streak length, seconds of travel
	int    aim;
	double offset;       // map units off the surface before emitting
}

// AN IMPACT: what a landing round does to a surface.
class RSB_ImpactDef : RSB_Def
{
	Array<String> bursts;
	int    markShape;      // a STAMP_* id; -1 = no mark
	double markRadius;
	int    markLife;       // tics
	Color  markColor;
	String soundName;      // an SNDINFO name, or "none"
	double lightRadius;    // 0 = no light
	double lightIntensity;
	int    lightTics;
	Color  lightColor;
	double glanceDeg;      // a round arriving within this many degrees of the surface glances; 0 = never
	String glanceSound;
	String glanceBurst;
}

// A FLASH: the muzzle's light, its lit-air cone, its bursts, flame and smoke.
class RSB_FlashDef : RSB_Def
{
	double lightRadius;
	double lightPunch;     // brightness on the shot tic
	int    lightTics;
	Color  lightColor;
	double coneInner, coneOuter, coneLength, coneDensity;
	int    coneTics;
	Array<String> bursts;
	double flameScale;     // 0 = no flame sprite
	int    smokeCount;
	double smokeScale;
	double smokeAlpha;
}

// EJECTA: a spent casing or hull thrown from a port. Live rounds are the
// reload system's, not this.
class RSB_EjectaDef : RSB_Def
{
	String lookKind;
	String lookName;
	double scale;
	double speedMul;       // x the throw speed the caller gives
	double speedJitter;    // +/- on speedMul
	double bounceFloor;
	double bounceWall;
	int    bounceCount;
	double gravity;
	String soundName;
	int    hotTics;        // fullbright out of the port
	int    lifeTics;       // on the floor before it fades
}

// A MATERIAL: which textures are what. Patterns, case-insensitive, with * and ?.
// A texture no material claims is the default surface (concrete-like). Later
// lumps take priority, so a map pack can reclassify textures.
class RSB_MaterialDef : RSB_Def
{
	Array<String> walls;
	Array<String> flats;

	bool Matches(String texName, bool flat)
	{
		if (flat)
		{
			for (int i = 0; i < flats.Size(); i++)
				if (Glob(flats[i], texName)) return true;
		}
		else
		{
			for (int i = 0; i < walls.Size(); i++)
				if (Glob(walls[i], texName)) return true;
		}
		return false;
	}

	// Both already upper-case. * matches any run, ? any one character.
	static bool Glob(String pat, String s)
	{
		int pn = pat.Length();
		int sn = s.Length();
		int pi = 0;
		int si = 0;
		int star = -1;
		int mark = 0;
		while (si < sn)
		{
			if (pi < pn && (pat.ByteAt(pi) == 63 || pat.ByteAt(pi) == s.ByteAt(si)))
			{
				pi++;
				si++;
			}
			else if (pi < pn && pat.ByteAt(pi) == 42)
			{
				star = pi;
				pi++;
				mark = si;
			}
			else if (star >= 0)
			{
				pi = star + 1;
				mark++;
				si = mark;
			}
			else
			{
				return false;
			}
		}
		while (pi < pn && pat.ByteAt(pi) == 42) pi++;
		return pi == pn;
	}
}

// A FLAME: a flamethrower's stream, where it lands, its light and sounds.
// Stream bursts read their speed and life as MULTIPLIERS: of the fuel speed, and
// of the time the fuel takes to reach where the stream lands.
class RSB_FlameDef : RSB_Def
{
	double reach;            // map units the stream carries
	double fuelSpeed;        // map units per second
	double spread;           // degrees the stream wanders
	Array<String> stream;    // bursts from the nozzle every tic
	Array<String> landing;   // bursts where the stream lands
	int    landingTics;
	int    markShape;        // scorch: a STAMP_* id; -1 = none
	double markRadius;
	int    markLife;
	Color  markColor;
	int    markTics;         // tics between scorch marks
	double lightRadius;      // at the nozzle; 0 = none
	double lightIntensity;
	double flicker;          // 0..1
	Color  lightColor;
	double landLightRadius;  // where it lands; 0 = none
	double landLightIntensity;
	String loopSound;
	String startSound;
	String stopSound;
	Array<String> pilot;     // bursts for RSB_Flame.Pilot
	int    jets;             // streams out of the nozzle, side by side
	double jetSpacing;       // map units between neighbouring jets
	double jetSplay;         // degrees each jet turns away from its neighbour
	double sputterBelow;     // fuel share (0..1) below which the jet coughs; 0 = never
	String sputterSound;     // as a coughing jet catches again
	Array<String> flameout;  // bursts when the trigger lets go
}

// A STYLE: a named look the player picks in the menu. Multipliers over every
// profile, plus any `~style` variants written for it.
class RSB_StyleDef : RSB_Def
{
	double particlesMul;   // particle counts: impacts, flash bursts, wakes
	double glowMul;        // particle brightness
	double lightsMul;      // impact lights
	double marksMul;       // how long surface marks last
	double flashMul;       // muzzle light brightness
	double coneMul;        // lit-air cone density
	double flameMul;       // flame sprite size
	double smokeMul;       // barrel smoke puffs
	double whizMul;        // near-miss distance
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

	// The most specific variant that exists. Material outranks style; tier is the
	// finest refinement of either:
	//   base~style.material@tier, base~style.material,
	//   base.material@tier,       base.material,
	//   base~style@tier,          base~style,
	//   base@tier,                base
	RSB_Def Resolve(String kind, String base, String material, String tierName, String styleName = "")
	{
		RSB_Def d;
		bool hasMat = material.Length() > 0;
		bool hasTier = tierName.Length() > 0;
		bool hasStyle = styleName.Length() > 0;
		String styled = base .. "~" .. styleName;

		if (hasStyle && hasMat)
		{
			if (hasTier)
			{
				d = Find(kind, styled .. "." .. material .. "@" .. tierName);
				if (d) return d;
			}
			d = Find(kind, styled .. "." .. material);
			if (d) return d;
		}
		if (hasMat)
		{
			if (hasTier)
			{
				d = Find(kind, base .. "." .. material .. "@" .. tierName);
				if (d) return d;
			}
			d = Find(kind, base .. "." .. material);
			if (d) return d;
		}
		if (hasStyle)
		{
			if (hasTier)
			{
				d = Find(kind, styled .. "@" .. tierName);
				if (d) return d;
			}
			d = Find(kind, styled);
			if (d) return d;
		}
		if (hasTier)
		{
			d = Find(kind, base .. "@" .. tierName);
			if (d) return d;
		}
		return Find(kind, base);
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
		kinds.Push("style");
		kinds.Push("round");
		kinds.Push("ballistics");
		kinds.Push("roundlook");
		kinds.Push("wake");
		kinds.Push("burst");
		kinds.Push("impact");
		kinds.Push("flash");
		kinds.Push("flame");
		kinds.Push("ejecta");
		kinds.Push("material");

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
			s = s .. kinds[k] .. ": " .. ((ids.Length() > 0) ? ids : "none");
		}
		return s;
	}
}
