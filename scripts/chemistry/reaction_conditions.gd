class_name ReactionConditions
extends RefCounted
## The single evaluator for the `conditions` list of a reaction definition. The reaction engine and
## the read-only matcher both use it, so a condition can never mean two different things.
##
## Supported condition objects (data/reactions/*.json):
##   {"type": "temperature", "min": <deg C>, "max": <deg C>}   either bound optional ("value" = exact)
##   {"type": "pressure",    "min": <kPa>,   "max": <kPa>}
##   {"type": "ph",          "min": <pH>,    "max": <pH>}
##   {"type": "closed_system", "value": true|false}
##   {"type": "catalyst", "chemical_id": "<id>"}
## An unknown condition type is a definition error, never silently ignored: a reaction whose
## requirement the engine cannot check must not run.


## Returns {"ok": bool, "unsatisfied": bool, "message": String}. `unsatisfied` is true when the
## definition is valid but the vessel does not meet it; false with ok == false means the
## definition itself is invalid or unsupported.
static func evaluate(conditions: Array, vessel: VesselState, database: ContentDatabase) -> Dictionary:
	var ambient_pressure := VesselState.DEFAULT_AMBIENT_PRESSURE_KPA
	if database != null:
		ambient_pressure = database.constant("ambient_pressure_kpa", VesselState.DEFAULT_AMBIENT_PRESSURE_KPA)
	for condition_value in conditions:
		if typeof(condition_value) != TYPE_DICTIONARY:
			return _invalid("A reaction condition must be an object.")
		var condition: Dictionary = condition_value
		var condition_type := str(condition.get("type", ""))
		match condition_type:
			"temperature":
				if not _range_ok(vessel.temperature_c, condition):
					return _unsatisfied("The vessel temperature does not satisfy the reaction condition.")
			"pressure":
				if not _range_ok(vessel.pressure_kpa(ambient_pressure), condition):
					return _unsatisfied("The vessel pressure does not satisfy the reaction condition.")
			"ph":
				var ph := AcidBase.compute_ph(vessel, database)
				if not is_nan(ph) and not _range_ok(ph, condition):
					return _unsatisfied("The pH does not satisfy the reaction condition.")
			"closed_system":
				if bool(condition.get("value", true)) != vessel.is_closed_system:
					return _unsatisfied("The reaction requires a %s system." % ("closed" if bool(condition.get("value", true)) else "open"))
			"catalyst":
				var chemical_id := str(condition.get("chemical_id", ""))
				if not chemical_id.is_empty() and not _vessel_has(vessel, chemical_id):
					return _unsatisfied("The reaction requires its catalyst or promoter.")
			_:
				return _invalid("Unsupported reaction condition '%s'." % condition_type)
	return {"ok": true, "unsatisfied": false, "message": ""}


static func _range_ok(value: float, condition: Dictionary) -> bool:
	if condition.has("min") and value < float(condition["min"]):
		return false
	if condition.has("max") and value > float(condition["max"]):
		return false
	if condition.has("value"):
		return is_equal_approx(value, float(condition["value"]))
	return true


static func _vessel_has(vessel: VesselState, chemical_id: String) -> bool:
	return vessel.liquids.has(chemical_id) or vessel.solids.has(chemical_id) \
			or vessel.dissolved.has(chemical_id) or vessel.gases.has(chemical_id)


static func _unsatisfied(message: String) -> Dictionary:
	return {"ok": false, "unsatisfied": true, "message": message}


static func _invalid(message: String) -> Dictionary:
	return {"ok": false, "unsatisfied": false, "message": message}
