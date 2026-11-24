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
signal save_session_requested(path: String)
signal load_session_requested(path: String)
signal sound_enabled_changed(enabled: bool)
signal library_item_dropped(payload: Dictionary, screen_position: Vector2)
signal periodic_sample_dropped(payload: Dictionary, screen_position: Vector2)
signal canvas_zoom_requested(factor: float)
signal canvas_reset_requested

const TOAST_SECONDS := 4.0
const TOAST_FADE_SECONDS := 0.6
const TOAST_RADIUS := 12
const TOAST_PADDING_PX := 14
const FALLBACK_SPEEDS: Array = [1.0]
## Stage overlays (toast, hint, pinned references) must stay above the workspace's equipment, whose
## z values run up to about 2000 inside the stage slot; the welcome overlay covers everything.
const STAGE_OVERLAY_Z := 3500
## Top bar density: the bar sheds optional content one level at a time until it fits the window,
## so it never overflows on small desktop windows and shows everything on large ones.
const TOPBAR_MARGIN_PX := 36.0
const TOPBAR_MAX_LEVEL := 4
const TOPBAR_COMPACT_BUTTON_PX := 44.0
const STAGE_MAX_LEVEL := 3
const ICON_PATH := "res://assets/icons/%s.svg"
const LIBRARY_WIDTH_FRACTION := 0.18
const LIBRARY_WIDTH_MIN := 268.0
const LIBRARY_WIDTH_MAX := 330.0
const INSPECTOR_WIDTH_FRACTION := 0.20
const INSPECTOR_WIDTH_MIN := 300.0
const INSPECTOR_WIDTH_MAX := 370.0
const LIBRARY_OPEN_MIN_WIDTH := 1120.0
const SPEED_BUTTON_WIDTH := 44.0
const SPECIMEN_MARGIN := 18.0
const SPECIMEN_CELL := Vector2(342.0, 154.0)
const MENU_SAVE := 10
const MENU_OPEN := 11
const MENU_LOG := 12
const MENU_SOUND := 13

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
var _speed_buttons: Dictionary = {}
var _toast_left_s: float = 0.0
var _info_style: StyleBoxFlat
var _warning_style: StyleBoxFlat
var _pause_icon: Texture2D
var _play_icon: Texture2D
var _library_user_choice: bool = false
var _curriculum_catalog: CurriculumCatalog
var _selected_curriculum_profile: Dictionary = {}
var _teacher_guide_button: Button
var _topbar_original: Dictionary = {}
var _reference_pin_count: int = 0
var _specimen_count: int = 0
var _session_menu: MenuButton
var _save_dialog: FileDialog
var _open_dialog: FileDialog
var _log_window: Window
var _log_text: RichTextLabel
var _sound_enabled: bool = true
var _zoom_label: Label


func _ready() -> void:
	theme = LabTheme.build()
	_pause_icon = _load_icon("pause")
	_play_icon = _load_icon("play")
	undo_button.icon = _load_icon("undo")
	redo_button.icon = _load_icon("redo")
	reset_button.icon = _load_icon("reset")
	pause_button.icon = _pause_icon
	library_toggle.icon = _load_icon("library")
	library_toggle.tooltip_text = "Show or hide the Library (L)"
	logo.texture = _load_icon("logo")
	_info_style = _make_toast_style(LabColors.PANEL_RAISED, LabColors.PANEL_BORDER_STRONG)
	_warning_style = _make_toast_style(Color("#3A2D12"), LabColors.WARNING)
	toast_label.visible = false
	toast_label.z_index = STAGE_OVERLAY_Z
	(hint_label.get_parent() as Control).z_index = STAGE_OVERLAY_Z
	hint_label.text = "Drag items from the Library onto the bench; drop a reagent on a vessel to add it.  Drag empty bench or middle-drag to pan · wheel to zoom · Home to centre · [ ] speed · L library"
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
		(stage_slot as LabDropZone).library_item_dropped.connect(_on_library_item_dropped_from_stage)
	_build_session_menu()
	_build_session_dialogs()
	_build_experiment_log_window()
	_build_canvas_controls()
	_apply_responsive_layout()


