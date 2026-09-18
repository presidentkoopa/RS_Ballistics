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
// KNOWN LIMITATION, stated in the menu rather than left to look like a bug: a sector
// with a light special (flicker, strobe, glow) recomputes its own light every tic and
// overwrites anything written here. Script cannot reach those specials at all --
// `class Lighting : SectorEffect native { }` is empty and their endpoints live only in
// C++ -- so a specialled room needs the engine's per-sector light trim, which is with
// the build lane. Until it lands, those rooms do not dim.
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

	// IS THERE A DARKNESS MOD, AND IS IT ON: 0 not asked yet, 1 no or off, 2 on. A Thinker's fields
	// start at zero, so "not asked" has to BE zero -- a -1 sentinel would read as an answer on a fresh
	// level and we would never ask at all. Caching this one is safe; the glow lane says "active" is
	// stable for a level while "surviving" and "floorlight" are not, because RS_Sweeps pushes a live
	// offset into the curve as a sweep crosses the map. So those two are asked every time.
	private int darknessState;

	const CELL = 256.0;        // a ceiling panel's grid, map units
	const CELL_BIAS = 2048;    // so a negative cell packs positive
	const MAX_CELLS = 12;      // a vast lit ceiling must not need two hundred rounds

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

	// ---------------------------------------------------------------- the floor
	// HOW DARK A ROOM MAY GET, and why the setting alone is not the answer. A raw sector level of 48
	// is a lit room with no darkness mod and pitch black under a Darkness preset -- the curve is not
	// linear, so a room losing half its light does not get half as dark. RS_Darkness publishes a
	// Service that answers for the player's CURRENT settings, so we ask instead of guessing.
	//
	// -1 BACK MEANS DO NOT DIM AT ALL. Under Blackout no sector level survives; under Ember the
	// post-gain pins every level to the same handful of units, so no raw level reaches the guarantee
	// either. Both answer -1, and the rule catches the second one without anybody having predicted it.
	// A feature that quietly does nothing under Blackout is correct. One that dims a room to invisible
	// because the curve could not reach the guarantee is not.
	const MIN_EFFECTIVE = 20.0;   // light the player should still have after the curve

	// Returns the floor to use, or -1 meaning leave this room alone entirely.
	private int FloorNow()
	{
		int set = RSB_Settings.LightFloor();
		if (darknessState == 1) return set;      // asked already: nothing to correct for

		let it = ServiceIterator.Find("RSD_DarknessService");
		Service s = it.Next();
		if (!s)
		{
			darknessState = 1;       // no darkness mod in the load order: the raw number is the truth
			return set;
		}
		if (darknessState == 0) darknessState = (s.GetDouble("active") > 0.5) ? 2 : 1;
		if (darknessState == 1) return set;

		double raw = s.GetDouble("floorlight", "", 0, MIN_EFFECTIVE);
		if (raw < 0) return -1;      // the curve cannot reach it at any level: do not dim
		return max(set, int(raw + 0.5));
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

		// ITS SHARE OF THE ROOM. The whole budget only comes off when every fixture is out.
		double budget = RSB_Settings.LightDrop();
		int floorLevel = r.FloorNow();
		if (floorLevel < 0)
		{
			// The darkness curve leaves nothing to take. The lamp is still dead and still looks it --
			// the glass, the sparks and the pop all play -- the room simply keeps the light it has.
			RSB_Log.Once(RSB_Log.LV_INFO, "lights:nofloor",
				"a fixture was shot out, but the darkness curve leaves no light to take: not dimming");
			return true;
		}
		int drop = int(budget / double(max(1, r.tally[idx])) + 0.5);
		int now = surf.sec.lightlevel;
		int want = max(floorLevel, now - drop);
		if (want < now) surf.sec.SetLightLevel(want);

		RSB_Log.Once(RSB_Log.LV_INFO, "lights:first", String.Format(
			"first fixture shot out: %s, room %d has %d, %d now dead, light %d -> %d",
			surf.texName, idx, r.tally[idx], r.dead[idx], now, want));
		return true;
	}
}
