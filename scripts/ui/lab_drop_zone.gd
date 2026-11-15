class_name LabDropZone
extends Control
## Receives catalogue drag payloads over the visible workbench surface.
## It only forwards data to the UI layer; it never mutates simulation state.

signal element_dropped(element_data: Dictionary, local_position: Vector2)
signal library_item_dropped(payload: Dictionary, local_position: Vector2)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var kind := str((data as Dictionary).get("kind", ""))
	return kind in ["periodic_element", "equipment", "reagent"]


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var payload: Dictionary = (data as Dictionary).duplicate(true)
	if str(payload.get("kind", "")) == "periodic_element":
		element_dropped.emit(payload, at_position)
	else:
		library_item_dropped.emit(payload, at_position)
