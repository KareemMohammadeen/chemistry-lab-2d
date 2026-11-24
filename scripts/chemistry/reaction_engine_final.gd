class_name ReactionEngineFinal
extends RefCounted
## Complete reaction executor used by the simulation.
## Supports condition checks, stoichiometry, kinetics, equilibrium and pH-aware reporting.

const MIN_AMOUNT_G := 0.001
## Smallest reaction extent worth applying. VesselState.EPSILON (1e-6) is a ledger tolerance in
## mL/g and is far too coarse when the extent is measured in moles.
const MIN_EXTENT_MOL := 1.0e-9
const MIN_MOLES := 1.0e-9
const MIN_PROGRESS := 0.02
const DEFAULT_BOILING_POINT_C := 100.0

const PHASE_AMOUNT_UNITS := {
	"liquid": "mL",
	"solid": "g",
	"dissolved": "g",
	"gas": "mol",
}

var _db: ContentDatabase
var _handlers: Dictionary = {}


func _init(content: ContentDatabase) -> void:
	_db = content
	_handlers = {
		"dissolution": Callable(self, "_execute_dissolution_reaction"),
		"neutralisation": Callable(self, "_execute_neutralisation_reaction"),
		"boiling": Callable(self, "_execute_boiling_reaction"),
		"visual_demo": Callable(self, "_execute_visual_demo_reaction"),
		"gas_evolution": Callable(self, "_execute_generic_reaction"),
		"precipitation": Callable(self, "_execute_generic_reaction"),
		"single_displacement": Callable(self, "_execute_generic_reaction"),
		"double_displacement": Callable(self, "_execute_generic_reaction"),
		"acid_carbonate": Callable(self, "_execute_generic_reaction"),
		"combustion": Callable(self, "_execute_generic_reaction"),
		"phase_change": Callable(self, "_execute_generic_reaction"),
	}


func step_vessel(vessel: VesselState, dt: float, extra_heat_capacity_j_per_k: float) -> Array:
	var events: Array = []
	for result in execute_step_reactions(vessel, dt, extra_heat_capacity_j_per_k):
		events.append_array(result.observations)
	vessel.stir_time_left_s = maxf(vessel.stir_time_left_s - dt, 0.0)
	return events


func execute_step_reactions(vessel: VesselState, dt: float = 1.0, extra_heat_capacity_j_per_k: float = 0.0) -> Array:
	var results: Array = []
	if _db == null or vessel == null:
		return results
	for reaction_id in _enabled_reaction_ids():
		var reaction := _db.reactions.get(reaction_id) as ReactionDefinition
		if reaction == null or reaction.virtual_only or reaction.type == "visual_demo":
			continue
		var result := _execute_reaction(reaction, vessel, dt, extra_heat_capacity_j_per_k, true)
		if result.status == ReactionResult.Status.EXECUTED or result.status == ReactionResult.Status.MATCHED:
			results.append(result)
	return results


func execute_registered_reaction(reaction_id: String, vessel: VesselState, extra_heat_capacity_j_per_k: float = 0.0) -> ReactionResult:
	var result := ReactionResult.new()
	result.reaction_id = reaction_id
	if _db == null or vessel == null:
		result.status = ReactionResult.Status.INVALID
		result.message = "The reaction executor is missing its database or vessel."
		result.errors.append(result.message)
		return result
	var reaction := _db.reactions.get(reaction_id) as ReactionDefinition
	if reaction == null:
		result.status = ReactionResult.Status.REJECTED
		result.message = "The requested reaction does not exist."
		result.errors.append(result.message)
		return result
	return _execute_reaction(reaction, vessel, 0.0, extra_heat_capacity_j_per_k, false)


