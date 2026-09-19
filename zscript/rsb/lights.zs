// ============================================================================
// SHOOTING THE LIGHTS OUT. A round into a lamp kills that lamp, and the room it
// lit gets darker by that lamp's share.
//
// THIS IS THE ONLY PART OF RS_Ballistics THAT IS NOT PRESENTATION, and everything
// about its shape follows from that one fact.
//
//   A sector's light level is LEVEL STATE. It goes in savegames, it must match on
//   every machine, and in co-op one player shooting a lamp darkens it for everyone.
//   Our impact LOOKS are the opposite: client-side, and deliberately allowed to
//   differ -- view culling, distance LOD and the effects dial all skip them. So the
//   break must NEVER ride on the look path, or two players end up disagreeing about
//   whether a room is dark. RSB_Impact calls ShootOut() before it spawns anything.
//
//   And the record of what is broken lives on a THINKER, not on an event handler.
//   Handler fields are not serialized (src/events.cpp serializes nothing), so a
//   registry kept there forgets every dead lamp the moment a save is loaded -- while
//   the darkened sector, which IS saved, stays dark. The room would be black with
//   every lamp reporting alive. A Thinker is saved with the level, so the dark room
//   and the tally come back together.
//
// TWO LISTS, NOT ONE. SURFACES.txt's `light` material is tuned for the LOOK and is
// deliberately generous -- it includes ceilings and floors that merely read as
// bright, because those deserve the pop and the bulb glass when shot. The FIXTURE
// list (RSBDEFS `fixture` blocks) is strict, and it alone decides what darkens a
// room. Anything can be a lit-looking surface; only a lamp is a fixture.
//
// A SHARE PER FIXTURE. A room's fixtures are counted the first time one of them is
// broken, and each break takes its share of that room's drop. Shoot one lamp of
// four and the room dims a quarter; shoot them all and it reaches its floor. That is
// "shoot the lights out" rather than "shoot a lamp, room goes black".
//
// A CEILING PANEL IS GRIDDED. A wall lamp is one sidedef among many, but a light
// panel usually IS the whole ceiling -- one surface for the entire room, which would
// collapse it on a single shot. So a flat fixture's identity is the HIT snapped to a
// 256-unit world grid: each cell dies once, and the player has to walk their fire
// across the panel to take the room down.
//
// FLICKERING AND STROBING ROOMS DIM TOO, and keep flickering. Writing `lightlevel` was
// hopeless in those rooms -- the special recomputes its own light every tic and wipes it,
// and script cannot reach the specials at all, `class Lighting : SectorEffect native { }`
// being empty -- so this needed an engine change (the per-sector light trim, exe 13:55).
// The trim is applied AFTER the special decides, so a strobe keeps its rhythm and simply
// runs darker.
//
// AND IT TAKES A SHARE, NOT A NUMBER OF LIGHT UNITS, which is the right shape and was not
// what the first version did: a bright room loses more than a dim one when its lamps die,
// which is what looks right. `SetLightTrim(0, 0)` puts a room back exactly where the map
// left it, and the trimmed value IS `lightlevel`, so the smoke's ambient and any darkness
// curve see a shot-out room as dark with no call of their own.
// ============================================================================

class RSB_Lights : Thinker
{
	// THE DEAD, as two parallel int arrays rather than objects: an Array<int> on a Thinker
	// serializes, a plain Object referenced by one does not reliably.
	//   deadA   a wall's line index, or -(sector index + 1) for a flat
	//   deadB   a wall's side and part; a flat's plane and grid cell
	private Array<int> deadA;
	private Array<int> deadB;
	// Per sector, filled lazily the first time a fixture in it breaks. -1 = not counted yet.
	private Array<int> tally;
	private Array<int> dead;
	// A ROOM IN THE ACT OF GOING DARK. A filament does not stop, it gutters: the room stutters
	// between what it was and what it is becoming for a few tics and then settles. Playsim state,
	// stepped on world tics from a fixed table -- no RNG, nothing per player, identical everywhere.
	private Array<int> setSec;
	private Array<double> setFrom;
	private Array<double> setTo;
	private Array<int> setAge;


	const CELL = 256.0;        // a ceiling panel's grid, map units
	const CELL_BIAS = 2048;    // so a negative cell packs positive
	const MAX_CELLS = 12;      // a vast lit ceiling must not need two hundred rounds

