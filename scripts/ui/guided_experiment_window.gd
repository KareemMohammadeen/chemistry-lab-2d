class_name GuidedExperimentWindow
extends Window
## A data-driven guide that checks accepted virtual actions and model observations.
## It does not issue laboratory commands or provide real-world experiment instructions.

const DATA_PATH := "res://data/learning/guided_experiments.json"

var _host: SimulationHost
var _experiments: Array = []
var _active_experiment: Dictionary = {}
var _start_history_index: int = 0
var _started: bool = false
var _refresh_left_s: float = 0.0
var _picker: OptionButton
var _start_button: Button
var _progress_label: Label
var _status_label: Label
var _steps_box: VBoxContainer


func _init() -> void:
	title = "Guided virtual experiment"
	size = Vector2i(780, 660)
	min_size = Vector2i(620, 500)
	transient = true
	close_requested.connect(hide)


func bind(host: SimulationHost) -> void:
	_host = host
	var data: Dictionary = JsonDataLoader.load_dictionary(DATA_PATH)
	_experiments = data.get("experiments", [])
	_build_ui()
	if _host.commands != null and not _host.commands.changed.is_connected(_on_history_changed):
		_host.commands.changed.connect(_on_history_changed)


func _exit_tree() -> void:
	if _host != null and _host.commands != null and _host.commands.changed.is_connected(_on_history_changed):
		_host.commands.changed.disconnect(_on_history_changed)


func _process(delta: float) -> void:
	if not _started:
		return
	_refresh_left_s -= delta
	if _refresh_left_s <= 0.0:
		_refresh_left_s = 0.25
		_refresh_progress()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var heading := Label.new()
	heading.text = "GUIDED VIRTUAL LEARNING"
	heading.theme_type_variation = &"HeadingLabel"
	column.add_child(heading)

	var notice := Label.new()
	notice.text = "Software-only classroom activity. This guide does not describe a real laboratory procedure."
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_color_override("font_color", LabColors.WARNING)
	column.add_child(notice)

	var selector_row := HBoxContainer.new()
	column.add_child(selector_row)
	var selector_label := Label.new()
	selector_label.text = "Activity"
	selector_row.add_child(selector_label)

	_picker = OptionButton.new()
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.item_selected.connect(_on_activity_selected)
	selector_row.add_child(_picker)

	_start_button = Button.new()
	_start_button.text = "Start tracking"
	_start_button.pressed.connect(_on_start_pressed)
	column.add_child(_start_button)

	_progress_label = Label.new()
	_progress_label.text = "Progress: 0 / 0"
	_progress_label.theme_type_variation = &"StrongLabel"
	column.add_child(_progress_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", LabColors.TEXT_SECONDARY)
	column.add_child(_status_label)

	var separator := HSeparator.new()
	column.add_child(separator)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_steps_box = VBoxContainer.new()
	_steps_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steps_box.add_theme_constant_override("separation", 10)
	scroll.add_child(_steps_box)

	for experiment_value in _experiments:
		if typeof(experiment_value) != TYPE_DICTIONARY:
			continue
		var experiment: Dictionary = experiment_value
		_picker.add_item(str(experiment.get("name", experiment.get("id", "Activity"))))
		_picker.set_item_metadata(_picker.item_count - 1, str(experiment.get("id", "")))

	if _picker.item_count > 0:
		_picker.select(0)
		_on_activity_selected(0)
	else:
		_status_label.text = "No guided activities are configured."


func _on_activity_selected(index: int) -> void:
	if index < 0 or index >= _picker.item_count:
		return
	var wanted_id: String = str(_picker.get_item_metadata(index))
	for experiment_value in _experiments:
		if typeof(experiment_value) != TYPE_DICTIONARY:
			continue
		var experiment: Dictionary = experiment_value
		if str(experiment.get("id", "")) == wanted_id:
			_active_experiment = experiment
			_started = false
			_start_button.text = "Start tracking"
			_refresh_progress()
			return


func _on_start_pressed() -> void:
	if _host == null or _active_experiment.is_empty():
		return
	_start_history_index = _host.commands.history.size()
	_started = true
	_start_button.text = "Restart tracking"
	_refresh_progress()


func _on_history_changed() -> void:
	_refresh_progress()


func _refresh_progress() -> void:
	if _steps_box == null or _host == null:
		return
	var result: Dictionary = {"progress": 0, "total": _active_experiment.get("steps", []).size(), "complete": false, "error": ""}
	if _started:
		result = GuidedExperimentTracker.evaluate(
			_active_experiment, _host.commands.history, _start_history_index, _host.simulation)

	var progress: int = int(result.get("progress", 0))
	var total: int = int(result.get("total", 0))
	_progress_label.text = "Progress: %d / %d" % [progress, total]
	if not str(result.get("error", "")).is_empty():
		_status_label.text = str(result.get("error", ""))
	elif not _started:
		_status_label.text = "Press Start tracking, then perform the virtual actions in the workbench."
	elif bool(result.get("complete", false)):
		_status_label.text = "Completed. Review the beaker contents and the Experiment Log."
	elif progress == 0:
		_status_label.text = "Waiting for the first accepted action."
	else:
		_status_label.text = "Step %d is next. Continue in the workbench; progress updates automatically." % (progress + 1)

	_clear_steps()
	var steps: Array = _active_experiment.get("steps", [])
	for index in range(steps.size()):
		var step_value: Variant = steps[index]
		if typeof(step_value) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_value
		var status_text: String = "✓" if index < progress else ("▶" if index == progress and _started else "○")
		var status_color: Color = LabColors.SUCCESS if index < progress else (LabColors.ACCENT if index == progress and _started else LabColors.TEXT_MUTED)
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", LabTheme.box(LabColors.PANEL_RAISED, LabColors.PANEL_BORDER, 1, 10, 10, 8))
		_steps_box.add_child(card)

		var row := HBoxContainer.new()
		card.add_child(row)
		var status := Label.new()
		status.text = status_text
		status.add_theme_color_override("font_color", status_color)
		status.custom_minimum_size.x = 24
		row.add_child(status)

		var content := VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(content)
		var title_label := Label.new()
		title_label.text = "Step %d" % (index + 1)
		title_label.theme_type_variation = &"StrongLabel"
		content.add_child(title_label)
		var prompt := Label.new()
		prompt.text = str(step.get("success", step.get("prompt", ""))) if index < progress else str(step.get("prompt", ""))
		prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(prompt)


func _clear_steps() -> void:
	if _steps_box == null:
		return
	for child in _steps_box.get_children():
		_steps_box.remove_child(child)
		child.queue_free()