func run_visual_demo(vessel: VesselState, reaction_id: String) -> Dictionary:
	if _db == null or vessel == null:
		return {}
	var reaction := _db.reactions.get(reaction_id) as ReactionDefinition
	if reaction == null or reaction.type != "visual_demo" or not reaction.virtual_only:
		return {}
	var result := _execute_visual_demo_reaction(reaction, vessel, 0.0, false)
	if result.status != ReactionResult.Status.EXECUTED:
		return {}
	return {
		"key": "visual_demo:%s" % reaction_id,
		"kind": "visual_demo",
		"text": reaction.observation("summary"),
		"explanation": reaction.explanation,
		"equation": reaction.equation,
		"effect_id": reaction.visual_effect,
		"virtual_only": true,
	}


func add_gas_product(vessel: VesselState, chemical_id: String, amount: float, ambient_pressure_kpa: float = VesselState.DEFAULT_AMBIENT_PRESSURE_KPA) -> bool:
	if vessel == null or amount <= 0.0:
		return false
	var chemical := _db.get_chemical(chemical_id) if _db != null else null
	if chemical == null or chemical.state != "gas" or not chemical.virtual_simulation_enabled:
		return false
	if vessel.free_volume_ml() <= VesselState.EPSILON:
		return false
	var projected_pressure := vessel.pressure_after_adding_gas(amount, ambient_pressure_kpa)
	var pressure_limit := _db.constant("max_virtual_pressure_kpa", 300.0) if _db != null else 300.0
	if not is_finite(projected_pressure) or projected_pressure > pressure_limit:
		return false
	vessel.add_gas(chemical_id, amount, ambient_pressure_kpa)
	return true


func _enabled_reaction_ids() -> Array[String]:
	var reaction_ids: Array[String] = []
	if _db == null:
		return reaction_ids
	if _db.reaction_registry != null:
		reaction_ids = _db.reaction_registry.enabled_reaction_ids()
	else:
		reaction_ids = _db.reactions.keys()
		reaction_ids.sort()
	return reaction_ids


func _reaction_is_allowed(reaction: ReactionDefinition) -> bool:
	if reaction == null:
		return false
	if _db == null or _db.reaction_registry == null:
		return true
	if not _db.reaction_registry.has_reaction(reaction.id):
		return false
	return _db.reaction_registry.is_enabled(reaction.id)


func _reaction_handler_for(type: String) -> Callable:
	return _handlers.get(type, Callable(self, "_execute_generic_reaction"))


func _execute_reaction(reaction: ReactionDefinition, vessel: VesselState, dt: float, extra_heat_capacity_j_per_k: float, step_mode: bool) -> ReactionResult:
	var result := ReactionResult.new()
	result.reaction_id = reaction.id
	result.reaction_name = reaction.display_name
	result.reaction_type = reaction.type

	if not _reaction_is_allowed(reaction):
		result.status = ReactionResult.Status.REJECTED
		result.message = "The reaction is registered but disabled."
		result.errors.append(result.message)
		return result

	if reaction.type == "visual_demo":
		result.status = ReactionResult.Status.REJECTED
		result.message = "Visual demos are user-triggered, not ambient simulation steps."
		result.errors.append(result.message)
		return result

	if not _conditions_allow_reaction(reaction, vessel, result):
		result.status = ReactionResult.Status.INVALID if not result.errors.is_empty() else ReactionResult.Status.NOT_MATCHED
		if result.message.is_empty():
			result.message = "The reaction conditions are not satisfied."
		return result

	var handler := _reaction_handler_for(reaction.type)
	if not handler.is_valid():
		result.status = ReactionResult.Status.REJECTED
		result.message = "No executor exists for reaction type '%s'." % reaction.type
		result.errors.append(result.message)
		return result

	return handler.call(reaction, vessel, extra_heat_capacity_j_per_k, dt if step_mode else 0.0)


