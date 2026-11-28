class_name VesselState
extends RefCounted
## Serializable contents and thermodynamic state for one virtual vessel.
## Amount ledgers are separated by phase: liquids (mL), solids/dissolved (g), gases (mol).

const EPSILON := 1.0e-6
const MAX_OBSERVATIONS := 60
const GAS_CONSTANT_J_PER_MOL_K := 8.314462618
const DEFAULT_AMBIENT_PRESSURE_KPA := 101.325
const MIN_HEADSPACE_L := 0.005

var capacity_ml: float = 0.0
var temperature_c: float = 22.0
var liquids: Dictionary = {}
var solids: Dictionary = {}
var dissolved: Dictionary = {}
## Gas substance id -> amount in moles.
var gases: Dictionary = {}
## Once gas is introduced, the model installs a virtual stopper and retains the gas.
var is_closed_system: bool = false
## Moles of room air captured when the virtual system is first sealed.
var trapped_air_moles: float = 0.0
var stir_time_left_s: float = 0.0
var neutralised_mol: float = 0.0
var fired_observations: Dictionary = {}
var observations: Array = []
## Ids of binary melting systems (data/materials/binary_systems.json) whose components have been
## melted together in this vessel: system id -> true. Once set, re-frozen solid is one alloy,
## not two separate metals. Absent in sessions saved before alloys existed (treated as empty).
var fused_systems: Dictionary = {}


func liquid_volume_ml() -> float:
	var total := 0.0
	for amount in liquids.values():
		total += float(amount)
	return total


func free_volume_ml() -> float:
	return maxf(capacity_ml - liquid_volume_ml(), 0.0)


func headspace_l() -> float:
	return maxf((capacity_ml - liquid_volume_ml()) / 1000.0, MIN_HEADSPACE_L)


func has_gas() -> bool:
	for amount in gases.values():
		if float(amount) > EPSILON:
			return true
	return false


func total_gas_moles() -> float:
	var total := 0.0
	for amount in gases.values():
		total += float(amount)
	return total


func seal_system(ambient_pressure_kpa: float = DEFAULT_AMBIENT_PRESSURE_KPA) -> void:
	if is_closed_system:
		return
	var temperature_k := maxf(temperature_c + 273.15, 1.0)
	trapped_air_moles = maxf(ambient_pressure_kpa, 1.0) * headspace_l() / (GAS_CONSTANT_J_PER_MOL_K * temperature_k)
	is_closed_system = true


## Adds a virtual gas sample. An open vessel is sealed automatically before gas is retained.
func add_gas(chemical_id: String, amount_mol: float,
		ambient_pressure_kpa: float = DEFAULT_AMBIENT_PRESSURE_KPA) -> void:
	if not is_closed_system:
		seal_system(ambient_pressure_kpa)
	gases[chemical_id] = float(gases.get(chemical_id, 0.0)) + amount_mol


func pressure_after_adding_gas(amount_mol: float,
		ambient_pressure_kpa: float = DEFAULT_AMBIENT_PRESSURE_KPA) -> float:
	var temperature_k := maxf(temperature_c + 273.15, 1.0)
	var air_moles := trapped_air_moles
	if not is_closed_system:
		air_moles = maxf(ambient_pressure_kpa, 1.0) * headspace_l() / (GAS_CONSTANT_J_PER_MOL_K * temperature_k)
	return (air_moles + total_gas_moles() + amount_mol) * GAS_CONSTANT_J_PER_MOL_K * temperature_k / headspace_l()


## Absolute pressure in the virtual vessel. Open systems remain at ambient pressure.
func pressure_kpa(ambient_pressure_kpa: float = DEFAULT_AMBIENT_PRESSURE_KPA) -> float:
	if not is_closed_system:
		return ambient_pressure_kpa
	var temperature_k := maxf(temperature_c + 273.15, 1.0)
	return (trapped_air_moles + total_gas_moles()) * GAS_CONSTANT_J_PER_MOL_K * temperature_k / headspace_l()


## Maximum safe temperature for the current closed-system gas load and pressure limit.
## Open systems are not pressure-limited by the sealed-gas model.
func max_temperature_c_for_pressure_limit(pressure_limit_kpa: float) -> float:
	if not is_closed_system:
		return INF
	if pressure_limit_kpa <= 0.0:
		return -273.15
	var total_moles := trapped_air_moles + total_gas_moles()
	if total_moles <= EPSILON:
		return INF
	var temperature_k := pressure_limit_kpa * headspace_l() / (GAS_CONSTANT_J_PER_MOL_K * total_moles)
	return maxf(temperature_k - 273.15, -273.15)


## Returns the amount vented in the model and restores an open vessel at ambient pressure.
func open_system() -> Dictionary:
	var released := gases.duplicate(true)
	gases.clear()
	trapped_air_moles = 0.0
	is_closed_system = false
	return released


func has_liquid() -> bool:
	return liquid_volume_ml() > EPSILON


func has_solids() -> bool:
	for amount in solids.values():
		if float(amount) > EPSILON:
			return true
	return false


func is_empty() -> bool:
	return not has_liquid() and not has_solids() and dissolved.is_empty() and not has_gas()


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
		"gases": gases.duplicate(),
		"is_closed_system": is_closed_system,
		"trapped_air_moles": trapped_air_moles,
		"stir_time_left_s": stir_time_left_s,
		"neutralised_mol": neutralised_mol,
		"fired_observations": fired_observations.duplicate(true),
		"observations": observations.duplicate(true),
		"fused_systems": fused_systems.duplicate(),
	}


static func from_dictionary(data: Dictionary) -> VesselState:
	var vessel := VesselState.new()
	vessel.capacity_ml = float(data.get("capacity_ml", 0.0))
	vessel.temperature_c = float(data.get("temperature_c", 22.0))
	vessel.liquids = (data.get("liquids", {}) as Dictionary).duplicate()
	vessel.solids = (data.get("solids", {}) as Dictionary).duplicate()
	vessel.dissolved = (data.get("dissolved", {}) as Dictionary).duplicate()
	vessel.gases = (data.get("gases", {}) as Dictionary).duplicate()
	vessel.is_closed_system = bool(data.get("is_closed_system", false))
	vessel.trapped_air_moles = float(data.get("trapped_air_moles", 0.0))
	vessel.stir_time_left_s = float(data.get("stir_time_left_s", 0.0))
	vessel.neutralised_mol = float(data.get("neutralised_mol", 0.0))
	vessel.fired_observations = (data.get("fired_observations", {}) as Dictionary).duplicate(true)
	vessel.observations = (data.get("observations", []) as Array).duplicate(true)
	var fused: Variant = data.get("fused_systems", {})
	if typeof(fused) == TYPE_DICTIONARY:
		vessel.fused_systems = (fused as Dictionary).duplicate()
	return vessel
