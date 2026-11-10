class_name ThermalProperties
extends RefCounted
## Heat capacities of vessels. Shared by the HeatSystem and the ReactionEngine so both
## use the same numbers (constants come from data/simulation/simulation_constants.json).


## Heat capacity (J/K) of the liquid contents. Dilute aqueous liquids are treated as water;
## solids are ignored (documented simplification).
static func contents_capacity_j_per_k(vessel: VesselState, db: ContentDatabase) -> float:
	var water_specific_heat := db.constant("specific_heat_water_j_per_g_k", 4.184)
	var mass_g := 0.0
	for chemical_id in vessel.liquids.keys():
		var chemical := db.get_chemical(str(chemical_id))
		var density := 1.0 if chemical == null else chemical.density_g_ml
		mass_g += float(vessel.liquids[chemical_id]) * density
	return mass_g * water_specific_heat


static func glass_capacity_j_per_k(equipment: EquipmentDefinition, db: ContentDatabase) -> float:
	if equipment == null:
		return 0.0
	return equipment.glass_mass_g * db.constant("specific_heat_glass_j_per_g_k", 0.84)


static func total_capacity_j_per_k(vessel: VesselState, equipment: EquipmentDefinition, db: ContentDatabase) -> float:
	return contents_capacity_j_per_k(vessel, db) + glass_capacity_j_per_k(equipment, db)