func _execute_dissolution_reaction(reaction: ReactionDefinition, vessel: VesselState, extra_heat_capacity_j_per_k: float = 0.0, dt: float = 0.0) -> ReactionResult:
	if not reaction.reactants.is_empty() or not reaction.products.is_empty():
		return _execute_generic_reaction(reaction, vessel, extra_heat_capacity_j_per_k, dt)

	var result := ReactionResult.new()
	result.reaction_id = reaction.id
	result.reaction_name = reaction.display_name
	result.reaction_type = reaction.type
	var solute_id := reaction.solute
	if solute_id.is_empty() and not reaction.substance.is_empty():
		solute_id = reaction.substance
	if solute_id.is_empty():
		result.status = ReactionResult.Status.REJECTED
		result.message = "The reaction definition does not name a solute."
		result.errors.append(result.message)
		return result
	var available_g := float(vessel.solids.get(solute_id, 0.0))
	if available_g <= VesselState.EPSILON:
		result.status = ReactionResult.Status.NOT_MATCHED
		result.message = "No solid solute is present to dissolve."
		return result
	var progress := _reaction_progress(reaction, vessel, dt)
	result.progress = progress
	var moved_g := minf(available_g, maxf(available_g * progress, MIN_AMOUNT_G))
	vessel.solids[solute_id] = maxf(available_g - moved_g, 0.0)
	if vessel.solids[solute_id] <= VesselState.EPSILON:
		vessel.solids.erase(solute_id)
	vessel.dissolved[solute_id] = float(vessel.dissolved.get(solute_id, 0.0)) + moved_g
	result.consumed = {"solid": {solute_id: moved_g}}
	result.produced = {"dissolved": {solute_id: moved_g}}
	result.message = reaction.observation("summary")
	if result.message.is_empty():
		result.message = "The solid dissolves in the virtual solvent."
	_append_result_observation(result, vessel, "dissolution:%s" % reaction.id, "reaction", result.message, reaction.explanation, "dissolution_particles")
	result.status = ReactionResult.Status.EXECUTED
	return result


func _execute_neutralisation_reaction(reaction: ReactionDefinition, vessel: VesselState, extra_heat_capacity_j_per_k: float = 0.0, dt: float = 0.0) -> ReactionResult:
	var result := _execute_generic_reaction(reaction, vessel, extra_heat_capacity_j_per_k, dt)
	if result.status != ReactionResult.Status.EXECUTED:
		return result
	var ph := AcidBase.compute_ph(vessel, _db)
	var outcome := "neutral"
	if not is_nan(ph):
		if ph < 6.5:
			outcome = "acidic"
		elif ph > 7.5:
			outcome = "basic"
	var ph_key := outcome if reaction.observation(outcome) != "" else "neutral"
	if reaction.observation(ph_key) != "":
		_append_result_observation(result, vessel, "neutralisation:ph:%s" % reaction.id, "ph", reaction.observation(ph_key), reaction.explanation, "indicator_shift")
	if reaction.observation("heat") != "":
		_append_result_observation(result, vessel, "neutralisation:heat:%s" % reaction.id, "heat", reaction.observation("heat"), reaction.explanation, "heat_wave")
	return result


func _execute_boiling_reaction(reaction: ReactionDefinition, vessel: VesselState, extra_heat_capacity_j_per_k: float = 0.0, dt: float = 0.0) -> ReactionResult:
	var result := ReactionResult.new()
	result.reaction_id = reaction.id
	result.reaction_name = reaction.display_name
	result.reaction_type = reaction.type
	result.progress = _reaction_progress(reaction, vessel, dt)
	if vessel.temperature_c + 1.0e-6 < DEFAULT_BOILING_POINT_C:
		result.status = ReactionResult.Status.NOT_MATCHED
		result.message = "The liquid has not yet reached its boiling point."
		return result
	vessel.temperature_c = minf(vessel.temperature_c, DEFAULT_BOILING_POINT_C)
	result.message = reaction.observation("boiling")
	if result.message.is_empty():
		result.message = "The liquid is boiling."
	_append_result_observation(result, vessel, "boiling:%s" % reaction.id, "boiling", result.message, reaction.explanation, "vapour_stream")
	result.status = ReactionResult.Status.EXECUTED
	return result


