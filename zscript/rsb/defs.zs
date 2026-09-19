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
	// 0 ON speed OR radius MEANS `none`: THE ACTOR OWNS IT. Below zero means never stated, which is
	// still refused. See the hatch in RSB_Parser.ApplyBallistics -- a look package must always be able
	// to say "the actor owns this", and this is the third key that has needed it.
	double speed;        // map units per tic; 0 = the actor's own Speed stands
	double radius;       // map units; 0 = the actor's own Radius stands
	// THE ROUND'S HEIGHT, and it exists to make an accident DECLARED rather than to correct it.
	// A_SetSize was being called as (radius, radius), so a round's radius silently set its height too
	// and nothing said so. Defaulting this to the radius is bit-identical to that, and now anyone who
	// wants a real ellipsoid can state one without a single existing round changing size.
	double height;       // -1 = not stated, so the radius is used
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
	// A BEAM THE ROUND DRAWS FOR ITSELF (`trail`): laid muzzle-to-landing the moment it arrives.
	//
	// THIS EXISTS BECAUSE I BUILT TWO BEAMS AND THEN HANDED THE LAST MILE AWAY TWICE. `RSB_Trail.Lay`
	// has to be called by the GUN, so a beam needed a line of code in somebody else's package before
	// it drew anything -- and until that line existed the Tesla and the particle gun were a trail
	// profile nobody laid, which is to say nothing at all.
	//
	// The round already knows both ends: `spawnedAt` is the firing hand and `pos` is where it landed.
	// So it can lay its own beam and a gun gets one by naming a `roundprofile` -- no gun code, no
	// cross-lane change, and it cannot be half-wired into a weapon that fires an invisible nothing.
	//
	// The gun-side call stays for a weapon that needs its own timing (the rail gun's charge). This is
	// the path for a weapon whose beam simply IS its shot.
	String trail;
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
	// HOW THAT LIGHT FLIES (`lightlook`, engine effect lights): attached (a point light riding the round),
	// streak (a short fading streak), comet (a long comet tail) or head (a glow at the head).
	int    lightLook;
	const LIGHTLOOK_ATTACHED = 0;
	const LIGHTLOOK_STREAK   = 1;
	const LIGHTLOOK_COMET    = 2;
	const LIGHTLOOK_HEAD     = 3;
	// A PROJECTILE'S MOTOR (`motor`): a burst out of its tail each tic it flies. And a look
	// taking over MID-FLIGHT plays its `onset` flash there (an RPG's sustainer lighting).
	String motorBurst;
	String onsetFlash;
	// MORE OF THE MOTOR (`motormaybe`): bursts some tics fire as well, each at its chance.
	Array<String> motorMaybe;
	Array<double> motorMaybeChance;
	// CARVING THE ROOM'S SMOKE (engine 13b, `carve`): each tic of flight, a tunnel this wide.
	double carveRadius;
	double carveAmount;
	// SMOKE INTO THE ROOM along its flight (engine 13b/13e, `smoke`): each tic a capsule over the
	// step behind it -- a rocket's trail hanging in the room. 0 amount = none.
	double smokeRadius;
	double smokeAmount;
	double smokeHeat;
	double smokeSoot;
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
	// SPARK LIGHTS (Lights -> "Spark lights", rsb_spark_lights; optimization plan M5): capped, a spark or ember definition
	// draws its `_capped` twin. Per definition slot (0 the first, then the further ones): 0 not looked at yet, 1 it has a
	// twin (its hash handle in cappedHandles), 2 it has none.
	Array<int>    cappedState;
	Array<int>    cappedHandles;
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
	// THE ROOM ANSWERING A BLAST (`tail`): a second sound at the same place, whose files carry their
	// own head silence, so the roll arrives after the crack the way a real one comes back off the
	// walls. A near listener hears crack then roll; a far one hears mostly roll, because the crack
	// attenuates faster than the low rumble does -- distance changes an explosion shape, not just
	// its volume, with no per-listener code. Blast profiles only: a bullet hit has nothing to roll.
	// A BLAST RIPPLE where it lands (`ripple`): the air bending in a ring off an explosion. Look only,
	// anchored to the world rather than to anyone's hand -- it happened out there, not at a muzzle.
	double rippleRadius;   // 0 = none
	double rippleStrength;
	int    rippleTics;
	double rippleThickness;
	double rippleChroma;
	String tailSound;      // "" = none
	double tailVolume;     // x the Gunshot tails slider (the same room-answering knob)
	double lightRadius;    // 0 = no light
	double lightIntensity;
	int    lightTics;
	Color  lightColor;
	double glanceDeg;      // a round arriving within this many degrees of the surface glances; 0 = never
	String glanceSound;
	String glanceBurst;
	// LASTING DAMAGE (engine #17, `damage`): a hole, crater or scorch painted into the surface for the
	// map -- `glancedamage` instead when the round glances. A DAMAGEDEFS brush, its radius (map units),
	// depth, soot, heat and wet (0..1), and which way the brush's +x lies (RSB_Impact.DAMAGE_ALONG_*).
	String damageBrush;
	double damageRadius;          // 0 = none
	double damageDepth;
	double damageSoot;
	double damageHeat;
	double damageWet;
	int    damageAlong;
	String glanceDamageBrush;
	double glanceDamageRadius;    // 0 = a glance paints `damage` like any hit
	double glanceDamageDepth;
	double glanceDamageSoot;
	double glanceDamageHeat;
	double glanceDamageWet;
	int    glanceDamageAlong;
	// SENSORY IMPULSES (engine build 4; `exposure`, `hearing`): flash blindness -- strength 0..16, reach 16..8192, recovery
	// 0.25..4, tint -- and ringing ears -- strength, reach, recovery. 0 strength = none. Presentation only.
	double exposureStrength;
	double exposureReach;
	double exposureRecovery;
	Color  exposureTint;
	double hearingStrength;
	double hearingReach;
	double hearingRecovery;
	// EMISSIVE VOLUMES (engine #15, `volume`): VOLUMEDEFS definitions spawned where it lands (a blast's fireball).
	Array<String> volumeNames;
	Array<int>    volumeHandles;
	double        varyVolume;
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
	// SMOKE INTO THE ROOM (engine 13b, `smokevolume`): radius, amount, heat; 0 amount = none.
	double smokeVolRadius;
	double smokeVolAmount;
	double smokeVolHeat;
	double smokeVolSoot;     // its share of soot, 0..1 (engine 13e): black smoke that sends back no light
	double pushRadius;       // `push`: a blast shoving the room's smoke (and debris); 0 = none
	double pushStrength;
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
	// EACH SHOT ITS OWN SPRAY (`sparkvary`): how far a shot's spark bursts may lean off the bore
	// (degrees), and how much their spread, speed, size, glow, life and share of the mix vary per shot.
	double sparkLean;
	double sparkSpread;
	double sparkSpeed;
	double sparkSize;
	double sparkGlow;
	double sparkLife;
	double sparkMix;
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
	// WHERE THE BACK OF THE WEAPON IS: map units behind the muzzle, positive. NOT a heat
	// parameter, though `backheat` is what first set it and what it used to be named after.
	//
	// It is the one place a profile says how long its tube is, and three things read it: the
	// hot air out of the rear, an emissive volume tagged `back`, and a rear-aimed burst that
	// does not carry its own offset. Before it was named for what it is, the tube length was
	// restated in FIVE keys of `flash rocket_rpg` -- and with INCONSISTENT SIGNS, because this
	// field is positive and gets negated in code while `groundkick`, `push` and `smokevolume`
	// all take it negative. A second launcher copying that recipe gets a backblast out of the
	// FRONT and no error, which is why `backblast` now fills all of them from this one number.
	double rearOffset;
	// THE BACKBLAST'S HOT AIR (`backheat`): a column out of the rear of the tube, starting
	// rearOffset behind the muzzle and running backHeatLength further back.
	double backHeatRadius;
	double backHeatLength;
	double backHeatStrength;
	int    backHeatTics;
	// A GUN'S SIZE (`sizecvar`): a cvar holding the gun's size slider; every offset along the
	// bore -- burst offsets, the backheat, the ground kick -- is multiplied by it, so a
	// backblast stays at the rear of a resized tube. "" = size 1.
	String sizeCvar;
	// A CHARGE (RSB_Barrel.Charge, every tic a gun winds up): bursts gathering at the muzzle,
	// each this many times a second at full charge; a light swelling; the air bending.
	Array<String> chargeBursts;
	Array<double> chargeRates;
	double chargeLightRadius;
	double chargeLightIntensity;
	Color  chargeLightColor;
	double chargeShimmerRadius;
	double chargeShimmerStrength;
	// AN ENGINE'S EXHAUST (RSB_Exhaust.Run, every tic a motor runs, with its throttle): bursts
	// out of the port, each this many times a second at full throttle and `exhaustIdle` of that
	// at idle; a dark blip when the throttle snaps open or the engine catches; smoke into the
	// room; hot air at the port.
	Array<String> exhaustBursts;
	Array<double> exhaustRates;
	double exhaustIdle;
	String exhaustBlip;
	double exhaustBlipRise;
	double exhaustSmokeRadius;
	double exhaustSmokeAmount;
	double exhaustSmokeHeat;
	double exhaustSmokeSpeed;
	double exhaustSmokeSoot;
	// A GUNSHOT TAIL (`tail`): the room answering the shot -- a SNDINFO group with /int and /ext ($random
	// each) and its volume. "" = none (RSB_Tail, flash.zs).
	String tailSound;
	double tailVolume;
	// POINT-BLANK POWDER BURNS (`powderburn`): a surface straight ahead within `reach` takes a soot ring and powder
	// stipple (engine #17), stronger the closer the muzzle is.
	double powderReach;
	double powderRadius;
	double powderSoot;
	// THE BLAST HITTING WHAT IS NEAR (`blastkick`): walls beside and a ceiling above within `reach` shed an impact
	// (dust), and casings within reach are thrown off the muzzle (`shove`, map units a tic at the muzzle).
	String blastImpact;
	double blastReach;
	double blastShove;
	// BARRELS (`barrels`): each shot flashes from the next of `count` barrels, `radius` out from the bore.
	int    barrelCount;
	double barrelRadius;
	// POWDER VARIETY (`powdervary`): how far a shot's light swings redder or whiter, 0..1.
	// HOW LONG THE SMOKE WAITS (`smokedelay`, tics). -1 = not stated, and then it waits for the flash's
	// own light to finish -- which is the right answer for every gun and the reason it is the default
	// rather than an opt-in. See RSB_Flash.LaySmoke: a cloud born on the shot tic, six units from the
	// muzzle, sits inside a 150-330 radius light at ~98% of full brightness, an arm's length from the
	// player's eyes. 0 restores the old behaviour for anything that genuinely wants it.
	int    smokeDelay;
	double powderVary;
	// A SHOCKWAVE (`shockwave`): a bubble of bent air growing to `radius` over `tics`, fading as it grows.
	double shockRadius;
	double shockThickness;   // 0 = the engine's own default ring thickness
	double shockChroma;      // 0..1, how much this blast may split colour
	double shockStrength;
	int    shockTics;
	// EMISSIVE VOLUMES (engine #15, `volume`): VOLUMEDEFS definitions spawned with the flash -- `back` ones out of the
	// tube's rear at the backheat offset -- and `vary volume`. Where one draws, the flame card and the cone stand down.
	Array<String> volumeNames;
	Array<int>    volumeBack;
	// SENSORY IMPULSES (engine build 4; `exposure`, `hearing`): flash blindness -- strength 0..16, reach 16..8192, recovery
	// 0.25..4, tint -- and ringing ears -- strength, reach, recovery. 0 strength = none. Presentation only.
	double exposureStrength;
	double exposureReach;
	double exposureRecovery;
	Color  exposureTint;
	double hearingStrength;
	double hearingReach;
	double hearingRecovery;
	Array<int>    volumeHandles;   // EmissiveVolumeDefinition handles (a hash of the name, alike everywhere), filled on first use
	double        varyVolume;
	double exhaustShimmerRadius;
	double exhaustShimmerStrength;
	// A THROB (`throb`): the light and cone swell and ease on a beat by the map clock, so a
	// weapon firing every tic reads as one pulsing glow, not a strobe.
	int    throbTics;
	double throbDepth;
	// SMOKE INTO THE ROOM (engine 13b, `smokevolume`): radius, amount, heat; 0 amount = none.
	double smokeVolRadius;
	double smokeVolAmount;
	double smokeVolHeat;
	double smokeVolSoot;     // its share of soot, 0..1 (engine 13e): black smoke that sends back no light
	double smokeVolSpeed;    // out along the bore, map units a second
	double smokeVolAlong;    // from the muzzle along the bore (negative behind), x the gun's size
	double pushRadius;       // `push`: shove the room's smoke (and debris) outward; 0 = none
	double pushStrength;
	double pushAlong;
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
	// ONE CAPSULE LIGHT ALONG THE WHOLE BEAM (`beamlight`), instead of N point lights beaded along it.
	//
	// `lights` puts lightCount point lights down the path, which is what you do when the engine has only
	// point lights -- and ours does not. UZDXREMA has SEGMENT LIGHTS: level.SpawnEffectLight takes a
	// posEnd, and everything between the two points lights the room as one capsule. A beam is the exact
	// shape that was invented for.
	//
	// It is CHEAPER AND BETTER AT ONCE, which is rare. Sixteen point lights is the cap the `lights` key
	// enforces, so a long arc gets a light every sixty-odd units and at close range you can SEE the
	// beads; one segment light has no beads at any length and costs one light instead of sixteen.
	//
	// ADDITIVE AND DEFAULT-OFF: a trail that does not say `beamlight` behaves exactly as it did, so the
	// rail and the BFG ray are untouched until someone looks at them deliberately. Both should probably
	// move over, but their brightness was tuned against overlapping point lights and that is a change
	// the owner should see rather than inherit.
	double beamRadius;      // 0 = no beam light
	double beamIntensity;
	int    beamTics;
	double beamEnd;         // brightness at the far end as a share of the near end; 1 = even
	// THE ARC IS NOT A TUBE (`beamjag`, `beamcolorend`). A capsule is straight, and one straight capsule
	// is right for a rail slug and WRONG for lightning: a bolt is a jagged thing, and the light it
	// throws is jagged with it. So the beam can be laid as a CHAIN of capsules, each one pushed off the
	// axis, and the room is lit by the shape of the bolt rather than by a cylinder through it.
	//
	// Chaining buys the colour too, and that is the better half. One capsule takes one colour; a chain
	// takes one PER LINK, so the arc runs white-hot at the muzzle and violet by the time it lands --
	// which is what electricity actually does and what no single light could show.
	//
	// Still far cheaper than it sounds: six links is six lights against the sixteen `lights` beads at
	// its cap, and unlike the beads there are no gaps between them at any range.
	// A BEAM THAT BREATHES (`linepulse`): period in tics and depth 0..1. The core's brightness rides a
	// sine, and as it dims the FAR END'S HALO SWELLS to fill what the core gave up.
	//
	// That second half is what makes it read as two colours FIGHTING rather than one colour blinking.
	// The gradient's own third value is halo swell, not a colour mix, so the near colour and the far
	// colour cannot be cross-faded directly -- but pushing brightness into the core and reach into the
	// far halo, in antiphase, trades dominance between them along the beam, which is the same thing to
	// look at and costs nothing.
	int    pulseTics;       // 0 = steady
	double pulseDepth;      // how much of the core's brightness the beat takes, 0..1
	double pulseSwell;      // how far the far halo blooms as the core dims
	int    beamSegments;    // 1 = one straight capsule (the default, and right for a rail beam)
	double beamJag;         // map units a link may wander off the axis
	Color  beamColorEnd;    // colour at the far end; defaults to lightColor
	bool   beamColorEndSet;
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
	// SMOKE INTO THE ROOM (engine 13b, `smokevolume`): radius, amount, heat; 0 amount = none.
	double smokeVolRadius;
	double smokeVolAmount;
	double smokeVolHeat;
	double smokeVolSoot;     // its share of soot, 0..1 (engine 13e): black smoke that sends back no light
	// LASTING SCORCH (engine #17, `damage`): painted where it lands on the scorch beat (`scorchtics`).
	String damageBrush;
	double damageRadius;       // 0 = none
	double damageDepth;
	double damageSoot;
	double damageHeat;
	double damageWet;
	int    damageAlong;        // RSB_Impact.DAMAGE_ALONG_*; travel = along the stream
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
	// SMOKE INTO THE ROOM (engine 13b, `smokevolume`): radius, amount, heat; 0 amount = none.
	double smokeVolRadius;
	double smokeVolAmount;
	double smokeVolHeat;
	double smokeVolSoot;     // its share of soot, 0..1 (engine 13e): black smoke that sends back no light
	// LASTING DAMAGE while it burns (engine #17, `damage`): painted every RSB_Hotspot.DAMAGE_EVERY tics, the
	// radius growing from cold to hot and depth, soot and heat by its heat (a chainsaw's cut deepening).
	String damageBrush;
	double damageRadiusCold;   // 0 = none
	double damageRadiusHot;
	double damageDepth;
	double damageSoot;         // each paint, at full heat (soot adds up)
	double damageHeat;
	double damageWet;
	int    damageAlong;        // RSB_Impact.DAMAGE_ALONG_*; travel = along the way the spot is swept
}

