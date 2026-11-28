class_name ThermalProperties
extends RefCounted
## Heat capacities of vessels. Shared by the HeatSystem and the ReactionEngine so both
## use the same numbers (constants come from data/simulation/simulation_constants.json).


## Heat capacity (J/K) of the contents. A substance with a thermal profile (data/chemicals
## "thermal" block) uses its own specific heat for each phase. Liquids without one are treated as
## water, as before, and solids without one are ignored (documented simplification).
static func contents_capacity_j_per_k(vessel: VesselState, db: ContentDatabase) -> float:
	var water_specific_heat := db.constant("specific_heat_water_j_per_g_k", 4.184)
	var total := 0.0
	for chemical_id in vessel.liquids.keys():
		var chemical := db.get_chemical(str(chemical_id))
		var density := 1.0 if chemical == null else db.liquid_density_g_ml(str(chemical_id))
		var specific_heat := water_specific_heat
		if chemical != null and chemical.thermal != null:
			var own := chemical.thermal.cp_for_phase("liquid")
			if is_finite(own):
				specific_heat = own
		total += float(vessel.liquids[chemical_id]) * density * specific_heat
	for chemical_id in vessel.solids.keys():
		var chemical := db.get_chemical(str(chemical_id))
		if chemical != null and chemical.thermal != null:
			var own := chemical.thermal.cp_for_phase("solid")
			if is_finite(own):
				total += float(vessel.solids[chemical_id]) * own
	return total


static func glass_capacity_j_per_k(equipment: EquipmentDefinition, db: ContentDatabase) -> float:
	if equipment == null:
		return 0.0
	return equipment.glass_mass_g * db.constant("specific_heat_glass_j_per_g_k", 0.84)


static func total_capacity_j_per_k(vessel: VesselState, equipment: EquipmentDefinition, db: ContentDatabase) -> float:
	return contents_capacity_j_per_k(vessel, db) + glass_capacity_j_per_k(equipment, db)
