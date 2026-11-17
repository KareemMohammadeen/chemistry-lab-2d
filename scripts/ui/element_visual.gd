class_name ElementVisual
extends Control
## Procedural 2D specimen artwork for every periodic-table element.
## The artwork is an educational illustration, never a physical handling model or reagent.

const DIATOMIC_GASES: Array[String] = ["H", "N", "O", "F", "Cl"]
const MONATOMIC_GASES: Array[String] = ["He", "Ne", "Ar", "Kr", "Xe", "Rn"]

var _profile: Dictionary = {}
var _symbol: String = ""


func setup(data: Dictionary) -> void:
	_profile = profile_for(data)
	_symbol = str(data.get("symbol", "?"))
	custom_minimum_size = Vector2(116.0, 92.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


## Maps all 118 entries to a visual form. Unknown bulk properties deliberately
## fall back to a conceptual atom model instead of inventing a physical sample.
static func profile_for(data: Dictionary) -> Dictionary:
	var symbol := str(data.get("symbol", "?"))
	var raw_state: Variant = data.get("state_at_stp", "")
	var state := str(raw_state.get("value", "")) if typeof(raw_state) == TYPE_DICTIONARY else str(raw_state)
	state = state.to_lower()
	var category := str(data.get("category", "")).to_lower()
	var atomic_number := int(data.get("atomic_number", 0))
	var hazards := str(data.get("hazards", "")).strip_edges()
	var restricted := bool(data.get("radioactive", false)) or not hazards.is_empty()
	var form := "unknown_atom"
	var sample_form := str(data.get("sample_form", "")).to_lower()
	if sample_form == "ribbon" or symbol == "Mg":
		form = "solid_ribbon"
	elif sample_form == "powder" or symbol in ["S", "P"]:
		form = "solid_powder"
	elif sample_form in ["gas_cylinder", "sealed_gas_cylinder"] or state == "gas":
		form = "gas_cylinder"
	elif sample_form in ["liquid", "liquid_drop"] or state == "liquid":
		form = "liquid"
	elif sample_form == "cube":
		form = "solid_metal"
	elif sample_form == "crystal":
		form = "solid_crystal"
	elif state == "solid":
		form = "solid_metal" if _is_metal_category(category) else "solid_crystal"

	var form_label := "CONCEPTUAL ATOM MODEL · BULK STATE UNKNOWN"
	match form:
		"solid_metal":
			form_label = "SOLID · METALLIC SPECIMEN"
		"solid_crystal":
			form_label = "SOLID · CRYSTAL / MINERAL MODEL"
		"solid_powder":
			form_label = "SOLID · POWDER SAMPLE MODEL"
		"solid_ribbon":
			form_label = "SOLID · METALLIC RIBBON MODEL"
		"liquid":
			form_label = "LIQUID · CONTAINED DROP MODEL"
		"gas_cylinder":
			form_label = "GAS · SEALED DISPLAY CYLINDER"
	if restricted:
		form_label += " · SEALED VIRTUAL DISPLAY"

	return {
		"form": form,
		"label": form_label,
		"color": _element_color(symbol, atomic_number, category),
		"restricted": restricted,
		"known_bulk_state": state in ["solid", "liquid", "gas"],
		"state": state
	}


static func _is_metal_category(category: String) -> bool:
	return (category.contains("metal") and category != "nonmetal" and category != "metalloid") or category in ["lanthanoid", "actinoid"]


static func _element_color(symbol: String, atomic_number: int, category: String) -> Color:
	var palette := {
		"H": Color("#DDEBF2"), "He": Color("#F0D9B7"), "C": Color("#68727D"),
		"N": Color("#547BD8"), "O": Color("#E85F69"), "F": Color("#B9D34F"),
		"Ne": Color("#F28C59"), "Na": Color("#B9A5A5"), "Mg": Color("#AAB3BD"),
		"Al": Color("#B8C7D2"), "Si": Color("#829EAD"), "P": Color("#D77A4C"),
		"S": Color("#E8CF4F"), "Cl": Color("#A5C65A"), "Ar": Color("#8BC6D9"),
		"K": Color("#B6A0AE"), "Ca": Color("#C0B9AD"), "Fe": Color("#91A0AD"),
		"Cu": Color("#C77A50"), "Zn": Color("#9BAFAF"), "Br": Color("#9C4B32"),
		"Ag": Color("#D5DEE5"), "I": Color("#77639B"), "Au": Color("#D7B34D"),
		"Hg": Color("#BBC7D2"), "U": Color("#8B9C59"), "Pu": Color("#A89B68")
	}
	if palette.has(symbol):
		var selected: Color = palette[symbol]
		return selected
	var hue := fposmod(float(maxi(atomic_number, 1)) * 0.61803398875, 1.0)
	var saturation := 0.20 if _is_metal_category(category) else 0.48
	return Color.from_hsv(hue, saturation, 0.84)


func _draw() -> void:
	if _profile.is_empty():
		return
	var bounds := Rect2(Vector2.ZERO, size)
	var tint: Color = _profile.get("color", Color("#8C87FF"))
	draw_rect(bounds, Color("#0B1720"), true)
	var center := size * 0.5
	match str(_profile.get("form", "unknown_atom")):
		"solid_metal":
			if _symbol == "Mg":
				_draw_magnesium_ribbon(center, tint)
			else:
				_draw_metal_cube(center, tint)
		"solid_crystal":
			if _symbol == "C":
				_draw_graphite(center, tint)
			else:
				_draw_crystal_cluster(center, tint)
			_draw_symbol_tag(center, tint, _symbol)
		"solid_powder":
			_draw_powder_sample(center, tint)
		"solid_ribbon":
			_draw_magnesium_ribbon(center, tint)
		"liquid":
			_draw_liquid(center, tint)
		"gas_cylinder":
			_draw_gas_sample_cylinder(center, tint)
		_:
			_draw_conceptual_atom(center, tint)
			_draw_symbol_tag(center, tint, _symbol)
	if bool(_profile.get("restricted", false)):
		_draw_sealed_display_frame()
	draw_rect(Rect2(Vector2(1.0, 1.0), size - Vector2(2.0, 2.0)), Color("#365064"), false, 1.2, true)


func _draw_symbol_tag(center: Vector2, tint: Color, symbol: String) -> void:
	var tag := Rect2(center + Vector2(-20.0, 20.0), Vector2(40.0, 20.0))
	draw_rect(tag, Color(0.04, 0.09, 0.13, 0.78), true)
	draw_rect(tag, Color(tint.lightened(0.35), 0.8), false, 1.0)
	draw_string(ThemeDB.fallback_font, tag.position + Vector2(0.0, 15.0), symbol,
		HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 13, Color("#F8FBFD"))


func _draw_metal_cube(center: Vector2, tint: Color) -> void:
	var top := PackedVector2Array([
		center + Vector2(0.0, -30.0), center + Vector2(36.0, -11.0),
		center + Vector2(0.0, 8.0), center + Vector2(-36.0, -11.0)
	])
	var front := PackedVector2Array([
		center + Vector2(-36.0, -11.0), center + Vector2(0.0, 8.0),
		center + Vector2(0.0, 43.0), center + Vector2(-36.0, 23.0)
	])
	var side := PackedVector2Array([
		center + Vector2(0.0, 8.0), center + Vector2(36.0, -11.0),
		center + Vector2(36.0, 23.0), center + Vector2(0.0, 43.0)
	])
	draw_colored_polygon(top, tint.lightened(0.34))
	draw_colored_polygon(front, tint.darkened(0.12))
	draw_colored_polygon(side, tint.darkened(0.34))
	draw_polyline(PackedVector2Array([
		top[0], top[1], side[2], front[2], front[3], top[3], top[0]
	]), tint.lightened(0.55), 2.0, true)
	draw_line(center + Vector2(-25.0, -10.0), center + Vector2(-5.0, 1.0), Color(1.0, 1.0, 1.0, 0.32), 2.0, true)
	draw_string(ThemeDB.fallback_font, center + Vector2(-21.0, 24.0), _symbol,
		HORIZONTAL_ALIGNMENT_CENTER, 42.0, 16, Color("#F8FBFD"))


func _draw_magnesium_ribbon(center: Vector2, tint: Color) -> void:
	var back := PackedVector2Array([
		center + Vector2(-43.0, 21.0), center + Vector2(-31.0, -20.0),
		center + Vector2(32.0, -32.0), center + Vector2(41.0, -16.0),
		center + Vector2(-22.0, -5.0), center + Vector2(-30.0, 29.0)
	])
	draw_colored_polygon(back, tint.darkened(0.22))
	draw_polyline(back, tint.lightened(0.45), 1.7, true)
	var front := PackedVector2Array([
		center + Vector2(-42.0, 12.0), center + Vector2(-32.0, -25.0),
		center + Vector2(28.0, -36.0), center + Vector2(37.0, -21.0),
		center + Vector2(-25.0, -10.0), center + Vector2(-31.0, 21.0)
	])
	draw_colored_polygon(front, tint.lightened(0.18))
	draw_polyline(front, tint.lightened(0.58), 1.5, true)
	draw_line(center + Vector2(-21.0, -13.0), center + Vector2(25.0, -22.0), Color(1.0, 1.0, 1.0, 0.55), 1.8, true)
	draw_string(ThemeDB.fallback_font, center + Vector2(-12.0, 38.0), "Mg",
		HORIZONTAL_ALIGNMENT_CENTER, 24.0, 14, Color("#F8FBFD"))


func _draw_powder_sample(center: Vector2, tint: Color) -> void:
	var base := PackedVector2Array()
	for index in range(32):
		var angle := TAU * float(index) / 32.0
		base.append(center + Vector2(cos(angle) * 43.0, 20.0 + sin(angle) * 14.0))
	draw_colored_polygon(base, Color("#263440"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-40.0, 18.0), center + Vector2(-28.0, 1.0),
		center + Vector2(-12.0, -7.0), center + Vector2(9.0, -3.0),
		center + Vector2(29.0, 4.0), center + Vector2(40.0, 18.0)
	]), tint)
	for index in range(28):
		var x := (fposmod(float(index) * 0.618, 1.0) - 0.5) * 76.0
		var y := 7.0 + fposmod(float(index) * 0.371, 1.0) * 19.0
		draw_circle(center + Vector2(x, y), 1.2 + float(index % 3) * 0.4, tint.lightened(0.2))
	draw_string(ThemeDB.fallback_font, center + Vector2(-12.0, -15.0), _symbol,
		HORIZONTAL_ALIGNMENT_CENTER, 24.0, 14, Color("#1C2B33"))


