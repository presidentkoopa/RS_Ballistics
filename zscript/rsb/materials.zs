// ============================================================================
// WHAT A ROUND HIT. The surface under a landing round: where exactly, which way
// it faces, and what it is made of.
//
// WHAT IT IS MADE OF is the engine's answer (surface materials, #16):
// TexMan.GetSurface reads the tags RS_Ballistics' SURFACES.txt (and any later
// SURFACES lump, GLDEFS `surface` tag or TERRAIN) put on the texture. Untagged
// is the default surface (concrete-like).
//
// HOW. A short trace along the round's last direction of flight, from a little
// behind where it stopped: the trace reports the texture, the wall line or the
// plane, and the exact point -- including the tier of a two-sided line and 3D
// floors, which the projectile's own Blocking* fields do not. If the trace
// finds nothing (a round stopped on an edge), those fields are the fallback.
//
// NETPLAY. A trace and a lookup of load-time texture data; no RNG, the same on
// every machine.
// ============================================================================

class RSB_Surface
{
	String  material;   // "" = the default surface; otherwise lower-case (metal, wood...)
	String  texName;    // for the diagnostics
	Vector3 at;
	Vector3 normal;     // unit, facing back toward the round
	bool    sky;        // the round went into the sky: no effects
	bool    flat;
	bool    air;        // no surface: a blast in mid-air or on a monster; no mark
	// WHAT IT WAS PART OF (shot-out lights). Presentation never needed these -- a spark does not care
	// which sidedef it came off -- but BREAKING something does: a fixture has to be identified exactly,
	// so a second round into a dead lamp is recognised, and the room that loses its light has to be the
	// one the lamp FACES, which is the side's own sector and never the line's front sector.
	Sector  sec;        // the side's sector for a wall, the sector itself for a flat; null if unknown
	Line    hitLine;    // null for a flat
	int     lineSide;   // 0 front, 1 back; -1 for a flat
	int     linePart;   // 0 upper, 1 middle, 2 lower; -1 for a flat
	int     plane;      // for a flat: 0 floor, 1 ceiling; -1 for a wall
}

class RSB_Materials play
{
	// A landing projectile.
	static RSB_Surface Probe(Actor mo, Vector3 travel)
	{
		if (travel != (0, 0, 0))
		{
			Vector3 start = mo.pos - travel * 12.0;
			double ang = VectorAngle(travel.x, travel.y);
			double pit = -asin(clamp(travel.z, -1.0, 1.0));
			FLineTraceData d;
			if (mo.LineTrace(ang, 24.0, pit, TRF_ABSPOSITION | TRF_THRUACTORS, start.z, start.x, start.y, d))
			{
				let s = FromTrace(d, travel);
				if (s) return s;
			}
		}
		return FromBlocking(mo, travel);
	}

	// Any trace that hit something: a projectile's, or a preview's from the eye.
	// Null if it hit nothing usable (an actor).
	static RSB_Surface FromTrace(out FLineTraceData d, Vector3 travel)
	{
		let s = MakeSurface(d.HitLocation, travel);
		TextureID tex;
		tex.SetInvalid();

		if (d.HitType == FLineTraceData.TRACE_HasHitSky)
		{
			s.sky = true;
			return s;
		}
		if (d.HitType == FLineTraceData.TRACE_HitWall && d.HitLine)
		{
			Vector2 dl = d.HitLine.delta;
			Vector3 n = (dl.y, -dl.x, 0);
			if (n.Length() > 0.000001) n = n.Unit();
			else n = s.normal;
			if (travel != (0, 0, 0) && (n dot travel) > 0) n = -n;
			s.normal = n;
			tex = d.HitTexture;
			// THE SIDE YOU ARE LOOKING AT IT FROM, and its OWN sector -- not the line's front sector.
			// A lamp on a wall between two rooms must darken the room it faces (shot-out lights).
			s.hitLine = d.HitLine;
			s.lineSide = d.LineSide;
			s.linePart = d.LinePart;
			let sd = d.HitLine.sidedef[(d.LineSide == 1) ? 1 : 0];
			s.sec = sd ? sd.sector : d.HitSector;
		}
		else if (d.HitType == FLineTraceData.TRACE_HitFloor)
		{
			s.normal = (0, 0, 1);
			s.flat = true;
			tex = d.HitTexture;
			s.sec = d.HitSector;
			s.plane = 0;
		}
		else if (d.HitType == FLineTraceData.TRACE_HitCeiling)
		{
			s.normal = (0, 0, -1);
			s.flat = true;
			tex = d.HitTexture;
			s.sec = d.HitSector;
			s.plane = 1;
		}
		else
		{
			return null;
		}
		Classify(s, tex);
		return s;
	}

