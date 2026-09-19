// ============================================================================
// HOTSPOTS. A beam or stream held on one place -- 35 hits a second -- heats ONE spot
// instead of landing 35 impacts of its own. From an impact's `hotspot`: each hit feeds the
// live spot of that profile within its merge radius, or starts one there. The spot keeps a
// single light that grows and throbs, a molten mark re-stamped as it grows, bursts emitted
// at rates set by its heat, a column of hot air every few tics, and a looping sound that
// swells. Stop feeding it and it cools and goes out: no stutter, no 35 Hz buzz, a heat slot
// every few tics instead of every hit. First user: the Unmaker.
//
// NETPLAY. Presentation only: a +NOINTERACTION actor fed by landings that happen on every
// machine; seeds are hashes; nothing is read back. The effects level and settings change
// only what each machine draws and plays.
// SLOW MOTION: heat, emission and the throb follow the map clock (level.maptime).
// ============================================================================

class RSB_Hotspot : Actor
{
	Default
	{
		+CLIENTSIDE        // a look for this machine: the engine's client-side thinkers, never the playsim's
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
		+NOTELEPORT
		+DONTSPLASH
		RenderStyle "None";
		Radius 1;
		Height 1;
	}

	const MAX_SPOTS = 16;
	const SHIMMER_EVERY = 6;
	const MAX_BURSTS_A_TIC = 4;
	const DAMAGE_EVERY = 6;      // tics between lasting damage paints while it burns

	String  spotId;
	Vector3 surfNormal;
	// WHO IT IS BURNING ON (`ride`), and where on him it caught. Null for the ordinary case: a spot
	// on a wall. While he lives the spot is moved to him every tic; when he is gone it stays where it
	// last was and burns out there, which is what a fire does when the man it was on stops existing.
	Actor   rider;
	Vector3 riderOfs;
	private double heat;
	private Vector3 sweep;       // which way it has been dragged (a unit-ish average; its sign kept steady)
	private int    heatTic;
	private bool   soundOn;
	private Array<double> carry;
	transient RSB_HotspotDef spotDef;

	States
	{
	Spawn:
		TNT1 A -1;
		Stop;
	}

	// A HIT on a surface, from an impact's `hotspot`: feeds the live spot of that profile
	// within its merge radius, or starts one there (past MAX_SPOTS the oldest goes out).
	static void Feed(String whichSpot, RSB_Surface surf)
	{
		if (!surf || surf.sky || whichSpot.Length() == 0) return;
		let reg = RSB_Registry.Get();
		if (!reg) return;
		let hs = reg.ResolveHotspot(whichSpot, RSB_Tier.Name(RSB_Tier.Current()));
		if (!hs) return;
		// `air` MEANS NO SURFACE, which is exactly the case a rider needs. A round that lands on a man
		// gets an air surface with no mark -- so the old guard, which ran before the profile was even
		// resolved, made it impossible to set a monster alight no matter what any profile asked for.
		// A spot that does not ride still refuses air: there is nothing there to be hot.
		Actor on = (hs.ride && surf.onActor && !surf.onActor.bDESTROYED) ? surf.onActor : null;
		if (surf.air && !on) return;

		RSB_Hotspot spot = null;
		for (int i = reg.hotspots.Size() - 1; i >= 0; i--)
		{
			let s = reg.hotspots[i];
			if (!s)
			{
				reg.hotspots.Delete(i);
				continue;
			}
			// A RIDING SPOT MERGES BY WHO, not by where. Two flares into one man make one fire that
			// burns hotter, and they do it however far he has run between them -- distance is the wrong
			// question once the thing being burnt can move.
			bool match = on ? (s.rider == on) : (s.rider == null && (s.pos - surf.at).Length() <= hs.mergeRadius);
			if (s.spotId ~== whichSpot && match)
			{
				spot = s;
				break;
			}
		}
		if (!spot)
		{
			if (reg.hotspots.Size() >= MAX_SPOTS)
			{
				let oldest = reg.hotspots[0];
				reg.hotspots.Delete(0);
				if (oldest) oldest.GoOut();
			}
			// ON HIM AND FACING UP: fire rises, so a spot riding a man emits along +Z rather than back
			// along the shot. On a wall nothing changes -- it still faces out of the surface it is on.
			Vector3 where = on ? (on.pos + (0, 0, on.height * 0.5)) : (surf.at + surf.normal);
			spot = RSB_Hotspot(Actor.SpawnClientSide("RSB_Hotspot", where, NO_REPLACE));
			if (!spot) return;
			spot.spotId = whichSpot;
			spot.surfNormal = on ? (0, 0, 1) : surf.normal;
			spot.rider = on;
			if (on) spot.riderOfs = (0, 0, on.height * 0.5);
			spot.heatTic = level.maptime;
			reg.hotspots.Push(spot);
		}
		else
		{
			// A sweeping beam drags its spot after it -- and which way it goes lays a cut along it. Sawing
			// back and forth keeps one line: a move against the sweep counts as along it.
			Vector3 was = spot.pos;
			spot.SetOrigin(spot.pos * 0.8 + (surf.at + surf.normal) * 0.2, true);
			Vector3 moved = spot.pos - was;
			double movedLen = moved.Length();
			if (movedLen > 0.05)
			{
				Vector3 u = moved / movedLen;
				if ((u dot spot.sweep) < 0) u = -u;
				spot.sweep = spot.sweep * 0.75 + u * 0.25;
			}
		}
		spot.spotDef = hs;
		spot.Cool();
		spot.heat = min(hs.heatMax * 1.5, spot.heat + hs.heatPerHit);
	}

