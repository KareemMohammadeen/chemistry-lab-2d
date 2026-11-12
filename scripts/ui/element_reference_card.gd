class_name ElementReferenceCard
extends PanelContainer
## Read-only periodic-table card. Element entries are educational references, not reagents.

signal activated(element: ElementDefinition)

var element: ElementDefinition


func setup(value: ElementDefinition) -> void:
	element = value
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme_type_variation = &"CardPanel"
	var button := Button.new()
	button.custom_minimum_size = Vector2(48.0, 46.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.theme_type_variation = &"ToolButton"
	button.text = "%s\n%d" % [element.id, element.atomic_number]
	button.tooltip_text = _tooltip_text(element)
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(func() -> void: activated.emit(element))
	add_child(button)


static func _tooltip_text(value: ElementDefinition) -> String:
	var group_label := "f-block" if value.group <= 0 else str(value.group)
	var config := value.electron_configuration if value.electron_configuration != "" else "Not listed"
	return "%s (%s)\nAtomic number: %d\nCategory: %s\nPeriod: %d  •  Group: %s\nBlock: %s\nElectron configuration: %s\nReference entry only." % [
		value.display_name, value.id, value.atomic_number, value.category, value.period, group_label, value.block, config]
