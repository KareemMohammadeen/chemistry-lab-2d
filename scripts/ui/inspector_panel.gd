class_name InspectorPanel
extends PanelContainer
## Shows the information ObjectInspector prepares for the selected object and offers its
## actions (Pour, Mix, Heat, amount, hot plate setpoint). It contains no chemistry: it
## displays a dictionary and sends action requests upward.

## The action ids sent in action_requested; the InteractionController decides what they mean.
signal action_requested(action_id: StringName, payload: Dictionary)

const REFRESH_INTERVAL_S := 0.2
const SAFETY_FILL := Color("#2A2412")
const SAFETY_BORDER := Color("#6B5418")
const ACTION_MIN_WIDTH_PX := 84.0
const FONT_SIZE_BODY := 16
const FONT_SIZE_SMALL := 14
const HEATER_STEP_C := 5.0
const FADE_IN_S := 0.18
const SPIN_MIN_WIDTH_PX := 130.0

@export var empty_state: Control
@export var content_root: Control
@export var title_label: Label
@export var material_label: Label
@export var summary_label: Label
@export var rows_box: VBoxContainer
@export var contents_box: VBoxContainer
@export var observations_box: VBoxContainer
@export var safety_box: VBoxContainer
@export var actions_box: Container
@export var amount_row: HBoxContainer
@export var amount_label: Label
@export var amount_spin: SpinBox
@export var heater_row: HBoxContainer
@export var heater_button: Button
@export var heater_spin: SpinBox
@export var controls_card: Control
@export var observations_card: Control
@export var safety_card: Control

var _host: SimulationHost
var _object_id: String = ""
var _refresh_left_s: float = 0.0
var _actions_signature: String = ""
var _amount_signature: String = ""
var _heater_signature: String = ""
var _heater_power_on: bool = false
var _amount_unit: String = "mL"
var _fade: Tween


func _ready() -> void:
	safety_card.add_theme_stylebox_override("panel", LabTheme.box(SAFETY_FILL, SAFETY_BORDER, 1, LabTheme.RADIUS, 12, 10))
	amount_spin.custom_minimum_size.x = SPIN_MIN_WIDTH_PX
	heater_spin.custom_minimum_size.x = SPIN_MIN_WIDTH_PX
	amount_spin.value_changed.connect(_on_amount_changed)
	heater_button.pressed.connect(_on_heater_button_pressed)
	heater_button.focus_mode = Control.FOCUS_NONE
	heater_spin.value_changed.connect(_on_heater_setpoint_changed)
	_refresh()


func bind(host: SimulationHost) -> void:
	_host = host
	EventBus.object_selected.connect(_on_object_selected)
	EventBus.command_logged.connect(_on_command_logged)
	_refresh()


func _process(delta: float) -> void:
	_refresh_left_s -= delta
	if _refresh_left_s <= 0.0:
		_refresh_left_s = REFRESH_INTERVAL_S
		_refresh()


func _on_object_selected(object_id: String) -> void:
	_object_id = object_id
	_refresh()
	if object_id != "":
		_fade_in()


func _fade_in() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	content_root.modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(content_root, "modulate:a", 1.0, FADE_IN_S)