	// THE RECORD IF THERE IS ONE, never making it. A question must not create state -- something asking
	// "has anything been shot out" on a map where nothing has would otherwise leave a thinker behind.
	clearscope static RSB_Lights Existing()
	{
		ThinkerIterator it = ThinkerIterator.Create("RSB_Lights", Thinker.STAT_STATIC);
		return RSB_Lights(it.Next());
	}

	// Has ANY fixture on this map been shot out? One cheap call that lets a listener skip a whole
	// per-sector pass on the ordinary map where nobody has shot a lamp.
	clearscope bool AnyDead() const { return deadA.Size() > 0; }

	static RSB_Lights Get()
	{
		ThinkerIterator it = ThinkerIterator.Create("RSB_Lights", Thinker.STAT_STATIC);
		let r = RSB_Lights(it.Next());
		if (!r)
		{
			r = new("RSB_Lights");
			r.ChangeStatNum(Thinker.STAT_STATIC);
		}
		return r;
	}

	// ---------------------------------------------------------------- matching
	// A texture name against a fixture pattern. Exact, or a trailing * (LITEBLU*).
	private static bool Matches(String name, String pattern)
	{
		int star = pattern.IndexOf("*");
		if (star < 0) return name ~== pattern;
		if (star == 0) return true;
		String head = pattern.Left(star);
		return name.Length() >= head.Length() && (name.Left(head.Length()) ~== head);
	}

	// Is this texture name a LAMP -- not merely a surface that reads as lit?
	static bool IsFixture(String texName)
	{
		if (texName.Length() == 0) return false;
		let reg = RSB_Registry.Get();
		if (!reg || !reg.defs) return false;
		for (int i = 0; i < reg.defs.defs.Size(); i++)
		{
			let f = RSB_FixtureDef(reg.defs.defs[i]);
			if (!f) continue;
			for (int k = 0; k < f.textures.Size(); k++)
				if (Matches(texName, f.textures[k])) return true;
		}
		return false;
	}

	// ---------------------------------------------------------------- identity
	private static int, int KeyFor(RSB_Surface surf)
	{
		if (!surf || !surf.sec) return 0, -1;
		if (surf.flat)
		{
			int cx = clamp(int(floor(surf.at.x / CELL)) + CELL_BIAS, 0, CELL_BIAS * 2);
			int cy = clamp(int(floor(surf.at.y / CELL)) + CELL_BIAS, 0, CELL_BIAS * 2);
			return -(surf.sec.Index() + 1), (surf.plane & 1) | (cx << 1) | (cy << 14);
		}
		if (!surf.hitLine) return 0, -1;
		return surf.hitLine.Index(), (surf.lineSide & 1) | ((surf.linePart & 3) << 1);
	}

	private bool AlreadyDead(int a, int b)
	{
		for (int i = 0; i < deadA.Size(); i++)
			if (deadA[i] == a && deadB[i] == b) return true;
		return false;
	}

	// ---------------------------------------------------------------- the tally
	// How many fixtures this room has. Counted the first time one of them breaks -- one
	// sector's own lines and its two flats, not a whole-map scan -- and identical on every
	// machine, because it is geometry.
	private int FixtureCount(Sector sec)
	{
		int n = 0;
		for (int i = 0; i < sec.lines.Size(); i++)
		{
			let ln = sec.lines[i];
			for (int sd = 0; sd < 2; sd++)
			{
				let side = ln.sidedef[sd];
				if (!side || side.sector != sec) continue;
				for (int part = 0; part < 3; part++)
				{
					let tex = side.GetTexture(part);
					if (!tex.IsValid()) continue;
					if (IsFixture(TexMan.GetName(tex))) n++;
				}
			}
		}
		// A lit ceiling or floor is gridded: a big panel takes several shots, a small one a couple.
		for (int pl = 0; pl < 2; pl++)
		{
			let tex = sec.GetTexture(pl);
			if (!tex.IsValid() || !IsFixture(TexMan.GetName(tex))) continue;
			n += PanelCells(sec);
		}
		return max(n, 1);
	}

