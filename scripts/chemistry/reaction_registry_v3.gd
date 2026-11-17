class_name ReactionRegistryV3
extends RefCounted
## Explicit allowlist of data-defined reactions and the handlers permitted to interpret them.
## This registry keeps future reaction entries available as disabled references until
## a dedicated executable handler is registered and reviewed.

const REGISTRY_VERSION := 1
const SAFETY_SCOPE := "virtual_only_classroom_model"

const EXECUTABLE_REACTION_TYPES := {
	"dissolution": true,
	"neutralisation": true,
	"boiling": true,
	"gas_evolution": true,
	"precipitation": true,
	"acid_carbonate": true,
	"single_displacement": true,
	"double_displacement": true,
	"combustion": true,
	"phase_change": true,
}

var entries: Dictionary = {}
var handlers: Dictionary = {}
var errors: PackedStringArray = PackedStringArray()


func load_from_dictionary(data: Dictionary, definitions: Dictionary) -> PackedStringArray:
	entries.clear()
	handlers.clear()
	errors.clear()

	if int(data.get("version", 0)) != REGISTRY_VERSION:
		errors.append("Reaction registry has an unsupported or missing version.")
	if str(data.get("safety_scope", "")) != SAFETY_SCOPE:
		errors.append("Reaction registry must declare the virtual-only classroom safety scope.")

	var handler_data: Variant = data.get("handlers", {})
	if typeof(handler_data) != TYPE_DICTIONARY:
		errors.append("Reaction registry handlers must be a dictionary.")
	else:
		for handler_id_value in handler_data.keys():
			var handler_id := str(handler_id_value)
			var handler_value: Variant = handler_data[handler_id_value]
			if typeof(handler_value) != TYPE_DICTIONARY:
				errors.append("Handler '%s' has an invalid definition." % handler_id)
				continue
			var handler: Dictionary = handler_value
			var reaction_type := str(handler.get("reaction_type", ""))
			if reaction_type.is_empty():
				errors.append("Handler '%s' must declare a reaction_type." % handler_id)
				continue
			if typeof(handler.get("enabled", false)) != TYPE_BOOL:
				errors.append("Handler '%s' must declare enabled as a boolean." % handler_id)
				continue
			handlers[handler_id] = handler.duplicate(true)
			if bool(handler.get("enabled", false)) and not EXECUTABLE_REACTION_TYPES.has(reaction_type):
				errors.append("Handler '%s' is enabled for unsupported reaction type '%s'." % [handler_id, reaction_type])

	var reaction_data: Variant = data.get("reactions", [])
	if typeof(reaction_data) != TYPE_ARRAY:
		errors.append("Reaction registry reactions must be an array.")
		return errors

	for reaction_value in reaction_data:
		if typeof(reaction_value) != TYPE_DICTIONARY:
			errors.append("Reaction registry contains a non-dictionary entry.")
			continue
		var entry: Dictionary = reaction_value
		var reaction_id := str(entry.get("id", ""))
		var handler_id := str(entry.get("handler_id", ""))
		if reaction_id.is_empty():
			errors.append("Reaction registry entry has no id.")
			continue
		if entries.has(reaction_id):
			errors.append("Reaction registry contains duplicate id '%s'." % reaction_id)
			continue
		if typeof(entry.get("enabled", false)) != TYPE_BOOL:
			errors.append("Reaction '%s' must declare enabled as a boolean." % reaction_id)
			continue
		if str(entry.get("safety_scope", "")) != SAFETY_SCOPE:
			errors.append("Reaction '%s' is outside the approved virtual-only scope." % reaction_id)
			continue
		if not handlers.has(handler_id):
			errors.append("Reaction '%s' refers to unknown or invalid handler '%s'." % [reaction_id, handler_id])
			continue

		var definition: ReactionDefinition = definitions.get(reaction_id) as ReactionDefinition
		if definition == null:
			errors.append("Reaction registry refers to missing definition '%s'." % reaction_id)
			continue
		var expected_type: String = str(handlers[handler_id].get("reaction_type", ""))
		if definition.type != expected_type:
			errors.append("Reaction '%s' type '%s' does not match handler '%s'." % [reaction_id, definition.type, handler_id])
			continue

		var is_enabled: bool = bool(entry.get("enabled", false))
		if is_enabled and not bool(handlers[handler_id].get("enabled", false)):
			errors.append("Reaction '%s' is enabled while its handler is disabled." % reaction_id)
			continue
		if is_enabled and not EXECUTABLE_REACTION_TYPES.has(expected_type):
			errors.append("Reaction '%s' cannot be enabled until its handler type '%s' is supported by the engine." % [reaction_id, expected_type])
			continue
		if definition.type == "visual_demo" and is_enabled:
			errors.append("Visual demonstration '%s' cannot be enabled as a generic executable reaction." % reaction_id)
			continue

		entries[reaction_id] = entry.duplicate(true)

	for reaction_id_value in definitions.keys():
		var reaction_id := str(reaction_id_value)
		if not entries.has(reaction_id):
			errors.append("Reaction definition '%s' is missing from the explicit registry." % reaction_id)

	return errors


func has_reaction(reaction_id: String) -> bool:
	return entries.has(reaction_id)


func is_enabled(reaction_id: String) -> bool:
	var entry: Dictionary = entries.get(reaction_id, {})
	return bool(entry.get("enabled", false))


func get_entry(reaction_id: String) -> Dictionary:
	var entry: Dictionary = entries.get(reaction_id, {})
	return entry.duplicate(true)


func get_handler_id(reaction_id: String) -> String:
	return str(entries.get(reaction_id, {}).get("handler_id", ""))


func enabled_reaction_ids() -> Array[String]:
	var result: Array[String] = []
	for reaction_id_value in entries.keys():
		var reaction_id := str(reaction_id_value)
		if is_enabled(reaction_id):
			result.append(reaction_id)
	result.sort()
	return result


func get_enabled_reaction_ids_by_type(reaction_type: String) -> Array[String]:
	var result: Array[String] = []
	if reaction_type.is_empty():
		return result
	for reaction_id_value in entries.keys():
		var reaction_id := str(reaction_id_value)
		if not is_enabled(reaction_id):
			continue
		var handler_id := get_handler_id(reaction_id)
		var handler: Dictionary = handlers.get(handler_id, {})
		if str(handler.get("reaction_type", "")) == reaction_type:
			result.append(reaction_id)
	result.sort()
	return result


func first_enabled_reaction_id_by_type(reaction_type: String) -> String:
	var ids := get_enabled_reaction_ids_by_type(reaction_type)
	if ids.is_empty():
		return ""
	return ids[0]
