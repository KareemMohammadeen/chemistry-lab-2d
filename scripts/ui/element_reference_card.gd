class_name ElementReferenceCard
extends PanelContainer
## Draggable periodic-table tile. Dropping it creates a visual learning token on the workbench;
## element tiles are not chemical reagents and cannot enter the reaction engine.

signal activated(element: ElementDefinition)

const TILE_SIZE := Vector2(58.0, 64.0)

var element: ElementDefinition
var _search_match: bool = true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = TILE_SIZE


func setup(value: ElementDefinition) -> void:
	element = value
	var accent := _accent_for(value.block)
	var fill := Color("#142431")
	add_theme_stylebox_override("panel", LabTheme.box(fill, accent.darkened(0.35), 1, 9, 4, 4))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	add_child(column)

	var number := Label.new()
	number.text = str(element.atomic_number)
	number.add_theme_font_size_override("font_size", 10)
	number.add_theme_color_override("font_color", LabColors.TEXT_MUTED)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(number)

	var symbol := Label.new()
	symbol.text = element.id
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol.add_theme_font_size_override("font_size", 19)
	symbol.add_theme_color_override("font_color", LabColors.TEXT_PRIMARY)
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(symbol)

	var name_label := Label.new()
	name_label.text = element.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", LabColors.TEXT_SECONDARY)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)
	tooltip_text = _tooltip_text(element) + "\nDrag this tile onto the workbench to create a stylized 2D specimen. It is a visual model, not a reagent."


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if element != null:
			activated.emit(element)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if element == null:
		return null
		var payload := {
		"kind": "periodic_element",
		"symbol": element.id,
		"name": element.display_name,
		"atomic_number": element.atomic_number,
		"period": element.period,
		"group": element.group,
		"block": element.block,
		"category": element.category,
		"state_at_stp": element.state_at_stp,
		"appearance": element.appearance,
		"hazards": element.hazards,
		"radioactive": element.radioactive,
		"display_only_sample": true,
		"simulation_reagent": false
	}
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(104.0, 68.0)
	preview.add_theme_stylebox_override("panel", LabTheme.box(Color("#132635"), _accent_for(element.block), 2, 12, 10, 8))
	var label := Label.new()
	label.text = "%s  ·  %s" % [element.id, element.display_name]
	label.add_theme_color_override("font_color", LabColors.TEXT_PRIMARY)
	preview.add_child(label)
	set_drag_preview(preview)
	return payload


func matches_query(query: String) -> bool:
	if element == null or query.strip_edges().is_empty():
		return true
	var needle := query.strip_edges().to_lower()
	return element.id.to_lower().contains(needle) \
		or element.display_name.to_lower().contains(needle) \
		or str(element.atomic_number).contains(needle) \
		or element.category.to_lower().contains(needle)


func set_search_match(matches: bool) -> void:
	_search_match = matches
	modulate.a = 1.0 if matches else 0.22
	mouse_filter = Control.MOUSE_FILTER_STOP if matches else Control.MOUSE_FILTER_IGNORE


func _accent_for(block_name: String) -> Color:
	match block_name:
		"s":
			return Color("#66D4BD")
		"p":
			return Color("#65BFE8")
		"d":
			return Color("#A99AFB")
		"f":
			return Color("#E6B86F")
	return LabColors.ACCENT


static func _tooltip_text(value: ElementDefinition) -> String:
	var group_label := "f-block" if value.group <= 0 else str(value.group)
	var config := value.electron_configuration if value.electron_configuration != "" else "Not listed"
	return "%s (%s)\nAtomic number: %d\nCategory: %s\nPeriod: %d  •  Group: %s\nBlock: %s\nElectron configuration: %s\n%s" % [
		value.display_name, value.id, value.atomic_number, value.category, value.period, group_label, value.block, config,
		"Every dropped element is a 2D educational visual model only; it is not a classroom reagent."]
