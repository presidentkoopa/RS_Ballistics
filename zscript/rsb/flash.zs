// ============================================================================
// THE MUZZLE FLASH, from a `flash` profile: a strobing light, lit air in a cone,
// bursts at the bore, a flame sprite and a puff of smoke -- each scaled by the
// player's menu settings and style.
//
// Once the reload system's own flash (WM_MuzzleFlash, since removed), now data:
//
//   THE STROBE. One over-bright tic on the shot, fading over lightTics, then
//   dark: a real muzzle flash is over in a millisecond, and a light that holds
//   reads as a lamp. Re-attaching the light under the same name updates it that
//   tic.
//
//   THE CONE lights the AIR (PPVolumetricBeam) and resolves per eye, so it has
//   depth in stereo, which no billboard has. It falls off as a cube.
//
// Spawned by the firing hand's rig through RSB_Flash.Fire, which gives the beam
// slot (one per hand) and the carrier's velocity for the smoke.
//
// EVERY SHOT ITS OWN. A profile's `vary` wobbles the light, flame, cone, sparks and
// smoke; `maybe` bursts fire on some shots; `surge` now and then makes a whole shot
// bigger; the flame sprite turns to a new angle each shot. All hashed from the tic and
// the muzzle's position.
//
// NETPLAY. A flash is presentation for the machine that draws it: no RNG, no
// interaction, nothing a netgame compares.
// ============================================================================

class RSB_Flash : Actor
{
	Default
	{
		+CLIENTSIDE        // a look for this machine: the engine's client-side thinkers, never the playsim's
		+PRECACHEALWAYS    // loaded with the map, not on its first use: no stutter (engine precache)
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
		+NOTELEPORT
		+DONTSPLASH
		RenderStyle "Add";
		Alpha 1.0;
		Radius 1;
		Height 1;
	}

	String  flashId;
	Vector3 dir;
	int     slot;
	private int    age;
	private int    life;
	private bool   strobeLit;
	private bool   coneOn;
	private double punchMul;
	private double rangeMul;
	private double densityMul;
	private double coneMul;
	private Color  shotColor;      // this shot's light colour (`powdervary`)
	private int    smokePuffs;     // counted at the shot, laid once the flash is done (see LaySmoke)
	private int    smokeDelay;
	// THE TIC THE SHOT HAPPENED ON. LaySmoke runs several tics later and hashes from this rather than
	// from `level.maptime`, so a given shot always makes the same smoke however long it waited.
	private int    smokeTic;
	int            shooterPlayer;  // who fired (-1 = no one): a volume follows that player
	int            shooterHand;    // 0 main hand, 1 off hand, 2 head

	transient RSB_FlashDef flashDef;

	States
	{
	Spawn:
		RSMF B 1 Bright;
		RSMF C 1 Bright;
		RSMF D 1 Bright;
		RSMF E -1 Bright;
		Stop;
	}

	// shooterPlayer, shooterHand: who fired (a player number, -1 = no one) and from where -- 0 the main hand, 1 the off
	// hand, 2 the head -- so a volume (engine #15) follows it. With no one it stays in the world, carried by carrierVel.
	static RSB_Flash Fire(String whichFlash, Vector3 at, Vector3 aim, int beamSlot, Vector3 carrierVel, int shooterPlayer = -1, int shooterHand = 0)
	{
		let reg = RSB_Registry.Get();
		if (!reg) return null;
		int tier = RSB_Tier.Current();
		let fd = reg.ResolveFlash(whichFlash, RSB_Tier.Name(tier));
		if (!fd)
		{
			RSB_Log.Once(RSB_Log.LV_ERR, "flash:missing:" .. whichFlash, String.Format(
				"flash \"%s\" is not defined in any RSBDEFS", whichFlash));
			return null;
		}
		// BARRELS (`barrels`): each shot of this slot flashes from the next barrel round the bore.
		Vector3 muzzle = at;
		if (fd.barrelCount > 1 && fd.barrelRadius > 0)
		{
			let shot = RSB_Tail.SlotOf(beamSlot);
			if (shot)
			{
				Vector3 bore = (aim.Length() > 0.000001) ? aim.Unit() : (1, 0, 0);
				Vector3 side = bore cross (0, 0, 1);
				if (side.Length() < 0.001) side = (1, 0, 0);
				side = side.Unit();
				Vector3 lift = side cross bore;
				double turn = 360.0 * (shot.shots % fd.barrelCount) / fd.barrelCount;
				shot.shots++;
				muzzle = at + (side * cos(turn) + lift * sin(turn)) * fd.barrelRadius;
			}
		}
		let f = RSB_Flash(Actor.SpawnClientSide("RSB_Flash", muzzle, ALLOW_REPLACE));
		if (!f) return null;
		// SLOW MOTION: the flash belongs to the gun in your hands, not to the world, so by default it
		// ticks on the real clock and snaps the way it does at full speed. Set per flash at spawn rather
		// than in Default, because it is the player's choice (Ballistics -> "Muzzle flash in slow motion").
		f.bREALTIME = RSB_Settings.SlowMoFlashReal();
		f.flashId = whichFlash;
		f.flashDef = fd;
		f.dir = (aim.Length() > 0.000001) ? aim.Unit() : (1, 0, 0);
		f.slot = beamSlot;
		f.shooterPlayer = (shooterPlayer >= 0 && shooterPlayer < MAXPLAYERS) ? shooterPlayer : -1;
		f.shooterHand = shooterHand;
		f.Ignite(tier, carrierVel);
		RSB_Tail.Start(fd, muzzle, beamSlot);
		return f;
	}

