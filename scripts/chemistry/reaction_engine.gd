class_name ReactionEngine
extends RefCounted
## The single authority on what happens when substances meet (dissolution, neutralisation).
## It changes vessel contents and returns observation records. Animations and the interface
## only display what it decides. Reactions are defined in data/reactions/*.json.

## Below this mass (g) an almost-finished dissolution is completed in one step.
const MIN_AMOUNT_G := 0.001
const MIN_MOLES := 1.0e-9

var _db: ContentDatabase


func _init(content: ContentDatabase) -> void:
	_db = content


## Advances the chemistry of one vessel by dt seconds. extra_heat_capacity_j_per_k is the
## thermal mass of the vessel itself (glass). Returns observation dictionaries
## {key, kind, text, explanation} for things that just became noticeable.
func step_vessel(vessel: VesselState, dt: float, extra_heat_capacity_j_per_k: float) -> Array:
	var events: Array = []
	_step_dissolution(vessel, dt, events)
	_step_neutralisation(vessel, extra_heat_capacity_j_per_k, events)
	vessel.stir_time_left_s = maxf(vessel.stir_time_left_s - dt, 0.0)
	return events


func _step_dissolution(vessel: VesselState, dt: float, events: Array) -> void:
	var solvent_ml := AcidBase.aqueous_volume_ml(vessel, _db)
	for solute_id in vessel.solids.keys():
		var undissolved := float(vessel.solids[solute_id])
		if undissolved <= 0.0:
			vessel.solids.erase(solute_id)
			continue
		var chemical := _db.get_chemical(str(solute_id))
		var reaction := _db.find_dissolution(str(solute_id))
		if chemical == null or reaction == null or not _reaction_is_allowed(reaction):
			if solvent_ml > 0.0:
				_emit_once(vessel, events, "no_model:%s" % solute_id, "model",
					"No dissolution model exists yet for this solid, so it stays as it is.", "")
			continue
		if solvent_ml <= 0.0:
			continue

		var capacity_g := chemical.solubility_g_per_100ml(vessel.temperature_c) * solvent_ml / 100.0
		var dissolved_g := float(vessel.dissolved.get(solute_id, 0.0))
		var room_g := maxf(capacity_g - dissolved_g, 0.0)
		var target_g := minf(undissolved, room_g)
		var time_constant := maxf(reaction.time_constant_s, 0.001)
		if vessel.stir_time_left_s > 0.0:
			time_constant /= maxf(_db.constant("stir_time_constant_divisor", 4.0), 1.0)
		var moved_g := target_g * (1.0 - exp(-dt / time_constant))
		if target_g >= undissolved and undissolved - moved_g < MIN_AMOUNT_G:
			moved_g = undissolved
		if moved_g > 0.0:
			vessel.solids[solute_id] = undissolved - moved_g
			vessel.dissolved[solute_id] = dissolved_g + moved_g
			if float(vessel.solids[solute_id]) <= 0.0:
				vessel.solids.erase(solute_id)
			_emit_once(vessel, events, "dissolve_started:%s" % solute_id, "dissolution",
				reaction.observation("started"), "")

		var threshold := _db.constant("colour_observation_threshold", 0.15)
		var colour_text := reaction.observation("colour")
		if SolutionAppearance.solute_strength(vessel, _db, str(solute_id)) >= threshold:
			_emit_once(vessel, events, "dissolve_colour:%s" % solute_id, "colour_change",
				colour_text, reaction.explanation)
		if not vessel.solids.has(solute_id):
			var explanation := "" if not colour_text.is_empty() else reaction.explanation
			_emit_once(vessel, events, "dissolve_completed:%s" % solute_id, "dissolution",
				reaction.observation("completed"), explanation)
		elif room_g - moved_g <= MIN_AMOUNT_G:
			_emit_once(vessel, events, "dissolve_saturated:%s" % solute_id, "dissolution",
				reaction.observation("saturated"), "")