	// The panel's extent in grid cells, from the sector's bounding box. A box is geometry, so
	// the number is the same everywhere; an L-shaped room is overestimated, costing a shot or two.
	private int PanelCells(Sector sec)
	{
		if (sec.lines.Size() == 0) return 1;
		double lo_x = 1e30, lo_y = 1e30, hi_x = -1e30, hi_y = -1e30;
		for (int i = 0; i < sec.lines.Size(); i++)
		{
			let ln = sec.lines[i];
			Vector2 a = ln.v1.p, b = ln.v2.p;
			lo_x = min(lo_x, min(a.x, b.x)); hi_x = max(hi_x, max(a.x, b.x));
			lo_y = min(lo_y, min(a.y, b.y)); hi_y = max(hi_y, max(a.y, b.y));
		}
		int cw = max(1, int(ceil((hi_x - lo_x) / CELL)));
		int ch = max(1, int(ceil((hi_y - lo_y) / CELL)));
		return clamp(cw * ch, 1, MAX_CELLS);
	}

	private void EnsureRoom(int idx, Sector sec)
	{
		while (tally.Size() <= idx) { tally.Push(-1); dead.Push(0); }
		if (tally[idx] < 0) tally[idx] = FixtureCount(sec);
	}

	// ---------------------------------------------------------------- the query
	// What share of this room's fixtures are out, 0..1. For anything that reacts to a room
	// losing its lights -- called at load, it rebuilds a reaction in one pass, so no events
	// ever have to be replayed and no glass-break sound is heard twice.
	clearscope double DeadShare(Sector sec) const
	{
		if (!sec) return 0;
		int idx = sec.Index();
		if (idx < 0 || idx >= tally.Size() || tally[idx] <= 0) return 0;
		return clamp(double(dead[idx]) / double(tally[idx]), 0.0, 1.0);
	}

	// ---------------------------------------------------------------- the broken look
	// A DEAD LAMP THAT STILL LOOKS LIT is the thing the owner noticed first: a Doom lamp texture emits
	// nothing, so taking the room's light away just dims the PICTURE of a working lamp along with the
	// walls. RS_ShotOutLights ships a `<NAME>_OUT` for every lamp in the four IWADs -- the lit element
	// crushed, the housing kept, scorched and cracked. If that package is not loaded the lookup simply
	// fails and nothing swaps, which is why the art lives in its own pk3 and this does not depend on it.
	//
	// A WALL SWAPS AT ONCE: one sidedef is one lamp. A FLAT WAITS UNTIL THE ROOM IS OUT, because a
	// ceiling panel is usually the whole ceiling and there is no way to break a quarter of a flat --
	// swapping on the first hit would black out a ceiling the player has only started shooting.
	private void Blacken(RSB_Surface surf, int idx)
	{
		// NOT named `out`: that is the parameter qualifier and a local called it is "Unexpected 'out'".
		// Same family as Break(), Case(), Void() and Static() -- ZScript keywords are case-insensitive.
		// Type_Any, not Wall or Flat: the broken versions come from PNGs in the addon's textures/ folder,
		// which GZDoom makes into plain textures named by their file rather than into wall or flat types.
		TextureID broken = TexMan.CheckForTexture(surf.texName .. "_OUT", TexMan.Type_Any);
		if (!broken.IsValid()) return;

		if (!surf.flat)
		{
			if (!surf.hitLine) return;
			let sd = surf.hitLine.sidedef[(surf.lineSide == 1) ? 1 : 0];
			if (sd) sd.SetTexture(surf.linePart, broken);
			return;
		}
		if (idx >= 0 && idx < tally.Size() && dead[idx] >= tally[idx])
			surf.sec.SetTexture(surf.plane, broken);
	}

	// ---------------------------------------------------------------- the floor
	// HOW DARK A ROOM MAY GET. A SERVER CVAR AND NOTHING ELSE, and that is a correction rather than a
	// simplification -- the first version asked RS_Darkness, through their Service, what light survives
	// THE PLAYER'S OWN darkness curve, and used the answer to clamp the trim.
	//
	// THAT WAS A NETPLAY BUG AND IT SHIPPED. The darkness preset is per player: one machine running
	// Blackout would have been told "no light survives, do not dim at all" while another with darkness
	// off dimmed the room to 48 -- and the trim is a PLAYSIM WRITE to a shared sector. Two players would
	// have disagreed about how dark a room is, from a difference in a menu neither of them thought was
	// a gameplay setting. It is the crossplatform co-op rule exactly (Engine docs/CROSSPLATFORM_COOP_RULE.md):
	// gameplay may depend only on the playsim, the usercmd and server cvars, and the error is asking a
	// per-player question on a path every machine runs. Going through a Service hid it one step further.
	//
	// So the darkness-aware floor is GONE from the decision, and it cannot come back in any form that
	// reads a player: a room's light is the same for everyone or it is broken. What survives is the menu
	// saying in words that a Darkness preset deepens the floor past the number set here -- true, local,
	// and it changes nothing the playsim does.
	private int FloorNow()
	{
		return RSB_Settings.LightFloor();
	}