	private void Ignite(int tier, Vector3 carrierVel)
	{
		let fd = flashDef;
		life = max(3, fd.coneTics);
		life = max(life, fd.lightTics);

		// EVERY SHOT ITS OWN: hashed from the tic and where the muzzle is, so no two
		// shots match and nothing touches the playsim RNG.
		int shotTic = level.maptime;
		int posSeed = RSB_Hash.OfPos(pos);
		double surge = (fd.surgeChance > 0 && RSB_Hash.Frac(shotTic, 401, posSeed) < fd.surgeChance) ? fd.surgeScale : 1.0;
		double vLight  = RSB_Hash.Wobble(fd.varyLight, shotTic, 403, posSeed) * surge;
		double vFlame  = RSB_Hash.Wobble(fd.varyFlame, shotTic, 405, posSeed) * surge;
		double vCone   = RSB_Hash.Wobble(fd.varyCone, shotTic, 407, posSeed) * surge;
		double vSparks = RSB_Hash.Wobble(fd.varySparks, shotTic, 409, posSeed) * surge;
		double vSmoke  = RSB_Hash.Wobble(fd.varySmoke, shotTic, 411, posSeed) * surge;
		// POWDER VARIETY (`powdervary`): this shot's powder burns a little redder or whiter -- its light's colour.
		shotColor = fd.lightColor;
		if (fd.powderVary > 0)
		{
			double warm = RSB_Hash.Between(-fd.powderVary, fd.powderVary, shotTic, 461, posSeed);
			Color lc = fd.lightColor;
			shotColor = Color(255, lc.r, clamp(int(lc.g * (1.0 - 0.25 * warm)), 0, 255), clamp(int(lc.b * (1.0 - 0.55 * warm)), 0, 255));
		}
		// A THROB (`throb`): light and cone swell and ease on a beat by the map clock.
		if (fd.throbTics > 0)
		{
			double beat = (1.0 - fd.throbDepth) + fd.throbDepth * (0.5 + 0.5 * sin(shotTic * 360.0 / fd.throbTics));
			vLight *= beat;
			vCone *= beat;
		}

		// EMISSIVE VOLUMES (engine #15, `volume`): the flash as real glowing gas. Where one draws, the flat flame card and
		// the lit-air cone stand down; the sparks, smoke, shimmer and the strobe (its wall shadows) stay.
		bool volumed = SpawnVolumes(fd, tier, surge, shotTic, posSeed, carrierVel);
		double flameSize = fd.flameScale * RSB_Settings.FlashFlameSize() * vFlame;
		if (tier <= RSB_Tier.T_OFF || flameSize <= 0 || !RSB_Settings.FlashFlame() || volumed) bINVISIBLE = true;
		else
		{
			// Not a stamp: the star stretches a little and turns to a new angle each shot.
			double stretch = fd.varyFlame * 0.5;
			A_SetScale(flameSize * RSB_Hash.Wobble(stretch, shotTic, 413, posSeed),
				flameSize * RSB_Hash.Wobble(stretch, shotTic, 415, posSeed));
			if (fd.flameRoll)
			{
				bROLLSPRITE = true;
				roll = RSB_Hash.Between(0.0, 360.0, shotTic, 417, posSeed);
			}
		}

		// SENSORY IMPULSES (engine build 4; `hearing`, `exposure`): ringing ears and flash blindness. Every machine calls
		// them alike; the engine weighs each against its own listener and camera (distance, facing, walls, darkness, room)
		// and both are off until the player turns them on. Ringing ears at every effects level -- the dial turns the visuals
		// down, not the fight; flash blindness goes with the visuals. The shot's surge makes both a little stronger.
		if (fd.hearingStrength > 0)
			level.HearingImpulse(pos, fd.hearingStrength * surge, fd.hearingReach, fd.hearingRecovery);
		if (fd.exposureStrength > 0 && tier > RSB_Tier.T_OFF)
			level.ExposureImpulse(pos + dir * 4.0, fd.exposureStrength * surge, fd.exposureReach, fd.exposureRecovery, fd.exposureTint);

		if (tier <= RSB_Tier.T_OFF) return;

		// WHAT THIS MACHINE CAN SEE (M1, M2; looks only): someone's flash behind the view throws no sparks, puffs or bent
		// air; past the range, fewer and no maybe bursts. The strobe, volumes, room smoke, shove, powder burns and blast
		// kick are kept. Your own muzzle is always near, so always in full.
		int seen = RSB_Settings.ViewBand(pos);

		punchMul = RSB_Settings.FlashLight() * vLight;
		rangeMul = RSB_Settings.FlashSize() * (0.75 + 0.25 * vLight);
		densityMul = RSB_Settings.FlashConeDensity() * vCone;
		coneMul = 0.85 + 0.15 * vCone;

		if (fd.lightRadius > 0 && fd.lightTics > 0 && punchMul > 0 && rangeMul > 0) StrobeLight(1.0);
		coneOn = !volumed && fd.coneLength > 0 && fd.coneTics > 0 && RSB_Settings.FlashCone() && densityMul > 0;
		if (coneOn) Beam(1.0);

		let reg = RSB_Registry.Get();
		// A GUN'S SIZE (`sizecvar`): offsets along the bore follow the gun's size slider. The flash
		// is the local rig's, so the local player's slider is the right one to read.
		double sizeMul = 1.0;
		if (fd.sizeCvar.Length() > 0) sizeMul = max(0.05, RSB_Settings.Cvf(fd.sizeCvar, 1.0));

		double countScale = RSB_Tier.CountScale(tier);   // a profile written for a level is scaled by it too
		if (seen == RSB_Settings.VIEW_FAR) countScale *= RSB_Settings.LOD_COUNT;
		if (reg && seen != RSB_Settings.VIEW_BEHIND)
		{
			double sparkScale = countScale * RSB_Settings.FlashSparks() * vSparks;
			// EACH SHOT ITS OWN SPRAY (`sparkvary`, owner 09-14: "the sparks need more randomization per
			// shot"): this shot's spark bursts lean a hashed few degrees off the bore, open wider or
			// tighter, fly faster or lazier, burn fatter or finer, brighter or dimmer, longer or shorter,
			// and each one's share of the mix rises or falls. Flame, core, plumes and smoke keep their shape.
			int leanSeed   = RSB_Hash.Seed(shotTic, 433, posSeed);
			double sSpread = RSB_Hash.Wobble(fd.sparkSpread, shotTic, 435, posSeed);
			double sSpeed  = RSB_Hash.Wobble(fd.sparkSpeed, shotTic, 437, posSeed);
			double sSize   = RSB_Hash.Wobble(fd.sparkSize, shotTic, 439, posSeed);
			double sGlow   = RSB_Hash.Wobble(fd.sparkGlow, shotTic, 441, posSeed);
			double sLife   = RSB_Hash.Wobble(fd.sparkLife, shotTic, 443, posSeed);
			for (int i = 0; i < fd.bursts.Size(); i++)
				ShotBurst(reg.FindBurst(fd.bursts[i]), fd, sparkScale, RSB_Hash.Seed(shotTic, i + 1, posSeed), sizeMul,
					RSB_Hash.Wobble(fd.sparkMix, shotTic, 451 + i * 2, posSeed), leanSeed, sSpread, sSpeed, sSize, sGlow, sLife);
			// Bursts only some shots throw: powder specks, a wider spray.
			for (int i = 0; i < fd.maybeBursts.Size(); i++)
			{
				if (seen != RSB_Settings.VIEW_FULL) break;
				if (RSB_Hash.Frac(shotTic, 421 + i * 2, posSeed) >= fd.maybeChance[i]) continue;
				ShotBurst(reg.FindBurst(fd.maybeBursts[i]), fd, sparkScale, RSB_Hash.Seed(shotTic, 61 + i, posSeed), sizeMul,
					RSB_Hash.Wobble(fd.sparkMix, shotTic, 481 + i * 2, posSeed), leanSeed, sSpread, sSpeed, sSize, sGlow, sLife);
			}
		}

		// HEAT SHIMMER out of the muzzle (RSB_Heat): a column of hot air along the shot.
		if (fd.heatStrength > 0 && seen != RSB_Settings.VIEW_BEHIND)
			RSB_Heat.Along(pos, dir, fd.heatLength, fd.heatRadius, fd.heatStrength * surge, fd.heatTics);
		// THE BACKBLAST'S HOT AIR (`backheat`): a column out of the rear of the tube, behind.
		if (fd.backHeatStrength > 0 && seen != RSB_Settings.VIEW_BEHIND)
			RSB_Heat.Along(pos - dir * (fd.rearOffset * sizeMul), -dir, fd.backHeatLength * sizeMul, fd.backHeatRadius, fd.backHeatStrength * surge, fd.backHeatTics);

		// THE GROUND KICK (`groundkick`): a big gun's blast raises the floor under and just
		// ahead of it -- dust rolling out, water thrown up -- the impact chosen by the
		// floor's surface, when the floor is within reach below the muzzle.
		if (fd.kickImpact.Length() > 0 && fd.kickReach > 0)
		{
			Vector3 groundDir = (dir.x, dir.y, 0);
			Vector3 kickFrom = pos;
			if (groundDir.Length() > 0.001)
			{
				groundDir = groundDir.Unit();
				if (level.IsPointInLevel(pos + groundDir * (fd.kickAlong * sizeMul))) kickFrom = pos + groundDir * (fd.kickAlong * sizeMul);
			}
			let ground = RSB_Materials.FloorUnder(self, kickFrom, fd.kickReach);
			if (ground) RSB_Impact.LandOn(self, ground, fd.kickImpact, groundDir);
		}

		// POINT-BLANK POWDER BURNS (`powderburn`): a surface straight ahead within reach takes a soot ring and
		// powder stipple, stronger the closer the muzzle was (engine #17).
		if (fd.powderReach > 0 && RSB_Settings.FlashPowderBurns())
		{
			let ahead = NearSurface(dir, fd.powderReach);
			if (ahead)
			{
				double closeness = 1.0 - clamp((ahead.at - pos).Length() / fd.powderReach, 0.0, 1.0);
				// TIGHTER AND FAINTER THAN IT WAS (owner, in the headset: "i sorta like the idea of it
				// but im not a fan of the visual on walls and flats"). They like the IDEA, so this is not
				// switched off -- it is made subtle. Two changes, and the second was the ugly one:
				//   the scorch loses about a third of its soot, so it reads as a mark rather than paint;
				//   and the STIPPLE, which used to be painted at 1.6x the radius, is now 1.05x and falls
				//   off with closeness SQUARED like the scorch does. A wide speckled halo round every
				//   shot fired near a wall is what made it read as decal spam rather than as powder.
				// Note it is also 2.5x longer-lived at Extreme than at Heavy (the mark ladder), which is
				// the tier and not this -- but it is why the marks built up the way they did.
				// ONE MARK. The stipple is gone entirely -- softening it was not the answer, because TWO
				// decals a shot is what made this read as decal spam rather than as a powder burn, and
				// the owner said they like the IDEA and dislike the VISUAL. A powder burn is a soot
				// smudge; it is not patterned, and there is only ever one of it.
				RSB_Impact.PaintDamageAt(ahead.at, ahead.normal, (0, 0, 0), "scorch", fd.powderRadius * (0.55 + 0.35 * closeness),
					0.0, fd.powderSoot * closeness * closeness * closeness * 0.7, 0.0, 0.0);
			}
		}
		// THE BLAST HITTING WHAT IS NEAR (`blastkick`): walls beside and a ceiling above shed dust; casings are thrown.
		if (fd.blastImpact.Length() > 0 && fd.blastReach > 0 && RSB_Settings.FlashBlastKick())
			BlastKick(fd, sizeMul);
		// THE BLAST RIPPLE (`shockwave`): the air bending in a ring off the muzzle.
		//
		// THIS USED TO BE A HEAT BALL re-laid every tic from a claimed heat slot -- an approximation
		// built before the engine had the real thing. `SpawnShockwave` is fire-and-forget: ONE call,
		// and the engine owns the slot and animates the ring itself every frame. So the per-tic
		// Shockwave() and the heat slot are gone, and a blast no longer holds a heat slot that a
		// hotspot or a flamethrower could have used.
		//
		// PRESENTATION, and wired local deliberately (build lane, verified in the thunk): it moves no
		// actor, deals no damage, spawns no thinker, draws no RNG and returns nothing an actor reads.
		// Two machines may legitimately draw different ripples or none -- a player with them switched
		// off is a preference, not a divergence -- so there is no network event and no applier.
		//
		// THE ANCHOR IS THE TRAP. The engine's own comment: without an owner it rides THE LOCAL
		// PLAYER'S hand, "wrong in netplay for someone else's blast". We know who fired -- the same
		// shooterPlayer the emissive volumes already follow -- so the owner is passed explicitly and
		// someone else's muzzle blast rides THEIR hand.
		if (fd.shockRadius > 0 && fd.shockStrength > 0 && fd.shockTics > 0 && RSB_Settings.FlashShockwave())
		{
			Actor owner = null;
			int anchor = 0;   // 0 world, 1 main hand, 2 off hand
			if (shooterPlayer >= 0 && playeringame[shooterPlayer])
			{
				owner = players[shooterPlayer].mo;
				// ours: 0 main, 1 off, 2 head. The engine has no head anchor, so a head mount rides the world.
				anchor = (shooterHand == 0) ? 1 : ((shooterHand == 1) ? 2 : 0);
			}
			level.SpawnShockwave(pos, fd.shockRadius,
				fd.shockStrength * RSB_Tier.HeatScale(RSB_Tier.Current()),
				fd.shockTics, fd.shockThickness, fd.shockChroma, anchor, owner);
		}

		// SMOKE INTO THE ROOM (engine 13b, `smokevolume`) and A SHOVE (`push`): muzzle haze that
		// builds over a string of shots, out of the muzzle or a tube's rear; a blast pushing it.
		if (fd.smokeVolAmount > 0 && RSB_Settings.FlashSmoke() > 0)
			level.EmitSmoke(pos + dir * (fd.smokeVolAlong * sizeMul + fd.smokeVolRadius * 0.5), fd.smokeVolRadius, fd.smokeVolAmount * vSmoke * RSB_Settings.FlashSmoke(), fd.smokeVolHeat, dir * fd.smokeVolSpeed, (0, 0, 0), fd.smokeVolSoot);
		if (fd.pushRadius > 0 && fd.pushStrength > 0)
			level.PushEffectImpulse(pos + dir * (fd.pushAlong * sizeMul), fd.pushRadius, fd.pushStrength * surge * RSB_Tier.PushScale(tier));

		int puffs = int(fd.smokeCount * countScale * RSB_Settings.FlashSmoke() * vSmoke + 0.5);
		if (seen == RSB_Settings.VIEW_BEHIND) puffs = 0;
		// THE SMOKE IS HELD BACK UNTIL THE FLASH HAS GONE (owner, in the headset: "when it lights up the
		// barrel smoke sometimes i can't see shit"). Counted here, laid in Tick a few tics later.
		//
		// I damped the smoke's `lit` first and that was treating the symptom. The cause is TIMING. This
		// cloud was born SIX UNITS out of the bore on the SAME TIC as a light of radius 150 to 330 --
		// and that light attenuates linearly, so at six units it is at about 98% of full. A bright,
		// soft, view-filling quad at arm's length, lit as hard as the engine can light it, is exactly
		// what the owner described, and no amount of `lit` tuning fixes a cloud that should not be
		// there yet: AT THE INSTANT OF A MUZZLE FLASH THERE IS A GAS JET, NOT A CLOUD. Smoke takes
		// about a tenth of a second to become smoke.
		//
		// Waiting also puts it where it belongs. By the time it is laid the gun has moved, so the cloud
		// is left hanging in the air behind the muzzle instead of riding it -- which is what real smoke
		// does and what we were faking badly with drift.
		smokePuffs = puffs;
		smokeTic = shotTic;
		smokeDelay = fd.smokeDelay >= 0 ? fd.smokeDelay : max(1, fd.lightTics);

		RSB_Log.Once(RSB_Log.LV_INFO, "flash:first:" .. fd.id, String.Format(
			"first flash this map using %s: light %d x%.2f, punch %.2f x%.2f, %d tics; cone %s; %d burst(s); %d smoke",
			fd.id, int(fd.lightRadius), rangeMul, fd.lightPunch, punchMul, fd.lightTics,
			coneOn ? "on" : "off", fd.bursts.Size(), puffs));
	}


