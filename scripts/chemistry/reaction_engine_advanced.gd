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


func _reaction_quotient(reaction: ReactionDefinition, vessel: VesselState) -> float:
	var reactant_score := maxf(_participants_activity(reaction.reactants, vessel), MIN_MOLES)
	var product_score := maxf(_participants_activity(reaction.products, vessel), MIN_MOLES)
	return product_score / reactant_score


func _product_activity(participant: Dictionary, vessel: VesselState) -> float:
	var amount := _participant_amount_on_vessel(participant, vessel)
	var phase := str(participant.get("phase", ""))
	if phase == "gas":
		return amount / maxf(vessel.headspace_l(), VesselState.MIN_HEADSPACE_L)
	if phase == "liquid" or phase == "dissolved":
		return amount / maxf(vessel.liquid_volume_ml() / 1000.0, 1.0e-6)
	return maxf(amount, MIN_MOLES)


func _participants_activity(participants: Array, vessel: VesselState) -> float:
	var score := 1.0
	for participant_value in participants:
		if typeof(participant_value) != TYPE_DICTIONARY:
			continue
		var participant: Dictionary = participant_value
		score *= maxf(_product_activity(participant, vessel), MIN_MOLES)
	return score


func _conditions_allow_reaction(reaction: ReactionDefinition, vessel: VesselState, result: ReactionResult) -> bool:
	var failures: Array[String] = []
	var ambient_pressure := _db.constant("ambient_pressure_kpa", VesselState.DEFAULT_AMBIENT_PRESSURE_KPA)
	var current_temperature := vessel.temperature_c
	var current_pressure := vessel.pressure_kpa(ambient_pressure)
	var current_ph := AcidBase.compute_ph(vessel, _db)
	for condition_value in reaction.conditions:
		if typeof(condition_value) != TYPE_DICTIONARY:
			continue
		var condition: Dictionary = condition_value
		var kind := str(condition.get("type", condition.get("kind", ""))).to_lower()
		match kind:
			"temperature":
				var min_c := float(condition.get("min_c", condition.get("min_temperature_c", -INF)))
				var max_c := float(condition.get("max_c", condition.get("max_temperature_c", INF)))
				if current_temperature < min_c or current_temperature > max_c:
					failures.append("Temperature must be between %.1f °C and %.1f °C." % [min_c, max_c])
			"pressure":
				var min_kpa := float(condition.get("min_kpa", condition.get("min_pressure_kpa", -INF)))
				var max_kpa := float(condition.get("max_kpa", condition.get("max_pressure_kpa", INF)))
				if current_pressure < min_kpa or current_pressure > max_kpa:
					failures.append("Pressure must be between %.1f and %.1f kPa." % [min_kpa, max_kpa])
			"ph":
				if not is_nan(current_ph):
					var min_ph := float(condition.get("min_ph", -INF))
					var max_ph := float(condition.get("max_ph", INF))
					if current_ph < min_ph or current_ph > max_ph:
						failures.append("pH must be between %.1f and %.1f." % [min_ph, max_ph])
			"light":
				if bool(condition.get("requires_light", false)) and not bool(_db.constant("light_available", true)):
					failures.append("Light is required.")
			"system":
				if bool(condition.get("closed", false)) and not vessel.is_closed_system:
					failures.append("The vessel must be closed.")
				if bool(condition.get("open", false)) and vessel.is_closed_system:
					failures.append("The vessel must be open.")
			"catalyst":
				var catalyst_id := str(condition.get("catalyst_id", _kinetics_catalyst_id(reaction)))
				if not catalyst_id.is_empty() and not _vessel_has_chemical(vessel, catalyst_id):
					failures.append("Catalyst '%s' is missing." % catalyst_id)
			_:
				pass
	if failures.is_empty():
		return true
	result.warnings.append_array(failures)
	result.message = failures[0]
	return false


func _kinetics_catalyst_id(reaction: ReactionDefinition) -> String:
	if reaction.kinetics.has("catalyst_id"):
		return str(reaction.kinetics.get("catalyst_id", ""))
	return ""