func _step_neutralisation(vessel: VesselState, extra_heat_capacity_j_per_k: float, events: Array) -> void:
	var reaction := _db.first_enabled_reaction_of_type("neutralisation")
	if reaction == null or not _reaction_is_allowed(reaction):
		return
	var amounts := AcidBase.moles(vessel, _db)
	var acid_mol := float(amounts["acid"])
	var base_mol := float(amounts["base"])
	if acid_mol <= MIN_MOLES or base_mol <= MIN_MOLES:
		return

	var reacted_mol := minf(acid_mol, base_mol)
	var new_mol := reacted_mol - vessel.neutralised_mol
	if new_mol > MIN_MOLES:
		var capacity := ThermalProperties.contents_capacity_j_per_k(vessel, _db) + extra_heat_capacity_j_per_k
		if capacity > 0.0:
			# enthalpy is negative for heat released, so the temperature rises
			vessel.temperature_c -= reaction.enthalpy_kj_per_mol * 1000.0 * new_mol / capacity
			var pressure_limit := _db.constant("max_virtual_pressure_kpa", 300.0)
			vessel.temperature_c = minf(vessel.temperature_c, vessel.max_temperature_c_for_pressure_limit(pressure_limit))
		vessel.neutralised_mol = reacted_mol
		_emit_once(vessel, events, "neutralisation_heat", "heat", reaction.observation("heat"), "")

	var imbalance := (acid_mol - base_mol) / maxf(acid_mol, base_mol)
	var tolerance := _db.constant("neutral_ph_tolerance_fraction", 0.001)
	var outcome := "neutral"
	if imbalance > tolerance:
		outcome = "acidic"
	elif imbalance < -tolerance:
		outcome = "basic"
	_emit_on_change(vessel, events, "acid_base_outcome", outcome, "neutralisation",
		reaction.observation(outcome), reaction.explanation)


func _reaction_is_allowed(reaction: ReactionDefinition) -> bool:
	if reaction == null:
		return false
	if _db == null or _db.reaction_registry == null:
		return true
	if not _db.reaction_registry.has_reaction(reaction.id):
		return false
	return _db.reaction_registry.is_enabled(reaction.id)


## Announces an observation the first time only.
func _emit_once(vessel: VesselState, events: Array, key: String, kind: String, text: String, explanation: String) -> void:
	if text.is_empty() or vessel.fired_observations.has(key):
		return
	vessel.fired_observations[key] = true
	events.append({"key": key, "kind": kind, "text": text, "explanation": explanation})


## Announces an observation whenever the tracked state value changes.
func _emit_on_change(vessel: VesselState, events: Array, key: String, state_value: String,
		kind: String, text: String, explanation: String) -> void:
	if str(vessel.fired_observations.get(key, "")) == state_value:
		return
	vessel.fired_observations[key] = state_value
	if text.is_empty():
		return
	events.append({"key": key, "kind": kind, "text": text, "explanation": explanation})


## Runs a data-described visual demonstration. Output mass is explicitly illustrative and
## is not derived from reactant quantities or presented as a measured yield.
func run_visual_demo(vessel: VesselState, reaction_id: String) -> Dictionary:
	var reaction := _db.reactions.get(reaction_id) as ReactionDefinition
	if reaction == null or reaction.type != "visual_demo" or not reaction.virtual_only:
		return {}
	var fired_key := "visual_demo:%s" % reaction_id
	if vessel.fired_observations.has(fired_key):
		return {}
	var product := _db.get_chemical(reaction.product_solid_id)
	if product == null or product.state != "solid":
		return {}
	if reaction.illustrative_output_g <= 0.0 or reaction.illustrative_output_g > 5.0:
		return {}
	vessel.add_solid(product.id, reaction.illustrative_output_g)
	vessel.fired_observations[fired_key] = true
	return {
		"key": fired_key,
		"kind": "visual_demo",
		"text": reaction.observation("summary"),
		"explanation": reaction.explanation,
		"equation": reaction.equation,
		"effect_id": reaction.visual_effect,
		"virtual_only": true,
	}