	// ONE OF THE SHOT'S BURSTS: a spark burst takes this shot's spray (lean, spread, speed, size, glow,
	// life) and its own share of the mix; any other burst fires as the profile wrote it.
	private void ShotBurst(RSB_BurstDef bd, RSB_FlashDef fd, double countScale, int seed, double sizeMul,
		double mix, int leanSeed, double sSpread, double sSpeed, double sSize, double sGlow, double sLife)
	{
		if (!bd) return;
		// A REAR-AIMED BURST CARRYING NO OFFSET OF ITS OWN COMES OUT OF THE BACK OF THIS WEAPON.
		// A burst def is SHARED, so one that bakes in a tube length can only ever serve the launcher it
		// was written for -- which is why `rpg_backblast_fire` has -51.5 in it and a Panzerfaust cannot
		// reuse it. Taking the length from the PROFILE instead lets one set of backblast bursts serve
		// every launcher there will ever be. Additive and default-off: a burst that states its own
		// offset is untouched, so the RPG that shipped with those numbers behaves exactly as before.
		Vector3 from = pos;
		if (bd.aim == RSB_BurstDef.AIM_BACK && bd.offset == 0 && fd.rearOffset > 0)
			from = pos - dir * (fd.rearOffset * sizeMul);
		if (!RSB_Burst.IsSpark(bd))
		{
			RSB_Burst.Fire(bd, from, dir, dir, countScale, 1.0, seed, null, 1.0, sizeMul);
			return;
		}
		RSB_Burst.Fire(bd, from, dir, dir, countScale * mix, sGlow, seed, null, sSize, sizeMul,
			sSpread, sSpeed, sLife, fd.sparkLean, leanSeed);
	}