func _vessel_has_chemical(vessel: VesselState, chemical_id: String) -> bool:
	return not chemical_id.is_empty() and (vessel.liquids.has(chemical_id) or vessel.solids.has(chemical_id)
		or vessel.dissolved.has(chemical_id) or vessel.gases.has(chemical_id))


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
		var chemical := _db.get_chemical(chemical_id)
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
				pass
			_:
				return false
	if total_gas > 0.0 and vessel.free_volume_ml() <= VesselState.EPSILON:
		return false
	if total_gas > 0.0:
		var ambient_pressure := _db.constant("ambient_pressure_kpa", VesselState.DEFAULT_AMBIENT_PRESSURE_KPA)
		var pressure_limit := _db.constant("max_virtual_pressure_kpa", 300.0)
		var projected_pressure := vessel.pressure_after_adding_gas(total_gas, ambient_pressure)
		if not is_finite(projected_pressure) or projected_pressure > pressure_limit:
			return false
	return true


func _reaction_message(reaction: ReactionDefinition, _extent: float) -> String:
	if reaction.observation("summary") != "":
		return reaction.observation("summary")
	if reaction.observation("completed") != "":
		return reaction.observation("completed")
	return "The registered reaction completed in the virtual model."


func _append_result_observation(result: ReactionResult, vessel: VesselState, key: String,
		kind: String, text: String, explanation: String, effect_id: String = "") -> void:
	if text.is_empty() or vessel.fired_observations.has(key):
		return
	vessel.fired_observations[key] = true
	var entry := {"key": key, "kind": kind, "text": text, "explanation": explanation}
	if not effect_id.is_empty():
		entry["effect_id"] = effect_id
	result.observations.append(entry.duplicate(true))
	if not effect_id.is_empty():
		result.effects.append({"effect_id": effect_id, "kind": kind, "intensity": 1.0, "source": key})


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
	var chemical := _db.get_chemical(chemical_id)
	return chemical != null and chemical.virtual_simulation_enabled


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
		var amount := float(participant.get("coefficient", 1.0)) * extent
		if amount <= 0.0:
			continue
		if not ledger.has(phase):
			ledger[phase] = {}
		var phase_ledger: Dictionary = ledger[phase]
		phase_ledger[chemical_id] = float(phase_ledger.get(chemical_id, 0.0)) + amount
		ledger[phase] = phase_ledger
	return ledger


func _product_activity(participant: Dictionary, vessel: VesselState) -> float:
	var amount := _participant_amount_on_vessel(participant, vessel)
	var phase := str(participant.get("phase", ""))
	if phase == "gas":
		return amount / maxf(vessel.headspace_l(), VesselState.MIN_HEADSPACE_L)
	if phase == "liquid" or phase == "dissolved":
		return amount / maxf(vessel.liquid_volume_ml() / 1000.0, 1.0e-6)
	return maxf(amount, MIN_MOLES)


func _participants_activity(participants: Array, vessel: VesselState) -> float:
	var score := 1.0
	for participant_value in participants:
		if typeof(participant_value) != TYPE_DICTIONARY:
			continue
		var participant: Dictionary = participant_value
		score *= maxf(_product_activity(participant, vessel), MIN_MOLES)
	return score


func _reaction_quotient(reaction: ReactionDefinition, vessel: VesselState) -> float:
	var reactant_score := maxf(_participants_activity(reaction.reactants, vessel), MIN_MOLES)
	var product_score := maxf(_participants_activity(reaction.products, vessel), MIN_MOLES)
	return product_score / reactant_score


func _kinetics_catalyst_id(reaction: ReactionDefinition) -> String:
	if reaction.kinetics.has("catalyst_id"):
		return str(reaction.kinetics.get("catalyst_id", ""))
	return ""