func bind(host: SimulationHost) -> void:
	_host = host
	title_label.text = "WORKBENCH"
	inspector.bind(host)
	library.bind(host)
	_curriculum_catalog = CurriculumCatalog.new()
	_curriculum_catalog.load_profiles()
	for message in _curriculum_catalog.errors:
		push_error("Curriculum: %s" % message)
	_populate_grade_selector()
	_build_speed_buttons(host.database.constants.get("speeds", FALLBACK_SPEEDS))
	_apply_topbar_density()
	EventBus.feedback_message_requested.connect(_show_toast)
	EventBus.observation_added.connect(_on_observation_added)
	EventBus.command_logged.connect(_on_command_logged)


## Desktop shortcuts for the interface itself (data/input/default_bindings.json).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.TOGGLE_LIBRARY):
		library_toggle.button_pressed = not library_toggle.button_pressed
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(InputActions.SAVE_SESSION):
		_on_session_menu_id_pressed(MENU_SAVE)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(InputActions.OPEN_SESSION):
		_on_session_menu_id_pressed(MENU_OPEN)
		get_viewport().set_input_as_handled()


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
	for speed_button in _speed_buttons:
		(speed_button as Button).set_pressed_no_signal(is_equal_approx(float(_speed_buttons[speed_button]), _host.clock.speed))
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
	_apply_topbar_density()
	call_deferred("_apply_stage_density")
	library.custom_minimum_size.x = clampf(width * LIBRARY_WIDTH_FRACTION, LIBRARY_WIDTH_MIN, LIBRARY_WIDTH_MAX)
	inspector.custom_minimum_size.x = clampf(width * INSPECTOR_WIDTH_FRACTION, INSPECTOR_WIDTH_MIN, INSPECTOR_WIDTH_MAX)
	if not _library_user_choice:
		var open := width >= LIBRARY_OPEN_MIN_WIDTH
		library.visible = open
		library_toggle.set_pressed_no_signal(open)


## Sheds optional top-bar content, level by level, until the bar fits the window width.
func _apply_topbar_density() -> void:
	if top_bar == null or reset_button == null or size.x <= 0.0:
		return
	var row := reset_button.get_parent() as HBoxContainer
	var available := size.x - TOPBAR_MARGIN_PX
	for level in range(TOPBAR_MAX_LEVEL + 1):
		_set_topbar_level(level)
		if row.get_combined_minimum_size().x <= available:
			return


## The stage header (title, zoom controls, drop hint) and the side panels shed content until the
## whole interface fits the window width, so small desktop windows never push it off screen.
func _apply_stage_density() -> void:
	if stage_slot == null or size.x <= 0.0:
		return
	var root := get_node_or_null("Root") as Control
	var header_row := stage_slot.get_parent().get_node_or_null("StageHeader/StageHeaderRow")
	if root == null or header_row == null:
		return
	for level in range(STAGE_MAX_LEVEL + 1):
		var drop_chip := header_row.get_node_or_null("DropChip") as Control
		var title_box := header_row.get_node_or_null("StageTitleBox") as Control
		if drop_chip != null:
			drop_chip.visible = level < 1
		if title_box != null:
			title_box.visible = level < 2
		if level >= 3 and library != null and library.visible:
			library.visible = false
			library_toggle.set_pressed_no_signal(false)
		if root.get_combined_minimum_size().x <= size.x + 0.5:
			return