// RECOIL (GAMEPLAY, recoil.zs): how a gun's kick turns where its rounds go, and how the kick
// looks. Base names only -- no ~style, .material or @tier variants, which follow local settings.
class RSB_RecoilDef : RSB_Def
{
	double climb;          // degrees up each shot adds
	double drift;          // degrees of sideways walk ...
	double driftPeriod;    // ... over this many shots: a sine by shot number (0 = none)
	double recoverRate;    // degrees a second back toward dead on ...
	int    recoverDelay;   // ... starting this many tics after the last shot
	double maxPitch;       // the kick's cap, up
	double maxYaw;         // and sideways
	double bloom;          // extra spread degrees per degree of kick
	// `kick = none`: THE WEAPON OWNS WHERE ITS SHOTS GO, and this profile only shakes the view.
	//
	// The same hatch as `damage = none`, for the same reason, one layer down. climb, drift, max,
	// recover and bloom do not nudge a view -- they feed RSB_Recoil.Turn, which rewrites the round's
	// Vel, angle and pitch. So a weapon mod with its own kick model had no way to say so: the two
	// composed silently and this one won the tie. A gun promising its first shots are dead on does not
	// get them once this profile's climb has built.
	//
	// Stated, Step returns nothing and accumulates nothing. `view` and `viewjolt` still fire, because
	// the visible shove of the prop is this package's job and never touches where a bullet goes.
	bool   kickOwned;
	double braceCrouch;    // the kick crouched, times
	double braceStill;     // the kick standing still, times
	// THE PHYSICS OF THE SHOT (`shot`), which is NOT this package's to use and is published anyway.
	//
	// climb above is already derived from these three offline, in a Python table, which means the only
	// copy of them lives outside the engine -- so the Body IK lane, which needs impulse to displace an
	// arm, would have had to be handed a stale table by hand. A fact about a shot belongs on the shot.
	//
	//   vg        free recoil velocity, fps -- how fast the gun itself goes backwards. This is what
	//             drives climb. Energy is what the shoulder absorbs; velocity is the muzzle rising.
	//   energy    free recoil energy, ft-lb -- what STOPS the arm, not what moves it.
	//   impulse   lb-s, the momentum leaving the muzzle: (grains x fps + 4700 x charge) / 7000 / 32.174.
	//             INDEPENDENT OF GUN WEIGHT -- it is a cartridge fact. Weight decides how fast the gun
	//             moves in answer to it, which is why an MG42 and a Kar98k share an impulse of 3.17 and
	//             are three times apart in energy. This is the number that pushes an arm.
	//
	// Zero means not stated, and a consumer must treat zero as "no data", never as "no recoil": a BFG
	// has no cartridge and inventing one to make the arithmetic run would be false precision.
	double vg, energy, impulse;
	double viewBack;       // THE LOOK (render only): map units back ...
	double viewRise;       // ... degrees up ...
	double viewRoll;       // ... degrees of roll ...
	int    viewTics;       // ... over this many tics
}