func _conditions_allow_reaction(reaction: ReactionDefinition, vessel: VesselState, result: ReactionResult) -> bool:
	var failures: Array[String] = []
	var ambient_pressure := _db.constant("ambient_pressure_kpa", VesselState.DEFAULT_AMBIENT_PRESSURE_KPA)
	var current_temperature := vessel.temperature_c
	var current_pressure := vessel.pressure_kpa(ambient_pressure)
	var current_ph := AcidBase.compute_ph(vessel, _db)
	for condition_value in reaction.conditions:
		if typeof(condition_value) != TYPE_DICTIONARY:
			continue
		var condition: Dictionary = condition_value
		var kind := str(condition.get("type", condition.get("kind", ""))).to_lower()
		match kind:
			"temperature":
				var min_c := float(condition.get("min_c", condition.get("min_temperature_c", -INF)))
				var max_c := float(condition.get("max_c", condition.get("max_temperature_c", INF)))
				if current_temperature < min_c or current_temperature > max_c:
					failures.append("Temperature must be between %.1f °C and %.1f °C." % [min_c, max_c])
			"pressure":
				var min_kpa := float(condition.get("min_kpa", condition.get("min_pressure_kpa", -INF)))
				var max_kpa := float(condition.get("max_kpa", condition.get("max_pressure_kpa", INF)))
				if current_pressure < min_kpa or current_pressure > max_kpa:
					failures.append("Pressure must be between %.1f and %.1f kPa." % [min_kpa, max_kpa])
			"ph":
				if not is_nan(current_ph):
					var min_ph := float(condition.get("min_ph", -INF))
					var max_ph := float(condition.get("max_ph", INF))
					if current_ph < min_ph or current_ph > max_ph:
						failures.append("pH must be between %.1f and %.1f." % [min_ph, max_ph])
			"light":
				if bool(condition.get("requires_light", false)) and not bool(_db.constant("light_available", true)):
					failures.append("Light is required.")
			"system":
				if bool(condition.get("closed", false)) and not vessel.is_closed_system:
					failures.append("The vessel must be closed.")
				if bool(condition.get("open", false)) and vessel.is_closed_system:
					failures.append("The vessel must be open.")
			"catalyst":
				var catalyst_id := str(condition.get("catalyst_id", _kinetics_catalyst_id(reaction)))
				if not catalyst_id.is_empty() and not _vessel_has_chemical(vessel, catalyst_id):
					failures.append("Catalyst '%s' is missing." % catalyst_id)
			_:
				pass
	if failures.is_empty():
		return true
	result.warnings.append_array(failures)
	result.message = failures[0]
	return false


func _vessel_has_chemical(vessel: VesselState, chemical_id: String) -> bool:
	return not chemical_id.is_empty() and (vessel.liquids.has(chemical_id) or vessel.solids.has(chemical_id)
		or vessel.dissolved.has(chemical_id) or vessel.gases.has(chemical_id))


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
		var chemical := _db.get_chemical(chemical_id)
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
				pass
			_:
				return false
	if total_gas > 0.0 and vessel.free_volume_ml() <= VesselState.EPSILON:
		return false
	if total_gas > 0.0:
		var ambient_pressure := _db.constant("ambient_pressure_kpa", VesselState.DEFAULT_AMBIENT_PRESSURE_KPA)
		var pressure_limit := _db.constant("max_virtual_pressure_kpa", 300.0)
		var projected_pressure := vessel.pressure_after_adding_gas(total_gas, ambient_pressure)
		if not is_finite(projected_pressure) or projected_pressure > pressure_limit:
			return false
	return true


func _reaction_message(reaction: ReactionDefinition, _extent: float) -> String:
	if reaction.observation("summary") != "":
		return reaction.observation("summary")
	if reaction.observation("completed") != "":
		return reaction.observation("completed")
	return "The registered reaction completed in the virtual model."


func _append_result_observation(result: ReactionResult, vessel: VesselState, key: String,
		kind: String, text: String, explanation: String, effect_id: String = "") -> void:
	if text.is_empty() or vessel.fired_observations.has(key):
		return
	vessel.fired_observations[key] = true
	var entry := {"key": key, "kind": kind, "text": text, "explanation": explanation}
	if not effect_id.is_empty():
		entry["effect_id"] = effect_id
	result.observations.append(entry.duplicate(true))
	if not effect_id.is_empty():
		result.effects.append({"effect_id": effect_id, "kind": kind, "intensity": 1.0, "source": key})


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
	var chemical := _db.get_chemical(chemical_id)
	return chemical != null and chemical.virtual_simulation_enabled


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
		var amount := float(participant.get("coefficient", 1.0)) * extent
		if amount <= 0.0:
			continue
		if not ledger.has(phase):
			ledger[phase] = {}
		var phase_ledger: Dictionary = ledger[phase]
		phase_ledger[chemical_id] = float(phase_ledger.get(chemical_id, 0.0)) + amount
		ledger[phase] = phase_ledger
	return ledger


