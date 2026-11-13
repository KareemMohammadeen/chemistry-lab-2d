class_name LabInterface
extends Control
## Presentation layer for the chemistry workbench. The scene is organised as a compact studio:
## command header, materials dock, central live bench, and contextual inspector.

signal undo_requested
signal redo_requested
signal reset_requested
signal pause_toggled(paused: bool)
signal speed_selected(speed: float)
signal action_requested(action_id: StringName, payload: Dictionary)
signal object_focus_requested(object_id: String)
signal reference_pin_requested(reference: Dictionary)

const TOAST_SECONDS := 4.0
const TOAST_FADE_SECONDS := 0.6
const TOAST_RADIUS := 12
const TOAST_PADDING_PX := 14
const FALLBACK_SPEEDS: Array = [1.0]
const ICON_PATH := "res://assets/icons/%s.svg"
const LIBRARY_WIDTH_FRACTION := 0.18
const LIBRARY_WIDTH_MIN := 268.0
const LIBRARY_WIDTH_MAX := 330.0
const INSPECTOR_WIDTH_FRACTION := 0.20
const INSPECTOR_WIDTH_MIN := 300.0
const INSPECTOR_WIDTH_MAX := 370.0
const LIBRARY_OPEN_MIN_WIDTH := 1120.0
const SPEED_BUTTON_WIDTH := 48.0
const SPECIMEN_MARGIN := 18.0
const SPECIMEN_CELL := Vector2(252.0, 110.0)

@export var top_bar: Control
@export var title_label: Label
@export var time_label: Label
@export var undo_button: Button
@export var redo_button: Button
@export var reset_button: Button
@export var pause_button: Button
@export var speed_box: HBoxContainer
@export var library_toggle: Button
@export var grade_selector: OptionButton
@export var logo: TextureRect
@export var library: LibraryPanel
@export var inspector: InspectorPanel
@export var stage_slot: Control
@export var toast_label: Label
@export var hint_label: Label

var _host: SimulationHost
var _toast_left_s: float = 0.0
var _info_style: StyleBoxFlat
var _warning_style: StyleBoxFlat
var _pause_icon: Texture2D
var _play_icon: Texture2D
var _library_user_choice: bool = false
var _curriculum_catalog: CurriculumCatalog
var _selected_curriculum_profile: Dictionary = {}
var _teacher_guide_button: Button
var _reference_pin_count: int = 0
var _specimen_count: int = 0


func _ready() -> void:
	theme = LabTheme.build()
	_pause_icon = _load_icon("pause")
	_play_icon = _load_icon("play")
	undo_button.icon = _load_icon("undo")
	redo_button.icon = _load_icon("redo")
	reset_button.icon = _load_icon("reset")
	pause_button.icon = _pause_icon
	library_toggle.icon = _load_icon("library")
	logo.texture = _load_icon("logo")
	_info_style = _make_toast_style(LabColors.PANEL_RAISED, LabColors.PANEL_BORDER_STRONG)
	_warning_style = _make_toast_style(Color("#3A2D12"), LabColors.WARNING)
	toast_label.visible = false
	hint_label.text = "Drag an element from the periodic table into this workbench. Tokens are visual learning aids, not reactive reagents."
	hint_label.visible = true
	undo_button.pressed.connect(undo_requested.emit)
	redo_button.pressed.connect(redo_requested.emit)
	reset_button.pressed.connect(reset_requested.emit)
	pause_button.toggled.connect(pause_toggled.emit)
	inspector.action_requested.connect(action_requested.emit)
	library.object_focus_requested.connect(object_focus_requested.emit)
	EventBus.reference_pin_requested.connect(_on_reference_pin_requested)
	library_toggle.toggled.connect(_on_library_toggled)
	grade_selector.item_selected.connect(_on_grade_selected)
	resized.connect(_apply_responsive_layout)
	for button in [undo_button, redo_button, reset_button, pause_button, library_toggle]:
		(button as Button).focus_mode = Control.FOCUS_NONE
	grade_selector.focus_mode = Control.FOCUS_NONE
	_add_teacher_guide_button()
	if stage_slot is LabDropZone:
		(stage_slot as LabDropZone).element_dropped.connect(_on_periodic_element_dropped)
	_apply_responsive_layout()


