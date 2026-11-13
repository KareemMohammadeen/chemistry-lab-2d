extends Control
## First-run entry screen. It only routes the user into the existing lab or Teacher Mode;
## it does not create or mutate simulation state.

signal mode_selected(mode: String)

const TITLE := "VIRTUAL CHEMISTRY LABORATORY"
const SUBTITLE := "A guided 2D learning space for exploring matter and solutions."


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = LabTheme.build()
	_build_screen()


func _build_screen() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#07111B")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var glow := ColorRect.new()
	glow.color = Color(0.12, 0.42, 0.48, 0.12)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(glow)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540.0, 0.0)
	panel.add_theme_stylebox_override("panel",
		LabTheme.box(Color("#111F2D"), Color("#2B5363"), 1, 22, 24, 18))
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(content)

	var eyebrow := Label.new()
	eyebrow.text = "INTERACTIVE SCIENCE • GODOT 4"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_color_override("font_color", LabColors.ACCENT)
	eyebrow.add_theme_font_size_override("font_size", 13)
	content.add_child(eyebrow)

	var title := Label.new()
	title.text = TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", LabColors.TEXT_PRIMARY)
	title.add_theme_font_size_override("font_size", 31)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = SUBTITLE
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", LabColors.TEXT_SECONDARY)
	subtitle.add_theme_font_size_override("font_size", 17)
	content.add_child(subtitle)

	var separator := HSeparator.new()
	content.add_child(separator)

	var demo_note := Label.new()
	demo_note.text = "The guided classroom demo focuses on water and table salt. The periodic table is available as a read-only reference."
	demo_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	demo_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	demo_note.add_theme_color_override("font_color", LabColors.TEXT_SECONDARY)
	content.add_child(demo_note)

	var demo_button := Button.new()
	demo_button.text = "Start Classroom Demo"
	demo_button.custom_minimum_size = Vector2(0.0, 54.0)
	demo_button.theme_type_variation = &"AccentButton"
	demo_button.focus_mode = Control.FOCUS_NONE
	demo_button.pressed.connect(func() -> void: mode_selected.emit("student"))
	content.add_child(demo_button)

	var teacher_button := Button.new()
	teacher_button.text = "Open Teacher Mode"
	teacher_button.custom_minimum_size = Vector2(0.0, 50.0)
	teacher_button.theme_type_variation = &"ToolButton"
	teacher_button.focus_mode = Control.FOCUS_NONE
	teacher_button.pressed.connect(func() -> void: mode_selected.emit("teacher"))
	content.add_child(teacher_button)

	var footer := Label.new()
	footer.text = "Virtual demonstrations are simplified models, not instructions for real laboratory work."
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_theme_color_override("font_color", LabColors.TEXT_MUTED)
	footer.add_theme_font_size_override("font_size", 12)
	content.add_child(footer)