	// THE FLASH'S VOLUMES: each named definition this machine draws, at the muzzle (a `back` one out of the rear), scaled
	// by the effects level and the shot's wobble, as bright as its surge, following the shooter. True when any drew.
	private bool SpawnVolumes(RSB_FlashDef fd, int tier, double surge, int shotTic, int posSeed, Vector3 carrierVel)
	{
		if (tier <= RSB_Tier.T_OFF || fd.volumeNames.Size() == 0) return false;
		while (fd.volumeHandles.Size() < fd.volumeNames.Size())
			fd.volumeHandles.Push(LevelLocals.EmissiveVolumeDefinition(Name(fd.volumeNames[fd.volumeHandles.Size()])));
		double sizeMul = 1.0;
		if (fd.sizeCvar.Length() > 0) sizeMul = max(0.05, RSB_Settings.Cvf(fd.sizeCvar, 1.0));
		double scale = RSB_Tier.SizeScale(tier) * sizeMul * RSB_Hash.Wobble(fd.varyVolume, shotTic, 491, posSeed);
		double bright = RSB_Tier.GlowScale(tier) * surge;
		int follow = EVF_WORLD;
		Vector3 carried = carrierVel;
		if (shooterPlayer >= 0)
		{
			follow = (shooterHand == 1) ? EVF_OFFHAND : ((shooterHand == 2) ? EVF_HEAD : EVF_MAINHAND);
			carried = (0, 0, 0);
		}
		bool drew = false;
		for (int i = 0; i < fd.volumeNames.Size(); i++)
		{
			int handle = fd.volumeHandles[i];
			if (!LevelLocals.EmissiveVolumeEnabled(handle)) continue;
			bool back = fd.volumeBack[i] != 0;
			Vector3 at = back ? pos - dir * (fd.rearOffset * sizeMul) : pos;
			level.SpawnEmissiveVolume(handle, at, back ? -dir : dir, scale, bright, 1.0, Color(255, 255, 255, 255), carried, 0,
				follow, shooterPlayer, 1.0, 1.0);
			drew = true;
		}
		return drew;
	}