func _set_topbar_level(level: int) -> void:
	var brand_title_box := title_label.get_parent() as Control
	var app_label := brand_title_box.get_node_or_null("AppLabel") as Control
	if app_label != null:
		app_label.visible = level < 1
	if not _topbar_original.has(title_label):
		_topbar_original[title_label] = title_label.custom_minimum_size.x
	title_label.custom_minimum_size.x = float(_topbar_original[title_label]) if level < 1 else 110.0
	var compact := level >= 2
	for button in [library_toggle, undo_button, redo_button, reset_button]:
		_set_button_compact(button as Button, compact)
	if _teacher_guide_button != null:
		if not _topbar_original.has(_teacher_guide_button):
			_topbar_original[_teacher_guide_button] = [_teacher_guide_button.text, _teacher_guide_button.custom_minimum_size.x]
		var saved: Array = _topbar_original[_teacher_guide_button]
		_teacher_guide_button.text = "Guide" if compact else str(saved[0])
		_teacher_guide_button.custom_minimum_size.x = 70.0 if compact else float(saved[1])
	var grade_chip := grade_selector.get_parent().get_parent() as Control
	grade_chip.visible = level < 3
	brand_title_box.visible = level < 3
	var brand := brand_title_box.get_parent() as Control
	brand.visible = level < 4


## Icon-only when compact (the tooltips keep the names), original text and width otherwise.
func _set_button_compact(button: Button, compact: bool) -> void:
	if not _topbar_original.has(button):
		_topbar_original[button] = [button.text, button.custom_minimum_size.x]
	var saved: Array = _topbar_original[button]
	button.text = "" if compact else str(saved[0])
	button.custom_minimum_size.x = TOPBAR_COMPACT_BUTTON_PX if compact else float(saved[1])


func _on_library_toggled(pressed: bool) -> void:
	_library_user_choice = true
	library.visible = pressed


func _build_speed_buttons(speeds: Array) -> void:
	_speed_buttons.clear()
	var group := ButtonGroup.new()
	for entry in speeds:
		var speed := float(entry)
		var button := Button.new()
		button.text = UnitFormat.speed(speed)
		button.theme_type_variation = &"ToolButton"
		button.custom_minimum_size = Vector2(SPEED_BUTTON_WIDTH, 38.0)
		button.tooltip_text = "Run the simulation at %s speed" % UnitFormat.speed(speed)
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.button_pressed = is_equal_approx(speed, _host.clock.speed)
		button.pressed.connect(func() -> void: speed_selected.emit(speed))
		speed_box.add_child(button)
		_speed_buttons[button] = speed


func _on_periodic_element_dropped(element_data: Dictionary, drop_position: Vector2) -> void:
	var symbol := str(element_data.get("symbol", ""))
	if symbol.is_empty():
		return
	var screen_position := stage_slot.get_global_transform_with_canvas() * drop_position
	periodic_sample_dropped.emit(element_data.duplicate(true), screen_position)
	var profile := ElementVisual.profile_for(element_data)
	_show_toast("%s sample added to the workbench. This is a visual reference, not a reactive reagent." % str(element_data.get("name", symbol)), &"info")



func _on_library_item_dropped_from_stage(payload: Dictionary, local_position: Vector2) -> void:
	var screen_position := stage_slot.get_global_transform_with_canvas() * local_position
	library_item_dropped.emit(payload, screen_position)


