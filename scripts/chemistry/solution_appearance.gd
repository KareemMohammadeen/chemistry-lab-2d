class_name SolutionAppearance
extends RefCounted
## Derives how the liquid in a vessel looks from its contents. Display only: the result
## never feeds back into the simulation.

const STRENGTH_EXPONENT := 0.7


## Colour of the liquid (alpha 0 when there is no liquid).
static func liquid_color(vessel: VesselState, db: ContentDatabase) -> Color:
	var total_ml := 0.0
	var mixed := Color(0.0, 0.0, 0.0, 0.0)
	for chemical_id in vessel.liquids.keys():
		var chemical := db.get_chemical(str(chemical_id))
		if chemical == null:
			continue
		var amount := float(vessel.liquids[chemical_id])
		mixed += chemical.color * amount
		total_ml += amount
	if total_ml <= 0.0:
		return Color(1.0, 1.0, 1.0, 0.0)
	var result := mixed / total_ml
	for solute_id in vessel.dissolved.keys():
		var chemical := db.get_chemical(str(solute_id))
		if chemical == null or not chemical.has_solution_color:
			continue
		result = result.lerp(chemical.solution_color, solute_strength(vessel, db, str(solute_id)))
	return result


## 0..1 strength of a dissolved substance's colour, from its concentration.
static func solute_strength(vessel: VesselState, db: ContentDatabase, solute_id: String) -> float:
	var chemical := db.get_chemical(solute_id)
	if chemical == null or not chemical.has_solution_color:
		return 0.0
	var solvent_ml := AcidBase.aqueous_volume_ml(vessel, db)
	if solvent_ml <= 0.0:
		return 0.0
	var concentration := float(vessel.dissolved.get(solute_id, 0.0)) / solvent_ml * 100.0
	var ratio := clampf(concentration / maxf(chemical.color_full_at_g_per_100ml, 0.001), 0.0, 1.0)
	return pow(ratio, STRENGTH_EXPONENT)