func _product_activity(participant: Dictionary, vessel: VesselState) -> float:
	var amount := _participant_amount_on_vessel(participant, vessel)
	var phase := str(participant.get("phase", ""))
	if phase == "gas":
		return amount / maxf(vessel.headspace_l(), VesselState.MIN_HEADSPACE_L)
	if phase == "liquid" or phase == "dissolved":
		return amount / maxf(vessel.liquid_volume_ml() / 1000.0, 1.0e-6)
	return maxf(amount, MIN_MOLES)


func _participants_activity(participants: Array, vessel: VesselState) -> float:
	var score := 1.0
	for participant_value in participants:
		if typeof(participant_value) != TYPE_DICTIONARY:
			continue
		var participant: Dictionary = participant_value
		score *= maxf(_product_activity(participant, vessel), MIN_MOLES)
	return score


func _reaction_quotient(reaction: ReactionDefinition, vessel: VesselState) -> float:
	var reactant_score := maxf(_participants_activity(reaction.reactants, vessel), MIN_MOLES)
	var product_score := maxf(_participants_activity(reaction.products, vessel), MIN_MOLES)
	return product_score / reactant_score


func _kinetics_catalyst_id(reaction: ReactionDefinition) -> String:
	if reaction.kinetics.has("catalyst_id"):
		return str(reaction.kinetics.get("catalyst_id", ""))
	return ""


func _conditions_allow_reaction(reaction: ReactionDefinition, vessel: VesselState, result: ReactionResult) -> bool:
	var failures: Array[String] = []
	var ambient_pressure := _db.constant("ambient_pressure_kpa", VesselState.DEFAULT_AMBIENT_PRESSURE_KPA)
	var current_temperature := vessel.temperature_c
	var current_pressure := vessel.pressure_kpa(ambient_pressure)
	var current_ph := AcidBase.compute_ph(vessel, _db)
	for condition_value in reaction.conditions:
		if typeof(condition_value) != TYPE_DICTIONARY:
			continue
		var condition: Dictionary = condition_value
		var kind := str(condition.get("type", condition.get("kind", ""))).to_lower()
		match kind:
			"temperature":
				var min_c := float(condition.get("min_c", condition.get("min_temperature_c", -INF)))
				var max_c := float(condition.get("max_c", condition.get("max_temperature_c", INF)))
				if current_temperature < min_c or current_temperature > max_c:
					failures.append("Temperature must be between %.1f °C and %.1f °C." % [min_c, max_c])
			"pressure":
				var min_kpa := float(condition.get("min_kpa", condition.get("min_pressure_kpa", -INF)))
				var max_kpa := float(condition.get("max_kpa", condition.get("max_pressure_kpa", INF)))
				if current_pressure < min_kpa or current_pressure > max_kpa:
					failures.append("Pressure must be between %.1f and %.1f kPa." % [min_kpa, max_kpa])
			"ph":
				if not is_nan(current_ph):
					var min_ph := float(condition.get("min_ph", -INF))
					var max_ph := float(condition.get("max_ph", INF))
					if current_ph < min_ph or current_ph > max_ph:
						failures.append("pH must be between %.1f and %.1f." % [min_ph, max_ph])
			"light":
				if bool(condition.get("requires_light", false)) and not bool(_db.constant("light_available", true)):
					failures.append("Light is required.")
			"system":
				if bool(condition.get("closed", false)) and not vessel.is_closed_system:
					failures.append("The vessel must be closed.")
				if bool(condition.get("open", false)) and vessel.is_closed_system:
					failures.append("The vessel must be open.")
			"catalyst":
				var catalyst_id := str(condition.get("catalyst_id", _kinetics_catalyst_id(reaction)))
				if not catalyst_id.is_empty() and not _vessel_has_chemical(vessel, catalyst_id):
					failures.append("Catalyst '%s' is missing." % catalyst_id)
			_:
				pass
	if failures.is_empty():
		return true
	result.warnings.append_array(failures)
	result.message = failures[0]
	return false


