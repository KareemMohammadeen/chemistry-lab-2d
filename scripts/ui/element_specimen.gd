class_name ElementSpecimen
extends PanelContainer
## A draggable 2D visual specimen. It is never a chemical reagent or simulation vessel.

var element_data: Dictionary = {}
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO


func setup(data: Dictionary) -> void:
	element_data = data.duplicate(true)
	custom_minimum_size = Vector2(342.0, 154.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE

	var profile := ElementVisual.profile_for(data)
	var accent: Color = profile.get("color", Color("#8C87FF"))
	add_theme_stylebox_override("panel", LabTheme.box(Color("#101E2A"), accent, 1, 14, 10, 8))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	var details := VBoxContainer.new()
	details.custom_minimum_size = Vector2(158.0, 0.0)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 4)
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(details)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 7)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(heading)

	var symbol_panel := PanelContainer.new()
	symbol_panel.custom_minimum_size = Vector2(48.0, 48.0)
	symbol_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	symbol_panel.add_theme_stylebox_override("panel", LabTheme.box(Color("#1C3443"), accent, 1, 9, 4, 3))
	heading.add_child(symbol_panel)

	var symbol_label := Label.new()
	symbol_label.text = str(data.get("symbol", "?"))
	symbol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	symbol_label.add_theme_font_size_override("font_size", 21)
	symbol_label.add_theme_color_override("font_color", LabColors.TEXT_PRIMARY)
	symbol_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	symbol_panel.add_child(symbol_label)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 1)
	title_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(title_stack)

	var name_label := Label.new()
	name_label.text = str(data.get("name", "Unknown element"))
	name_label.theme_type_variation = &"StrongLabel"
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_stack.add_child(name_label)

	var number_label := Label.new()
	number_label.text = "Atomic number %s" % str(data.get("atomic_number", "—"))
	number_label.theme_type_variation = &"CaptionLabel"
	number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_stack.add_child(number_label)

	var form_label := Label.new()
	form_label.text = str(profile.get("label", "CONCEPTUAL ATOM MODEL"))
	form_label.add_theme_font_size_override("font_size", 9)
	form_label.add_theme_color_override("font_color", accent)
	form_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(form_label)

	var status := Label.new()
	status.text = "SEALED VIRTUAL SPECIMEN" if bool(profile.get("restricted", false)) else "VISUAL MODEL · NOT A REAGENT"
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", Color("#D1A85F") if bool(profile.get("restricted", false)) else LabColors.TEXT_MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(status)

	var visual := ElementVisual.new()
	visual.setup(data)
	visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(visual)

	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(26.0, 28.0)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.theme_type_variation = &"ToolButton"
	close_button.tooltip_text = "Remove this visual specimen from the workbench"
	close_button.pressed.connect(queue_free)
	row.add_child(close_button)

	tooltip_text = "%s (%s) · Atomic number %s\n%s\nEducational 2D visual only. This specimen cannot be mixed, heated or reacted." % [
		str(data.get("name", "Unknown element")),
		str(data.get("symbol", "?")),
		str(data.get("atomic_number", "—")),
		str(profile.get("label", "Conceptual atom model"))
	]


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