func _execute_visual_demo_reaction(reaction: ReactionDefinition, vessel: VesselState, extra_heat_capacity_j_per_k: float = 0.0, dt: float = 0.0) -> ReactionResult:
	var result := ReactionResult.new()
	result.reaction_id = reaction.id
	result.reaction_name = reaction.display_name
	result.reaction_type = reaction.type
	var fired_key := "visual_demo:%s" % reaction.id
	if vessel.fired_observations.has(fired_key):
		result.status = ReactionResult.Status.NOT_MATCHED
		result.message = "The visual demo has already been shown."
		return result
	var product := _db.get_chemical(reaction.product_solid_id) if _db != null else null
	if product == null or product.state != "solid":
		result.status = ReactionResult.Status.REJECTED
		result.message = "The visual demo product is missing or invalid."
		result.errors.append(result.message)
		return result
	if reaction.illustrative_output_g <= 0.0 or reaction.illustrative_output_g > 5.0:
		result.status = ReactionResult.Status.REJECTED
		result.message = "The visual demo amount is outside the safe illustrative range."
		result.errors.append(result.message)
		return result
	vessel.add_solid(product.id, reaction.illustrative_output_g)
	vessel.fired_observations[fired_key] = true
	result.status = ReactionResult.Status.EXECUTED
	result.message = reaction.observation("summary")
	result.observations.append({"key": fired_key, "kind": "visual_demo", "text": reaction.observation("summary"), "explanation": reaction.explanation})
	if reaction.visual_effect != "":
		result.effects = [{"effect_id": reaction.visual_effect, "kind": "visual_demo", "intensity": 1.0, "reaction_id": reaction.id}]
	return result


func _execute_generic_reaction(reaction: ReactionDefinition, vessel: VesselState, extra_heat_capacity_j_per_k: float = 0.0, dt: float = 0.0) -> ReactionResult:
	var result := ReactionResult.new()
	result.reaction_id = reaction.id
	result.reaction_name = reaction.display_name
	result.reaction_type = reaction.type

	var missing_data := _participants_missing_conversion_data(reaction)
	if not missing_data.is_empty():
		result.status = ReactionResult.Status.INVALID
		result.message = "Reaction '%s' cannot run: no molar mass or concentration data for %s." % [reaction.id, ", ".join(missing_data)]
		result.errors.append(result.message)
		return result

	var reactant_extent := _reactant_extent(reaction, vessel)
	if reactant_extent <= MIN_EXTENT_MOL:
		result.status = ReactionResult.Status.NOT_MATCHED
		result.message = "The required reactants are not present in enough quantity."
		return result

	var progress := _reaction_progress(reaction, vessel, dt)
	result.progress = progress
	var extent := reactant_extent * progress
	if extent <= MIN_EXTENT_MOL:
		result.status = ReactionResult.Status.NOT_MATCHED
		result.message = "The reaction would proceed only negligibly at this time step."
		return result

	if not _generic_products_fit(vessel, reaction, extent):
		result.status = ReactionResult.Status.REJECTED
		result.message = "The product set cannot be represented safely in the virtual vessel."
		result.errors.append(result.message)
		return result

	var before_temperature := vessel.temperature_c
	var capacity := maxf(ThermalProperties.contents_capacity_j_per_k(vessel, _db) + extra_heat_capacity_j_per_k, 0.0)
	if capacity > 0.0 and is_finite(reaction.enthalpy_kj_per_mol) and absf(reaction.enthalpy_kj_per_mol) > 0.0:
		vessel.temperature_c -= reaction.enthalpy_kj_per_mol * 1000.0 * extent / capacity
		var pressure_limit := _db.constant("max_virtual_pressure_kpa", VesselState.DEFAULT_AMBIENT_PRESSURE_KPA) if _db != null else VesselState.DEFAULT_AMBIENT_PRESSURE_KPA
		vessel.temperature_c = minf(vessel.temperature_c, vessel.max_temperature_c_for_pressure_limit(pressure_limit))
	result.temperature_delta_c = vessel.temperature_c - before_temperature
	result.energy_kj = reaction.enthalpy_kj_per_mol * extent

	result.consumed = _ledger_for(reaction.reactants, extent)
	result.produced = _ledger_for(reaction.products, extent)

	for participant_value in reaction.reactants:
		if typeof(participant_value) != TYPE_DICTIONARY:
			continue
		var participant: Dictionary = participant_value
		var chemical_id := str(participant.get("chemical_id", ""))
		var phase := str(participant.get("phase", ""))
		var amount := _ledger_amount(participant, extent)
		if amount <= 0.0:
			continue
		if not _remove_from_phase_ledger(vessel, phase, chemical_id, amount):
			result.status = ReactionResult.Status.REJECTED
			result.message = "The generic executor could not remove all reactants from the vessel."
			result.errors.append(result.message)
			return result

	for participant_value in reaction.products:
		if typeof(participant_value) != TYPE_DICTIONARY:
			continue
		var participant: Dictionary = participant_value
		var chemical_id := str(participant.get("chemical_id", ""))
		var phase := str(participant.get("phase", ""))
		var amount := _ledger_amount(participant, extent)
		if amount <= 0.0:
			continue
		match phase:
			"liquid":
				vessel.add_liquid(chemical_id, amount)
			"solid":
				vessel.add_solid(chemical_id, amount)
			"dissolved":
				vessel.dissolved[chemical_id] = float(vessel.dissolved.get(chemical_id, 0.0)) + amount
			"gas":
				var ambient_pressure := _db.constant("ambient_pressure_kpa", VesselState.DEFAULT_AMBIENT_PRESSURE_KPA) if _db != null else VesselState.DEFAULT_AMBIENT_PRESSURE_KPA
				vessel.add_gas(chemical_id, amount, ambient_pressure)

	result.message = _reaction_message(reaction, extent)
	if result.message.is_empty():
		result.message = "The registered reaction completed in the virtual model."

	var gas_total := _product_moles_total(reaction, extent)
	if gas_total > 0.0:
		result.effects.append({"effect_id": "gas_bubbles", "kind": "gas", "intensity": clampf(gas_total, 0.2, 1.0), "reaction_id": reaction.id})
	for participant_value in reaction.products:
		if typeof(participant_value) != TYPE_DICTIONARY:
			continue
		var participant: Dictionary = participant_value
		if str(participant.get("phase", "")) == "solid":
			result.effects.append({"effect_id": "precipitate_cloud", "kind": "precipitate", "intensity": 0.8, "reaction_id": reaction.id})
	if reaction.visual_effect != "":
		result.effects.append({"effect_id": reaction.visual_effect, "kind": "reaction", "intensity": 1.0, "reaction_id": reaction.id})

	_append_result_observation(result, vessel, "generic_reaction:%s" % reaction.id, "reaction", result.message, reaction.explanation, reaction.visual_effect)
	result.status = ReactionResult.Status.EXECUTED
	return result


