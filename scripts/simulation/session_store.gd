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
	# full_precision keeps every digit of a double, so a reload restores the exact state.
	var serialised := JSON.stringify(document, "\t", true, true)
	if serialised.to_utf8_buffer().size() > MAX_FILE_BYTES:
		return _failure("This experiment is too large to save as one session file.")
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return _failure("Could not open the save file: %s" % error_string(FileAccess.get_open_error()))
	file.store_string(serialised)
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
	var snapshot_dictionary: Dictionary = snapshot
	var validation_message := _validate_snapshot(snapshot_dictionary, database)
	if not validation_message.is_empty():
		return _failure(validation_message)

	var raw_history: Variant = document.get("history", [])
	if typeof(raw_history) != TYPE_ARRAY:
		return _failure("The experiment log in this session is not valid.")
	var saved_history: Array = raw_history
	var history: Array = []
	for entry in saved_history:
		if typeof(entry) != TYPE_DICTIONARY:
			return _failure("The experiment log contains an invalid entry.")
		if history.size() >= MAX_HISTORY_ENTRIES:
			break
		history.append((entry as Dictionary).duplicate(true))

	# No live state is changed until every part of the file has passed validation.
	simulation.restore_snapshot(snapshot_dictionary)
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
	if not _is_whole_number(next_index) or int(next_index) < 1:
		return "The saved object counter is invalid."
	var highest_object_index := 0

	for object_key in objects.keys():
		var object_data: Variant = objects[object_key]
		if typeof(object_data) != TYPE_DICTIONARY:
			return "A saved laboratory object is not valid."
		var item: Dictionary = object_data
		var object_id := str(object_key)
		if not object_id.begins_with("obj_") or not object_id.trim_prefix("obj_").is_valid_int() or int(object_id.trim_prefix("obj_")) < 1:
			return "A saved laboratory object has an invalid id."
		highest_object_index = maxi(highest_object_index, int(object_id.trim_prefix("obj_")))
		if str(item.get("id", "")) != object_id:
			return "A saved object's id does not match its object key."
		if typeof(item.get("power_on", false)) != TYPE_BOOL:
			return "A saved object has an invalid power state."
		var equipment_id := str(item.get("equipment_id", ""))
		var equipment := database.get_equipment(equipment_id)
		if equipment == null:
			return "The session refers to unknown equipment '%s'." % equipment_id
		for numeric_field in ["target_temperature_c", "surface_temperature_c"]:
			if not _is_finite_number(item.get(numeric_field, 22.0)):
				return "A saved object has an invalid %s." % numeric_field
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
			if absf(float(capacity) - equipment.capacity_ml) > VOLUME_EPSILON:
				return "A saved vessel capacity does not match its equipment definition."
			for numeric_field in ["temperature_c", "stir_time_left_s", "neutralised_mol"]:
				var fallback := 22.0 if numeric_field == "temperature_c" else 0.0
				var numeric_value: Variant = vessel.get(numeric_field, fallback)
				if not _is_finite_number(numeric_value) or float(numeric_value) < 0.0 and numeric_field != "temperature_c":
					return "A saved vessel has an invalid %s." % numeric_field
			if float(vessel.get("temperature_c", 22.0)) < -273.15 or float(vessel.get("temperature_c", 22.0)) > 5000.0:
				return "A saved vessel temperature is outside the supported model range."
			var raw_fired: Variant = vessel.get("fired_observations", {})
			if typeof(raw_fired) != TYPE_DICTIONARY:
				return "A saved vessel has invalid observation flags."
			var raw_fused: Variant = vessel.get("fused_systems", {})
			if typeof(raw_fused) != TYPE_DICTIONARY:
				return "A saved vessel has invalid alloy records."
			for system_key in (raw_fused as Dictionary).keys():
				if not _is_known_binary_system(database, str(system_key)):
					return "A saved vessel refers to unknown alloy system '%s'." % str(system_key)
			var raw_observations: Variant = vessel.get("observations", [])
			if typeof(raw_observations) != TYPE_ARRAY or (raw_observations as Array).size() > VesselState.MAX_OBSERVATIONS:
				return "A saved vessel has an invalid observation history."
			for observation in raw_observations:
				if typeof(observation) != TYPE_DICTIONARY:
					return "A saved vessel contains an invalid observation."
				if not _is_finite_number(observation.get("time_s", 0.0)):
					return "A saved observation contains an invalid time."
			var liquid_total := 0.0
			for bucket in ["liquids", "solids", "dissolved"]:
				var amounts: Variant = vessel.get(bucket, {})
				if typeof(amounts) != TYPE_DICTIONARY:
					return "A saved vessel has an invalid %s ledger." % bucket
				for chemical_key in (amounts as Dictionary).keys():
					var chemical_id := str(chemical_key)
					var chemical := database.get_chemical(chemical_id)
					if chemical == null:
						return "The session refers to unknown simulated chemical '%s'." % chemical_id
					if not _fits_phase_bucket(chemical, bucket):
						return "A saved vessel contains '%s' in the wrong phase bucket." % chemical_id
					var amount: Variant = amounts[chemical_key]
					if not _is_finite_number(amount) or float(amount) < 0.0:
						return "A saved amount for '%s' is invalid." % chemical_id
					if bucket == "liquids":
						liquid_total += float(amount)
			var raw_gases: Variant = vessel.get("gases", {})
			if typeof(raw_gases) != TYPE_DICTIONARY:
				return "A saved vessel has an invalid gas ledger."
			var gas_total := 0.0
			# Largest plausible amount of one gas: the vessel filled to the virtual pressure limit at
			# 0 degC (and never below the original 0.01 mol demo limit). Vapour from boiling or
			# evaporation can exceed the demo limit in a hot sealed vessel.
			var max_gas_moles := maxf(0.01, database.constant("max_virtual_pressure_kpa", 300.0) * float(capacity) / 1000.0 \
				/ (VesselState.GAS_CONSTANT_J_PER_MOL_K * ThermalProfile.KELVIN_OFFSET))
			for gas_key in (raw_gases as Dictionary).keys():
				var gas_id := str(gas_key)
				var gas := database.get_chemical(gas_id)
				if gas == null or gas.state != "gas" or not gas.virtual_simulation_enabled:
					return "The session refers to an unsupported virtual gas '%s'." % gas_id
				var moles: Variant = raw_gases[gas_key]
				if not _is_finite_number(moles) or float(moles) <= 0.0 or float(moles) > max_gas_moles:
					return "A saved virtual gas amount is invalid."
				gas_total += float(moles)
			if typeof(vessel.get("is_closed_system", false)) != TYPE_BOOL:
				return "A saved vessel has an invalid open/closed system state."
			var closed_system := bool(vessel.get("is_closed_system", false))
			var trapped_air: Variant = vessel.get("trapped_air_moles", 0.0)
			if not _is_finite_number(trapped_air) or float(trapped_air) < 0.0:
				return "A saved vessel has an invalid trapped-air amount."
			if gas_total > 0.0 and not closed_system:
				return "A saved vessel cannot retain gas while marked as an open system."
			if closed_system:
				if float(trapped_air) <= 0.0:
					return "A closed vessel is missing its trapped-air state."
				var restored_vessel := VesselState.from_dictionary(vessel)
				if restored_vessel.pressure_kpa(database.constant("ambient_pressure_kpa", 101.325)) > database.constant("max_virtual_pressure_kpa", 300.0):
					return "The saved vessel pressure is outside the supported virtual model range."
			if liquid_total > float(capacity) + VOLUME_EPSILON:
				return "A saved vessel contains more liquid than its capacity."

	if int(next_index) <= highest_object_index:
		return "The saved object counter could create duplicate object ids."
	for object_key in objects.keys():
		var item: Dictionary = objects[object_key]
		var supported_by := str(item.get("supported_by", ""))
		var inserted_in := str(item.get("inserted_in", ""))
		if not supported_by.is_empty() and not inserted_in.is_empty():
			return "A saved object cannot be supported by and inserted into another object at the same time."
		for relation in ["supported_by", "inserted_in"]:
			var related_id := str(item.get(relation, ""))
			if related_id.is_empty():
				continue
			if not objects.has(related_id) or related_id == str(object_key):
				return "A saved object has an invalid %s relationship." % relation
			var related_item: Dictionary = objects[related_id]
			var related_equipment := database.get_equipment(str(related_item.get("equipment_id", "")))
			if relation == "supported_by" and (related_equipment == null or related_equipment.support.is_empty()):
				return "A saved support relationship points to equipment that cannot support objects."
			if relation == "inserted_in":
				if related_item.get("vessel") == null or not bool(database.get_equipment(str(item.get("equipment_id", ""))).placement.get("insert_into_vessel", false)):
					return "A saved insertion relationship is not supported by the equipment definitions."
	for object_key in objects.keys():
		if _has_relation_cycle(objects, str(object_key)):
			return "A saved object is part of a circular support or insertion chain."
	return ""