	// The surface along `d` within `reach` of the muzzle, or null (sky, nothing, too far).
	private RSB_Surface NearSurface(Vector3 d, double reach)
	{
		FLineTraceData t;
		if (!LineTrace(VectorAngle(d.x, d.y), reach, -asin(clamp(d.z, -1.0, 1.0)), TRF_ABSPOSITION | TRF_THRUACTORS,
			pos.z, pos.x, pos.y, t))
			return null;
		if (t.HitType != FLineTraceData.TRACE_HitWall && t.HitType != FLineTraceData.TRACE_HitFloor
			&& t.HitType != FLineTraceData.TRACE_HitCeiling)
			return null;
		let s = RSB_Materials.FromTrace(t, d);
		return (s && !s.sky && !s.air) ? s : null;
	}

	// THE BLAST HITTING WHAT IS NEAR (`blastkick`): traces to both sides and up; a surface within reach sheds the
	// profile's impact -- always close by, now and then further out -- and casings within reach are thrown.
	private void BlastKick(RSB_FlashDef fd, double sizeMul)
	{
		Vector3 side = dir cross (0, 0, 1);
		if (side.Length() < 0.001) side = (1, 0, 0);
		side = side.Unit();
		double reach = fd.blastReach * sizeMul;
		int posSeed = RSB_Hash.OfPos(pos);
		for (int i = 0; i < 3; i++)
		{
			Vector3 d = (0, 0, 1);
			if (i == 0) d = side;
			else if (i == 1) d = -side;
			let s = NearSurface(d, reach);
			if (!s) continue;
			double closeness = 1.0 - clamp((s.at - pos).Length() / reach, 0.0, 1.0);
			if (RSB_Hash.Frac(level.maptime, 471 + i, posSeed) > closeness * 1.5) continue;
			RSB_Impact.LandOn(self, s, fd.blastImpact, d);
		}
		if (fd.blastShove <= 0) return;
		let reg = RSB_Registry.Get();
		if (reg)
		{
			for (int i = 0; i < reg.casings.Size(); i++)
			{
				let c = RSB_LocalEjecta(reg.casings[i]);
				if (c) c.Shove(pos, reach, fd.blastShove);
			}
		}
		if (fd.pushStrength <= 0)
			level.PushEffectImpulse(pos, reach, fd.blastShove * 40.0 * RSB_Tier.PushScale(RSB_Tier.Current()));
	}


