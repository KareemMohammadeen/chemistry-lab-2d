class_name LabTheme
extends RefCounted
## The look of every control, built once from the colour tokens. Scenes pick a look with
## theme_type_variation (SidePanel, TopBarPanel, CardPanel, GroupPill, ChipPanel, ToolButton,
## AccentButton, TitleLabel, HeadingLabel, CaptionLabel, MutedLabel, HeroPanel, StatPanel)
## so no scene sets colours itself.

const FONT_SIZE := 16
const RADIUS := 14
const RADIUS_SMALL := 10
const BUTTON_PADDING_X := 14
const BUTTON_PADDING_Y := 10
const SCROLLBAR_WIDTH := 8
const SURFACE := LabColors.PANEL_RAISED
const SURFACE_HOVER := Color("#22384A")
const SURFACE_PRESSED := Color("#1A4F51")
const SURFACE_DISABLED := Color("#141D27")


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	theme.set_color("font_color", "Label", LabColors.TEXT_PRIMARY)
	_style_panels(theme)
	_style_buttons(theme)
	_style_inputs(theme)
	_style_scrollbars(theme)
	_style_tooltips(theme)
	_style_labels(theme)
	return theme


## A rounded rectangle used by panels, buttons and chips.
static func box(fill: Color, border: Color = Color(0, 0, 0, 0), border_width: int = 0, radius: int = RADIUS,
		pad_x: int = 0, pad_y: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = pad_x
	style.content_margin_right = pad_x
	style.content_margin_top = pad_y
	style.content_margin_bottom = pad_y
	style.shadow_color = Color(0, 0, 0, 0.26)
	style.shadow_size = 8
	return style


static func _variation(theme: Theme, name: StringName, base: StringName) -> void:
	theme.set_type_variation(name, base)


static func _style_panels(theme: Theme) -> void:
	var side := box(LabColors.PANEL, LabColors.PANEL_BORDER, 1, 0)
	_variation(theme, &"SidePanel", &"PanelContainer")
	theme.set_stylebox("panel", "SidePanel", side)

	var top := box(LabColors.PANEL, LabColors.PANEL_BORDER, 0, 0)
	top.border_width_bottom = 1
	top.shadow_color = Color(0, 0, 0, 0.38)
	top.shadow_size = 10
	_variation(theme, &"TopBarPanel", &"PanelContainer")
	theme.set_stylebox("panel", "TopBarPanel", top)

	_variation(theme, &"HeroPanel", &"PanelContainer")
	theme.set_stylebox("panel", "HeroPanel", box(Color("#101C28"), LabColors.PANEL_BORDER_STRONG, 1, 20, 18, 14))

	_variation(theme, &"CardPanel", &"PanelContainer")
	theme.set_stylebox("panel", "CardPanel", box(LabColors.PANEL_RAISED, LabColors.PANEL_BORDER, 1, RADIUS, 12, 10))
	_variation(theme, &"CardPanelHover", &"PanelContainer")
	theme.set_stylebox("panel", "CardPanelHover", box(Color("#22364A"), LabColors.ACCENT_STRONG, 1, RADIUS, 12, 10))
	_variation(theme, &"CardPanelActive", &"PanelContainer")
	theme.set_stylebox("panel", "CardPanelActive", box(Color("#183C43"), LabColors.ACCENT, 2, RADIUS, 11, 9))

	_variation(theme, &"StatPanel", &"PanelContainer")
	theme.set_stylebox("panel", "StatPanel", box(Color("#10202C"), LabColors.PANEL_BORDER_STRONG, 1, 18, 12, 9))

	_variation(theme, &"GlassPanel", &"PanelContainer")
	theme.set_stylebox("panel", "GlassPanel", box(Color("#0F1822"), Color(1, 1, 1, 0.10), 1, 18, 14, 11))

	_variation(theme, &"DisplayPanel", &"PanelContainer")
	theme.set_stylebox("panel", "DisplayPanel", box(Color("#111A24"), Color(1, 1, 1, 0.08), 1, 20, 16, 12))

	_variation(theme, &"GroupPill", &"PanelContainer")
	theme.set_stylebox("panel", "GroupPill", box(LabColors.PANEL_SUNKEN, LabColors.PANEL_BORDER, 1, RADIUS, 4, 4))
	_variation(theme, &"ChipPanel", &"PanelContainer")
	theme.set_stylebox("panel", "ChipPanel", box(LabColors.PANEL_SUNKEN, LabColors.PANEL_BORDER, 1, RADIUS, 12, 7))
	_variation(theme, &"HeaderPanel", &"PanelContainer")
	theme.set_stylebox("panel", "HeaderPanel", box(LabColors.PANEL_RAISED, LabColors.PANEL_BORDER, 0, 0, 16, 14))
	_variation(theme, &"HintPanel", &"PanelContainer")
	theme.set_stylebox("panel", "HintPanel", box(Color(0.06, 0.09, 0.12, 0.74), Color(1, 1, 1, 0.06), 1, RADIUS, 12, 6))


static func _style_buttons(theme: Theme) -> void:
	theme.set_stylebox("normal", "Button", box(SURFACE, LabColors.PANEL_BORDER_STRONG, 1, RADIUS_SMALL, BUTTON_PADDING_X, BUTTON_PADDING_Y))
	theme.set_stylebox("hover", "Button", box(SURFACE_HOVER, LabColors.ACCENT, 1, RADIUS_SMALL, BUTTON_PADDING_X, BUTTON_PADDING_Y))
	theme.set_stylebox("pressed", "Button", box(SURFACE_PRESSED, LabColors.ACCENT, 2, RADIUS_SMALL, BUTTON_PADDING_X, BUTTON_PADDING_Y))
	theme.set_stylebox("hover_pressed", "Button", box(SURFACE_PRESSED, LabColors.CYAN, 2, RADIUS_SMALL, BUTTON_PADDING_X, BUTTON_PADDING_Y))
	theme.set_stylebox("disabled", "Button", box(SURFACE_DISABLED, LabColors.PANEL_BORDER, 1, RADIUS_SMALL, BUTTON_PADDING_X, BUTTON_PADDING_Y))
	theme.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), LabColors.CYAN, 2, RADIUS_SMALL))
	_button_colors(theme, "Button", LabColors.TEXT_PRIMARY, LabColors.TEXT_SECONDARY)
	theme.set_constant("h_separation", "Button", 8)
	theme.set_constant("icon_max_width", "Button", 22)

	# Flat buttons that live inside a GroupPill.
	_variation(theme, &"ToolButton", &"Button")
	var flat := box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, RADIUS_SMALL, 12, 9)
	theme.set_stylebox("normal", "ToolButton", flat)
	theme.set_stylebox("hover", "ToolButton", box(SURFACE_HOVER, Color(0, 0, 0, 0), 0, RADIUS_SMALL, 12, 9))
	theme.set_stylebox("pressed", "ToolButton", box(LabColors.ACCENT_STRONG, Color(0, 0, 0, 0), 0, RADIUS_SMALL, 12, 9))
	theme.set_stylebox("hover_pressed", "ToolButton", box(LabColors.ACCENT, Color(0, 0, 0, 0), 0, RADIUS_SMALL, 12, 9))
	theme.set_stylebox("disabled", "ToolButton", flat)
	theme.set_stylebox("focus", "ToolButton", box(Color(0, 0, 0, 0), LabColors.CYAN, 2, RADIUS_SMALL))
	_button_colors(theme, "ToolButton", LabColors.TEXT_PRIMARY, LabColors.TEXT_SECONDARY)
	theme.set_color("font_pressed_color", "ToolButton", Color.WHITE)
	theme.set_color("font_hover_pressed_color", "ToolButton", Color.WHITE)
	theme.set_color("icon_pressed_color", "ToolButton", Color.WHITE)
	theme.set_color("icon_hover_pressed_color", "ToolButton", Color.WHITE)
	theme.set_color("font_disabled_color", "ToolButton", LabColors.TEXT_MUTED)
	theme.set_color("icon_disabled_color", "ToolButton", Color("#3A4A59"))

	# The one primary action of a section.
	_variation(theme, &"AccentButton", &"Button")
	theme.set_stylebox("normal", "AccentButton", box(LabColors.ACCENT_STRONG, LabColors.ACCENT, 1, RADIUS, BUTTON_PADDING_X, BUTTON_PADDING_Y))
	theme.set_stylebox("hover", "AccentButton", box(LabColors.ACCENT, LabColors.CYAN, 1, RADIUS, BUTTON_PADDING_X, BUTTON_PADDING_Y))
	theme.set_stylebox("pressed", "AccentButton", box(Color("#17776E"), LabColors.CYAN, 2, RADIUS, BUTTON_PADDING_X, BUTTON_PADDING_Y))
	theme.set_stylebox("hover_pressed", "AccentButton", box(Color("#17776E"), LabColors.CYAN, 2, RADIUS, BUTTON_PADDING_X, BUTTON_PADDING_Y))
	theme.set_stylebox("disabled", "AccentButton", box(SURFACE_DISABLED, LabColors.PANEL_BORDER, 1, RADIUS, BUTTON_PADDING_X, BUTTON_PADDING_Y))
	theme.set_stylebox("focus", "AccentButton", box(Color(0, 0, 0, 0), LabColors.CYAN, 2, RADIUS))
	_button_colors(theme, "AccentButton", Color.WHITE, Color.WHITE)


