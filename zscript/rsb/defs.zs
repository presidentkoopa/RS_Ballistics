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
	String kind;     // round, ballistics, roundlook, wake, burst, impact, flash, flame, trail, ejecta, style
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
	// AIR SHIMMER along its flight (`heat`): a narrow line of bent air over the last
	// heatReach units behind the round, re-laid each tic, fading once it lands. It
	// follows the round, so in slow motion the air tears open behind it. 0 = none.
	double heatRadius;
	double heatStrength;
	int    heatTics;
	double heatReach;
	// A TRACER (`tracer`): every tracerEvery-th round of a hand flies in the tracerLook
	// round look instead; its impact and near-miss sound stay this look's.
	int    tracerEvery;
	String tracerLook;
	// A LIGHT THE ROUND CARRIES in flight (`light`, `lightcolor`): a tracer lighting what
	// it passes. 0 = none.
	double lightRadius;
	double lightIntensity;
	Color  lightColor;
	// A PROJECTILE'S MOTOR (`motor`): a burst out of its tail each tic it flies. And a look
	// taking over MID-FLIGHT plays its `onset` flash there (an RPG's sustainer lighting).
	String motorBurst;
	String onsetFlash;
}

// A WAKE: what a round sheds as it flies.
class RSB_WakeDef : RSB_Def
{
	int    perStep;      // particles laid along each tic's travel
	double spacing;      // map units between motes instead, when above 0: as dense at any speed or time scale
	double sizeStart;
	double sizeEnd;
	double life;         // seconds
	double drift;        // map units per second
	double drag;
	double gravity;
	Color  tint;
	double glow;
	// A PARTICLEDEFS definition for each mote, or "" (then the definition gives size,
	// gravity and drag, and `color` tints it). Hash handle, cached, never tested.
	String particle;
	int    particleHandle;
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

	const SHAPE_CONE  = 0;   // around the aim, `cone` its half-angle
	const SHAPE_DISC  = 1;   // across the aim (along a surface), lifted up to `cone` degrees

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
	int    shape;        // SHAPE_CONE or SHAPE_DISC; only a `particle` burst draws a disc

	// A PARTICLEDEFS definition to draw with, or "". With one, the DEFINITION
	// supplies colour, emissive, size, gravity, drag, orient, stretch and spin; the
	// burst still supplies count, cone, speed, life, aim and offset, and the glow
	// slider still scales it. The handle is a hash of the name -- the same number
	// on every machine -- cached on first use and never tested (netplay rule).
	String particle;
	int    particleHandle;
	// FURTHER DEFINITIONS (`particle = a, b, c`): the burst's count is shared among the
	// first and these, so one burst throws chips of several shapes. Hash handles, cached.
	Array<String> moreParticles;
	Array<int>    moreHandles;
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
	double heatRadius;     // heat shimmer where it lands: a ball fading over heatTics; 0 = none
	double heatStrength;
	int    heatTics;
	double countScale;     // `scale`: every burst's particle count x this (how hard a weapon class bites); 1 = as written
	double sizeScale;      // `scale`: every burst's particle size x this
	String hotspot;        // a hotspot profile each hit feeds (a sustained beam), or ""
	// EVERY HIT ITS OWN, hashed per hit: `vary` wobbles counts, sizes and the light;
	// `maybe` bursts fire on only some hits, each at its own chance.
	double varyCount;
	double varySize;
	double varyLight;
	Array<String> maybeBursts;
	Array<double> maybeChance;
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
	// A PARTICLEDEFS definition for the smoke instead of RSB_Smoke sprites, or "".
	// The handle is a hash of the name, cached and never tested (netplay rule).
	String smokeParticle;
	int    smokeHandle;
	double heatRadius;     // heat shimmer out of the muzzle: a column heatLength long; 0 = none
	double heatLength;
	double heatStrength;
	int    heatTics;
	// EVERY SHOT ITS OWN, hashed per shot: `vary` wobbles each part; `maybe` bursts fire
	// on some shots; `surge` now and then makes a whole shot bigger; `flameroll` turns
	// the flame sprite to a new angle each shot.
	double varyLight, varyFlame, varyCone, varySparks, varySmoke;
	Array<String> maybeBursts;
	Array<double> maybeChance;
	double surgeChance;
	double surgeScale;
	bool   flameRoll;
	// THE SMOKING BARREL (RSB_Barrel): heat a shot adds, heat lost a second, the heat it
	// starts smoking at; the ribbon and its puffs a tic at full heat; the hot air over it.
	double barrelPerShot;
	double barrelCool;
	double barrelSmokeFrom;
	String barrelSmokeParticle;
	int    barrelSmokeHandle;
	double barrelSmokePerTic;
	double barrelShimmerRadius;
	double barrelShimmerStrength;
	// A BARREL RUN HOT glows (`barrelglow`): a dull light at the muzzle from glowFrom heat.
	double barrelGlowFrom;
	double barrelGlowRadius;
	double barrelGlowIntensity;
	Color  barrelGlowColor;
	// THE GROUND KICK (`groundkick`): an impact profile the blast throws off the floor
	// under the muzzle, by the floor's surface, when the floor is within kickReach below.
	String kickImpact;
	double kickReach;
	double kickAlong;      // map units along the level bore from the muzzle to the kick; negative = behind
	// THE BACKBLAST'S HOT AIR (`backheat`): a column out of the rear of the tube, starting
	// backHeatOffset behind the muzzle and running backHeatLength further back.
	double backHeatRadius;
	double backHeatLength;
	double backHeatStrength;
	int    backHeatTics;
	double backHeatOffset;
	// A GUN'S SIZE (`sizecvar`): a cvar holding the gun's size slider; every offset along the
	// bore -- burst offsets, the backheat, the ground kick -- is multiplied by it, so a
	// backblast stays at the rear of a resized tube. "" = size 1.
	String sizeCvar;
	// A THROB (`throb`): the light and cone swell and ease on a beat by the map clock, so a
	// weapon firing every tic reads as one pulsing glow, not a strobe.
	int    throbTics;
	double throbDepth;
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
	// GUN SMOKE out of the port: a puff as the case leaves (`portsmoke`), and a thin wisp
	// the hot case trails for its first tics (`wisp`). PARTICLEDEFS names, hash handles.
	String portSmokeParticle;
	int    portSmokeHandle;
	int    portSmokeCount;
	String wispParticle;
	int    wispHandle;
	int    wispTics;
}