	// ---------------------------------------------------------------- guttering out
	// HOW A LAMP DIES, one entry per world tic. 1 is all the way to the new darkness, 0 is the light
	// it had. It fails, catches, fails harder, half comes back, and it is gone -- the shape of a tube
	// letting go rather than a dimmer being turned. A fixed table and not a hash: this is playsim
	// state written to a shared sector, so it must be the same on every machine, and "deterministic
	// random" is a harder promise to keep than "no random at all".
	static const double GUTTER[] = { 1.0, 0.15, 0.9, 0.0, 1.0, 0.45, 1.0, 0.8, 1.0, 1.0 };

	private void Settle(int idx, double from, double to)
	{
		for (int i = 0; i < setSec.Size(); i++)
			if (setSec[i] == idx)
			{
				// Already guttering: keep where it started from, aim at the deeper target.
				setTo[i] = to;
				return;
			}
		setSec.Push(idx); setFrom.Push(from); setTo.Push(to); setAge.Push(0);
	}

	override void Tick()
	{
		for (int i = setSec.Size() - 1; i >= 0; i--)
		{
			let sec = level.sectors[setSec[i]];
			int age = setAge[i];
			if (!sec || age >= GUTTER.Size())
			{
				if (sec) sec.SetLightTrim(setTo[i], 0);
				setSec.Delete(i); setFrom.Delete(i); setTo.Delete(i); setAge.Delete(i);
				continue;
			}
			double k = GUTTER[age];
			sec.SetLightTrim(setFrom[i] + (setTo[i] - setFrom[i]) * k, 0);
			setAge[i] = age + 1;
		}
	}

	// ---------------------------------------------------------------- the break
	// PLAYSIM, on the hit, on every machine alike. Returns true if this hit killed a fixture
	// that was alive -- the caller uses that to play the break rather than the ordinary pop.
	// NOT NAMED Break(): `break` is a ZScript keyword and method names are case-insensitive, so
	// `Break()` is "Unexpected 'break', expecting identifier" at load -- the same family as Case(),
	// Void() and Static(), and not caught by anything but an actual compile.
	static bool ShootOut(RSB_Surface surf)
	{
		if (!surf || !surf.sec || surf.sky || surf.air) return false;
		if (!RSB_Settings.ShootOutLights()) return false;
		if (!IsFixture(surf.texName)) return false;

		let r = Get();
		if (!r) return false;
		int a, b;
		[a, b] = KeyFor(surf);
		if (b < 0) return false;
		if (r.AlreadyDead(a, b)) return false;

		int idx = surf.sec.Index();
		if (idx < 0) return false;
		r.EnsureRoom(idx, surf.sec);
		r.deadA.Push(a);
		r.deadB.Push(b);
		r.dead[idx] = min(r.dead[idx] + 1, r.tally[idx]);

		int floorLevel = r.FloorNow();
		if (floorLevel < 0)
		{
			// The darkness curve leaves nothing to take. The lamp is still dead and still looks it --
			// the glass, the sparks and the pop all play -- the room simply keeps the light it has.
			RSB_Log.Once(RSB_Log.LV_INFO, "lights:nofloor",
				"a fixture was shot out, but the darkness curve leaves no light to take: not dimming");
			return true;
		}

		// THE SHARE OF THE ROOM THAT IS OUT, recomputed from the tally every time rather than taken off
		// a bit at a time. That makes it idempotent: the trim is whatever the room's state says it
		// should be, nothing drifts, and no lamp can dim a room twice however the breaks arrive.
		int now = surf.sec.lightlevel;
		double dim = clamp(r.DeadShare(surf.sec) * RSB_Settings.LightShare(), 0.0, 1.0);

		// THE FLOOR IS WORKED OUT AGAINST THE UNTRIMMED LIGHT. In a flickering room `lightlevel` is a
		// different number every tic, so a share measured against it would wander; the base is what the
		// map and the special asked for, and it holds still.
		int base = surf.sec.GetLightTrimBase();
		if (base > 0)
		{
			double most = 1.0 - double(floorLevel) / double(base);
			dim = min(dim, max(0.0, most));
		}
		// GUTTER INTO IT rather than snapping. The lamp is dead either way and the room ends at the
		// same darkness; it just takes a beat to get there, which is the moment the shot earns.
		if (RSB_Settings.LightStutter())
			r.Settle(idx, surf.sec.GetLightTrimDim(), dim);
		else
			surf.sec.SetLightTrim(dim, 0);

		r.Blacken(surf, idx);

		RSB_Log.Once(RSB_Log.LV_INFO, "lights:first", String.Format(
			"first fixture shot out: %s, room %d has %d, %d now dead, trim %.2f, light %d -> %d",
			surf.texName, idx, r.tally[idx], r.dead[idx], dim, now, surf.sec.lightlevel));
		return true;
	}
}

