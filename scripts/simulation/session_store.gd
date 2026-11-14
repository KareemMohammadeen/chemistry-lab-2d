class_name LabSessionStore
extends RefCounted
## Versioned JSON save/load for a complete virtual-lab session.
## Only serialisable simulation state and the operator-facing command log are stored.
## Loading validates the whole document before replacing the live session.

const FORMAT_ID := "chemistry_lab_session"
const FORMAT_VERSION := 1
const MAX_FILE_BYTES := 5 * 1024 * 1024
const MAX_SAVED_OBJECTS := 256
const MAX_HISTORY_ENTRIES := 5000
const VOLUME_EPSILON := 0.01


static func save_to_path(simulation: LabSimulation, command_stack: CommandStack, path: String) -> Dictionary:
	var target_path := path.strip_edges()
	if target_path.is_empty():
		return _failure("Choose a file name before saving.")
	if not target_path.to_lower().ends_with(".json"):
		target_path += ".json"

	var document := {
		"format": FORMAT_ID,
		"version": FORMAT_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"setup_title": simulation.setup_title,
		"state": simulation.capture_snapshot(),
		"history": command_stack.history.duplicate(true),
	}
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return _failure("Could not open the save file: %s" % error_string(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(document, "\t"))
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return _failure("The session could not be written: %s" % error_string(write_error))
	return {"ok": true, "message": "Experiment saved to %s." % target_path, "path": target_path}


static func load_from_path(simulation: LabSimulation, command_stack: CommandStack,
		database: ContentDatabase, path: String) -> Dictionary:
	var source_path := path.strip_edges()
	if source_path.is_empty():
		return _failure("Choose a session file to open.")
	if not FileAccess.file_exists(source_path):
		return _failure("The selected session file does not exist.")
	var file := FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		return _failure("Could not open the session file: %s" % error_string(FileAccess.get_open_error()))
	if file.get_length() > MAX_FILE_BYTES:
		file.close()
		return _failure("This session file is larger than the 5 MB safety limit.")
	var source_text := file.get_as_text()
	file.close()

	var parser := JSON.new()
	var parse_error := parser.parse(source_text)
	if parse_error != OK:
		return _failure("Invalid session JSON at line %d: %s" % [
			parser.get_error_line(), parser.get_error_message()])
	var document: Variant = parser.data
	if typeof(document) != TYPE_DICTIONARY:
		return _failure("This file is not a Chemistry Lab session.")
	if str(document.get("format", "")) != FORMAT_ID:
		return _failure("This file was not created by Chemistry Lab.")
	if int(document.get("version", -1)) != FORMAT_VERSION:
		return _failure("This session uses an unsupported save-file version.")

	var snapshot: Variant = document.get("state")
	if typeof(snapshot) != TYPE_DICTIONARY:
		return _failure("The session does not contain a valid laboratory state.")
	var validation_message := _validate_snapshot(snapshot, database)
	if not validation_message.is_empty():
		return _failure(validation_message)

	var raw_history: Variant = document.get("history", [])
	if typeof(raw_history) != TYPE_ARRAY:
		return _failure("The experiment log in this session is not valid.")
	var history: Array = []
	for entry in raw_history:
		if typeof(entry) != TYPE_DICTIONARY:
			return _failure("The experiment log contains an invalid entry.")
		if history.size() >= MAX_HISTORY_ENTRIES:
			break
		history.append((entry as Dictionary).duplicate(true))

	# No live state is changed until every part of the file has passed validation.
	simulation.restore_snapshot(snapshot)
	simulation.setup_title = str(document.get("setup_title", "Saved experiment"))
	command_stack.restore_history(history)
	return {"ok": true, "message": "Opened experiment: %s." % simulation.setup_title,
		"path": source_path}


static func _validate_snapshot(snapshot: Dictionary, database: ContentDatabase) -> String:
	var time_value: Variant = snapshot.get("time_s", 0.0)
	if not _is_finite_number(time_value) or float(time_value) < 0.0:
		return "The saved simulation time is invalid."
	var raw_objects: Variant = snapshot.get("objects")
	if typeof(raw_objects) != TYPE_DICTIONARY:
		return "The saved session has no valid object collection."
	var objects: Dictionary = raw_objects
	if objects.size() > MAX_SAVED_OBJECTS:
		return "This session contains too many laboratory objects."
	var next_index: Variant = snapshot.get("next_index", 1)
	if typeof(next_index) != TYPE_INT or int(next_index) < 1:
		return "The saved object counter is invalid."

	for object_key in objects.keys():
		var object_data: Variant = objects[object_key]
		if typeof(object_data) != TYPE_DICTIONARY:
			return "A saved laboratory object is not valid."
		var item: Dictionary = object_data
		var equipment_id := str(item.get("equipment_id", ""))
		var equipment := database.get_equipment(equipment_id)
		if equipment == null:
			return "The session refers to unknown equipment '%s'." % equipment_id
		var position: Variant = item.get("position", [])
		if typeof(position) != TYPE_ARRAY or (position as Array).size() < 2:
			return "A saved object's position is invalid."
		if not _is_finite_number(position[0]) or not _is_finite_number(position[1]):
			return "A saved object's position is not a finite number."

		var vessel_data: Variant = item.get("vessel")
		if vessel_data == null:
			if equipment.is_vessel():
				return "A saved vessel is missing its contents record."
		else:
			if typeof(vessel_data) != TYPE_DICTIONARY or not equipment.is_vessel():
				return "A saved object's vessel data does not match its equipment."
			var vessel: Dictionary = vessel_data
			var capacity: Variant = vessel.get("capacity_ml", equipment.capacity_ml)
			if not _is_finite_number(capacity) or float(capacity) <= 0.0:
				return "A saved vessel has an invalid capacity."
			var liquid_total := 0.0
			for bucket in ["liquids", "solids", "dissolved"]:
				var amounts: Variant = vessel.get(bucket, {})
				if typeof(amounts) != TYPE_DICTIONARY:
					return "A saved vessel has an invalid %s ledger." % bucket
				for chemical_key in (amounts as Dictionary).keys():
					var chemical_id := str(chemical_key)
					if database.get_chemical(chemical_id) == null:
						return "The session refers to unknown simulated chemical '%s'." % chemical_id
					var amount: Variant = amounts[chemical_key]
					if not _is_finite_number(amount) or float(amount) < 0.0:
						return "A saved amount for '%s' is invalid." % chemical_id
					if bucket == "liquids":
						liquid_total += float(amount)
			if liquid_total > float(capacity) + VOLUME_EPSILON:
				return "A saved vessel contains more liquid than its capacity."

	for object_key in objects.keys():
		var item: Dictionary = objects[object_key]
		for relation in ["supported_by", "inserted_in"]:
			var related_id := str(item.get(relation, ""))
			if not related_id.is_empty() and (not objects.has(related_id) or related_id == str(object_key)):
				return "A saved object has an invalid %s relationship." % relation
	return ""


static func _is_finite_number(value: Variant) -> bool:
	var value_type := typeof(value)
	if value_type != TYPE_INT and value_type != TYPE_FLOAT:
		return false
	return is_finite(float(value))


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