## Names the participants whose amounts cannot be converted to moles (missing data).
func _participants_missing_conversion_data(reaction: ReactionDefinition) -> Array:
	var missing: Array = []
	for participant_value in reaction.reactants + reaction.products:
		if typeof(participant_value) != TYPE_DICTIONARY:
			continue
		var participant: Dictionary = participant_value
		var chemical_id := str(participant.get("chemical_id", ""))
		var chemical := _db.get_chemical(chemical_id) if _db != null else null
		if chemical != null and chemical.virtual_simulation_enabled and _moles_per_ledger_unit(participant) <= 0.0 \
				and not missing.has(chemical_id):
			missing.append(chemical_id)
	return missing


## Molar mass of a participant: the chemical's own value, else its compound record.
func _molar_mass_g_mol(chemical_id: String) -> float:
	var chemical := _db.get_chemical(chemical_id) if _db != null else null
	if chemical != null and is_finite(chemical.molar_mass_g_mol) and chemical.molar_mass_g_mol > 0.0:
		return chemical.molar_mass_g_mol
	var compound := _db.get_compound(chemical_id) if _db != null else null
	if compound != null and is_finite(compound.molar_mass_g_mol) and compound.molar_mass_g_mol > 0.0:
		return compound.molar_mass_g_mol
	return NAN