func bind(host: SimulationHost) -> void:
	_host = host
	title_label.text = "WORKBENCH  /  CHEMISTRY LAB"
	inspector.bind(host)
	library.bind(host)
	_curriculum_catalog = CurriculumCatalog.new()
	_curriculum_catalog.load_profiles()
	for message in _curriculum_catalog.errors:
		push_error("Curriculum: %s" % message)
	_populate_grade_selector()
	_build_speed_buttons(host.database.constants.get("speeds", FALLBACK_SPEEDS))
	EventBus.feedback_message_requested.connect(_show_toast)
	EventBus.observation_added.connect(_on_observation_added)


## Screen-space panels that should reject placement from the simulation pointer controller.
func get_blocking_rects() -> Array:
	var rects: Array = [top_bar.get_global_rect(), inspector.get_global_rect()]
	if library.visible:
		rects.append(library.get_global_rect())
	return rects


## Screen-space region occupied by the visible laboratory stage.
func get_stage_rect() -> Rect2:
	return stage_slot.get_global_rect()


func _process(delta: float) -> void:
	if _host == null or _host.simulation == null:
		return
	undo_button.disabled = not _host.commands.can_undo()
	redo_button.disabled = not _host.commands.can_redo()
	pause_button.set_pressed_no_signal(_host.clock.paused)
	pause_button.icon = _play_icon if _host.clock.paused else _pause_icon
	pause_button.text = "Resume" if _host.clock.paused else "Pause"
	var time_text := UnitFormat.time_mmss(_host.simulation.state.time_s)
	if _host.clock.paused:
		time_text += "  ·  PAUSED"
	time_label.text = time_text
	if _toast_left_s > 0.0:
		_toast_left_s -= delta
		toast_label.modulate.a = clampf(_toast_left_s / TOAST_FADE_SECONDS, 0.0, 1.0)
		if _toast_left_s <= 0.0:
			toast_label.visible = false


func _apply_responsive_layout() -> void:
	var width := size.x
	if width <= 0.0:
		return
	library.custom_minimum_size.x = clampf(width * LIBRARY_WIDTH_FRACTION, LIBRARY_WIDTH_MIN, LIBRARY_WIDTH_MAX)
	inspector.custom_minimum_size.x = clampf(width * INSPECTOR_WIDTH_FRACTION, INSPECTOR_WIDTH_MIN, INSPECTOR_WIDTH_MAX)
	if not _library_user_choice:
		var open := width >= LIBRARY_OPEN_MIN_WIDTH
		library.visible = open
		library_toggle.set_pressed_no_signal(open)


func _on_library_toggled(pressed: bool) -> void:
	_library_user_choice = true
	library.visible = pressed


func _build_speed_buttons(speeds: Array) -> void:
	var group := ButtonGroup.new()
	for entry in speeds:
		var speed := float(entry)
		var button := Button.new()
		button.text = "%gx" % speed
		button.theme_type_variation = &"ToolButton"
		button.custom_minimum_size = Vector2(SPEED_BUTTON_WIDTH, 38.0)
		button.tooltip_text = "Run the simulation at %gx speed" % speed
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.button_pressed = is_equal_approx(speed, _host.clock.speed)
		button.pressed.connect(func() -> void: speed_selected.emit(speed))
		speed_box.add_child(button)


func _on_periodic_element_dropped(element_data: Dictionary, drop_position: Vector2) -> void:
	var symbol := str(element_data.get("symbol", ""))
	if symbol.is_empty():
		return
	var specimen := ElementSpecimen.new()
	specimen.setup(element_data)
	specimen.position = drop_position - SPECIMEN_CELL * 0.5
	var maximum := Vector2(maxf(stage_slot.size.x - SPECIMEN_CELL.x, 0.0), maxf(stage_slot.size.y - SPECIMEN_CELL.y, 0.0))
	specimen.position = specimen.position.clamp(Vector2(SPECIMEN_MARGIN, SPECIMEN_MARGIN), Vector2(
		maxf(SPECIMEN_MARGIN, maximum.x - SPECIMEN_MARGIN), maxf(SPECIMEN_MARGIN, maximum.y - SPECIMEN_MARGIN)))
	specimen.z_index = 10
	stage_slot.add_child(specimen)
	_specimen_count += 1
	var label := "visual sample token" if bool(element_data.get("display_only_sample", false)) else "reference-only token"
	_show_toast("%s added to the workbench as a %s. It cannot be mixed or reacted." % [str(element_data.get("name", symbol)), label], &"info")


