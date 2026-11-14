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
var _session_menu: MenuButton
var _save_dialog: FileDialog
var _open_dialog: FileDialog
var _log_window: Window
var _log_text: RichTextLabel
var _sound_enabled: bool = true


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
	_build_session_menu()
	_build_session_dialogs()
	_build_experiment_log_window()
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
	EventBus.command_logged.connect(_on_command_logged)


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
	var stagger := Vector2(float(_specimen_count % 5) * 14.0, float(_specimen_count % 4) * 10.0)
	specimen.position = drop_position - SPECIMEN_CELL * 0.5 + stagger
	var maximum := Vector2(maxf(stage_slot.size.x - SPECIMEN_CELL.x, 0.0), maxf(stage_slot.size.y - SPECIMEN_CELL.y, 0.0))
	specimen.position = specimen.position.clamp(Vector2(SPECIMEN_MARGIN, SPECIMEN_MARGIN), Vector2(
		maxf(SPECIMEN_MARGIN, maximum.x - SPECIMEN_MARGIN), maxf(SPECIMEN_MARGIN, maximum.y - SPECIMEN_MARGIN)))
	specimen.z_index = 10
	stage_slot.add_child(specimen)
	_specimen_count += 1
	var label := "visual sample token" if bool(element_data.get("display_only_sample", false)) else "reference-only token"
	_show_toast("%s added to the workbench as a %s. It cannot be mixed or reacted." % [str(element_data.get("name", symbol)), label], &"info")



# ---------------------------------------------------------------- session tools

func _build_session_menu() -> void:
	_session_menu = MenuButton.new()
	_session_menu.text = "Session"
	_session_menu.tooltip_text = "Save, open and review a laboratory session."
	_session_menu.theme_type_variation = &"ToolButton"
	_session_menu.custom_minimum_size = Vector2(88.0, 40.0)
	_session_menu.focus_mode = Control.FOCUS_NONE
	var popup := _session_menu.get_popup()
	popup.add_item("Save experiment…", MENU_SAVE)
	popup.add_item("Open experiment…", MENU_OPEN)
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
