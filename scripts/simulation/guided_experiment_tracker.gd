class_name GuidedExperimentTracker
extends RefCounted
## Evaluates a guided activity against accepted command-log entries and the live simulation.
## It recognises a deliberately small, safe set of virtual classroom actions.

const ALLOWED_COMMANDS: Array[String] = ["pour", "add_solid", "mix"]
const ALLOWED_CHEMICALS: Array[String] = ["water", "sodium_chloride"]
const ALLOWED_VESSELS: Array[String] = ["beaker_250ml", "erlenmeyer_flask_250ml", "test_tube_20ml"]


static func evaluate(experiment: Dictionary, history: Array, start_index: int, sim: LabSimulation) -> Dictionary:
	var steps_value: Variant = experiment.get("steps", [])
	if not bool(experiment.get("enabled", false)) or str(experiment.get("safety_scope", "virtual_only_classroom_model")) != "virtual_only_classroom_model":
		return _result(0, 0, "", false, "This activity is not enabled for the virtual classroom model.")
	if typeof(steps_value) != TYPE_ARRAY:
		return _result(0, 0, "", false, "The activity step list is invalid.")
	var steps: Array = steps_value
	if steps.is_empty() or steps.size() > 20:
		return _result(0, steps.size(), "", false, "The activity must contain between 1 and 20 steps.")

	var cursor: int = clampi(start_index, 0, history.size())
	var active_vessel_id: String = ""
	var completed: int = 0

	for step_value in steps:
		if typeof(step_value) != TYPE_DICTIONARY:
			return _result(completed, steps.size(), active_vessel_id, false, "An activity step is invalid.")
		var step: Dictionary = step_value
		var step_type: String = str(step.get("type", ""))
		if step_type == "action":
			var expected_command: String = str(step.get("command", ""))
			var expected_interaction: String = str(step.get("interaction_id", ""))
			if not ALLOWED_COMMANDS.has(expected_command) or expected_interaction.is_empty():
				return _result(completed, steps.size(), active_vessel_id, false, "The activity contains an unsupported action.")
			var source_chemical_id: String = str(step.get("source_contains_chemical_id", ""))
			var target_chemical_id: String = str(step.get("target_contains_chemical_id", ""))
			if (not source_chemical_id.is_empty() and not ALLOWED_CHEMICALS.has(source_chemical_id)) or (not target_chemical_id.is_empty() and not ALLOWED_CHEMICALS.has(target_chemical_id)):
				return _result(completed, steps.size(), active_vessel_id, false, "The activity refers to a material outside the approved classroom subset.")

			var matched_index: int = -1
			for history_index in range(cursor, history.size()):
				var entry_value: Variant = history[history_index]
				if typeof(entry_value) != TYPE_DICTIONARY:
					continue
				var entry: Dictionary = entry_value
				if not bool(entry.get("ok", false)) or str(entry.get("command", "")) != expected_command:
					continue
				var context_value: Variant = entry.get("context", {})
				if typeof(context_value) != TYPE_DICTIONARY:
					continue
				var context: Dictionary = context_value
				if str(context.get("interaction_id", "")) != expected_interaction:
					continue
				var source_id: String = str(context.get("source", ""))
				var target_id: String = str(context.get("target", ""))
				var vessel_candidate: String = target_id if not target_id.is_empty() else source_id
				if bool(step.get("same_vessel_as_previous", false)) and vessel_candidate != active_vessel_id:
					continue
				if not source_chemical_id.is_empty() and not _object_contains(sim, source_id, source_chemical_id):
					continue
				if not target_chemical_id.is_empty() and not _object_contains(sim, vessel_candidate, target_chemical_id):
					continue
				var target_equipment_id: String = str(step.get("target_equipment_id", ""))
				if not target_equipment_id.is_empty():
					if not ALLOWED_VESSELS.has(target_equipment_id):
						return _result(completed, steps.size(), active_vessel_id, false, "The activity requests unsupported equipment.")
					var target_object: LabObject = sim.state.get_object(vessel_candidate)
					if target_object == null or target_object.equipment_id != target_equipment_id:
						continue
				matched_index = history_index
				if active_vessel_id.is_empty():
					active_vessel_id = vessel_candidate
				break

			if matched_index < 0:
				return _result(completed, steps.size(), active_vessel_id, false, "")
			cursor = matched_index + 1
			completed += 1
		elif step_type == "condition":
			if active_vessel_id.is_empty():
				return _result(completed, steps.size(), active_vessel_id, false, "")
			var condition: String = str(step.get("condition", ""))
			if condition != "minimum_dissolved_g":
				return _result(completed, steps.size(), active_vessel_id, false, "The activity contains an unsupported condition.")
			var chemical_id: String = str(step.get("chemical_id", ""))
			var minimum_value: Variant = step.get("minimum_g", 0.0)
			if not ALLOWED_CHEMICALS.has(chemical_id) or (typeof(minimum_value) != TYPE_INT and typeof(minimum_value) != TYPE_FLOAT) or not is_finite(float(minimum_value)) or float(minimum_value) <= 0.0 or float(minimum_value) > 10.0:
				return _result(completed, steps.size(), active_vessel_id, false, "The activity condition is outside the supported model.")
			var vessel_object: LabObject = sim.state.get_object(active_vessel_id)
			if vessel_object == null or vessel_object.vessel == null:
				return _result(completed, steps.size(), active_vessel_id, false, "")
			if float(vessel_object.vessel.dissolved.get(chemical_id, 0.0)) + VesselState.EPSILON < float(minimum_value):
				return _result(completed, steps.size(), active_vessel_id, false, "")
			completed += 1
		else:
			return _result(completed, steps.size(), active_vessel_id, false, "The activity contains an unknown step type.")

	return _result(completed, steps.size(), active_vessel_id, completed == steps.size(), "")


static func _object_contains(sim: LabSimulation, object_id: String, chemical_id: String) -> bool:
	var item: LabObject = sim.state.get_object(object_id)
	if item == null or item.vessel == null:
		return false
	return item.vessel.liquids.has(chemical_id) or item.vessel.solids.has(chemical_id) or item.vessel.dissolved.has(chemical_id) or item.vessel.gases.has(chemical_id)


static func _result(progress: int, total: int, vessel_id: String, complete: bool, error: String) -> Dictionary:
	return {
		"progress": progress,
		"total": total,
		"vessel_id": vessel_id,
		"complete": complete,
		"error": error,
	}
