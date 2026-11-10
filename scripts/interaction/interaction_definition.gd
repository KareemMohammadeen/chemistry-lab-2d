class_name InteractionDefinition
extends RefCounted
## Data describing one kind of interaction (data/interaction/interaction_types.json).

var id: StringName = &""
var label: String = ""
## instant, drag or toggle (see Design Bible, Section 59.2).
var mode: String = "instant"


static func from_dictionary(data: Dictionary) -> InteractionDefinition:
	var id_text := str(data.get("id", ""))
	var label_text := str(data.get("label", ""))
	if id_text.is_empty() or label_text.is_empty():
		push_error("InteractionDefinition: entry needs 'id' and 'label': %s" % str(data))
		return null
	var definition := InteractionDefinition.new()
	definition.id = StringName(id_text)
	definition.label = label_text
	definition.mode = str(data.get("mode", "instant"))
	return definition