	// The projectile's own record of what stopped it.
	static RSB_Surface FromBlocking(Actor mo, Vector3 travel)
	{
		let s = MakeSurface(mo.pos, travel);
		TextureID tex;
		tex.SetInvalid();

		if (mo.BlockingFloor)
		{
			tex = mo.BlockingFloor.GetTexture(Sector.floor);
			s.normal = (0, 0, 1);
			s.flat = true;
		}
		else if (mo.BlockingCeiling)
		{
			tex = mo.BlockingCeiling.GetTexture(Sector.ceiling);
			s.normal = (0, 0, -1);
			s.flat = true;
		}
		else if (mo.BlockingLine)
		{
			// Not `side`: ZScript names are case-insensitive, and a local called
			// side hides the Side type that Side.mid below needs.
			int lineSide = level.PointOnLineSide(mo.pos.xy, mo.BlockingLine);
			Side sd = mo.BlockingLine.sidedef[lineSide];
			if (sd)
			{
				tex = sd.GetTexture(Side.mid);
				if (!tex.IsValid()) tex = sd.GetTexture(Side.top);
				if (!tex.IsValid()) tex = sd.GetTexture(Side.bottom);
			}
		}
		Classify(s, tex);
		return s;
	}

	// Not `New`: case-insensitive, it would hide the `new` operator inside itself.
	private static RSB_Surface MakeSurface(Vector3 at, Vector3 travel)
	{
		let s = new("RSB_Surface");
		s.material = "";
		s.texName = "";
		s.at = at;
		s.normal = (travel != (0, 0, 0)) ? -travel : (0, 0, 1);
		s.sky = false;
		s.flat = false;
		s.air = false;
		s.sec = null;
		s.hitLine = null;
		s.lineSide = -1;
		s.linePart = -1;
		s.plane = -1;
		return s;
	}

	// THE FLOOR UNDER A POINT, within `reach` straight below it: what a big gun's blast
	// kicks up (a flash's `groundkick`). `tracer` only runs the trace. Null when nothing
	// is that close below.
	static RSB_Surface FloorUnder(Actor tracer, Vector3 at, double reach)
	{
		if (!tracer || reach <= 0) return null;
		FLineTraceData d;
		if (!tracer.LineTrace(0, reach, 90, TRF_ABSPOSITION | TRF_THRUACTORS, at.z, at.x, at.y, d)) return null;
		return FromTrace(d, (0, 0, -1));
	}

	// NO SURFACE: where a projectile blew up on a monster or in the air. Facing back
	// along its flight, the default material, and flagged so no mark is stamped.
	static RSB_Surface InAir(Vector3 at, Vector3 travel)
	{
		let s = MakeSurface(at, travel);
		s.air = true;
		return s;
	}

	// THE ENGINE'S ANSWER, lower-cased: a Name's text comes back in whichever
	// spelling the engine made first ("Metal" or "metal"), and impact variant ids
	// are strings. 'None' is untagged: the default surface.
	private static void Classify(RSB_Surface s, TextureID tex)
	{
		if (!tex.IsValid()) return;
		s.texName = TexMan.GetName(tex);
		Name surfaceName = TexMan.GetSurface(tex);
		if (surfaceName == 'None') return;
		String m = surfaceName;
		s.material = m.MakeLower();
		RSB_Log.Trace(String.Format("material: %s %s -> %s", s.flat ? "flat" : "wall", s.texName, s.material));
	}
}