func _on_command_logged(_entry: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	if _host == null or _host.simulation == null:
		_show_empty()
		return
	var data: Dictionary = {}
	if _object_id != "":
		data = ObjectInspector.inspect(_host.simulation, _object_id)
	if data.is_empty():
		_show_empty()
		return
	empty_state.visible = false
	content_root.visible = true
	title_label.text = str(data["title"])
	material_label.text = "Material: %s" % str(data["material"])
	summary_label.text = str(data["summary"])
	summary_label.visible = summary_label.text != ""
	_fill_rows(data["rows"])
	_fill_contents(data["contents"])
	_fill_observations(data["observations"])
	_fill_safety(data["safety"])
	_update_actions(data["actions"])
	_update_amount(data["amount"])
	_update_heater(data["heater"])
	controls_card.visible = actions_box.visible or amount_row.visible or heater_row.visible


func _show_empty() -> void:
	empty_state.visible = true
	content_root.visible = false
	title_label.text = "Nothing selected"
	material_label.text = ""


# ---------------------------------------------------------------- read-only sections

func _fill_rows(rows: Array) -> void:
	_clear(rows_box)
	for entry in rows:
		var row := HBoxContainer.new()
		var name_label := _make_label(str(entry["label"]), FONT_SIZE_BODY, LabColors.TEXT_SECONDARY)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value_label := _make_label(str(entry["value"]), FONT_SIZE_BODY, LabColors.TEXT_PRIMARY)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		value_label.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(name_label)
		row.add_child(value_label)
		rows_box.add_child(row)


func _fill_contents(contents: Array) -> void:
	_clear(contents_box)
	_add_heading(contents_box, "CONTENTS")
	if contents.is_empty():
		contents_box.add_child(_make_label("Nothing inside.", FONT_SIZE_BODY, LabColors.TEXT_SECONDARY))
		return
	for entry in contents:
		var row := HBoxContainer.new()
		var name_label := _make_label(str(entry["name"]), FONT_SIZE_BODY, LabColors.TEXT_PRIMARY)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var amount_text := _make_label(str(entry["amount"]), FONT_SIZE_BODY, LabColors.TEXT_PRIMARY)
		amount_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount_text.autowrap_mode = TextServer.AUTOWRAP_OFF
		amount_text.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(name_label)
		row.add_child(amount_text)
		contents_box.add_child(row)
		if str(entry["detail"]) != "":
			contents_box.add_child(_make_label(str(entry["detail"]), FONT_SIZE_SMALL, LabColors.TEXT_SECONDARY))


func _fill_observations(observations: Array) -> void:
	_clear(observations_box)
	observations_card.visible = not observations.is_empty()
	if observations.is_empty():
		return
	_add_heading(observations_box, "WHAT HAPPENED")
	for entry in observations:
		observations_box.add_child(_make_label(str(entry["time_text"]), FONT_SIZE_SMALL, LabColors.TEXT_MUTED))
		observations_box.add_child(_make_label(str(entry["text"]), FONT_SIZE_BODY, LabColors.TEXT_PRIMARY))
		if str(entry["explanation"]) != "":
			observations_box.add_child(_make_label(str(entry["explanation"]), FONT_SIZE_SMALL, LabColors.TEXT_SECONDARY))


func _fill_safety(lines: Array) -> void:
	_clear(safety_box)
	safety_card.visible = not lines.is_empty()
	if lines.is_empty():
		return
	_add_heading(safety_box, "SAFETY", LabColors.WARNING)
	for line in lines:
		safety_box.add_child(_make_label(str(line), FONT_SIZE_SMALL, LabColors.TEXT_PRIMARY))


# ---------------------------------------------------------------- controls (kept between refreshes)

func _update_actions(actions: Array) -> void:
	var signature := ""
	for entry in actions:
		signature += "%s:%s;" % [str(entry["id"]), str(entry["label"])]
	actions_box.visible = not actions.is_empty()
	if signature == _actions_signature:
		return
	_actions_signature = signature
	_clear(actions_box)
	for entry in actions:
		var action_id := StringName(str(entry["id"]))
		var button := Button.new()
		button.text = str(entry["label"])
		button.tooltip_text = str(entry["hint"])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: action_requested.emit(action_id, {}))
		actions_box.add_child(button)


func _update_amount(amount: Dictionary) -> void:
	amount_row.visible = bool(amount.get("visible", false))
	if not amount_row.visible:
		_amount_signature = ""
		return
	var signature := "%s:%s" % [_object_id, str(amount["unit"])]
	if signature == _amount_signature:
		return
	_amount_signature = signature
	_amount_unit = str(amount["unit"])
	amount_label.text = "Amount to add" if _amount_unit == "g" else "Amount to pour"
	amount_spin.min_value = float(amount["min"])
	amount_spin.max_value = float(amount["max"])
	amount_spin.step = float(amount["step"])
	amount_spin.suffix = " %s" % _amount_unit
	amount_spin.set_value_no_signal(float(amount["value"]))
	# Keep the controller in step with what the panel shows after selection changes.
	action_requested.emit(&"amount_changed", {"unit": _amount_unit, "value": float(amount["value"])})


func _update_heater(heater: Dictionary) -> void:
	heater_row.visible = bool(heater.get("available", false))
	if not heater_row.visible:
		_heater_signature = ""
		return
	_heater_power_on = bool(heater["power_on"])
	heater_button.text = "Switch off" if _heater_power_on else "Switch on"
	var signature := _object_id
	if signature == _heater_signature:
		return
	_heater_signature = signature
	heater_spin.min_value = float(heater["min_c"])
	heater_spin.max_value = float(heater["max_c"])
	heater_spin.step = HEATER_STEP_C
	heater_spin.suffix = " °C"
	heater_spin.set_value_no_signal(float(heater["target_c"]))


func _on_amount_changed(value: float) -> void:
	action_requested.emit(&"amount_changed", {"unit": _amount_unit, "value": value})


func _on_heater_button_pressed() -> void:
	action_requested.emit(&"heat", {})


func _on_heater_setpoint_changed(value: float) -> void:
	action_requested.emit(&"set_heater", {"target_c": value, "power": "on" if _heater_power_on else "off"})


# ---------------------------------------------------------------- helpers

func _clear(box: Container) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _add_heading(box: Container, text: String, color: Color = LabColors.ACCENT) -> void:
	var heading := Label.new()
	heading.text = text
	heading.theme_type_variation = &"HeadingLabel"
	heading.add_theme_color_override("font_color", color)
	box.add_child(heading)
