class_name ExperimentCatalog
extends Window
## Browse the evidence-labelled, safe conceptual experiment bank for all requested grades.
## Entries are explanatory activities, not real-world procedures.

const DATA_PATH := "res://data/learning/expanded_safe_experiments.json"

var _database: ContentDatabase
var _pack: Dictionary = {}
var _grade_picker: OptionButton
var _cards_box: VBoxContainer
var _grade_records: Dictionary = {}


func _init() -> void:
	title = "Safe experiment bank"
	size = Vector2i(980, 760)
	min_size = Vector2i(700, 520)
	transient = true
	close_requested.connect(hide)


func bind(database: ContentDatabase) -> void:
	_database = database
	_pack = JsonDataLoader.load_dictionary(DATA_PATH)
	_build_ui()


func set_grade(grade_id: String) -> void:
	if _grade_picker == null:
		return
	for index in range(_grade_picker.item_count):
		if str(_grade_picker.get_item_metadata(index)) == grade_id:
			_grade_picker.select(index)
			_render_grade(grade_id)
			return
	if _grade_picker.item_count > 0:
		_grade_picker.select(0)
		_render_grade(str(_grade_picker.get_item_metadata(0)))


func _build_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_grade_records.clear()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(column)

	var heading := Label.new()
	heading.text = "SAFE EXPERIMENT CONCEPTS"
	heading.theme_type_variation = &"HeadingLabel"
	column.add_child(heading)

	var notice := Label.new()
	notice.text = "These are software learning activities, not laboratory instructions. Grade mapping is suggested and has not been verified against every official textbook or pathway."
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_color_override("font_color", LabColors.WARNING)
	column.add_child(notice)

	var selector_row := HBoxContainer.new()
	selector_row.add_theme_constant_override("separation", 10)
	column.add_child(selector_row)

	var grade_label := Label.new()
	grade_label.text = "Grade"
	grade_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	selector_row.add_child(grade_label)

	_grade_picker = OptionButton.new()
	_grade_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grade_picker.item_selected.connect(_on_grade_selected)
	selector_row.add_child(_grade_picker)

	var separator := HSeparator.new()
	column.add_child(separator)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_cards_box = VBoxContainer.new()
	_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_box.add_theme_constant_override("separation", 10)
	scroll.add_child(_cards_box)

	for grade_value in _pack.get("grades", []):
		if typeof(grade_value) != TYPE_DICTIONARY:
			continue
		var grade: Dictionary = grade_value
		var grade_id := str(grade.get("grade_id", ""))
		if grade_id.is_empty():
			continue
		_grade_records[grade_id] = grade
		_grade_picker.add_item(str(grade.get("grade_label", grade_id.capitalize())))
		_grade_picker.set_item_metadata(_grade_picker.item_count - 1, grade_id)

	if _grade_picker.item_count > 0:
		_grade_picker.select(0)
		_render_grade(str(_grade_picker.get_item_metadata(0)))


func _on_grade_selected(index: int) -> void:
	if index < 0 or index >= _grade_picker.item_count:
		return
	_render_grade(str(_grade_picker.get_item_metadata(index)))


func _render_grade(grade_id: String) -> void:
	for child in _cards_box.get_children():
		_cards_box.remove_child(child)
		child.queue_free()
	var grade: Dictionary = _grade_records.get(grade_id, {})
	if grade.is_empty():
		_add_text_card("No activity pack is available for this grade.", LabColors.TEXT_SECONDARY)
		return

	var activities: Array = grade.get("experiments", [])
	var summary := Label.new()
	summary.text = "%s · %d learning activities" % [str(grade.get("grade_label", grade_id)), activities.size()]
	summary.theme_type_variation = &"StrongLabel"
	_cards_box.add_child(summary)

	for activity_value in activities:
		if typeof(activity_value) != TYPE_DICTIONARY:
			continue
		var activity: Dictionary = activity_value
		_add_activity_card(activity)


func _add_activity_card(activity: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", LabTheme.box(LabColors.PANEL_RAISED, LabColors.PANEL_BORDER, 1, 10, 12, 10))
	_cards_box.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)

	var title_label := Label.new()
	title_label.text = str(activity.get("title", activity.get("id", "Learning activity")))
	title_label.theme_type_variation = &"StrongLabel"
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title_label)

	var focus := Label.new()
	focus.text = str(activity.get("focus", ""))
	focus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	focus.add_theme_color_override("font_color", LabColors.TEXT_PRIMARY)
	column.add_child(focus)

	var materials := _format_items(activity.get("materials", []), false)
	var equipment := _format_items(activity.get("equipment", []), true)
	var material_label := Label.new()
	material_label.text = "Materials / concepts: %s" % materials
	material_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	material_label.add_theme_color_override("font_color", LabColors.TEXT_SECONDARY)
	column.add_child(material_label)

	var equipment_label := Label.new()
	equipment_label.text = "Equipment models: %s" % equipment
	equipment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipment_label.add_theme_color_override("font_color", LabColors.TEXT_SECONDARY)
	column.add_child(equipment_label)

	var observations: Array = activity.get("student_observations", [])
	if not observations.is_empty():
		var observation_parts := PackedStringArray()
		for observation in observations:
			observation_parts.append(str(observation))
		var observation_label := Label.new()
		observation_label.text = "Look for: " + " · ".join(observation_parts)
		observation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(observation_label)

	var teacher_note := Label.new()
	teacher_note.text = "Teacher note: %s" % str(activity.get("teacher_note", ""))
	teacher_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	teacher_note.add_theme_color_override("font_color", LabColors.TEXT_SECONDARY)
	column.add_child(teacher_note)

	if str(activity.get("visual_demo_id", "")) == "magnesium_combustion_virtual_demo":
		var demo_label := Label.new()
		demo_label.text = "Virtual visual demo: select a vessel, then use “Show magnesium model” in its Inspector. This only displays the white-light observation and illustrative white MgO product."
		demo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		demo_label.add_theme_color_override("font_color", LabColors.ACCENT)
		column.add_child(demo_label)

	var alignment := Label.new()
	alignment.text = "Alignment: %s" % str(activity.get("curriculum_alignment_status", "suggested_not_verified_against_official_textbook"))
	alignment.add_theme_font_size_override("font_size", 11)
	alignment.add_theme_color_override("font_color", LabColors.WARNING)
	column.add_child(alignment)


func _format_items(values: Array, equipment_items: bool) -> String:
	var labels: Array[String] = []
	for raw_value in values:
		var item_id := str(raw_value)
		var display := item_id.replace("_", " ").capitalize()
		var is_reference := false
		if _database != null:
			if equipment_items:
				var equipment := _database.get_equipment(item_id)
				if equipment != null:
					display = equipment.display_name
				else:
					is_reference = true
			else:
				var chemical := _database.get_chemical(item_id)
				if chemical != null:
					display = chemical.display_name
				else:
					var compound := _database.get_compound(item_id)
					if compound != null:
						display = compound.display_name
					else:
						is_reference = true
		elif item_id in ["ice", "air", "sand", "magnesium_ribbon_reference", "oxygen_reference"]:
			is_reference = true
		if is_reference:
			display += " (concept/reference)"
		labels.append(display)
	return ", ".join(PackedStringArray(labels)) if not labels.is_empty() else "Not specified"


func _add_text_card(message: String, color: Color) -> void:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	_cards_box.add_child(label)
