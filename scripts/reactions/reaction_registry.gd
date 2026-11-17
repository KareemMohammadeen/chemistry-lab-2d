class_name ReactionRegistry
extends RefCounted

const REGISTRY_PATH := "res://data/reactions/reaction_registry.json"

var enabled_reactions: Dictionary = {}
var registry_types: Dictionary = {}


func load() -> void:
	var data := JsonDataLoader.load_dictionary(REGISTRY_PATH)
	load_from_dictionary(data)


func load_from_dictionary(data: Dictionary) -> void:
	enabled_reactions.clear()
	registry_types.clear()
	for entry in data.get("reactions", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var reaction_id := str(entry.get("id", ""))
		if reaction_id.is_empty():
			continue
		var enabled := bool(entry.get("enabled", false))
		enabled_reactions[reaction_id] = enabled
		registry_types[reaction_id] = str(entry.get("type", ""))


func is_enabled(reaction_id: String) -> bool:
	return bool(enabled_reactions.get(reaction_id, false))


func get_type(reaction_id: String) -> String:
	return str(registry_types.get(reaction_id, ""))