## Moles represented by one ledger unit of the participant (1 mL, 1 g or 1 mol, by phase).
## Returns 0 when the data needed for the conversion is missing, so the reaction fails closed.
func _moles_per_ledger_unit(participant: Dictionary) -> float:
	var chemical_id := str(participant.get("chemical_id", ""))
	var chemical := _db.get_chemical(chemical_id) if _db != null else null
	if chemical == null:
		return 0.0
	match str(participant.get("phase", "")):
		"gas":
			return 1.0
		"solid", "dissolved":
			var molar_mass := _molar_mass_g_mol(chemical_id)
			return 1.0 / molar_mass if is_finite(molar_mass) else 0.0
		"liquid":
			if chemical.concentration_mol_per_l > 0.0:
				return chemical.concentration_mol_per_l / 1000.0
			var liquid_molar_mass := _molar_mass_g_mol(chemical_id)
			if not is_finite(liquid_molar_mass) or chemical.density_g_ml <= 0.0:
				return 0.0
			return chemical.density_g_ml / liquid_molar_mass
	return 0.0


## Ledger amount (mL, g or mol) that corresponds to `extent` moles of reaction.
func _ledger_amount(participant: Dictionary, extent: float) -> float:
	var moles_per_unit := _moles_per_ledger_unit(participant)
	if moles_per_unit <= 0.0:
		return 0.0
	return float(participant.get("coefficient", 1.0)) * extent / moles_per_unit


func _product_moles_total(reaction: ReactionDefinition, extent: float) -> float:
	var total := 0.0
	for participant_value in reaction.products:
		if typeof(participant_value) != TYPE_DICTIONARY:
			continue
		var participant: Dictionary = participant_value
		if str(participant.get("phase", "")) == "gas":
			total += float(participant.get("coefficient", 1.0)) * extent
	return total


func _reaction_progress(reaction: ReactionDefinition, vessel: VesselState, dt: float) -> float:
	if dt <= 0.0:
		return 1.0
	var time_constant_s := maxf(_num(reaction.kinetics, "time_constant_s", reaction.time_constant_s), 0.0)
	var progress := 1.0
	if time_constant_s > 0.0:
		progress = 1.0 - exp(-dt / time_constant_s)
	progress *= clampf(_num(reaction.kinetics, "rate_multiplier", 1.0), 0.01, 50.0)
	if reaction.equilibrium.has("enabled") and bool(reaction.equilibrium.get("enabled", false)):
		var equilibrium_constant := _num(reaction.equilibrium, "equilibrium_constant", 0.0)
		if equilibrium_constant > 0.0:
			var quotient := _reaction_quotient(reaction, vessel)
			progress *= clampf(equilibrium_constant / (equilibrium_constant + quotient), 0.05, 1.0)
	return clampf(progress, MIN_PROGRESS, 1.0)


func _conditions_allow_reaction(reaction: ReactionDefinition, vessel: VesselState, result: ReactionResult) -> bool:
	if reaction.conditions.is_empty():
		return true
	var check := ReactionConditions.evaluate(reaction.conditions, vessel, _db)
	if bool(check["ok"]):
		return true
	result.message = str(check["message"])
	if not bool(check["unsatisfied"]):
		result.errors.append(result.message)
	return false


func _reaction_quotient(reaction: ReactionDefinition, vessel: VesselState) -> float:
	var products := 1.0
	var reactants := 1.0
	for participant_value in reaction.products:
		if typeof(participant_value) != TYPE_DICTIONARY:
			continue
		var participant: Dictionary = participant_value
		var amount := maxf(_participant_amount_on_vessel(participant, vessel), MIN_MOLES)
		var coefficient := maxf(float(participant.get("coefficient", 1.0)), 1.0)
		products *= pow(amount, 1.0 / coefficient)
	for participant_value in reaction.reactants:
		if typeof(participant_value) != TYPE_DICTIONARY:
			continue
		var participant: Dictionary = participant_value
		var amount := maxf(_participant_amount_on_vessel(participant, vessel), MIN_MOLES)
		var coefficient := maxf(float(participant.get("coefficient", 1.0)), 1.0)
		reactants *= pow(amount, 1.0 / coefficient)
	return products / maxf(reactants, MIN_MOLES)


