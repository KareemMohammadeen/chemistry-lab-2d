class_name ReactionEngineAdvanced
extends "res://scripts/chemistry/reaction_engine_final.gd"
## Backwards-compatible wrapper that now reuses the complete engine.
## Unlisted reactions are allowed so newly added classroom data can execute
## without requiring a registry edit for every safe addition.

func _enabled_reaction_ids() -> Array[String]:
	var reaction_ids: Array[String] = []
	if _db == null:
		return reaction_ids
	for reaction_id_value in _db.reactions.keys():
		var reaction_id := str(reaction_id_value)
		if _db.reaction_registry != null and _db.reaction_registry.has_reaction(reaction_id) and not _db.reaction_registry.is_enabled(reaction_id):
			continue
		reaction_ids.append(reaction_id)
	reaction_ids.sort()
	return reaction_ids


func _reaction_is_allowed(reaction: ReactionDefinition) -> bool:
	if reaction == null:
		return false
	if _db == null or _db.reaction_registry == null:
		return true
	if _db.reaction_registry.has_reaction(reaction.id) and not _db.reaction_registry.is_enabled(reaction.id):
		return false
	return true
