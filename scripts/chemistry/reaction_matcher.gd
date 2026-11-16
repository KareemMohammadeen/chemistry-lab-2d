class_name ReactionMatcher
extends RefCounted
## Checks whether an explicitly registered virtual reaction's reactants and conditions
## are present in one vessel. Matching is read-only and does not execute chemistry.

const PHASE_LEDGER_KEYS := {
	"liquid": "liquids",
	"solid": "solids",
	"dissolved": "dissolved",
	"gas": "gases",
}

var _database: ContentDatabase
var _registry: ReactionRegistryV3


func _init(database: ContentDatabase, registry: ReactionRegistryV3) -> void:
	_database = database
	_registry = registry


func match_reaction(reaction_id: String, vessel: VesselState) -> ReactionResult:
	var result := ReactionResult.new()
	result.reaction_id = reaction_id

	if _database == null or _registry == null or vessel == null:
		result.status = ReactionResult.Status.INVALID
		result.message = "Reaction matcher is missing its database, registry or vessel."
		result.errors.append(result.message)
		return result

	var reaction: ReactionDefinition = _database.reactions.get(reaction_id) as ReactionDefinition
	if reaction == null:
		result.status = ReactionResult.Status.REJECTED
		result.message = "The requested reaction does not exist."
		result.errors.append(result.message)
		return result

	result.reaction_name = reaction.display_name
	result.reaction_type = reaction.type
	if not _registry.has_reaction(reaction_id):
		result.status = ReactionResult.Status.REJECTED
		result.message = "The reaction is not present in the explicit allowlist."
		result.errors.append(result.message)
		return result
	if not _registry.is_enabled(reaction_id):
		result.status = ReactionResult.Status.REJECTED
		result.message = "The reaction is registered but disabled until its handler is reviewed and implemented."
		result.errors.append(result.message)
		return result

	var reactants: Variant = reaction.reactants
	if typeof(reactants) != TYPE_ARRAY or reactants.is_empty():
		result.status = ReactionResult.Status.INVALID
		result.message = "The reaction has no executable reactant requirements."
		result.errors.append(result.message)
		return result

	for participant_value in reactants:
		if typeof(participant_value) != TYPE_DICTIONARY:
			result.status = ReactionResult.Status.INVALID
			result.errors.append("Reaction participant is not a dictionary.")
			continue

		var participant: Dictionary = participant_value
		if not str(participant.get("reference_element_symbol", "")).is_empty():
			result.status = ReactionResult.Status.REJECTED
			result.errors.append("Reference-only periodic-table elements cannot be reaction participants.")
			continue

		var chemical_id := str(participant.get("chemical_id", ""))
		var chemical: ChemicalDefinition = _database.get_chemical(chemical_id)
		if chemical == null:
			result.status = ReactionResult.Status.INVALID
			result.errors.append("Reaction refers to unknown chemical '%s'." % chemical_id)
			continue
		if not chemical.virtual_simulation_enabled:
			result.status = ReactionResult.Status.REJECTED
			result.errors.append("Chemical '%s' is reference-only and is not enabled for virtual simulation." % chemical_id)
			continue

		var phase := str(participant.get("phase", ""))
		if not PHASE_LEDGER_KEYS.has(phase):
			result.status = ReactionResult.Status.INVALID
			result.errors.append("Reaction participant '%s' has unsupported phase '%s'." % [chemical_id, phase])
			continue

		var minimum_value: Variant = participant.get("minimum_amount", VesselState.EPSILON)
		if (typeof(minimum_value) != TYPE_INT and typeof(minimum_value) != TYPE_FLOAT) \
				or not is_finite(float(minimum_value)) or float(minimum_value) <= 0.0:
			result.status = ReactionResult.Status.INVALID
			result.errors.append("Reaction participant '%s' has an invalid minimum amount." % chemical_id)
			continue
		var minimum_amount := float(minimum_value)
		var ledger_key: String = str(PHASE_LEDGER_KEYS[phase])
		var ledger: Dictionary = vessel.get(ledger_key)
		var available_amount := float(ledger.get(chemical_id, 0.0))
		var participant_result := {
			"chemical_id": chemical_id,
			"phase": phase,
			"available_amount": available_amount,
			"required_amount": minimum_amount,
			"coefficient": float(participant.get("coefficient", 1.0)),
		}
		if available_amount + VesselState.EPSILON >= minimum_amount:
			result.matched_reactants.append(participant_result)
		else:
			participant_result["reason"] = "Required material or phase is not present in sufficient model quantity."
			result.missing_reactants.append(participant_result)

	if not result.errors.is_empty():
		if result.status != ReactionResult.Status.REJECTED:
			result.status = ReactionResult.Status.INVALID
		result.message = "The reaction definition or one of its participants is invalid or not permitted."
		return result

	if not result.missing_reactants.is_empty():
		result.status = ReactionResult.Status.NOT_MATCHED
		result.message = "One or more required reactants are missing from this vessel."
		return result

	var condition_result := _check_conditions(reaction.conditions, vessel)
	if not bool(condition_result.get("ok", false)):
		result.status = ReactionResult.Status.NOT_MATCHED if bool(condition_result.get("unsatisfied", false)) else ReactionResult.Status.INVALID
		result.message = str(condition_result.get("message", "Reaction conditions are not satisfied."))
		if result.status == ReactionResult.Status.INVALID:
			result.errors.append(result.message)
		return result

	result.status = ReactionResult.Status.MATCHED
	result.message = "All registered reactants and supported conditions are present. No materials were changed."
	result.warnings.append("Matching is a read-only readiness check; the reaction executor is a separate component.")
	return result


func _check_conditions(conditions: Array, vessel: VesselState) -> Dictionary:
	for condition_value in conditions:
		if typeof(condition_value) != TYPE_DICTIONARY:
			return {"ok": false, "unsatisfied": false, "message": "Reaction condition is not a dictionary."}
		var condition: Dictionary = condition_value
		var property_name := str(condition.get("property", ""))
		var operator := str(condition.get("operator", ""))
		var value: Variant = condition.get("value", null)
		if property_name != "temperature_c":
			return {"ok": false, "unsatisfied": false, "message": "Unsupported reaction condition '%s'." % property_name}
		if (typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT) or not is_finite(float(value)):
			return {"ok": false, "unsatisfied": false, "message": "Temperature condition has an invalid numeric value."}
		var expected := float(value)
		var actual := vessel.temperature_c
		var satisfied := false
		match operator:
			"gte":
				satisfied = actual >= expected
			"lte":
				satisfied = actual <= expected
			"eq":
				satisfied = is_equal_approx(actual, expected)
			_:
				return {"ok": false, "unsatisfied": false, "message": "Unsupported temperature comparison '%s'." % operator}
		if not satisfied:
			return {"ok": false, "unsatisfied": true, "message": "The vessel temperature does not satisfy the registered reaction condition."}
	return {"ok": true, "unsatisfied": false, "message": ""}