## True when following supported_by / inserted_in from `start_id` ever returns to an object already seen.
static func _has_relation_cycle(objects: Dictionary, start_id: String) -> bool:
	var seen: Dictionary = {}
	var current_id := start_id
	while current_id != "":
		if seen.has(current_id):
			return true
		seen[current_id] = true
		var raw_item: Variant = objects.get(current_id, {})
		if typeof(raw_item) != TYPE_DICTIONARY:
			return false
		var item: Dictionary = raw_item
		var next_id := str(item.get("supported_by", ""))
		if next_id.is_empty():
			next_id = str(item.get("inserted_in", ""))
		current_id = next_id
	return false


## JSON has a single number type, so an integer written by the game is read
## back as a float. A counter is valid when it is finite and has no fraction.
static func _is_whole_number(value: Variant) -> bool:
	if not _is_finite_number(value):
		return false
	return is_equal_approx(float(value), roundf(float(value)))


## A chemical belongs in a ledger bucket of its own state, or of another phase its thermal profile
## defines: molten zinc is a liquid entry although "zinc" is a solid, and frozen ethanol a solid one.
static func _fits_phase_bucket(chemical: ChemicalDefinition, bucket: String) -> bool:
	var wanted := "liquid" if bucket == "liquids" else "solid"
	if chemical.state == wanted:
		return true
	var profile := chemical.thermal
	return profile != null and profile.can_melt() and profile.id_for_phase(wanted) == chemical.id


static func _is_known_binary_system(database: ContentDatabase, system_id: String) -> bool:
	for system_value in database.binary_systems:
		if (system_value as BinaryMeltSystem).id == system_id:
			return true
	return false


static func _is_finite_number(value: Variant) -> bool:
	var value_type := typeof(value)
	if value_type != TYPE_INT and value_type != TYPE_FLOAT:
		return false
	return is_finite(float(value))


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}