// ============================================================================
// A ROOM ON FIRE. The inverse of shooting the lights out: set a room alight and it
// gets BRIGHTER while it burns, then falls dark as the fire dies.
//
// AND IT IS THE OPPOSITE KIND OF THING, which is what makes it cheap. A shot-out
// lamp changes a sector's light level -- level state, saved, identical on every
// machine. Fire does not: RSB_FlameEmitter is +CLIENTSIDE, so where the fire lands
// is already this machine's own look. So THIS WRITES NO SECTOR LIGHT AND NOTHING THE
// GAME READS. It keeps a number, a lighting mod reads it, and two machines disagreeing
// about it costs nothing -- which is exactly why it must never be allowed to touch
// sector.lightlevel, however tempting the symmetry with the lights work is.
//
// A COUNT WOULD BE WRONG. The dead-lamp registry is a RATCHET: a lamp stays dead and
// the share only ever rises. Fire goes OUT. If this were a count of burning surfaces,
// the share would drop in one step when the last flame expired and the room would snap
// dark at exactly the moment the effect should look best -- dying down. So it is a
// DECAYING QUANTITY per sector: pouring fire feeds it, and it falls smoothly on its own
// whether or not anything is still burning. (The glow lane caught this before either of
// us built the wrong structure.)
//
// NO FLOOR. The lights work has one because darkness can make a room unplayable. A room
// getting brighter needs no protecting, and nobody should add one for symmetry.
//
// WORLD CLOCK, not real: fire in the world burns slowly when the world is slowed.
// ============================================================================
class RSB_Fires : Thinker
{
	// Only the sectors actually burning, so the per-tic decay is over a handful of entries
	// rather than every sector on the map.
	private Array<int> hotSec;
	private Array<double> hotVal;
	private int lastTic;

	clearscope static RSB_Fires Existing()
	{
		ThinkerIterator it = ThinkerIterator.Create("RSB_Fires", Thinker.STAT_STATIC);
		return RSB_Fires(it.Next());
	}

	private static RSB_Fires Get()
	{
		let r = Existing();
		if (!r)
		{
			r = new("RSB_Fires");
			r.ChangeStatNum(Thinker.STAT_STATIC);
			r.lastTic = level.maptime;
		}
		return r;
	}

	clearscope bool AnyFire() const { return hotSec.Size() > 0; }

	// ENUMERATING WHAT IS BURNING. A falling value has to be polled several times a second to be
	// followed smoothly, and asking every sector on a 3000-sector map at that rate is not a thing
	// anyone should ship. Only burning sectors are kept, so this hands out that short list directly.
	//
	// THE INDEX IS ONLY GOOD FOR THE PASS YOU READ THE COUNT IN. Entries are removed as fires die and
	// the last one is swapped down into the hole, so position `i` is not the same room next tic. Read
	// the count and walk it in one go; never remember an `i` across ticks.
	clearscope int HotCount() const { return hotSec.Size(); }
	clearscope int HotSector(int i) const { return (i >= 0 && i < hotSec.Size()) ? hotSec[i] : -1; }

	clearscope double FireShare(Sector sec) const
	{
		if (!sec) return 0;
		int idx = sec.Index();
		for (int i = 0; i < hotSec.Size(); i++)
			if (hotSec[i] == idx) return clamp(hotVal[i], 0.0, 1.0);
		return 0;
	}