func _draw_gas_sample_cylinder(center: Vector2, tint: Color) -> void:
	var body := Rect2(center + Vector2(-23.0, -31.0), Vector2(46.0, 68.0))
	draw_style_box(LabTheme.box(Color("#AFC1CA"), Color("#536D7B"), 2, 13, 3, 3), body)
	draw_rect(Rect2(center.x - 15.0, center.y - 39.0, 30.0, 9.0), LabColors.METAL)
	draw_rect(Rect2(center.x - 7.0, center.y - 47.0, 14.0, 8.0), LabColors.METAL.lightened(0.2))
	draw_rect(Rect2(center.x - 13.0, center.y - 15.0, 26.0, 30.0), Color(tint, 0.28))
	draw_line(center + Vector2(-15.0, -23.0), center + Vector2(-15.0, 27.0), Color(1.0, 1.0, 1.0, 0.65), 2.6, true)
	var gas_label := _symbol
	if DIATOMIC_GASES.has(_symbol):
		gas_label += "₂"
	draw_string(ThemeDB.fallback_font, center + Vector2(-16.0, 6.0), gas_label,
		HORIZONTAL_ALIGNMENT_CENTER, 32.0, 14, Color("#16242D"))


func _draw_crystal_cluster(center: Vector2, tint: Color) -> void:
	_draw_crystal_shard(center + Vector2(-20.0, 9.0), 31.0, 58.0, tint.darkened(0.12))
	_draw_crystal_shard(center + Vector2(15.0, 4.0), 34.0, 72.0, tint)
	_draw_crystal_shard(center + Vector2(39.0, 17.0), 22.0, 43.0, tint.darkened(0.24))


