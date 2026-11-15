class_name LibraryCard
extends PanelContainer
## One row of the Library: a picture, a name, a subtitle (formula or capacity) and a short tag
## (stock or count). Clicking it asks for the matching object to be selected. Display only.

signal activated(card: LibraryCard)

const ICON_SIZE := Vector2(52.0, 60.0)
const NAME_FONT_SIZE := 16
const SUB_FONT_SIZE := 13
const TAG_FONT_SIZE := 13

## "reagent" (key = chemical id) or "equipment" (key = equipment id).
var kind: String = ""
var key: String = ""

var _icon: LibraryIcon
var _tag_label: Label
var _active: bool = false
var _hovered: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	theme_type_variation = &"CardPanel"


## `icon_kind` is a LibraryIcon.Kind value; `profile` is only used by vessel icons.
func setup(card_kind: String, card_key: String, title: String, subtitle: String, hint: String,
		icon_kind: LibraryIcon.Kind, tint: Color, profile: Array = []) -> void:
	kind = card_kind
	key = card_key
	tooltip_text = hint
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_icon = LibraryIcon.new()
	_icon.custom_minimum_size = ICON_SIZE
	row.add_child(_icon)
	_icon.configure(icon_kind, tint, profile)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 1)
	row.add_child(texts)
	texts.add_child(_make_label(title, &"StrongLabel", NAME_FONT_SIZE, true))
	texts.add_child(_make_label(subtitle, &"CaptionLabel", SUB_FONT_SIZE, true))
	_tag_label = _make_label("", &"CaptionLabel", TAG_FONT_SIZE, false)
	_tag_label.add_theme_color_override("font_color", LabColors.ACCENT)
	texts.add_child(_tag_label)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	gui_input.connect(_on_gui_input)


func set_tag(text: String) -> void:
	if _tag_label != null and _tag_label.text != text:
		_tag_label.text = text
		_tag_label.visible = text != ""


func set_active(active: bool) -> void:
	if active != _active:
		_active = active
		_restyle()


func _on_hover(hovered: bool) -> void:
	_hovered = hovered
	_restyle()


func _restyle() -> void:
	if _active:
		theme_type_variation = &"CardPanelActive"
	elif _hovered:
		theme_type_variation = &"CardPanelHover"
	else:
		theme_type_variation = &"CardPanel"


func _get_drag_data(_at_position: Vector2) -> Variant:
	if kind != "equipment" and kind != "reagent":
		return null
	var preview := PanelContainer.new()
	preview.theme_type_variation = &"CardPanelActive"
	preview.custom_minimum_size = Vector2(190.0, 54.0)
	var preview_label := Label.new()
	preview_label.text = tooltip_text if not tooltip_text.is_empty() else key.replace("_", " ").capitalize()
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_label.custom_minimum_size = Vector2(180.0, 46.0)
	preview.add_child(preview_label)
	set_drag_preview(preview)
	return {"kind": kind, "id": key}


func _on_gui_input(event: InputEvent) -> void:
	# Activate on release so Godot can cross its drag threshold first.
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		activated.emit(self)
		accept_event()


func _make_label(text: String, variation: StringName, font_size: int, wrap: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		# Names wrap onto a second line instead of being cut off.
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 40.0
	return label
