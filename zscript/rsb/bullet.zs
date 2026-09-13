// ============================================================================
// THE BULLET. A real round that flies, reading a `round` profile.
//
// The same FastProjectile as the reload system's WM_Bullet -- it moves in small
// steps each tic, so a round travelling hundreds of units a tic still cannot
// skip through a thin monster -- plus what the profile adds:
//
//   glide    FastProjectile clears interpolation every tic, so the sprite would
//            jump a whole tic of travel per frame. Restoring Prev after the move
//            lets the renderer draw it between tics.
//   wake     particles laid along each tic's travel.
//   whiz     a round passing close to the listener's head, fired by someone
//            else, whizzes or cracks.
//   impact   RSB_Impact, by material, style and tier.
//
// THE CONTRACT the fire action relies on (kept from WM_Bullet):
//   damageMin, damageMax    set per round by the shooter; 0/0 = the profile's
//                           damageBase x 1d(damageDice).
//
// NETPLAY. Spawned by the weapon's fire action on every machine. Damage uses a
// named RNG, like any damage. Everything cosmetic is a hash, and the player's
// look settings only change what that player's machine draws and plays. The
// whiz is a sound for the local listener, which changes nothing a netgame
// compares.
// ============================================================================

class RSB_Bullet : FastProjectile
{
	Default
	{
		Radius 2;
		Height 2;
		Speed 245;          // map units per tic; Launch sets the live value from the profile
		Damage 1;           // replaced outright in DoSpecialDamage
		Projectile;
		+THRUSPECIES
		Species "Player";
		Decal "BulletChip";
	}

	String roundId;
	int    hand;            // 0 main, 1 off -- for the log
	int    shooterNum;      // player number of the shooter, -1 if none
	int    damageMin, damageMax;

	private Vector3 travel; // last direction of flight; Vel is zeroed before Death
	private bool    announced;
	private bool    whizzed;
	private bool    glide;
	transient RSB_RoundDef roundDef;   // re-read after a savegame load

	States
	{
	Spawn:
		RSBT A -1 Bright;
		Stop;
	Death:
		TNT1 A 0 { Landed(); }
		Stop;
	}

	// CALLED BY THE FIRE ACTION straight after A_FireProjectile. The engine has
	// already spawned the round at the firing hand and aimed it; this names its
	// profile, sets its speed and size, and records who fired it.
	static RSB_Bullet Launch(Actor shot, PlayerInfo shooter, int whichHand, String whichRound)
	{
		let b = RSB_Bullet(shot);
		if (!b) return null;     // null when it hit something the moment it spawned
		b.roundId = whichRound;
		b.hand = whichHand;
		b.shooterNum = -1;
		if (shooter && shooter.mo) b.shooterNum = shooter.mo.PlayerNumber();

		let d = b.Def();
		if (!d)
		{
			RSB_Log.Once(RSB_Log.LV_ERR, "bullet:noround:" .. whichRound, String.Format(
				"a round was launched as \"%s\", which no RSBDEFS defines -- it flies at its default speed with no effects", whichRound));
			return b;
		}
		double spd = clamp(d.speed, 1.0, 1000.0);
		if (b.Vel.Length() > 0.000001) b.Vel = b.Vel.Unit() * spd;
		b.Speed = spd;
		b.glide = d.glide;
		if (d.radius != b.radius) b.A_SetSize(d.radius, d.radius);
		return b;
	}

	RSB_RoundDef Def()
	{
		if (!roundDef)
		{
			let reg = RSB_Registry.Get();
			if (reg) roundDef = reg.FindRound(roundId);
		}
		return roundDef;
	}

	override void Tick()
	{
		// Remember which way it flies BEFORE moving: the move can end in Death,
		// and by then Vel is already zero.
		if (Vel != (0, 0, 0)) travel = Vel.Unit();
		Vector3 before = pos;

		if (!announced)
		{
			announced = true;
			RSB_Log.Once(RSB_Log.LV_INFO, "bullet:spawn", String.Format(
				"first round this map: %s, %s hand, %.0f units a tic", roundId, (hand == 0) ? "main" : "off", Vel.Length()));
		}

		Super.Tick();
		if (bDestroyed) return;

		if (glide && RSB_Settings.Glide())
		{
			double moved = (pos - before).Length();
			// Not across a teleport or portal jump.
			if (moved > 0 && moved <= Speed * 1.5 + 1.0) Prev = before;
		}
		LayWake(before);
		Whiz(before);
	}

	// DAMAGE: the shooter's damageMin-damageMax when set; otherwise the profile's
	// base x 1d(dice); without a profile, the vanilla pistol's 5 x 1d3. This runs
	// after the engine's own missile roll, so the value returned replaces it.
	override int DoSpecialDamage(Actor victim, int damage, Name damagetype)
	{
		int dealt;
		if (damageMin > 0)
		{
			dealt = random[RSBBullet](damageMin, max(damageMin, damageMax));
		}
		else
		{
			let d = Def();
			if (d) dealt = d.damageBase * random[RSBBullet](1, d.damageDice);
			else dealt = 5 * random[RSBBullet](1, 3);
		}
		return Super.DoSpecialDamage(victim, dealt, damagetype);
	}

	private void Landed()
	{
		if (BlockingMobj != null) return;   // an actor bleeds; its own mod decides how
		let d = Def();
		if (d) RSB_Impact.Land(self, d.impact, travel);
	}

	private void LayWake(Vector3 before)
	{
		let d = Def();
		if (!d || d.wake ~== "none") return;
		int tier = RSB_Tier.Current();
		if (tier <= RSB_Tier.T_OFF) return;
		let reg = RSB_Registry.Get();
		if (!reg) return;
		let w = reg.ResolveWake(d.wake, RSB_Tier.Name(tier));
		if (!w || w.perStep <= 0) return;

		int n = clamp(int(w.perStep * RSB_Tier.CountScale(tier) * RSB_Settings.Wake() + 0.5), 0, 32);
		Vector3 seg = pos - before;
		int posSeed = RSB_Hash.OfPos(pos);
		for (int k = 0; k < n; k++)
		{
			double t = (k + 0.5) / n;
			level.SpawnGpuParticles(before + seg * t, -travel, 1, 180.0, w.drift, 0.5, w.tint, w.glow,
				w.life, 0.3, w.sizeStart, w.sizeEnd, w.gravity, w.drag, 0, 0,
				RSB_Hash.Seed(level.maptime, k + 1, posSeed));
		}
	}

	// THE CLOSEST THIS TIC'S TRAVEL CAME TO THE LISTENER'S HEAD. Once per round,
	// never for the listener's own shots.
	private void Whiz(Vector3 before)
	{
		if (whizzed) return;
		let d = Def();
		if (!d || d.whizRadius <= 0 || d.whizSound ~== "none") return;
		if (shooterNum == consoleplayer) return;
		if (!RSB_Settings.Whiz()) return;
		double range = d.whizRadius * RSB_Settings.WhizRange();
		double vol = RSB_Settings.WhizVolume();
		if (range <= 0 || vol <= 0) return;
		let cam = players[consoleplayer].camera;
		if (!cam) return;

		Vector3 ear = cam.pos;
		if (cam.player) ear.z = cam.player.viewz;
		Vector3 seg = pos - before;
		double len2 = seg dot seg;
		double t = 0;
		if (len2 > 0) t = clamp(((ear - before) dot seg) / len2, 0.0, 1.0);
		Vector3 closest = before + seg * t;
		if ((ear - closest).Length() > range) return;

		whizzed = true;
		A_StartSound(d.whizSound, CHAN_AUTO, CHANF_OVERLAP, vol);
	}
}
