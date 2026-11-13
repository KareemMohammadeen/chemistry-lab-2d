class_name ReferenceBadge
extends PanelContainer
## Draggable dashboard badge for pinned reference entries. It is purely visual and does not
## create simulation state.

signal removed

var _title_label: Label
var _subtitle_label: Label
var _body_label: Label
var _close_button: Button
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _accent := Color("#63D5F0")


func setup(reference: Dictionary) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(280.0, 126.0)
	theme_type_variation = &"GlassPanel"
	_accent = reference.get("accent", Color("#63D5F0"))
	add_theme_stylebox_override("panel", _build_panel_style(_accent))

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(header)

	var accent_bar := ColorRect.new()
	accent_bar.color = _accent
	accent_bar.custom_minimum_size = Vector2(6.0, 34.0)
	header.add_child(accent_bar)

	var title_column := VBoxContainer.new()
	title_column.add_theme_constant_override("separation", 0)
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_column)

	_title_label = Label.new()
	_title_label.text = str(reference.get("title", "Reference"))
	_title_label.theme_type_variation = &"StrongLabel"
	title_column.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = str(reference.get("subtitle", ""))
	_subtitle_label.theme_type_variation = &"CaptionLabel"
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_column.add_child(_subtitle_label)

	_close_button = Button.new()
	_close_button.text = "×"
	_close_button.custom_minimum_size = Vector2(30.0, 30.0)
	_close_button.theme_type_variation = &"ToolButton"
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.pressed.connect(_on_close_pressed)
	header.add_child(_close_button)

	_body_label = Label.new()
	_body_label.text = str(reference.get("body", ""))
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.theme_type_variation = &"MutedLabel"
	root.add_child(_body_label)

	var pill := PanelContainer.new()
	pill.theme_type_variation = &"ChipPanel"
	var pill_label := Label.new()
	pill_label.text = "Reference only"
	pill_label.theme_type_variation = &"CaptionLabel"
	pill.add_child(pill_label)
	root.add_child(pill)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = event.position
			accept_event()
		else:
			_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
			_update_drag_position()
			accept_event()


func _process(_delta: float) -> void:
	if _dragging:
		_update_drag_position()


func _update_drag_position() -> void:
	var parent_control := get_parent() as Control
	if parent_control == null:
		return
	var target := parent_control.get_local_mouse_position() - _drag_offset
	target.x = clampf(target.x, 0.0, maxf(0.0, parent_control.size.x - size.x))
	target.y = clampf(target.y, 0.0, maxf(0.0, parent_control.size.y - size.y))
	position = target


func _on_close_pressed() -> void:
	removed.emit()
	queue_free()


func _build_panel_style(accent: Color) -> StyleBoxFlat:
	var style := LabTheme.box(Color("#0F1A25"), accent, 1, 16, 14, 12)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 10
	return style