func _reaction_message(reaction: ReactionDefinition, extent: float) -> String:
	if reaction.observation("summary") != "":
		return reaction.observation("summary")
	if reaction.observation("completed") != "":
		return reaction.observation("completed")
	if extent > 0.0:
		return "The registered reaction completed in the virtual model."
	return ""


func _ledger_for(participants: Array, extent: float) -> Dictionary:
	var ledger: Dictionary = {}
	for participant_value in participants:
		if typeof(participant_value) != TYPE_DICTIONARY:
			continue
		var participant: Dictionary = participant_value
		var phase := str(participant.get("phase", ""))
		var chemical_id := str(participant.get("chemical_id", ""))
		if phase.is_empty() or chemical_id.is_empty():
			continue
		var amount := _ledger_amount(participant, extent)
		if amount <= 0.0:
			continue
		if not ledger.has(phase):
			ledger[phase] = {}
		var phase_ledger: Dictionary = ledger[phase]
		phase_ledger[chemical_id] = float(phase_ledger.get(chemical_id, 0.0)) + amount
		ledger[phase] = phase_ledger
	return ledger


func _remove_from_phase_ledger(vessel: VesselState, phase: String, chemical_id: String, amount: float) -> bool:
	if amount <= 0.0:
		return true
	match phase:
		"liquid":
			var current_liquid := float(vessel.liquids.get(chemical_id, 0.0))
			if current_liquid + VesselState.EPSILON < amount:
				return false
			current_liquid -= amount
			if current_liquid <= VesselState.EPSILON:
				vessel.liquids.erase(chemical_id)
			else:
				vessel.liquids[chemical_id] = current_liquid
			return true
		"solid":
			var current_solid := float(vessel.solids.get(chemical_id, 0.0))
			if current_solid + VesselState.EPSILON < amount:
				return false
			current_solid -= amount
			if current_solid <= VesselState.EPSILON:
				vessel.solids.erase(chemical_id)
			else:
				vessel.solids[chemical_id] = current_solid
			return true
		"dissolved":
			var current_dissolved := float(vessel.dissolved.get(chemical_id, 0.0))
			if current_dissolved + VesselState.EPSILON < amount:
				return false
			current_dissolved -= amount
			if current_dissolved <= VesselState.EPSILON:
				vessel.dissolved.erase(chemical_id)
			else:
				vessel.dissolved[chemical_id] = current_dissolved
			return true
		"gas":
			var current_gas := float(vessel.gases.get(chemical_id, 0.0))
			if current_gas + VesselState.EPSILON < amount:
				return false
			current_gas -= amount
			if current_gas <= VesselState.EPSILON:
				vessel.gases.erase(chemical_id)
			else:
				vessel.gases[chemical_id] = current_gas
			return true
		_:
			return false


func _participant_amount_on_vessel(participant: Dictionary, vessel: VesselState) -> float:
	var chemical_id := str(participant.get("chemical_id", ""))
	if chemical_id.is_empty():
		return -1.0
	var phase := str(participant.get("phase", ""))
	match phase:
		"liquid":
			return float(vessel.liquids.get(chemical_id, 0.0))
		"solid":
			return float(vessel.solids.get(chemical_id, 0.0))
		"dissolved":
			return float(vessel.dissolved.get(chemical_id, 0.0))
		"gas":
			return float(vessel.gases.get(chemical_id, 0.0))
		_:
			return -1.0


func _participant_chemical_is_supported(participant: Dictionary) -> bool:
	if not str(participant.get("reference_element_symbol", "")).is_empty():
		return false
	var chemical_id := str(participant.get("chemical_id", ""))
	if chemical_id.is_empty():
		return false
	var chemical := _db.get_chemical(chemical_id) if _db != null else null
	if chemical == null or not chemical.virtual_simulation_enabled:
		return false
	return _moles_per_ledger_unit(participant) > 0.0