// A STYLE: a named look the player picks in the menu. Multipliers over every
// profile, plus any `~style` variants written for it.
// A FIXTURE LIST (`fixture`): which textures are LAMPS, as opposed to surfaces that merely read as
// lit. SURFACES.txt's `light` material is generous on purpose -- a bright ceiling tile deserves the
// pop and the bulb glass -- but only a lamp darkens a room when it dies, and using the generous list
// for that would make a room's own ceiling a fixture. Patterns are exact or end in * (LITEBLU*).
class RSB_FixtureDef : RSB_Def
{
	Array<String> textures;
	// LIT DECORATIONS (`actors`): torches, tech lamps, burning barrels -- props that carry their own
	// GLDEFS light. Shooting one kills the light with no sector arithmetic at all, which is why they
	// are the easy half of the lights work and were the last part nobody had picked up.
	Array<String> actors;
}

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

	// SPEED (Engine docs/EFFECTS_OPTIMIZATION_PLAN.md, M3). Every hit, flash, wake, casing and burst asks Find or
	// Resolve, and each Find scanned every profile (about 680) comparing names; a hit asked up to six Resolves' worth
	// plus one Find per burst. Now: an INDEX by kind and id, and a CACHE of what each request resolved to (misses
	// included), both keyed lower-case so they match `~==` as the scan did. Anything that changes the set -- Put, or
	// deleting from `defs` directly (the registry's completeness pass) -- calls Changed, so nothing stale is found.
	// Looks only: the same profiles resolve as before, on every machine.
	private Map<String, Object> index;      // "kind:id" -> RSB_Def
	private Map<String, Object> resolved;   // "kind|base|material|tier|style" -> RSB_Def or null
	private bool indexed;

	void Changed()
	{
		indexed = false;
		index.Clear();
		resolved.Clear();
	}

	private void BuildIndex()
	{
		index.Clear();
		for (int i = 0; i < defs.Size(); i++)
		{
			String key = defs[i].kind .. ":" .. defs[i].id;
			key = key.MakeLower();
			if (!index.CheckKey(key)) index.Insert(key, defs[i]);
		}
		indexed = true;
	}

	RSB_Def Find(String kind, String id)
	{
		if (!indexed) BuildIndex();
		String key = kind .. ":" .. id;
		key = key.MakeLower();
		if (!index.CheckKey(key)) return null;
		return RSB_Def(index.Get(key));
	}

	// The most specific variant that exists (ResolveUncached), remembered per request.
	RSB_Def Resolve(String kind, String base, String material, String tierName, String styleName = "")
	{
		String key = kind .. "|" .. base .. "|" .. material .. "|" .. tierName .. "|" .. styleName;
		key = key.MakeLower();
		if (resolved.CheckKey(key)) return RSB_Def(resolved.Get(key));
		RSB_Def d = ResolveUncached(kind, base, material, tierName, styleName);
		resolved.Insert(key, d);
		return d;
	}

	// The most specific variant that exists. Material outranks style; tier is the
	// finest refinement of either:
	//   base~style.material@tier, base~style.material,
	//   base.material@tier,       base.material,
	//   base~style@tier,          base~style,
	//   base@tier,                base
	private RSB_Def ResolveUncached(String kind, String base, String material, String tierName, String styleName)
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
		Changed();
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
		kinds.Push("fixture");
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
		kinds.Push("recoil");

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