	// FIRE LANDED HERE. Called from the flamethrower every tic it is pouring onto a surface.
	// `amount` is how much of a full burn one tic of pouring is worth.
	static void Feed(Sector sec, double amount)
	{
		if (!sec || amount <= 0) return;
		if (!RSB_Settings.FireLight()) return;
		let r = Get();
		if (!r) return;
		int idx = sec.Index();
		if (idx < 0) return;
		for (int i = 0; i < r.hotSec.Size(); i++)
			if (r.hotSec[i] == idx)
			{
				r.hotVal[i] = min(1.0, r.hotVal[i] + amount);
				return;
			}
		r.hotSec.Push(idx);
		r.hotVal.Push(min(1.0, amount));
	}

	override void Tick()
	{
		// The world clock: a room burns down slowly when the world is slowed.
		int now = level.maptime;
		int step = now - lastTic;
		lastTic = now;
		if (step <= 0 || hotSec.Size() == 0) return;

		double linger = RSB_Settings.FireLightLinger();
		double fall = (linger > 0.01) ? (double(step) / (linger * TICRATE)) : 1.0;
		for (int i = hotSec.Size() - 1; i >= 0; i--)
		{
			hotVal[i] -= fall;
			if (hotVal[i] <= 0)
			{
				hotSec.Delete(i);
				hotVal.Delete(i);
			}
		}
	}
}

// ============================================================================
// WHAT OTHER MODS ASK. A Service, and for exactly the reason RS_Ballistics reads
// RS_Darkness through one: a ZScript call to a class that is not in the load order
// fails at COMPILE, so a lighting mod naming RSB_Lights directly would refuse to
// load for anyone not running this package. Through a Service, a missing answer is
// simply no answer.
//
// PLAY SCOPE, and that is not my choice: `Service.GetDouble` is declared `play` in
// the engine, so an override cannot widen it to clearscope. The UI family is a
// SEPARATE set of virtuals (GetDoubleUI and friends). A caller that needs this from
// a UI tick should read it on a play tick and cache, which is the ordinary GZDoom
// shape anyway -- reaching into the playsim from the UI is what those scopes exist
// to prevent.
// ============================================================================
class RSB_FixtureService : Service
{
	// NOT `override play`: restating the scope on an override is "Attempt to change scope for virtual
	// function", even when it matches the base. The scope comes from the base and is not repeated.
	override double GetDouble(String request, string stringArg, int intArg, double doubleArg, Object objectArg, Name nameArg)
	{
		let r = RSB_Lights.Existing();

		// "anydead" -- has ANYTHING on this map been shot out. Ask this first and skip the rest.
		if (request ~== "anydead") return (r && r.AnyDead()) ? 1.0 : 0.0;
		if (request ~== "deadshare" && !r) return 0.0;

		// "deadshare", intArg = a SECTOR INDEX (not a Sector: a Sector is a struct and a Service only
		// carries an Object). Returns 0..1, how much of that room's lighting is out.
		if (request ~== "deadshare")
		{
			if (!level || intArg < 0 || intArg >= level.sectors.Size()) return 0.0;
			return r.DeadShare(level.sectors[intArg]);
		}

		// "anyfire" -- is ANY room on this map burning. The same cheap first question as anydead.
		if (request ~== "anyfire")
		{
			let f = RSB_Fires.Existing();
			return (f && f.AnyFire()) ? 1.0 : 0.0;
		}

		// "firecount" / "firesector" -- the short list of rooms actually alight, so a reader can follow a
		// falling value at whatever rate the effect needs without scanning the map. Read the count and
		// walk it in ONE pass: an entry that dies is replaced by the last one, so `i` is not stable.
		if (request ~== "firecount")
		{
			let f = RSB_Fires.Existing();
			return f ? double(f.HotCount()) : 0.0;
		}
		if (request ~== "firesector")
		{
			let f = RSB_Fires.Existing();
			return f ? double(f.HotSector(intArg)) : -1.0;
		}

		// "fireshare", intArg = a SECTOR INDEX. 0..1, how brightly this room is burning RIGHT NOW.
		// Unlike deadshare this FALLS as the fire dies, so a reader can ease its reaction off
		// instead of snapping when the last flame goes out.
		if (request ~== "fireshare")
		{
			let f = RSB_Fires.Existing();
			if (!f || !level || intArg < 0 || intArg >= level.sectors.Size()) return 0.0;
			return f.FireShare(level.sectors[intArg]);
		}
		return 0.0;
	}
}