func _vessel_has_chemical(vessel: VesselState, chemical_id: String) -> bool:
	return not chemical_id.is_empty() and (vessel.liquids.has(chemical_id) or vessel.solids.has(chemical_id)
		or vessel.dissolved.has(chemical_id) or vessel.gases.has(chemical_id))


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
		var chemical := _db.get_chemical(chemical_id)
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
				pass
			_:
				return false
	if total_gas > 0.0 and vessel.free_volume_ml() <= VesselState.EPSILON:
		return false
	if total_gas > 0.0:
		var ambient_pressure := _db.constant("ambient_pressure_kpa", VesselState.DEFAULT_AMBIENT_PRESSURE_KPA)
		var pressure_limit := _db.constant("max_virtual_pressure_kpa", 300.0)
		var projected_pressure := vessel.pressure_after_adding_gas(total_gas, ambient_pressure)
		if not is_finite(projected_pressure) or projected_pressure > pressure_limit:
			return false
	return true


func _reaction_message(reaction: ReactionDefinition, _extent: float) -> String:
	if reaction.observation("summary") != "":
		return reaction.observation("summary")
	if reaction.observation("completed") != "":
		return reaction.observation("completed")
	return "The registered reaction completed in the virtual model."


func _append_result_observation(result: ReactionResult, vessel: VesselState, key: String,
		kind: String, text: String, explanation: String, effect_id: String = "") -> void:
	if text.is_empty() or vessel.fired_observations.has(key):
		return
	vessel.fired_observations[key] = true
	var entry := {"key": key, "kind": kind, "text": text, "explanation": explanation}
	if not effect_id.is_empty():
		entry["effect_id"] = effect_id
	result.observations.append(entry.duplicate(true))
	if not effect_id.is_empty():
		result.effects.append({"effect_id": effect_id, "kind": kind, "intensity": 1.0, "source": key})


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
	var chemical := _db.get_chemical(chemical_id)
	return chemical != null and chemical.virtual_simulation_enabled


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
		var amount := float(participant.get("coefficient", 1.0)) * extent
		if amount <= 0.0:
			continue
		if not ledger.has(phase):
			ledger[phase] = {}
		var phase_ledger: Dictionary = ledger[phase]
		phase_ledger[chemical_id] = float(phase_ledger.get(chemical_id, 0.0)) + amount
		ledger[phase] = phase_ledger
	return ledger


func _product_activity(participant: Dictionary, vessel: VesselState) -> float:
	var amount := _participant_amount_on_vessel(participant, vessel)
	var phase := str(participant.get("phase", ""))
	if phase == "gas":
		return amount / maxf(vessel.headspace_l(), VesselState.MIN_HEADSPACE_L)
	if phase == "liquid" or phase == "dissolved":
		return amount / maxf(vessel.liquid_volume_ml() / 1000.0, 1.0e-6)
	return maxf(amount, MIN_MOLES)


func _participants_activity(participants: Array, vessel: VesselState) -> float:
	var score := 1.0
	for participant_value in participants:
		if typeof(participant_value) != TYPE_DICTIONARY:
			continue
		var participant: Dictionary = participant_value
		score *= maxf(_product_activity(participant, vessel), MIN_MOLES)
	return score


func _reaction_quotient(reaction: ReactionDefinition, vessel: VesselState) -> float:
	var reactant_score := maxf(_participants_activity(reaction.reactants, vessel), MIN_MOLES)
	var product_score := maxf(_participants_activity(reaction.products, vessel), MIN_MOLES)
	return product_score / reactant_score


func _kinetics_catalyst_id(reaction: ReactionDefinition) -> String:
	if reaction.kinetics.has("catalyst_id"):
		return str(reaction.kinetics.get("catalyst_id", ""))
	return ""


