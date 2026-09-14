// ============================================================================
// 3D CASINGS: one class per casing mesh, so MODELDEF can give each its model (a
// MODELDEF block is per class; A_ChangeModel can swap a mesh but cannot make a
// sprite actor draw a model).
//
// An `ejecta` profile names one with `look = model, <class>`. Everything a casing
// does -- flight, bounces, sounds, lying still, fading -- is RSB_LocalEjecta's; these
// add only the height the mesh's centre sits at when it lies on its side.
//
// THE MESHES (models/casings, tools/gen_casings.py) are built in millimetres at real
// size; MODELDEF scales them by 1/30.5 (a 56-unit marine is 1.71 m). RestHeight is
// the mesh's lying radius in map units at that scale; the casing size setting
// multiplies it with the model.
//
// NETPLAY: as RSB_LocalEjecta -- a look on one machine, touching nothing.
// ============================================================================

class RSB_CasingModel : RSB_LocalEjecta
{
}

class RSB_Casing9mm : RSB_CasingModel
{
	override double RestHeight() { return 0.162; }
}

class RSB_Casing45 : RSB_CasingModel
{
	override double RestHeight() { return 0.197; }
}

class RSB_Casing357 : RSB_CasingModel
{
	override double RestHeight() { return 0.183; }
}

// Rifle brass: Force Unleashed's belt round cut to a 5.56 NATO case; the 7.62 is the
// same mesh scaled up in MODELDEF (51 mm long).
class RSB_CasingRifle556 : RSB_CasingModel
{
	override double RestHeight() { return 0.151; }
}

class RSB_CasingRifle762 : RSB_CasingModel
{
	override double RestHeight() { return 0.172; }
}

class RSB_Shell12ga : RSB_CasingModel
{
	override double RestHeight() { return 0.364; }
}