func _on_observation_added(_object_id: String, entry: Dictionary) -> void:
	_show_toast(str(entry.get("text", "")), &"info")


func _show_toast(message: String, severity: StringName) -> void:
	toast_label.text = message
	toast_label.add_theme_stylebox_override("normal", _warning_style if severity == &"warning" else _info_style)
	toast_label.add_theme_color_override("font_color",
		LabColors.WARNING if severity == &"warning" else LabColors.TEXT_PRIMARY)
	toast_label.modulate.a = 1.0
	toast_label.visible = true
	_toast_left_s = TOAST_SECONDS


func _make_toast_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := LabTheme.box(fill, border, 1, TOAST_RADIUS, TOAST_PADDING_PX, TOAST_PADDING_PX)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	style.shadow_size = 10
	return style


func _load_icon(icon_name: String) -> Texture2D:
	var path := ICON_PATH % icon_name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _populate_grade_selector() -> void:
	grade_selector.clear()
	if _curriculum_catalog == null:
		return
	var selected_index := -1
	for profile in _curriculum_catalog.profiles:
		var entry: Dictionary = profile
		grade_selector.add_item(str(entry.get("label", entry.get("id", "Grade"))))
		var index := grade_selector.item_count - 1
		grade_selector.set_item_metadata(index, str(entry.get("id", "")))
		if str(entry.get("id", "")) == "prep1":
			selected_index = index
	if selected_index >= 0:
		grade_selector.select(selected_index)
		_on_grade_selected(selected_index)


func _on_grade_selected(index: int) -> void:
	if _curriculum_catalog == null or index < 0 or index >= grade_selector.item_count:
		return
	var profile_id := str(grade_selector.get_item_metadata(index))
	var profile := _curriculum_catalog.get_profile(profile_id)
	if profile.is_empty():
		return
	_selected_curriculum_profile = profile.duplicate(true)
	library.set_curriculum_profile(profile)
	_show_toast("%s selected — %s" % [str(profile.get("label", "")), str(profile.get("subject", ""))], &"info")


func _add_teacher_guide_button() -> void:
	var grade_chip := grade_selector.get_parent().get_parent()
	var top_row := grade_chip.get_parent()
	var teacher_button := Button.new()
	teacher_button.text = "Teacher Guide"
	teacher_button.tooltip_text = "Open grade previews, learning explanations and trusted sources."
	teacher_button.theme_type_variation = &"ToolButton"
	teacher_button.custom_minimum_size = Vector2(118.0, 38.0)
	teacher_button.focus_mode = Control.FOCUS_NONE
	teacher_button.pressed.connect(_open_teacher_guide)
	top_row.add_child(teacher_button)
	top_row.move_child(teacher_button, grade_chip.get_index() + 1)


func _open_teacher_guide() -> void:
	if library != null:
		library.open_learning_guide(_selected_curriculum_profile)


func open_teacher_mode() -> void:
	_library_user_choice = true
	library.visible = true
	library_toggle.set_pressed_no_signal(true)
	var caption := grade_selector.get_parent().get_node_or_null("GradeCaption") as Label
	if caption != null:
		caption.text = "TEACHER MODE"
	_open_teacher_guide()


func _on_reference_pin_requested(reference: Dictionary) -> void:
	if reference.is_empty():
		return
	var badge := ReferenceBadge.new()
	badge.setup(reference)
	var columns := maxi(1, int(floor((stage_slot.size.x - 28.0) / 300.0)))
	var index := _reference_pin_count
	badge.position = Vector2(18.0 + float(index % columns) * 300.0, 18.0 + float(index / columns) * 148.0)
	badge.removed.connect(_on_reference_badge_removed)
	stage_slot.add_child(badge)
	_reference_pin_count += 1


func _on_reference_badge_removed() -> void:
	_reference_pin_count = maxi(0, _reference_pin_count - 1)