## Shared gas-product entry point for future reaction definitions. A gas product automatically
## seals its receiving vessel before being retained; gas is never silently lost from a closed model.
func add_gas_product(vessel: VesselState, chemical_id: String, amount_mol: float) -> bool:
	var chemical := _db.get_chemical(chemical_id)
	if chemical == null or chemical.state != "gas" or not chemical.virtual_simulation_enabled:
		return false
	if not is_finite(amount_mol) or amount_mol <= 0.0 or amount_mol > 0.01:
		return false
	if vessel.free_volume_ml() <= VesselState.EPSILON:
		return false
	var ambient_pressure := _db.constant("ambient_pressure_kpa", 101.325)
	var pressure_limit := _db.constant("max_virtual_pressure_kpa", 300.0)
	var projected_pressure := vessel.pressure_after_adding_gas(amount_mol, ambient_pressure)
	if not is_finite(projected_pressure) or projected_pressure > pressure_limit:
		return false
	vessel.add_gas(chemical_id, amount_mol, ambient_pressure)
	return true


## Executes one registered reaction in a single deterministic step and returns the
## chemistry result together with render-friendly effect descriptors.
func execute_registered_reaction(reaction_id: String, vessel: VesselState,
		extra_heat_capacity_j_per_k: float = 0.0) -> ReactionResult:
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
	result.reaction_name = reaction.display_name
	result.reaction_type = reaction.type
	if not _reaction_is_allowed(reaction):
		result.status = ReactionResult.Status.REJECTED
		result.message = "The reaction is registered but disabled."
		result.errors.append(result.message)
		return result
	match reaction.type:
		"dissolution":
			return _execute_dissolution_reaction(reaction, vessel)
		"neutralisation":
			return _execute_neutralisation_reaction(reaction, vessel, extra_heat_capacity_j_per_k)
		_:
			result.status = ReactionResult.Status.REJECTED
			result.message = "No executor exists for reaction type '%s'." % reaction.type
			result.errors.append(result.message)
			return result


func _execute_dissolution_reaction(reaction: ReactionDefinition, vessel: VesselState) -> ReactionResult:
	var result := ReactionResult.new()
	result.reaction_id = reaction.id
	result.reaction_name = reaction.display_name
	result.reaction_type = reaction.type
	var chemical := _db.get_chemical(reaction.solute)
	if chemical == null or chemical.state != "solid" or not chemical.virtual_simulation_enabled:
		result.status = ReactionResult.Status.REJECTED
		result.message = "The dissolution participant is missing or not enabled for the virtual model."
		result.errors.append(result.message)
		return result
	var solvent_ml := AcidBase.aqueous_volume_ml(vessel, _db)
	if solvent_ml <= 0.0:
		result.status = ReactionResult.Status.NOT_MATCHED
		result.message = "The vessel needs water before this solid can dissolve."
		result.warnings.append("Dissolution is a read-only model until water is present.")
		return result
	var undissolved := float(vessel.solids.get(reaction.solute, 0.0))
	if undissolved <= MIN_AMOUNT_G:
		result.status = ReactionResult.Status.NOT_MATCHED
		result.message = "There is no registered solid left to dissolve."
		return result
	var capacity_g := chemical.solubility_g_per_100ml(vessel.temperature_c) * solvent_ml / 100.0
	var dissolved_g := float(vessel.dissolved.get(reaction.solute, 0.0))
	var room_g := maxf(capacity_g - dissolved_g, 0.0)
	if room_g <= MIN_AMOUNT_G:
		_append_result_observation(result, vessel, "dissolve_saturated:%s" % reaction.solute,
			"dissolution", reaction.observation("saturated"), "", "crystal_residue")
		result.status = ReactionResult.Status.NOT_MATCHED
		result.message = reaction.observation("saturated")
		result.warnings.append("The solution is already at the current solubility limit.")
		return result
	var moved_g := minf(undissolved, room_g)
	if moved_g <= MIN_AMOUNT_G:
		result.status = ReactionResult.Status.NOT_MATCHED
		result.message = "The model could not move enough solid into the solution.")
		return result
	vessel.solids[reaction.solute] = undissolved - moved_g
	if float(vessel.solids[reaction.solute]) <= MIN_AMOUNT_G:
		vessel.solids.erase(reaction.solute)
	vessel.dissolved[reaction.solute] = dissolved_g + moved_g
	result.consumed = {"solids": {reaction.solute: moved_g}}
	result.produced = {"dissolved": {reaction.solute: moved_g}}
	_append_result_observation(result, vessel, "dissolve_started:%s" % reaction.solute,
		"dissolution", reaction.observation("started"), "", "dissolution_particles")
	var colour_text := reaction.observation("colour")
	if SolutionAppearance.solute_strength(vessel, _db, reaction.solute) >= _db.constant("colour_observation_threshold", 0.15):
		_append_result_observation(result, vessel, "dissolve_colour:%s" % reaction.solute,
			"colour_change", colour_text, reaction.explanation, "colour_shift")
	if not vessel.solids.has(reaction.solute):
		_append_result_observation(result, vessel, "dissolve_completed:%s" % reaction.solute,
			"dissolution", reaction.observation("completed"), reaction.explanation, "solution_flow")
		result.message = reaction.observation("completed")
	else:
		_append_result_observation(result, vessel, "dissolve_saturated:%s" % reaction.solute,
			"dissolution", reaction.observation("saturated"), "", "crystal_residue")
		result.message = reaction.observation("saturated")
	result.status = ReactionResult.Status.EXECUTED
	result.effects = _dissolution_effects(reaction, moved_g, vessel)
	return result


