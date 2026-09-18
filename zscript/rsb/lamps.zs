// ============================================================================
// SHOOTING A LAMP THAT IS AN OBJECT. Torches, tech lamps, candelabra, burning
// barrels: Doom's lit decorations. Shoot one and its light dies with it.
//
// THE OWNER ASKED FOR EXACTLY THIS: "lamps would be dynamic lights, which we can
// sprite edit to 'shoot out' and snuff the dynamiuc light". It is the other half of
// the lights work, and the easier half -- a decoration carries its OWN light through
// GLDEFS, so killing it takes the light with no sector arithmetic, no fixture tally
// and no engine support at all. Both lanes had been calling it "gameplay, not ours"
// and nobody built it.
//
// IT IS GAMEPLAY, and it is handled as such: the decoration is made shootable in the
// playsim, on every machine, at map load. Not a look, not client-side, not skipped by
// the effects dial -- two players must not disagree about whether a torch is standing.
//
// WHAT HAPPENS WHEN IT DIES. Doom's decorations have no Death state, so the engine
// removes them outright, and a removed actor takes its GLDEFS light with it -- the
// light dying is free. What is NOT free is that the lamp would simply VANISH, which
// reads as a bug rather than as damage. So the break spawns RSB_DeadLamp: the same
// sprite and frame, shaded almost black, no light, standing where the lamp stood.
// The fixture is still there, it is just out.
//
// The glass, the sparks and the pop come from RS_Ballistics' ordinary `light`
// material impact, which has been shipping for weeks -- this adds no new look of its
// own beyond the dead prop.
// ============================================================================

// A lamp that has been shot out: the prop it was, dark and dead. Nothing ticks, nothing
// lights, nothing blocks differently -- it stands exactly where the original stood.
class RSB_DeadLamp : Actor
{
	Default
	{
		+SOLID
		+NOGRAVITY
		+DONTSPLASH
		+NOBLOCKMONST
		Radius 16;
		Height 16;
		RenderStyle "Normal";
	}

	States
	{
	Spawn:
		TNT1 A -1;
		Stop;
	}

	// Wear the dead lamp's own sprite, at the frame it was on, shaded down to almost nothing.
	void Become(Actor was, Color shade)
	{
		sprite = was.sprite;
		frame = was.frame;
		scale = was.scale;
		A_SetSize(was.radius, was.height);
		bSOLID = was.bSOLID;
		SetShade(shade);
	}
}

class RSB_Lamps : StaticEventHandler
{
	// MADE SHOOTABLE AT MAP LOAD, in the playsim. A decoration with no health and no
	// +SHOOTABLE ignores every round in the game; these get both, and +NOBLOOD so a lamp
	// does not bleed.
	override void WorldLoaded(WorldEvent e)
	{
		if (!RSB_Settings.ShootOutLamps()) return;
		let reg = RSB_Registry.Get();
		if (!reg || !reg.defs) return;

		int made = 0;
		ThinkerIterator it = ThinkerIterator.Create("Actor");
		Actor mo;
		while (mo = Actor(it.Next()))
		{
			if (mo.bSHOOTABLE || mo.bISMONSTER || mo.player) continue;
			if (!IsLampClass(reg, mo.GetClassName())) continue;
			mo.bSHOOTABLE = true;
			mo.bNOBLOOD = true;
			mo.health = RSB_Settings.LampHealth();
			made++;
		}
		if (made > 0)
			RSB_Log.Once(RSB_Log.LV_INFO, "lamps:made", String.Format(
				"%d lit decorations made shootable on this map", made));
	}

	// Does any `fixture` profile name this actor class? The list is RSBDEFS data so a mod's
	// own lamps are one line, not a code change.
	static bool IsLampClass(RSB_Registry reg, String cls)
	{
		for (int i = 0; i < reg.defs.defs.Size(); i++)
		{
			let f = RSB_FixtureDef(reg.defs.defs[i]);
			if (!f) continue;
			for (int k = 0; k < f.actors.Size(); k++)
				if (cls ~== f.actors[k]) return true;
		}
		return false;
	}

	// IT DIED: leave the dead prop standing where it was. The engine has already taken the
	// actor's GLDEFS light with it, which is the whole point.
	override void WorldThingDied(WorldEvent e)
	{
		let mo = e.Thing;
		if (!mo || mo.bISMONSTER || mo.player) return;
		if (!RSB_Settings.ShootOutLamps()) return;
		let reg = RSB_Registry.Get();
		if (!reg || !reg.defs || !IsLampClass(reg, mo.GetClassName())) return;

		let dead = RSB_DeadLamp(Actor.Spawn("RSB_DeadLamp", mo.pos, NO_REPLACE));
		if (dead) dead.Become(mo, RSB_Settings.DeadLampShade());
	}
}