func _draw_crystal_shard(center: Vector2, width: float, height: float, tint: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(-width * 0.5, height * 0.40),
		center + Vector2(-width * 0.34, -height * 0.34),
		center + Vector2(0.0, -height * 0.5),
		center + Vector2(width * 0.42, -height * 0.18),
		center + Vector2(width * 0.5, height * 0.40)
	])
	draw_colored_polygon(points, tint)
	draw_colored_polygon(PackedVector2Array([
		points[1], points[2], center + Vector2(width * 0.04, height * 0.12), points[0]
	]), tint.lightened(0.36))
	draw_colored_polygon(PackedVector2Array([
		points[2], points[3], points[4], center + Vector2(width * 0.04, height * 0.12)
	]), tint.darkened(0.22))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[4]]), tint.lightened(0.42), 1.4, true)


func _draw_graphite(center: Vector2, tint: Color) -> void:
	for layer in range(3):
		var offset := Vector2(float(layer) * 6.0, float(layer) * -8.0)
		var plate := PackedVector2Array([
			center + offset + Vector2(-40.0, 12.0),
			center + offset + Vector2(-20.0, -10.0),
			center + offset + Vector2(39.0, -10.0),
			center + offset + Vector2(18.0, 12.0)
		])
		draw_colored_polygon(plate, tint.lightened(float(layer) * 0.10))
		draw_polyline(PackedVector2Array([plate[0], plate[1], plate[2], plate[3], plate[0]]), tint.lightened(0.35), 1.2, true)