	private void StrobeLight(double k)
	{
		let fd = flashDef;
		int range = int(fd.lightRadius * rangeMul * (0.6 + 0.4 * k));
		// It ASKS to cast shadows (LF_CASTSHADOW, lights #20): the player's "Muzzle flash shadows" decides, Off by default.
		A_AttachLight("rsb_muzzle", DynamicLight.PointLight, shotColor,
			range, 0, DynamicLight.LF_ATTENUATE | DynamicLight.LF_CASTSHADOW, (0, 0, 0), 0, 10, 25, 0, fd.lightPunch * punchMul * k * k);
		strobeLit = true;
	}

	private void Beam(double f)
	{
		let fd = flashDef;
		Color c = shotColor;
		Level.SetVolumetricBeam(pos, dir,
			Color(255, int(c.r * f), int(c.g * f), int(c.b * f)),
			fd.coneInner, fd.coneOuter, fd.coneLength * f * coneMul, fd.coneDensity * densityMul * f,
			3.0, 0.5, 0.05, 0.6, slot);
	}

	// THE SMOKE, LAID LATE. Called from Tick once the flash's own light is done, never on the shot tic.
	private void LaySmoke(RSB_FlashDef fd)
	{
		int puffs = smokePuffs;
		smokePuffs = 0;
		if (puffs <= 0) return;
		int posSeed = RSB_Hash.OfPos(pos);
		if (fd.smokeParticle.Length() > 0)
		{
			if (fd.smokeHandle == 0) fd.smokeHandle = level.ParticleDefinition(fd.smokeParticle);
			// SMOKE COST (owner 2026-09-15: "that smoke shit lags like hell"): one puff per counted
			// puff, not two. Born further out than it was, because a cloud forms AHEAD of a muzzle
			// rather than on it, and because the costliest pixels in the game are big soft lit quads
			// an arm's length from the eyes.
			level.SpawnParticles(fd.smokeHandle, pos + dir * 14.0, dir, puffs, 30.0, 14.0, 0.6,
				1.8, 0.35, Color(255, 255, 255, 255), 1.0, 1.0, RSB_Hash.Seed(smokeTic, 77, posSeed));
			return;
		}
		for (int i = 0; i < puffs; i++)
		{
			let s = Actor.SpawnClientSide("RSB_Smoke", pos + dir * 8.0, ALLOW_REPLACE);
			if (!s) continue;
			s.A_SetScale(fd.smokeScale);
			s.Alpha = fd.smokeAlpha;
			Vector3 wander = (RSB_Hash.Between(-0.15, 0.15, smokeTic, i, posSeed),
				RSB_Hash.Between(-0.15, 0.15, smokeTic, i + 31, posSeed), 0.15);
			s.Vel = dir * 0.5 + wander;
		}
	}