func _execute_neutralisation_reaction(reaction: ReactionDefinition, vessel: VesselState,
		extra_heat_capacity_j_per_k: float) -> ReactionResult:
	var result := ReactionResult.new()
	result.reaction_id = reaction.id
	result.reaction_name = reaction.display_name
	result.reaction_type = reaction.type
	var amounts := AcidBase.moles(vessel, _db)
	var acid_mol := float(amounts["acid"])
	var base_mol := float(amounts["base"])
	if acid_mol <= MIN_MOLES or base_mol <= MIN_MOLES:
		result.status = ReactionResult.Status.NOT_MATCHED
		result.message = "The neutralisation participants are not both present in the vessel."
		return result
	var reacted_mol := minf(acid_mol, base_mol)
	var new_mol := reacted_mol - vessel.neutralised_mol
	if new_mol <= MIN_MOLES:
		result.status = ReactionResult.Status.NOT_MATCHED
		result.message = "The mixture is already neutralised to the current model precision."
		return result
	var before_temperature := vessel.temperature_c
	var capacity := ThermalProperties.contents_capacity_j_per_k(vessel, _db) + extra_heat_capacity_j_per_k
	if capacity > 0.0:
		# enthalpy is negative for heat released, so the temperature rises.
		vessel.temperature_c -= reaction.enthalpy_kj_per_mol * 1000.0 * new_mol / capacity
		var pressure_limit := _db.constant("max_virtual_pressure_kpa", 300.0)
		vessel.temperature_c = minf(vessel.temperature_c, vessel.max_temperature_c_for_pressure_limit(pressure_limit))
	vessel.neutralised_mol = reacted_mol
	result.temperature_delta_c = vessel.temperature_c - before_temperature
	result.energy_kj = reaction.enthalpy_kj_per_mol * new_mol
	result.consumed = {"acid_mol": new_mol, "base_mol": new_mol}
	result.produced = _reaction_products_to_ledger(reaction, new_mol)
	_append_result_observation(result, vessel, "neutralisation_heat", "heat",
		reaction.observation("heat"), "", "heat_wave")
	var imbalance := (acid_mol - base_mol) / maxf(acid_mol, base_mol)
	var tolerance := _db.constant("neutral_ph_tolerance_fraction", 0.001)
	var outcome := "neutral"
	if imbalance > tolerance:
		outcome = "acidic"
	elif imbalance < -tolerance:
		outcome = "basic"
	_append_state_observation(result, vessel, "acid_base_outcome", outcome, "neutralisation",
		reaction.observation(outcome), reaction.explanation, "indicator_shift")
	result.effects = _neutralisation_effects(reaction, outcome, new_mol, result.temperature_delta_c)
	result.status = ReactionResult.Status.EXECUTED
	result.message = reaction.observation(outcome)
	return result