func _draw_liquid(center: Vector2, tint: Color) -> void:
	draw_arc(center + Vector2(0.0, 15.0), 37.0, PI, TAU, 48, tint.darkened(0.3), 2.0, true)
	if _symbol == "Hg":
		draw_circle(center + Vector2(-17.0, 9.0), 17.0, tint.darkened(0.12))
		draw_circle(center + Vector2(11.0, 12.0), 23.0, tint)
		draw_circle(center + Vector2(32.0, 21.0), 11.0, tint.lightened(0.12))
		draw_circle(center + Vector2(3.0, 2.0), 7.0, Color(1.0, 1.0, 1.0, 0.58))
	else:
		draw_circle(center + Vector2(0.0, 11.0), 29.0, tint.darkened(0.16))
		draw_circle(center + Vector2(-8.0, 2.0), 18.0, tint)
		draw_circle(center + Vector2(-14.0, -5.0), 6.0, Color(1.0, 1.0, 1.0, 0.28))
	draw_string(ThemeDB.fallback_font, center + Vector2(-17.0, 39.0), _symbol,
		HORIZONTAL_ALIGNMENT_CENTER, 34.0, 14, Color("#24303A"))


func _draw_diatomic_molecule(center: Vector2, tint: Color) -> void:
	draw_arc(center, 43.0, 0.0, TAU, 56, Color("#55758A"), 1.4, true)
	draw_line(center + Vector2(-19.0, 0.0), center + Vector2(19.0, 0.0), tint.darkened(0.34), 8.0, true)
	draw_circle(center + Vector2(-20.0, 0.0), 18.0, tint.darkened(0.08))
	draw_circle(center + Vector2(20.0, 0.0), 18.0, tint)
	draw_circle(center + Vector2(-26.0, -7.0), 5.5, Color(1.0, 1.0, 1.0, 0.62))
	draw_circle(center + Vector2(14.0, -7.0), 5.5, Color(1.0, 1.0, 1.0, 0.62))


func _draw_monatomic_particle(center: Vector2, tint: Color) -> void:
	draw_arc(center, 39.0, 0.0, TAU, 64, Color(tint.r, tint.g, tint.b, 0.65), 1.5, true)
	draw_arc(center, 28.0, 0.7, TAU + 0.7, 64, Color(tint.r, tint.g, tint.b, 0.42), 1.2, true)
	draw_circle(center, 17.0, tint.darkened(0.08))
	draw_circle(center + Vector2(-5.0, -6.0), 6.0, Color(1.0, 1.0, 1.0, 0.72))
	draw_circle(center + Vector2(31.0, -22.0), 3.5, tint.lightened(0.45))


func _draw_conceptual_atom(center: Vector2, tint: Color) -> void:
	draw_arc(center, 40.0, 0.0, TAU, 64, Color(tint.r, tint.g, tint.b, 0.72), 1.4, true)
	draw_arc(center, 29.0, 0.55, TAU + 0.55, 64, Color(tint.r, tint.g, tint.b, 0.55), 1.4, true)
	draw_arc(center, 18.0, 1.15, TAU + 1.15, 64, Color(tint.r, tint.g, tint.b, 0.40), 1.2, true)
	draw_circle(center, 12.0, tint.lightened(0.12))
	draw_circle(center + Vector2(0.0, -40.0), 3.5, tint.lightened(0.45))
	draw_circle(center + Vector2(25.0, 15.0), 3.5, tint.lightened(0.45))
	draw_circle(center + Vector2(-17.0, -6.0), 3.5, tint.lightened(0.45))


func _draw_sealed_display_frame() -> void:
	var frame := Rect2(Vector2(5.0, 5.0), size - Vector2(10.0, 10.0))
	draw_rect(frame, Color(0.10, 0.20, 0.27, 0.08), true)
	draw_rect(frame, Color("#D1A85F"), false, 2.0, true)
	draw_line(Vector2(12.0, 13.0), Vector2(25.0, 13.0), Color("#D1A85F"), 2.0, true)
	draw_line(Vector2(12.0, 13.0), Vector2(12.0, 25.0), Color("#D1A85F"), 2.0, true)
	draw_line(Vector2(size.x - 12.0, size.y - 13.0), Vector2(size.x - 25.0, size.y - 13.0), Color("#D1A85F"), 2.0, true)
	draw_line(Vector2(size.x - 12.0, size.y - 13.0), Vector2(size.x - 12.0, size.y - 25.0), Color("#D1A85F"), 2.0, true)