	override void Tick()
	{
		let fd = flashDef;
		if (!fd)
		{
			Destroy();   // a savegame load: a flash is a tic or two, not worth restoring
			return;
		}
		age++;
		if (smokePuffs > 0 && age >= smokeDelay) LaySmoke(fd);

		// THE FLASH DIES AS IT AGES INSTEAD OF HOLDING (owner, in the headset: "some of the
		// muzzleflashes seem like they last a while for being a barrel flash"). The states run
		// B, C, D one tic each and then E -1 -- so anything whose `life` is longer than three tics,
		// which is every big gun, sat on a FROZEN BRIGHT SPRITE for the rest of it. The light may
		// honestly linger, because a real blast does light a room a moment longer; the flash itself
		// may not. Fading from the last animated frame keeps the lingering light and kills the hang.
		if (life > 3)
		{
			double left = double(life - age) / double(life - 3);
			if (age > 3) A_SetRenderStyle(clamp(left, 0.0, 1.0), STYLE_Add);
		}

		if (age > life)
		{
			Destroy();
			return;
		}

		if (strobeLit)
		{
			if (age >= fd.lightTics)
			{
				A_RemoveLight("rsb_muzzle");
				strobeLit = false;
			}
			else
			{
				StrobeLight(1.0 - double(age) / double(fd.lightTics));
			}
		}

		if (coneOn)
		{
			double f = 1.0 - (double(age) / double(fd.coneTics + 1));
			if (f <= 0)
			{
				Level.ClearVolumetricBeam(slot);
				coneOn = false;
			}
			else
			{
				Beam(f * f * f);
			}
		}
		Super.Tick();
	}

