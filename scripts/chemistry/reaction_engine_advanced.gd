class_name ReactionEngineAdvanced
extends RefCounted
## An upgraded data-driven reaction executor.
## It keeps the existing reaction families working and adds:
## - condition checking (temperature, pressure, pH, light, catalyst, system)
## - stoichiometry-aware limiting extent
## - simple kinetics via time constants
## - simple equilibrium damping for reversible reactions
## - pH-aware neutralisation reporting

const MIN_AMOUNT_G := 0.001
const MIN_MOLES := 1.0e-9
const MIN_PROGRESS := 0.02
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


func _execute_reaction(reaction: ReactionDefinition, vessel: VesselState, dt: float,
		extra_heat_capacity_j_per_k: float, step_mode: bool) -> ReactionResult:
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
		result.status = ReactionResult.Status.NOT_MATCHED
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


func _execute_dissolution_reaction(reaction: ReactionDefinition, vessel: VesselState,
		extra_heat_capacity_j_per_k: float = 0.0, dt: float = 0.0) -> ReactionResult:
	if not reaction.reactants.is_empty() or not reaction.products.is_empty():
		return _execute_generic_reaction(reaction, vessel, extra_heat_capacity_j_per_k, dt)

	var result := ReactionResult.new()
	result.reaction_id = reaction.id
	result.reaction_name = reaction.display_name
	result.reaction_type = reaction.type
	var solute_id := reaction.solute
	if solute_id.is_empty() and not reaction.substance.is_empty():
		solute_id = reaction.substance
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
	_append_result_observation(result, vessel, "dissolution:%s" % reaction.id,
		"reaction", result.message, reaction.explanation, "dissolution_particles")
	result.status = ReactionResult.Status.EXECUTED
	return result


func _execute_neutralisation_reaction(reaction: ReactionDefinition, vessel: VesselState,
		extra_heat_capacity_j_per_k: float = 0.0, dt: float = 0.0) -> ReactionResult:
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
		_append_result_observation(result, vessel, "neutralisation:ph:%s" % reaction.id,
			"ph", reaction.observation(ph_key), reaction.explanation, "indicator_shift")
	if reaction.observation("heat") != "":
		_append_result_observation(result, vessel, "neutralisation:heat:%s" % reaction.id,
			"heat", reaction.observation("heat"), reaction.explanation, "heat_wave")
	return result


func _execute_boiling_reaction(reaction: ReactionDefinition, vessel: VesselState,
		extra_heat_capacity_j_per_k: float = 0.0, dt: float = 0.0) -> ReactionResult:
	var result := ReactionResult.new()
	result.reaction_id = reaction.id
	result.reaction_name = reaction.display_name
	result.reaction_type = reaction.type

	var progress := _reaction_progress(reaction, vessel, dt)
	result.progress = progress
	var boiling_point_c := 100.0
	if vessel.temperature_c + 1.0e-6 < boiling_point_c:
		result.status = ReactionResult.Status.NOT_MATCHED
		result.message = "The liquid has not yet reached its boiling point."
		return result
	vessel.temperature_c = minf(vessel.temperature_c, boiling_point_c)
	result.message = reaction.observation("boiling")
	if result.message.is_empty():
		result.message = "The liquid is boiling."
	_append_result_observation(result, vessel, "boiling:%s" % reaction.id,
		"boiling", result.message, reaction.explanation, "vapour_stream")
	result.status = ReactionResult.Status.EXECUTED
	return result


func _execute_visual_demo_reaction(reaction: ReactionDefinition, vessel: VesselState,
		extra_heat_capacity_j_per_k: float = 0.0, dt: float = 0.0) -> ReactionResult:
	var result := ReactionResult.new()
	result.reaction_id = reaction.id
	result.reaction_name = reaction.display_name
	result.reaction_type = reaction.type
	var fired_key := "visual_demo:%s" % reaction.id
	if vessel.fired_observations.has(fired_key):
		result.status = ReactionResult.Status.NOT_MATCHED
		result.message = "The visual demo has already been shown."
		return result
	var product := _db.get_chemical(reaction.product_solid_id)
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
	result.observations.append({
		"key": fired_key,
		"kind": "visual_demo",
		"text": reaction.observation("summary"),
		"explanation": reaction.explanation,
	})
	if reaction.visual_effect != "":
		result.effects = [{
			"effect_id": reaction.visual_effect,
			"kind": "visual_demo",
			"intensity": 1.0,
			"reaction_id": reaction.id,
		}]
	return result


func _execute_generic_reaction(reaction: ReactionDefinition, vessel: VesselState,
		extra_heat_capacity_j_per_k: float = 0.0, dt: float = 0.0) -> ReactionResult:
	var result := ReactionResult.new()
	result.reaction_id = reaction.id
	result.reaction_name = reaction.display_name
	result.reaction_type = reaction.type

	var reactant_extent := _reactant_extent(reaction, vessel)
	if reactant_extent <= VesselState.EPSILON:
		result.status = ReactionResult.Status.NOT_MATCHED
		result.message = "The required reactants are not present in enough quantity."
		return result

	var progress := _reaction_progress(reaction, vessel, dt)
	result.progress = progress
	var extent := reactant_extent * progress
	if extent <= VesselState.EPSILON:
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
		var pressure_limit := _db.constant("max_virtual_pressure_kpa", VesselState.DEFAULT_AMBIENT_PRESSURE_KPA)
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
		var amount := float(participant.get("coefficient", 1.0)) * extent
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
		var amount := float(participant.get("coefficient", 1.0)) * extent
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
				var ambient_pressure := _db.constant("ambient_pressure_kpa", VesselState.DEFAULT_AMBIENT_PRESSURE_KPA)
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

	_append_result_observation(result, vessel, "generic_reaction:%s" % reaction.id,
		"reaction", result.message, reaction.explanation, reaction.visual_effect)
	result.status = ReactionResult.Status.EXECUTED
	return result


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


func _num(data: Dictionary, key: String, default_value: float) -> float:
	return float(data.get(key, default_value))