func _reactant_extent(reaction: ReactionDefinition, vessel: VesselState) -> float:
	var reactants: Variant = reaction.reactants
	if typeof(reactants) != TYPE_ARRAY or reactants.is_empty():
		return 0.0
	var extent := INF
	for participant_value in reactants:
		if typeof(participant_value) != TYPE_DICTIONARY:
			return 0.0
		var participant: Dictionary = participant_value
		if not _participant_chemical_is_supported(participant):
			return 0.0
		var phase := str(participant.get("phase", ""))
		if not PHASE_AMOUNT_UNITS.has(phase):
			return 0.0
		var available_amount := _participant_amount_on_vessel(participant, vessel)
		if available_amount < 0.0:
			return 0.0
		var coefficient := float(participant.get("coefficient", 1.0))
		if coefficient <= 0.0:
			return 0.0
		var required_amount := float(participant.get("minimum_amount", VesselState.EPSILON))
		if available_amount + VesselState.EPSILON < required_amount:
			return 0.0
		extent = minf(extent, available_amount * _moles_per_ledger_unit(participant) / coefficient)
	return 0.0 if extent == INF else extent


func _generic_products_fit(vessel: VesselState, reaction: ReactionDefinition, extent: float) -> bool:
	var total_gas := 0.0
	for participant_value in reaction.products:
		if typeof(participant_value) != TYPE_DICTIONARY:
			return false
		var participant: Dictionary = participant_value
		if not _participant_chemical_is_supported(participant):
			return false
		var phase := str(participant.get("phase", ""))
		if not PHASE_AMOUNT_UNITS.has(phase):
			return false
		var chemical_id := str(participant.get("chemical_id", ""))
		var chemical := _db.get_chemical(chemical_id) if _db != null else null
		if chemical == null:
			return false
		var amount := float(participant.get("coefficient", 1.0)) * extent
		if amount <= 0.0:
			return false
		match phase:
			"gas":
				if chemical.state != "gas":
					return false
				total_gas += amount
			"liquid":
				if chemical.state != "liquid":
					return false
			"solid":
				if chemical.state != "solid":
					return false
			"dissolved":
				if chemical.state != "solid":
					return false
			_:
				return false
	var net_liquid_ml := 0.0
	for participant_value in reaction.products:
		var product: Dictionary = participant_value
		if str(product.get("phase", "")) == "liquid":
			net_liquid_ml += _ledger_amount(product, extent)
	for participant_value in reaction.reactants:
		var reactant: Dictionary = participant_value
		if str(reactant.get("phase", "")) == "liquid":
			net_liquid_ml -= _ledger_amount(reactant, extent)
	if vessel.liquid_volume_ml() + net_liquid_ml > vessel.capacity_ml + VesselState.EPSILON:
		return false
	if total_gas > 0.0 and vessel.free_volume_ml() <= VesselState.EPSILON:
		return false
	if total_gas > 0.0:
		var ambient_pressure := _db.constant("ambient_pressure_kpa", VesselState.DEFAULT_AMBIENT_PRESSURE_KPA) if _db != null else VesselState.DEFAULT_AMBIENT_PRESSURE_KPA
		var pressure_limit := _db.constant("max_virtual_pressure_kpa", 300.0) if _db != null else 300.0
		var projected_pressure := vessel.pressure_after_adding_gas(total_gas, ambient_pressure)
		if not is_finite(projected_pressure) or projected_pressure > pressure_limit:
			return false
	return true


func _append_result_observation(result: ReactionResult, vessel: VesselState, key: String, kind: String, text: String, explanation: String, effect_id: String = "") -> void:
	if text.is_empty() or vessel.fired_observations.has(key):
		return
	vessel.fired_observations[key] = true
	var entry := {"key": key, "kind": kind, "text": text, "explanation": explanation}
	if not effect_id.is_empty():
		entry["effect_id"] = effect_id
	result.observations.append(entry.duplicate(true))
	if not effect_id.is_empty():
		result.effects.append({"effect_id": effect_id, "kind": kind, "intensity": 1.0, "source": key})


func _num(data: Dictionary, key: String, default_value: float) -> float:
	return float(data.get(key, default_value))