static func _button_colors(theme: Theme, type_name: String, text: Color, icon: Color) -> void:
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(state, type_name, text)
	theme.set_color("font_disabled_color", type_name, LabColors.TEXT_MUTED)
	theme.set_color("icon_normal_color", type_name, icon)
	theme.set_color("icon_hover_color", type_name, LabColors.CYAN)
	theme.set_color("icon_pressed_color", type_name, LabColors.CYAN)
	theme.set_color("icon_hover_pressed_color", type_name, LabColors.CYAN)
	theme.set_color("icon_focus_color", type_name, icon)
	theme.set_color("icon_disabled_color", type_name, Color("#3A4A59"))


static func _style_inputs(theme: Theme) -> void:
	var field := box(LabColors.PANEL_SUNKEN, LabColors.PANEL_BORDER_STRONG, 1, RADIUS_SMALL, 10, 7)
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("read_only", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", box(LabColors.PANEL_SUNKEN, LabColors.ACCENT, 2, RADIUS_SMALL, 10, 7))
	theme.set_color("font_color", "LineEdit", LabColors.TEXT_PRIMARY)
	theme.set_color("caret_color", "LineEdit", LabColors.CYAN)
	theme.set_color("selection_color", "LineEdit", Color(LabColors.ACCENT, 0.35))
	theme.set_stylebox("normal", "Label", StyleBoxEmpty.new())
	theme.set_stylebox("separator", "HSeparator", box(LabColors.PANEL_BORDER, Color(0, 0, 0, 0), 0, 0))
	theme.set_constant("separation", "HSeparator", 1)
	theme.set_stylebox("separator", "VSeparator", box(LabColors.PANEL_BORDER, Color(0, 0, 0, 0), 0, 0))
	theme.set_constant("separation", "VSeparator", 1)


static func _style_scrollbars(theme: Theme) -> void:
	var track := box(Color(1, 1, 1, 0.03), Color(0, 0, 0, 0), 0, SCROLLBAR_WIDTH)
	var grabber := box(Color("#3A4C5E"), Color(0, 0, 0, 0), 0, SCROLLBAR_WIDTH)
	var grabber_hover := box(LabColors.ACCENT, Color(0, 0, 0, 0), 0, SCROLLBAR_WIDTH)
	for bar in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", bar, track)
		theme.set_stylebox("grabber", bar, grabber)
		theme.set_stylebox("grabber_highlight", bar, grabber_hover)
		theme.set_stylebox("grabber_pressed", bar, grabber_hover)
	theme.set_constant("minimum_size", "VScrollBar", SCROLLBAR_WIDTH)
	theme.set_constant("minimum_size", "HScrollBar", SCROLLBAR_WIDTH)


static func _style_tooltips(theme: Theme) -> void:
	theme.set_stylebox("panel", "TooltipPanel", box(Color("#0B1015"), LabColors.PANEL_BORDER_STRONG, 1, 6, 10, 6))
	theme.set_color("font_color", "TooltipLabel", LabColors.TEXT_PRIMARY)


static func _style_labels(theme: Theme) -> void:
	var bold := FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 0.6
	_variation(theme, &"TitleLabel", &"Label")
	theme.set_font("font", "TitleLabel", bold)
	theme.set_font_size("font_size", "TitleLabel", 24)
	theme.set_color("font_color", "TitleLabel", LabColors.TEXT_PRIMARY)
	_variation(theme, &"HeadingLabel", &"Label")
	theme.set_font("font", "HeadingLabel", bold)
	theme.set_font_size("font_size", "HeadingLabel", 13)
	theme.set_color("font_color", "HeadingLabel", LabColors.ACCENT)
	_variation(theme, &"CaptionLabel", &"Label")
	theme.set_font_size("font_size", "CaptionLabel", 13)
	theme.set_color("font_color", "CaptionLabel", LabColors.TEXT_SECONDARY)
	_variation(theme, &"MutedLabel", &"Label")
	theme.set_font_size("font_size", "MutedLabel", 14)
	theme.set_color("font_color", "MutedLabel", LabColors.TEXT_MUTED)
	_variation(theme, &"StrongLabel", &"Label")
	theme.set_font("font", "StrongLabel", bold)
	theme.set_font_size("font_size", "StrongLabel", 16)
	theme.set_color("font_color", "StrongLabel", LabColors.TEXT_PRIMARY)
