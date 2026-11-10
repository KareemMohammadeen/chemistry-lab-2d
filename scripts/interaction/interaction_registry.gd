class_name InteractionRegistry
extends RefCounted
## Lookup of interaction definitions. New interaction types are added in
## data/interaction/interaction_types.json without touching code.

const DATA_PATH := "res://data/interaction/interaction_types.json"

var _definitions: Dictionary = {}


func load_definitions(path: String = DATA_PATH) -> void:
	_definitions.clear()
	var entries: Array = JsonDataLoader.load_dictionary(path).get("interactions", [])
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			push_error("InteractionRegistry: interaction entry is not an object in %s" % path)
			continue
		var definition := InteractionDefinition.from_dictionary(entry)
		if definition == null:
			continue
		if _definitions.has(definition.id):
			push_error("InteractionRegistry: duplicate interaction id '%s'" % definition.id)
			continue
		_definitions[definition.id] = definition


func has_definition(interaction_id: StringName) -> bool:
	return _definitions.has(interaction_id)


func get_definition(interaction_id: StringName) -> InteractionDefinition:
	return _definitions.get(interaction_id) as InteractionDefinition
