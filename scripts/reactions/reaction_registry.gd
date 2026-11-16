class_name ReactionRegistry
extends RefCounted

## Reaction Engine V3 foundation.
## Loads data-driven virtual reactions without coupling chemistry rules to UI.

const DEFAULT_SCOPE := "virtual_only_classroom_model"

var reactions: Dictionary = {}

func load_reactions(data: Dictionary) -> void:
	reactions.clear()
	if data.get("safety_scope", "") != DEFAULT_SCOPE:
		return

	for reaction in data.get("reactions", []):
		var id := str(reaction.get("id", ""))
		if not id.is_empty():
			reactions[id] = reaction

func get_reaction(id: String) -> Dictionary:
	return reactions.get(id, {})

func has_reaction(id: String) -> bool:
	return reactions.has(id)
