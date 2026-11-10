class_name InteractionContext
extends RefCounted
## Everything known about one interaction (Design Bible, Section 59.1). It travels from the
## pointer layer into a command and is stored in the command log, which is what makes
## undo, replay and laboratory reports possible with one mechanism.

var interaction_id: StringName = &""
## Object doing the action (the held vessel, the bottle, the heater). Empty if none.
var source: String = ""
## Object or zone acted upon. Empty if none.
var target: String = ""
## {"position": Vector2, "device": String, "button": int}
var pointer: Dictionary = {}
## Action parameters, for example {"amount_ml": 50.0} or {"mode": "surface", "position": Vector2}.
var payload: Dictionary = {}
var sim_time_s: float = 0.0
var real_time_msec: int = 0
var actor: String = "teacher"


static func create(interaction: StringName, source_id: String, target_id: String,
		pointer_data: Dictionary, payload_data: Dictionary, sim_time: float) -> InteractionContext:
	var context := InteractionContext.new()
	context.interaction_id = interaction
	context.source = source_id
	context.target = target_id
	context.pointer = pointer_data
	context.payload = payload_data
	context.sim_time_s = sim_time
	context.real_time_msec = Time.get_ticks_msec()
	return context


## Plain-data copy for the command log (vectors become [x, y] arrays).
func to_dictionary() -> Dictionary:
	return {
		"interaction_id": String(interaction_id),
		"source": source,
		"target": target,
		"pointer": _plain(pointer),
		"payload": _plain(payload),
		"sim_time_s": sim_time_s,
		"real_time_msec": real_time_msec,
		"actor": actor,
	}


static func _plain(value: Variant) -> Variant:
	if typeof(value) == TYPE_VECTOR2:
		var vector: Vector2 = value
		return [vector.x, vector.y]
	if typeof(value) == TYPE_DICTIONARY:
		var source_dictionary: Dictionary = value
		var converted: Dictionary = {}
		for key in source_dictionary.keys():
			converted[key] = _plain(source_dictionary[key])
		return converted
	return value
