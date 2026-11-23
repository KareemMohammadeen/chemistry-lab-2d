class_name ElementSpecimen
extends PanelContainer
## Compact material sample on the infinite lab surface.
## A periodic-table sample is always a visual reference, never a reactive reagent.

var element_data: Dictionary = {}
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO


func setup(data: Dictionary) -> void:
	element_data = data.duplicate(true)
	custom_minimum_size = Vector2(126.0, 126.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE

	var profile := ElementVisual.profile_for(data)
	var accent: Color = profile.get("color", Color("#8C87FF"))
	add_theme_stylebox_override("panel", LabTheme.box(Color("#101E2A"), accent, 1, 12, 6, 6))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	var visual := ElementVisual.new()
	visual.setup(data)
	visual.custom_minimum_size = Vector2(114.0, 92.0)
	visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(visual)

	var name_label := Label.new()
	name_label.text = "%s · %s" % [str(data.get("name", "Unknown")), str(data.get("symbol", "?"))]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", LabColors.TEXT_PRIMARY)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)

	var state_label := Label.new()
	state_label.text = "VISUAL MODEL · NOT A REAGENT"
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.add_theme_font_size_override("font_size", 8)
	state_label.add_theme_color_override("font_color", LabColors.TEXT_MUTED)
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(state_label)

	tooltip_text = "%s (%s), atomic number %s. %s. Visual reference only; it cannot be mixed, heated or reacted." % [
		str(data.get("name", "Unknown element")),
		str(data.get("symbol", "?")),
		str(data.get("atomic_number", "—")),
		str(profile.get("label", "Conceptual atom model"))
	]


func _gui_input(event: InputEvent) -> void:
	var parent_item := get_parent() as CanvasItem
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed and parent_item != null:
			_drag_offset = _parent_pointer_position(parent_item) - position
			_dragging = true
			z_index = LabWorkspace.SPECIMEN_DRAG_Z
			accept_event()
		elif not mouse_event.pressed:
			_dragging = false
			z_index = LabWorkspace.SPECIMEN_Z
			accept_event()


func _process(_delta: float) -> void:
	if not _dragging:
		return
	var parent_item := get_parent() as CanvasItem
	if parent_item == null:
		_dragging = false
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		position = _parent_pointer_position(parent_item) - _drag_offset
	else:
		_dragging = false
		z_index = LabWorkspace.SPECIMEN_Z


func _parent_pointer_position(parent_item: CanvasItem) -> Vector2:
	var screen_position := get_viewport().get_mouse_position()
	return parent_item.get_global_transform_with_canvas().affine_inverse() * screen_position