func _append_result_observation(result: ReactionResult, vessel: VesselState, key: String,
		kind: String, text: String, explanation: String, effect_id: String = "") -> void:
	if text.is_empty() or vessel.fired_observations.has(key):
		return
	vessel.fired_observations[key] = true
	var entry := {"key": key, "kind": kind, "text": text, "explanation": explanation}
	if not effect_id.is_empty():
		entry["effect_id"] = effect_id
	vessel.add_observation(entry)
	result.observations.append(entry.duplicate(true))
	if not effect_id.is_empty():
		result.effects.append({"effect_id": effect_id, "kind": kind, "intensity": 1.0, "source": key})


func _append_state_observation(result: ReactionResult, vessel: VesselState, key: String, state_value: String,
		kind: String, text: String, explanation: String, effect_id: String = "") -> void:
	if str(vessel.fired_observations.get(key, "")) == state_value:
		return
	vessel.fired_observations[key] = state_value
	if text.is_empty():
		return
	var entry := {"key": key, "kind": kind, "text": text, "explanation": explanation}
	if not effect_id.is_empty():
		entry["effect_id"] = effect_id
	vessel.add_observation(entry)
	result.observations.append(entry.duplicate(true))
	if not effect_id.is_empty():
		result.effects.append({"effect_id": effect_id, "kind": kind, "intensity": 1.0, "source": key})


func _dissolution_effects(reaction: ReactionDefinition, moved_g: float, vessel: VesselState) -> Array:
	var effects: Array = []
	var effect_strength := clampf(moved_g / maxf(moved_g + float(vessel.solids.get(reaction.solute, 0.0)), MIN_AMOUNT_G), 0.2, 1.0)
	effects.append({"effect_id": "dissolution_particles", "kind": "particles", "intensity": effect_strength,
		"reaction_id": reaction.id})
	if not reaction.observation("colour").is_empty():
		effects.append({"effect_id": "colour_shift", "kind": "colour", "intensity": 0.5,
			"reaction_id": reaction.id})
	if vessel.solids.has(reaction.solute):
		effects.append({"effect_id": "crystal_residue", "kind": "precipitate", "intensity": 0.6,
			"reaction_id": reaction.id})
	return effects


func _neutralisation_effects(reaction: ReactionDefinition, outcome: String, reacted_mol: float,
		temperature_delta_c: float) -> Array:
	var effects: Array = []
	var heat_strength := clampf(absf(reaction.enthalpy_kj_per_mol) / 60.0, 0.25, 1.0)
	if reacted_mol > MIN_MOLES:
		effects.append({"effect_id": "heat_wave", "kind": "heat", "intensity": heat_strength,
			"temperature_delta_c": temperature_delta_c, "reaction_id": reaction.id})
	if outcome != "neutral":
		effects.append({"effect_id": "indicator_shift", "kind": "colour", "intensity": 0.35,
			"outcome": outcome, "reaction_id": reaction.id})
	return effects


func _reaction_products_to_ledger(reaction: ReactionDefinition, extent: float) -> Dictionary:
	var ledger: Dictionary = {}
	for participant_value in reaction.products:
		if typeof(participant_value) != TYPE_DICTIONARY:
			continue
		var participant: Dictionary = participant_value
		var chemical_id := str(participant.get("chemical_id", ""))
		var phase := str(participant.get("phase", ""))
		if chemical_id.is_empty() or phase.is_empty():
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