func _conditions_allow_reaction(reaction: ReactionDefinition, vessel: VesselState, result: ReactionResult) -> bool:
	var failures: Array[String] = []
	var ambient_pressure := _db.constant("ambient_pressure_kpa", VesselState.DEFAULT_AMBIENT_PRESSURE_KPA)
	var current_temperature := vessel.temperature_c
	var current_pressure := vessel.pressure_kpa(ambient_pressure)
	var current_ph := AcidBase.compute_ph(vessel, _db)
	for condition_value in reaction.conditions:
		if typeof(condition_value) != TYPE_DICTIONARY:
			continue
		var condition: Dictionary = condition_value
		var kind := str(condition.get("type", condition.get("kind", ""))).to_lower()
		match kind:
			"temperature":
				var min_c := float(condition.get("min_c", condition.get("min_temperature_c", -INF)))
				var max_c := float(condition.get("max_c", condition.get("max_temperature_c", INF)))
				if current_temperature < min_c or current_temperature > max_c:
					failures.append("Temperature must be between %.1f °C and %.1f °C." % [min_c, max_c])
			"pressure":
				var min_kpa := float(condition.get("min_kpa", condition.get("min_pressure_kpa", -INF)))
				var max_kpa := float(condition.get("max_kpa", condition.get("max_pressure_kpa", INF)))
				if current_pressure < min_kpa or current_pressure > max_kpa:
					failures.append("Pressure must be between %.1f and %.1f kPa." % [min_kpa, max_kpa])
			"ph":
				if not is_nan(current_ph):
					var min_ph := float(condition.get("min_ph", -INF))
					var max_ph := float(condition.get("max_ph", INF))
					if current_ph < min_ph or current_ph > max_ph:
						failures.append("pH must be between %.1f and %.1f." % [min_ph, max_ph])
			"light":
				if bool(condition.get("requires_light", false)) and not bool(_db.constant("light_available", true)):
					failures.append("Light is required.")
			"system":
				if bool(condition.get("closed", false)) and not vessel.is_closed_system:
					failures.append("The vessel must be closed.")
				if bool(condition.get("open", false)) and vessel.is_closed_system:
					failures.append("The vessel must be open.")
			"catalyst":
				var catalyst_id := str(condition.get("catalyst_id", _kinetics_catalyst_id(reaction)))
				if not catalyst_id.is_empty() and not _vessel_has_chemical(vessel, catalyst_id):
					failures.append("Catalyst '%s' is missing." % catalyst_id)
			_:
				pass
	if failures.is_empty():
		return true
	result.warnings.append_array(failures)
	result.message = failures[0]
	return false


func _vessel_has_chemical(vessel: VesselState, chemical_id: String) -> bool:
	return not chemical_id.is_empty() and (vessel.liquids.has(chemical_id) or vessel.solids.has(chemical_id)
		or vessel.dissolved.has(chemical_id) or vessel.gases.has(chemical_id))


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
		var chemical := _db.get_chemical(chemical_id)
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
				pass
			_:
				return false
	if total_gas > 0.0 and vessel.free_volume_ml() <= VesselState.EPSILON:
		return false
	if total_gas > 0.0:
		var ambient_pressure := _db.constant("ambient_pressure_kpa", VesselState.DEFAULT_AMBIENT_PRESSURE_KPA)
		var pressure_limit := _db.constant("max_virtual_pressure_kpa", 300.0)
		var projected_pressure := vessel.pressure_after_adding_gas(total_gas, ambient_pressure)
		if not is_finite(projected_pressure) or projected_pressure > pressure_limit:
			return false
	return true


func _reaction_message(reaction: ReactionDefinition, _extent: float) -> String:
	if reaction.observation("summary") != "":
		return reaction.observation("summary")
	if reaction.observation("completed") != "":
		return reaction.observation("completed")
	return "The registered reaction completed in the virtual model."


func _append_result_observation(result: ReactionResult, vessel: VesselState, key: String,
		kind: String, text: String, explanation: String, effect_id: String = "") -> void:
	if text.is_empty() or vessel.fired_observations.has(key):
		return
	vessel.fired_observations[key] = true
	var entry := {"key": key, "kind": kind, "text": text, "explanation": explanation}
	if not effect_id.is_empty():
		entry["effect_id"] = effect_id
	result.observations.append(entry.duplicate(true))
	if not effect_id.is_empty():
		result.effects.append({"effect_id": effect_id, "kind": kind, "intensity": 1.0, "source": key})


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
		var pressure_limit := _db.constant("max_virtual_pressure_kpa", 300.0)
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


func _num(data: Dictionary, key: String, default_value: float) -> float:
	return float(data.get(key, default_value))