	override void Tick()
	{
		if (!spotDef)
		{
			let reg = RSB_Registry.Get();
			if (reg) spotDef = reg.ResolveHotspot(spotId, RSB_Tier.Name(RSB_Tier.Current()));
			if (!spotDef)
			{
				GoOut();
				return;
			}
		}
		// IT GOES WHERE HE GOES. Presentation only and client-side already, so this moves nothing the
		// playsim can see; when he is gone the spot simply stops being moved and burns out in place.
		if (rider)
		{
			if (rider.bDESTROYED) rider = null;
			else SetOrigin(rider.pos + riderOfs, true);
		}
		let hs = spotDef;
		Cool();
		double hot = clamp(heat / hs.heatMax, 0.0, 1.0);
		if (hot <= 0.0)
		{
			GoOut();
			return;
		}
		int now = level.maptime;
		double beat = 1.0;
		if (hs.throbTics > 0) beat = (1.0 - hs.throbDepth) + hs.throbDepth * (0.5 + 0.5 * sin(now * 360.0 / hs.throbTics));

		int tier = RSB_Tier.Current();
		if (tier > RSB_Tier.T_OFF && RSB_Settings.Impacts())
		{
			let reg = RSB_Registry.Get();
			double countScale = RSB_Tier.CountScale(tier) * RSB_Settings.ImpactParticles();
			double glowScale = RSB_Settings.ImpactGlow() * beat;
			int posSeed = RSB_Hash.OfPos(pos);
			while (carry.Size() < hs.bursts.Size()) carry.Push(0);
			for (int i = 0; i < hs.bursts.Size(); i++)
			{
				carry[i] += hs.burstRates[i] * hot / double(TICRATE);
				int n = int(carry[i]);
				carry[i] -= n;
				for (int k = 0; k < min(n, MAX_BURSTS_A_TIC); k++)
					RSB_Burst.Fire(reg ? reg.FindBurst(hs.bursts[i]) : null, pos, surfNormal, -surfNormal, countScale, glowScale,
						RSB_Hash.Seed(now, i * 8 + k + 1, posSeed));
			}

			if (hs.lightRadius > 0 && RSB_Settings.ImpactLights())
				A_AttachLight("rsb_hotspot", DynamicLight.PointLight, hs.lightColor, int(hs.lightRadius * (0.5 + 0.5 * hot)), 0,
					DynamicLight.LF_ATTENUATE, (0, 0, 0), 0, 10, 25, 0, hs.lightIntensity * hot * beat * RSB_Settings.ImpactLight());

			if (hs.markShape >= 0 && RSB_Settings.Marks() && (now % hs.markEvery) == 0)
			{
				Color c = hs.markColor;
				double k = 0.4 + 0.6 * hot;
				int life = int(hs.markLife * RSB_Settings.MarkLife() + 0.5);
				if (life > 0)
					level.SpawnSurfaceStamp(hs.markShape, pos - surfNormal, hs.markRadiusCold + (hs.markRadiusHot - hs.markRadiusCold) * hot,
						Color(255, int(c.r * k), int(c.g * k), int(c.b * k)), life, (0, 0, 0));
			}

			if (hs.shimmerRadius > 0 && hs.shimmerStrength > 0 && (now % SHIMMER_EVERY) == 0)
				RSB_Heat.Blast(pos + surfNormal * (hs.shimmerRadius * 0.4), hs.shimmerRadius, hs.shimmerStrength * hot, SHIMMER_EVERY + 6);
			// LASTING DAMAGE while it burns (engine #17, `damage`): a cut that grows and deepens with its heat,
			// laid along the way the spot has been swept -- up the wall while it is held still.
			if (hs.damageRadiusCold > 0 && (now % DAMAGE_EVERY) == 0)
			{
				Vector3 axis = (0, 0, 0);
				if (hs.damageAlong == RSB_Impact.DAMAGE_ALONG_TRAVEL)
				{
					axis = (0, 0, 1);
					if (sweep.Length() > 0.3) axis = sweep;
				}
				else if (hs.damageAlong == RSB_Impact.DAMAGE_ALONG_UP) axis = (0, 0, 1);
				RSB_Impact.PaintDamageAt(pos - surfNormal, surfNormal, axis, hs.damageBrush,
					hs.damageRadiusCold + (hs.damageRadiusHot - hs.damageRadiusCold) * hot,
					hs.damageDepth * hot, hs.damageSoot * hot, hs.damageHeat * hot, hs.damageWet * hot);
			}
			// SMOKE INTO THE ROOM while it burns (engine 13b, `smokevolume`), by its heat.
			if (hs.smokeVolAmount > 0 && (now % SHIMMER_EVERY) == 0)
				level.EmitSmoke(pos + surfNormal * (hs.smokeVolRadius * 0.5), hs.smokeVolRadius, hs.smokeVolAmount * hot * RSB_Tier.SmokeScale(RSB_Settings.SmokeLevel()), 0.5 * hot, (0, 0, 20), (0, 0, 0), hs.smokeVolSoot);
		}

		// THE SOUND at every effects level: the dial turns the visuals down, not the fight.
		if (!(hs.loopSound ~== "none"))
		{
			double vol = hs.loopVolume * hot * RSB_Settings.ImpactVolume();
			if (!soundOn && vol > 0.01)
			{
				A_StartSound(hs.loopSound, CHAN_BODY, CHANF_LOOPING, vol);
				soundOn = true;
			}
			else if (soundOn)
			{
				A_SoundVolume(CHAN_BODY, vol);
			}
		}
		Super.Tick();
	}

	// Heat lost since it was last brought up to date, by the map clock.
	private void Cool()
	{
		int now = level.maptime;
		if (spotDef && now > heatTic) heat = max(0.0, heat - spotDef.coolPerSecond * double(now - heatTic) / double(TICRATE));
		heatTic = now;
	}

	// OUT: its light and sound stop; the last marks, smoke and drips fade on their own.
	void GoOut()
	{
		A_RemoveLight("rsb_hotspot");
		if (soundOn) A_StopSound(CHAN_BODY);
		soundOn = false;
		Destroy();
	}
}
