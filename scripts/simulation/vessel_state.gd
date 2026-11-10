class_name VesselState
extends RefCounted
## The contents and temperature of one vessel. Plain data: no nodes, no drawing.
## Liquids are a ledger of what was added (mL per chemical id); dissolved and undissolved
## solids are grams per chemical id. Derived values (pH, colour) are computed, not stored.

const EPSILON := 1.0e-6
## Observation history is capped so a long session cannot grow without bound.
const MAX_OBSERVATIONS := 60

var capacity_ml: float = 0.0
var temperature_c: float = 22.0
var liquids: Dictionary = {}
var solids: Dictionary = {}
var dissolved: Dictionary = {}
## Remaining time (simulated seconds) during which the contents are being stirred.
var stir_time_left_s: float = 0.0
## Moles of H⁺/OH⁻ already neutralised (so heat is released only once per mole).
var neutralised_mol: float = 0.0
## Which observations were already announced (key -> true, or the last announced state).
var fired_observations: Dictionary = {}
## Newest last. Each: {key, kind, text, explanation, time_s}
var observations: Array = []


func liquid_volume_ml() -> float:
	var total := 0.0
	for amount in liquids.values():
		total += float(amount)
	return total


func free_volume_ml() -> float:
	return maxf(capacity_ml - liquid_volume_ml(), 0.0)


func has_liquid() -> bool:
	return liquid_volume_ml() > EPSILON


func has_solids() -> bool:
	for amount in solids.values():
		if float(amount) > EPSILON:
			return true
	return false


func is_empty() -> bool:
	return not has_liquid() and not has_solids() and dissolved.is_empty()


func add_liquid(chemical_id: String, volume_ml: float) -> void:
	liquids[chemical_id] = float(liquids.get(chemical_id, 0.0)) + volume_ml


func add_solid(chemical_id: String, mass_g: float) -> void:
	solids[chemical_id] = float(solids.get(chemical_id, 0.0)) + mass_g


## Removes a fraction (0..1) of every liquid and returns what was removed (id -> mL).
func take_liquid_fraction(fraction: float) -> Dictionary:
	var removed: Dictionary = {}
	for chemical_id in liquids.keys():
		var amount := float(liquids[chemical_id])
		var part := amount * fraction
		removed[chemical_id] = part
		if amount - part <= EPSILON:
			liquids.erase(chemical_id)
		else:
			liquids[chemical_id] = amount - part
	return removed


func add_observation(entry: Dictionary) -> void:
	observations.append(entry)
	if observations.size() > MAX_OBSERVATIONS:
		observations.pop_front()


func to_dictionary() -> Dictionary:
	return {
		"capacity_ml": capacity_ml,
		"temperature_c": temperature_c,
		"liquids": liquids.duplicate(),
		"solids": solids.duplicate(),
		"dissolved": dissolved.duplicate(),
		"stir_time_left_s": stir_time_left_s,
		"neutralised_mol": neutralised_mol,
		"fired_observations": fired_observations.duplicate(true),
		"observations": observations.duplicate(true),
	}


static func from_dictionary(data: Dictionary) -> VesselState:
	var vessel := VesselState.new()
	vessel.capacity_ml = float(data.get("capacity_ml", 0.0))
	vessel.temperature_c = float(data.get("temperature_c", 22.0))
	vessel.liquids = (data.get("liquids", {}) as Dictionary).duplicate()
	vessel.solids = (data.get("solids", {}) as Dictionary).duplicate()
	vessel.dissolved = (data.get("dissolved", {}) as Dictionary).duplicate()
	vessel.stir_time_left_s = float(data.get("stir_time_left_s", 0.0))
	vessel.neutralised_mol = float(data.get("neutralised_mol", 0.0))
	vessel.fired_observations = (data.get("fired_observations", {}) as Dictionary).duplicate(true)
	vessel.observations = (data.get("observations", []) as Array).duplicate(true)
	return vessel