func _build_canvas_controls() -> void:
	var stage_column := stage_slot.get_parent() as VBoxContainer
	var header_row := stage_column.get_node("StageHeader/StageHeaderRow") as HBoxContainer
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 3)
	controls.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var minus := Button.new()
	minus.text = "−"
	minus.tooltip_text = "Zoom out"
	minus.custom_minimum_size = Vector2(34.0, 34.0)
	minus.theme_type_variation = &"ToolButton"
	minus.focus_mode = Control.FOCUS_NONE
	minus.pressed.connect(func() -> void: canvas_zoom_requested.emit(1.0 / 1.2))
	controls.add_child(minus)

	_zoom_label = Label.new()
	_zoom_label.text = "100%"
	_zoom_label.custom_minimum_size = Vector2(48.0, 0.0)
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_zoom_label.theme_type_variation = &"StrongLabel"
	controls.add_child(_zoom_label)

	var plus := Button.new()
	plus.text = "+"
	plus.tooltip_text = "Zoom in"
	plus.custom_minimum_size = Vector2(34.0, 34.0)
	plus.theme_type_variation = &"ToolButton"
	plus.focus_mode = Control.FOCUS_NONE
	plus.pressed.connect(func() -> void: canvas_zoom_requested.emit(1.2))
	controls.add_child(plus)

	var centre := Button.new()
	centre.text = "Center"
	centre.tooltip_text = "Return to the starting workbench view (Home)"
	centre.custom_minimum_size = Vector2(68.0, 34.0)
	centre.theme_type_variation = &"ToolButton"
	centre.focus_mode = Control.FOCUS_NONE
	centre.pressed.connect(func() -> void: canvas_reset_requested.emit())
	controls.add_child(centre)

	var drop_chip := header_row.get_node("DropChip")
	header_row.add_child(controls)
	header_row.move_child(controls, drop_chip.get_index())
	var eyebrow := stage_column.get_node("StageHeader/StageHeaderRow/StageTitleBox/StageEyebrow") as Label
	eyebrow.text = "INFINITE WORKBENCH"
	var drop_label := drop_chip.get_node("DropLabel") as Label
	drop_label.text = "DRAG FROM LIBRARY"


func update_zoom_label(percent: int) -> void:
	if _zoom_label != null:
		_zoom_label.text = "%d%%" % percent


# ---------------------------------------------------------------- session tools

func _build_session_menu() -> void:
	_session_menu = MenuButton.new()
	_session_menu.text = "Session"
	_session_menu.tooltip_text = "Save, open and review a laboratory session."
	_session_menu.theme_type_variation = &"ToolButton"
	_session_menu.custom_minimum_size = Vector2(88.0, 40.0)
	_session_menu.focus_mode = Control.FOCUS_NONE
	var popup := _session_menu.get_popup()
	popup.add_item("Save experiment…   Ctrl+S", MENU_SAVE)
	popup.add_item("Open experiment…   Ctrl+O", MENU_OPEN)
	popup.add_item("Experiment log", MENU_LOG)
	popup.add_separator()
	popup.add_check_item("Sound effects", MENU_SOUND)
	popup.set_item_checked(popup.get_item_index(MENU_SOUND), _sound_enabled)
	popup.id_pressed.connect(_on_session_menu_id_pressed)
	var row := reset_button.get_parent() as HBoxContainer
	row.add_child(_session_menu)
	row.move_child(_session_menu, reset_button.get_index() + 1)


func _build_session_dialogs() -> void:
	_save_dialog = FileDialog.new()
	_save_dialog.title = "Save Chemistry Lab Session"
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_save_dialog.filters = PackedStringArray(["*.json ; Chemistry Lab Session"])
	_save_dialog.current_file = "chemistry_lab_session.json"
	_save_dialog.file_selected.connect(func(path: String) -> void:
		save_session_requested.emit(path))
	add_child(_save_dialog)

	_open_dialog = FileDialog.new()
	_open_dialog.title = "Open Chemistry Lab Session"
	_open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_open_dialog.filters = PackedStringArray(["*.json ; Chemistry Lab Session"])
	_open_dialog.file_selected.connect(func(path: String) -> void:
		load_session_requested.emit(path))
	add_child(_open_dialog)


func _build_experiment_log_window() -> void:
	_log_window = Window.new()
	_log_window.title = "Experiment Log"
	_log_window.visible = false
	_log_window.size = Vector2i(820, 620)
	_log_window.min_size = Vector2i(540, 380)
	_log_window.close_requested.connect(_on_log_window_close_requested)
	add_child(_log_window)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	_log_window.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(column)

	var subtitle := Label.new()
	subtitle.text = "A chronological record of accepted actions, refused actions and visible observations."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", LabColors.TEXT_SECONDARY)
	column.add_child(subtitle)

	_log_text = RichTextLabel.new()
	_log_text.bbcode_enabled = false
	_log_text.fit_content = false
	_log_text.scroll_active = true
	_log_text.selection_enabled = true
	_log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_text.add_theme_font_size_override("normal_font_size", 15)
	_log_text.add_theme_color_override("default_color", LabColors.TEXT_PRIMARY)
	column.add_child(_log_text)


