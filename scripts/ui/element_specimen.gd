class_name ElementSpecimen
extends PanelContainer
## A draggable teaching token placed on the workbench from the periodic table.
## It is a visual reference/sample token, not a chemical reagent or simulation vessel.

var element_data: Dictionary = {}
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO


func setup(data: Dictionary) -> void:
	element_data = data.duplicate(true)
	custom_minimum_size = Vector2(236.0, 92.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	theme_type_variation = &"CardPanel"
	var accent := Color("#63D5F0") if bool(data.get("display_only_sample", false)) else Color("#8C87FF")
	add_theme_stylebox_override("panel", LabTheme.box(Color("#101E2A"), accent, 1, 14, 12, 9))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	var symbol_panel := PanelContainer.new()
	symbol_panel.custom_minimum_size = Vector2(54.0, 62.0)
	symbol_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	symbol_panel.add_theme_stylebox_override("panel", LabTheme.box(Color("#1C3443"), accent, 1, 10, 5, 4))
	row.add_child(symbol_panel)

	var symbol := Label.new()
	symbol.text = str(data.get("symbol", "?"))
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	symbol.add_theme_font_size_override("font_size", 22)
	symbol.add_theme_color_override("font_color", LabColors.TEXT_PRIMARY)
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	symbol_panel.add_child(symbol)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 2)
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(details)

	var name_label := Label.new()
	name_label.text = str(data.get("name", "Unknown element"))
	name_label.theme_type_variation = &"StrongLabel"
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(name_label)

	var number_label := Label.new()
	number_label.text = "Atomic number %s" % str(data.get("atomic_number", "—"))
	number_label.theme_type_variation = &"CaptionLabel"
	number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(number_label)

	var status := Label.new()
	status.text = "VISUAL SAMPLE ONLY" if bool(data.get("display_only_sample", false)) else "REFERENCE ONLY"
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", accent)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(status)

	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(28.0, 28.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.theme_type_variation = &"ToolButton"
	close_button.tooltip_text = "Remove this element token from the workbench"
	close_button.pressed.connect(queue_free)
	row.add_child(close_button)


func _gui_input(event: InputEvent) -> void:
	var parent_control := get_parent() as Control
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed and parent_control != null:
			_drag_offset = parent_control.get_local_mouse_position() - position
			_dragging = true
			z_index = 100
			accept_event()
		elif not mouse_event.pressed:
			_dragging = false
			z_index = 10
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		if parent_control == null:
			return
		var maximum := Vector2(maxf(parent_control.size.x - size.x, 0.0), maxf(parent_control.size.y - size.y, 0.0))
		position = (parent_control.get_local_mouse_position() - _drag_offset).clamp(Vector2.ZERO, maximum)
		accept_event()