	override void OnDestroy()
	{
		A_RemoveLight("rsb_muzzle");
		if (coneOn) Level.ClearVolumetricBeam(slot);
		Super.OnDestroy();
	}
}

// A PUFF OF BARREL SMOKE as an authored sprite: the fallback for a flash profile
// with no `smokeparticle`. Every gun flash RS_Ballistics ships names one
// (rsb_smoke_gun, lit GPU smoke since stage 2d), so these draw only for a
// profile another package writes without it.
class RSB_Smoke : Actor
{
	Default
	{
		+CLIENTSIDE        // a look for this machine: the engine's client-side thinkers, never the playsim's
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
		+NOTELEPORT
		+DONTSPLASH
		RenderStyle "Translucent";
		Alpha 0.3;
		Radius 1;
		Height 1;
	}

	States
	{
	Spawn:
		RSSK ABCDEF 4;
		Stop;
	}

	override void Tick()
	{
		// Work first, then advance the state: the last state destroys the actor
		// inside Super.Tick(), and nothing may touch it after that.
		Vel *= 0.9;
		Vel.Z += 0.012;
		A_SetScale(Scale.X * 1.03);
		Alpha -= 0.012;
		if (Alpha <= 0)
		{
			Destroy();
			return;
		}
		Super.Tick();
	}
}

// ============================================================================
// GUNSHOT TAILS (a flash's `tail`): the room answering a shot -- a short boom under a ceiling, a long rolling
// echo under open sky, chosen by what is over the muzzle. Each beam slot (a hand) keeps its tail's sound
// handle and the next shot stops it, so a held trigger rolls one tail instead of stacking them into mush.
// Played at every effects level: the dial turns the visuals down, not the fight.
// NETPLAY. Sound is this machine's presentation: nothing reads a handle back, and no gameplay follows it.
// ============================================================================
class RSB_ShotSlot
{
	SoundHandle tail;   // its gunshot tail, stopped by the next shot
	int shots;          // shots fired from this slot: which barrel flashes next (`barrels`)
}

class RSB_Tail play
{
	const SLOTS = 32;   // the beam slots (Level.SetVolumetricBeam's 0..31)

	// A beam slot's record (its tail and shot count), made on first use; null outside 0..31.
	static RSB_ShotSlot SlotOf(int slot)
	{
		if (slot < 0 || slot >= SLOTS) return null;
		let reg = RSB_Registry.Get();
		if (!reg) return null;
		while (reg.shotSlots.Size() <= slot) reg.shotSlots.Push(new("RSB_ShotSlot"));
		return reg.shotSlots[slot];
	}

	static void Start(RSB_FlashDef fd, Vector3 at, int slot)
	{
		if (!fd || fd.tailSound.Length() == 0) return;
		let s = SlotOf(slot);
		if (!s) return;
		s.tail.StopSound();
		double vol = fd.tailVolume * RSB_Settings.TailVolume();
		if (vol <= 0) return;
		let sec = level.PointInSector(at.xy);
		bool openSky = sec && sec.GetTexture(Sector.ceiling) == skyflatnum;
		String which = fd.tailSound .. (openSky ? "/ext" : "/int");
		double pitch = RSB_Hash.Between(0.96, 1.04, level.maptime, 431, RSB_Hash.OfPos(at));
		s.tail = S_StartSoundAt(at, which, CHAN_AUTO, CHANF_OVERLAP, min(vol, 1.0), ATTN_NORM, pitch);
	}
}