func _on_session_menu_id_pressed(item_id: int) -> void:
	match item_id:
		MENU_SAVE:
			_save_dialog.popup_centered(Vector2i(900, 620))
		MENU_OPEN:
			_open_dialog.popup_centered(Vector2i(900, 620))
		MENU_LOG:
			_refresh_experiment_log()
			_log_window.popup_centered(Vector2i(820, 620))
		MENU_SOUND:
			_sound_enabled = not _sound_enabled
			var popup := _session_menu.get_popup()
			popup.set_item_checked(popup.get_item_index(MENU_SOUND), _sound_enabled)
			sound_enabled_changed.emit(_sound_enabled)


func _on_log_window_close_requested() -> void:
	_log_window.hide()


func _on_command_logged(_entry: Dictionary) -> void:
	if _log_window != null and _log_window.visible:
		_refresh_experiment_log()


func _refresh_experiment_log() -> void:
	if _log_text == null:
		return
	if _host == null or _host.simulation == null:
		_log_text.text = "The laboratory is not ready."
		return

	var lines := PackedStringArray()
	lines.append("ACTIONS")
	lines.append("-------")
	var history: Array = _host.commands.history
	if history.is_empty():
		lines.append("No actions have been recorded yet.")
	else:
		for entry in history:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var successful := bool(entry.get("ok", false))
			var detail := str(entry.get("description", ""))
			if not successful:
				detail = "Not completed: %s" % str(entry.get("reason", "Action refused."))
			lines.append("%s   %s   %s" % [
				UnitFormat.time_mmss(float(entry.get("sim_time_s", 0.0))),
				"OK" if successful else "BLOCKED",
				detail])

	var observations: Array = []
	for object_id in _host.simulation.state.objects.keys():
		var item := _host.simulation.state.get_object(str(object_id))
		if item == null or item.vessel == null:
			continue
		for observation in item.vessel.observations:
			if typeof(observation) != TYPE_DICTIONARY:
				continue
			var copy: Dictionary = (observation as Dictionary).duplicate(true)
			copy["object_label"] = _host.simulation.object_label(item)
			observations.append(copy)
	observations.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("time_s", 0.0)) < float(b.get("time_s", 0.0)))

	lines.append("")
	lines.append("OBSERVATIONS")
	lines.append("------------")
	if observations.is_empty():
		lines.append("No chemical or physical observations have been recorded yet.")
	else:
		for observation in observations:
			lines.append("%s   %s" % [
				UnitFormat.time_mmss(float(observation.get("time_s", 0.0))),
				str(observation.get("text", ""))])
			var object_label := str(observation.get("object_label", "Vessel"))
			var explanation := str(observation.get("explanation", ""))
			if not explanation.is_empty():
				lines.append("    %s — %s" % [object_label, explanation])
	_log_text.text = "\n".join(lines)


## Public message entry point for Main after save/load operations.
func show_message(message: String, severity: StringName = &"info") -> void:
	_show_toast(message, severity)


func _on_observation_added(_object_id: String, entry: Dictionary) -> void:
	_show_toast(str(entry.get("text", "")), &"info")
	if _log_window != null and _log_window.visible:
		_refresh_experiment_log()


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
	_teacher_guide_button = teacher_button
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
	badge.z_index = STAGE_OVERLAY_Z
	stage_slot.add_child(badge)
	_reference_pin_count += 1


func _on_reference_badge_removed() -> void:
	_reference_pin_count = maxi(0, _reference_pin_count - 1)
