// ============================================================================
// WHAT A ROUND HIT. The surface under a landing round: where exactly, which way
// it faces, and what it is made of.
//
// The prototype of the engine's surface-material query (ENGINE_SUPPORT_LIST.md
// #16). Doom has no materials; RSBDEFS `material` profiles map texture-name
// patterns to names, and anything unclaimed is the default surface.
//
// HOW. A short trace along the round's last direction of flight, from a little
// behind where it stopped: the trace reports the texture, the wall line or the
// plane, and the exact point -- including the tier of a two-sided line and 3D
// floors, which the projectile's own Blocking* fields do not. If the trace
// finds nothing (a round stopped on an edge), those fields are the fallback.
//
// NETPLAY. A trace and a lookup; no RNG, the same on every machine.
// ============================================================================

class RSB_Surface
{
	String  material;   // "" = the default surface
	String  texName;    // for the diagnostics
	Vector3 at;
	Vector3 normal;     // unit, facing back toward the round
	bool    sky;        // the round went into the sky: no effects
	bool    flat;
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
		let s = New(d.HitLocation, travel);
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
		}
		else if (d.HitType == FLineTraceData.TRACE_HitFloor)
		{
			s.normal = (0, 0, 1);
			s.flat = true;
			tex = d.HitTexture;
		}
		else if (d.HitType == FLineTraceData.TRACE_HitCeiling)
		{
			s.normal = (0, 0, -1);
			s.flat = true;
			tex = d.HitTexture;
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
		let s = New(mo.pos, travel);
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
			int side = level.PointOnLineSide(mo.pos.xy, mo.BlockingLine);
			Side sd = mo.BlockingLine.sidedef[side];
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

	private static RSB_Surface New(Vector3 at, Vector3 travel)
	{
		let s = new("RSB_Surface");
		s.material = "";
		s.texName = "";
		s.at = at;
		s.normal = (travel != (0, 0, 0)) ? -travel : (0, 0, 1);
		s.sky = false;
		s.flat = false;
		return s;
	}

	private static void Classify(RSB_Surface s, TextureID tex)
	{
		if (!tex.IsValid()) return;
		s.texName = TexMan.GetName(tex);
		let reg = RSB_Registry.Get();
		if (reg) s.material = reg.MaterialFor(tex, s.flat);
	}
}
