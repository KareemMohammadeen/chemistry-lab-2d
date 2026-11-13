class_name LabDropZone
extends Control
## Receives catalogue drag payloads over the visible workbench surface.
## It only forwards data to the UI layer; it never mutates simulation state.

signal element_dropped(element_data: Dictionary, local_position: Vector2)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and str((data as Dictionary).get("kind", "")) == "periodic_element"


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	element_dropped.emit((data as Dictionary).duplicate(true), at_position)
