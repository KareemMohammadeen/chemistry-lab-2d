class_name WelcomeOverlay
extends Control
## First-run entry screen. It only routes the user into the existing lab or Teacher Mode;
## it does not create or mutate simulation state.

signal mode_selected(mode: String)

const TITLE := "VIRTUAL CHEMISTRY LABORATORY"
const SUBTITLE := "A polished 2D classroom dashboard for safe chemistry and science learning."


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = LabTheme.build()
	_build_screen()


func _build_screen() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = LabColors.BACKGROUND
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var glow_left := ColorRect.new()
	glow_left.color = Color(0.13, 0.56, 0.54, 0.16)
	glow_left.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(glow_left)

	var glow_right := ColorRect.new()
	glow_right.color = Color(0.37, 0.30, 0.88, 0.12)
	glow_right.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(glow_right)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(center)

	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(860.0, 0.0)
	shell.add_theme_stylebox_override("panel", LabTheme.box(Color("#0F1B27"), Color("#2E5362"), 1, 24, 22, 20))
	center.add_child(shell)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_child(content)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 430.0
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	content.add_child(left)

	var eyebrow := Label.new()
	eyebrow.text = "INTERACTIVE SCIENCE • GODOT 4"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	eyebrow.add_theme_color_override("font_color", LabColors.ACCENT)
	eyebrow.add_theme_font_size_override("font_size", 13)
	left.add_child(eyebrow)

	var title := Label.new()
	title.text = TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", LabColors.TEXT_PRIMARY)
	title.add_theme_font_size_override("font_size", 34)
	left.add_child(title)

	var subtitle := Label.new()
	subtitle.text = SUBTITLE
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", LabColors.TEXT_SECONDARY)
	subtitle.add_theme_font_size_override("font_size", 17)
	left.add_child(subtitle)

	var separator := HSeparator.new()
	left.add_child(separator)

	var demo_note := Label.new()
	demo_note.text = "The guided classroom demo focuses on safe learning materials. The periodic table and extended reference catalogue stay visible for teaching, but only classroom-safe material flows are executable."
	demo_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	demo_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	demo_note.add_theme_color_override("font_color", LabColors.TEXT_SECONDARY)
	left.add_child(demo_note)

	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 10)
	left.add_child(stat_row)
	stat_row.add_child(_make_stat_card("118", "Reference elements"))
	stat_row.add_child(_make_stat_card("5", "Grade profiles"))
	stat_row.add_child(_make_stat_card("SAFE", "Teacher-first"))

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 10)
	left.add_child(button_row)

	var demo_button := Button.new()
	demo_button.text = "Start Classroom Demo"
	demo_button.custom_minimum_size = Vector2(0.0, 54.0)
	demo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	demo_button.theme_type_variation = &"AccentButton"
	demo_button.focus_mode = Control.FOCUS_NONE
	demo_button.pressed.connect(func() -> void: mode_selected.emit("student"))
	button_row.add_child(demo_button)

	var teacher_button := Button.new()
	teacher_button.text = "Open Teacher Mode"
	teacher_button.custom_minimum_size = Vector2(0.0, 54.0)
	teacher_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	teacher_button.theme_type_variation = &"ToolButton"
	teacher_button.focus_mode = Control.FOCUS_NONE
	teacher_button.pressed.connect(func() -> void: mode_selected.emit("teacher"))
	button_row.add_child(teacher_button)

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 320.0
	right.add_theme_constant_override("separation", 10)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(right)

	var right_panel := PanelContainer.new()
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", LabTheme.box(Color("#111E2A"), Color("#2A4D5A"), 1, 20, 16, 14))
	right.add_child(right_panel)

	var right_content := VBoxContainer.new()
	right_content.add_theme_constant_override("separation", 10)
	right_panel.add_child(right_content)

	var hero_card := PanelContainer.new()
	hero_card.add_theme_stylebox_override("panel", LabTheme.box(Color("#132331"), Color("#33576A"), 1, 18, 12, 10))
	hero_card.custom_minimum_size = Vector2(0.0, 120.0)
	hero_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_content.add_child(hero_card)

	var hero_column := VBoxContainer.new()
	hero_column.add_theme_constant_override("separation", 7)
	hero_card.add_child(hero_column)

	var hero_caption := Label.new()
	hero_caption.text = "Why this matters"
	hero_caption.add_theme_color_override("font_color", LabColors.ACCENT)
	hero_caption.add_theme_font_size_override("font_size", 13)
	hero_column.add_child(hero_caption)

	var hero_text := Label.new()
	hero_text.text = "A teacher can preview classroom-safe flows, inspect evidence-labelled curriculum notes and pin reference materials from the periodic table without turning the lab into unsafe real-world chemistry instructions."
	hero_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_text.add_theme_color_override("font_color", LabColors.TEXT_PRIMARY)
	hero_column.add_child(hero_text)

	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("separation", 8)
	right_content.add_child(chips)
	chips.add_child(_make_chip("Prep 1 → Senior 2"))
	chips.add_child(_make_chip("Safe by design"))
	chips.add_child(_make_chip("Modern dashboard"))

	var footer := Label.new()
	footer.text = "Virtual demonstrations are simplified models, not instructions for real laboratory work."
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_theme_color_override("font_color", LabColors.TEXT_MUTED)
	footer.add_theme_font_size_override("font_size", 12)
	left.add_child(footer)


func _make_stat_card(value: String, caption: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, 72.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.theme_type_variation = &"StatPanel"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	card.add_child(column)
	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_color_override("font_color", LabColors.TEXT_PRIMARY)
	value_label.add_theme_font_size_override("font_size", 20)
	column.add_child(value_label)
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.add_theme_color_override("font_color", LabColors.TEXT_SECONDARY)
	caption_label.add_theme_font_size_override("font_size", 12)
	column.add_child(caption_label)
	return card


func _make_chip(text: String) -> Control:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"ChipPanel"
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", LabColors.TEXT_PRIMARY)
	chip.add_child(label)
	return chip