// A TRAIL: what a beam leaves in the air from muzzle to hit -- a fading core line, a
// corkscrew of motes, brief lights along it, heat. Laid by RSB_Trail.Lay (trail.zs).
class RSB_TrailDef : RSB_Def
{
	double lineThick;        // the hot core, map units
	double lineSoft;         // the halo's reach, map units
	double lineIntensity;    // 0 = no core line
	int    lineFadeTics;
	Color  lineColor;
	Color  lineColorEnd;     // along the line, muzzle to hit, when set
	bool   lineColorEndSet;
	double lineHalo;         // SetDrawnLineLook's halo
	double lineSwell;        // how much the halo widens as it fades
	double licksStart;       // the edges' waver, fresh ...
	double licksEnd;         // ... and as it dies
	double lickScale;
	double lickSpeed;
	String helixParticle;    // a PARTICLEDEFS definition, or "" for no helix
	int    helixHandle;      // its hash handle, cached, never tested (netplay rule)
	double helixTurns;       // turns per 100 map units
	double helixRadius;
	double helixSpacing;     // map units between motes
	double helixDrift;       // outward, map units a second
	double helixLife;
	double helixLifeJitter;
	Color  helixColor;
	int    helixMax;
	int    lightCount;
	double lightRadius;
	double lightIntensity;
	int    lightTics;
	Color  lightColor;
	double heatRadius;
	double heatStrength;
	int    heatTics;
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
	double cling;            // seconds a stream puff slides on past the surface it hits; 0 = none
	// THE TUBE: drawn-line segments from the nozzle to where the stream lands.
	int    tubeSegments;     // 0 = no tube; up to 8
	double tubeThick;        // the hot core, map units
	double tubeSoft;         // the halo's reach at the nozzle, map units
	double tubeStreamShare;  // stream particle counts x this while the tube draws
	double tubeIntensity;
	double tubeSwell;        // the halo at the far end over the nozzle's
	double tubeHalo;         // SetDrawnLineLook's halo
	Array<int> tubeColors;   // r, g, b stops, spread evenly from the nozzle to the far end
	double tubeLickStrength; // 0 = no licks
	double tubeLickScale;    // noise cells per map unit
	double tubeLickSpeed;    // rising, cells a second
	// HEAT SHIMMER (RSB_Heat): the plume from the nozzle to where it lands, riding
	// the owner's hand, and a ball of heat there. Strength 0 = none.
	double heatRadiusStart;
	double heatRadiusEnd;
	double heatStrength;
	double heatNoise;        // noise cells per map unit
	double heatRise;         // how fast the shimmer rises
	double heatLandRadius;
	double heatLandStrength;
}

// A HOTSPOT: a spot a sustained beam or stream heats up (an impact's `hotspot`). Many hits
// a second on one place feed ONE spot, whose light, mark, sound and bursts grow with its heat
// and die away as it cools (hotspot.zs).
class RSB_HotspotDef : RSB_Def
{
	double mergeRadius;         // a hit this close to a live spot feeds it
	double heatPerHit;
	double coolPerSecond;
	double heatMax;             // full heat: everything at its strongest
	Array<String> bursts;       // emitted while it burns ...
	Array<double> burstRates;   // ... each this many times a second at full heat
	double lightRadius;         // 0 = no light
	double lightIntensity;
	Color  lightColor;
	int    throbTics;           // the light pulses on this beat (0 = steady)
	double throbDepth;
	int    markShape;           // a STAMP_* id; -1 = no mark
	double markRadiusCold;
	double markRadiusHot;
	Color  markColor;
	int    markEvery;           // tics between stamps
	int    markLife;            // each stamp's life, tics
	double shimmerRadius;       // 0 = none
	double shimmerStrength;
	String loopSound;           // a looping SNDINFO name, or "none"
	double loopVolume;          // at full heat
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
		kinds.Push("trail");
		kinds.Push("hotspot");

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
