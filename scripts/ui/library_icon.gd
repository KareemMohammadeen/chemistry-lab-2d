class_name LibraryIcon
extends Control
## The small picture on a Library card: a reagent bottle filled with the substance's colour, or
## a silhouette of a piece of equipment drawn from its vessel profile. Display only.

enum Kind { REAGENT_LIQUID, REAGENT_SOLID, VESSEL, DROPPER, THERMOMETER, HOT_PLATE }

const ICON_SIZE := Vector2(52.0, 60.0)
const MARGIN_PX := 4.0
const BOTTLE_BODY_FRACTION := 0.62
const SPECKLE_COUNT := 14

var kind: Kind = Kind.VESSEL
var tint: Color = Color.WHITE
## Vessel profile [[height, half_width], ...] in laboratory pixels (equipment only).
var profile: Array = []


func _ready() -> void:
	custom_minimum_size = ICON_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(new_kind: Kind, new_tint: Color, new_profile: Array = []) -> void:
	kind = new_kind
	tint = new_tint
	profile = new_profile
	queue_redraw()


static func _ellipse(center: Vector2, radius_x: float, radius_y: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


static func _hash01(index: int, salt: float) -> float:
	return fposmod(sin(float(index) * 12.9898 + salt) * 43758.5453, 1.0)


func _draw() -> void:
	match kind:
		Kind.REAGENT_LIQUID, Kind.REAGENT_SOLID:
			_draw_reagent()
		Kind.VESSEL:
			_draw_profile(false)
		Kind.DROPPER:
			_draw_profile(true)
		Kind.THERMOMETER:
			_draw_thermometer()
		Kind.HOT_PLATE:
			_draw_hot_plate()


func _draw_reagent() -> void:
	var box := Rect2(Vector2(MARGIN_PX, MARGIN_PX), size - Vector2(MARGIN_PX, MARGIN_PX) * 2.0)
	var neck_width := box.size.x * 0.38
	var body := Rect2(box.position.x + 1.0, box.end.y - box.size.y * BOTTLE_BODY_FRACTION, box.size.x - 2.0, box.size.y * BOTTLE_BODY_FRACTION)
	var neck := Rect2(box.get_center().x - neck_width * 0.5, box.position.y + 6.0, neck_width, body.position.y - box.position.y - 4.0)

	# Cap, neck and shoulders are layered so the reagent thumbnail reads as a glass bottle.
	draw_rect(Rect2(neck.position.x - 1.0, box.position.y, neck.size.x + 2.0, 7.0), LabColors.METAL)
	draw_line(Vector2(neck.position.x, box.position.y + 1.0), Vector2(neck.end.x, box.position.y + 1.0), Color(1.0, 1.0, 1.0, 0.30), 1.0)
	draw_rect(neck, Color(LabColors.GLASS_FILL, 0.24))
	draw_line(Vector2(neck.position.x + 2.0, neck.position.y + 2.0), Vector2(neck.position.x + 2.0, neck.end.y), Color(1.0, 1.0, 1.0, 0.34), 1.0)

	draw_style_box(LabTheme.box(Color(LabColors.GLASS_FILL, 0.15), Color(LabColors.GLASS_EDGE, 0.92), 1, 7), body)
	var fill := body.grow(-4.0)
	if kind == Kind.REAGENT_LIQUID:
		var liquid_top := fill.position.y + fill.size.y * 0.28
		var liquid := Rect2(fill.position.x + 1.0, liquid_top, fill.size.x - 2.0, fill.end.y - liquid_top - 1.0)
		draw_rect(liquid, Color(tint, maxf(tint.a, 0.48)))
		var surface := _ellipse(Vector2(liquid.get_center().x, liquid.position.y + 1.0), liquid.size.x * 0.5, 2.3)
		draw_colored_polygon(surface, Color(tint.lightened(0.12), minf(maxf(tint.a, 0.48) + 0.10, 0.72)))
		surface.append(surface[0])
		draw_polyline(surface, Color(1.0, 1.0, 1.0, 0.45), 1.0, true)
		draw_line(Vector2(liquid.position.x + 2.0, liquid.position.y + 7.0), Vector2(liquid.position.x + 2.0, liquid.end.y - 3.0),
			Color(1.0, 1.0, 1.0, 0.18), 1.0, true)
	else:
		var bed_top := fill.position.y + fill.size.y * 0.48
		var heap := PackedVector2Array([
			Vector2(fill.position.x + 1.0, fill.end.y - 1.0),
			Vector2(fill.position.x + 2.0, bed_top + 5.0),
			Vector2(fill.get_center().x, bed_top - 1.0),
			Vector2(fill.end.x - 2.0, bed_top + 5.0),
			Vector2(fill.end.x - 1.0, fill.end.y - 1.0)
		])
		draw_colored_polygon(heap, Color(tint, 0.88))
		for index in range(SPECKLE_COUNT + 8):
			var fx := _hash01(index, 12.9898)
			var fy := _hash01(index, 78.233)
			var x := lerpf(fill.position.x + 4.0, fill.end.x - 4.0, fx)
			var y := lerpf(bed_top + 3.0, fill.end.y - 4.0, fy)
			var radius := 1.0 + _hash01(index, 4.17) * 1.4
			var grain := PackedVector2Array([
				Vector2(x - radius, y),
				Vector2(x, y - radius),
				Vector2(x + radius, y),
				Vector2(x, y + radius * 0.7)
			])
			draw_colored_polygon(grain, tint.lightened(0.18 if index % 3 == 0 else 0.04))

	# Fine inner reflections and a restrained outer edge avoid the chunky cartoon outline.
	draw_line(Vector2(body.position.x + 5.0, body.position.y + 7.0), Vector2(body.position.x + 5.0, body.end.y - 7.0),
		Color(1.0, 1.0, 1.0, 0.34), 1.2, true)
	draw_line(Vector2(body.end.x - 4.0, body.position.y + 10.0), Vector2(body.end.x - 4.0, body.end.y - 10.0),
		Color(1.0, 1.0, 1.0, 0.13), 1.0, true)
	draw_style_box(LabTheme.box(Color(0.0, 0.0, 0.0, 0.0), LabColors.GLASS_EDGE, 1, 7), body)

func _draw_profile(with_bulb: bool) -> void:
	if profile.size() < 2:
		return
	var total_height := float(profile[profile.size() - 1][0])
	var max_width := 1.0
	for entry in profile:
		max_width = maxf(max_width, float(entry[1]))
	var bulb := 12.0 if with_bulb else 0.0
	var scale_factor := minf((size.y - MARGIN_PX * 2.0 - bulb) / maxf(total_height, 1.0), (size.x * 0.5 - MARGIN_PX) / max_width)
	var center_x := size.x * 0.5
	var bottom := size.y - MARGIN_PX
	# Outline: bottom-left corner, up the left wall, down the right wall, bottom-right corner.
	var outline := PackedVector2Array()
	var base_half := float(profile[0][1]) * scale_factor
	outline.append(Vector2(center_x - base_half, bottom))
	for entry in profile:
		outline.append(Vector2(center_x - float(entry[1]) * scale_factor, bottom - float(entry[0]) * scale_factor))
	for index in range(profile.size() - 1, -1, -1):
		var entry: Array = profile[index]
		outline.append(Vector2(center_x + float(entry[1]) * scale_factor, bottom - float(entry[0]) * scale_factor))
	outline.append(Vector2(center_x + base_half, bottom))
	draw_colored_polygon(outline, Color(LabColors.GLASS_FILL, 0.2))
	draw_polyline(outline, LabColors.GLASS_EDGE, 2.0, true)
	# A band of liquid in the lower third.
	var liquid_height := total_height * 0.35 * scale_factor
	var half_low := float(profile[0][1]) * scale_factor
	if profile.size() > 2 and float(profile[1][0]) > 0.0:
		half_low = lerpf(float(profile[0][1]), float(profile[1][1]), minf(liquid_height / (float(profile[1][0]) * scale_factor), 1.0)) * scale_factor
	draw_rect(Rect2(center_x - half_low + 2.0, bottom - liquid_height, half_low * 2.0 - 4.0, liquid_height - 1.0), Color(LabColors.CYAN, 0.35))
	if with_bulb:
		draw_rect(Rect2(center_x - 5.0, MARGIN_PX + bulb - 3.0, 10.0, 3.0), LabColors.METAL)
		draw_circle(Vector2(center_x, MARGIN_PX + bulb * 0.5), 6.0, LabColors.RUBBER)


func _draw_thermometer() -> void:
	var center_x := size.x * 0.5
	var top := MARGIN_PX + 2.0
	var bottom := size.y - MARGIN_PX - 8.0
	draw_style_box(LabTheme.box(Color(LabColors.GLASS_FILL, 0.25), LabColors.GLASS_EDGE, 2, 4), Rect2(center_x - 4.0, top, 8.0, bottom - top))
	draw_circle(Vector2(center_x, bottom + 2.0), 7.0, LabColors.LIQUID_THERMOMETER)
	draw_rect(Rect2(center_x - 1.5, top + (bottom - top) * 0.4, 3.0, (bottom - top) * 0.6), LabColors.LIQUID_THERMOMETER)
	for index in range(5):
		var y := top + 6.0 + float(index) * (bottom - top - 10.0) / 4.0
		draw_line(Vector2(center_x + 6.0, y), Vector2(center_x + 12.0, y), LabColors.TEXT_MUTED, 1.5)


func _draw_hot_plate() -> void:
	var slab := Rect2(MARGIN_PX, size.y * 0.5, size.x - MARGIN_PX * 2.0, size.y * 0.32)
	draw_style_box(LabTheme.box(LabColors.METAL, LabColors.METAL.lightened(0.3), 1, 5), slab)
	draw_rect(Rect2(slab.position.x + 4.0, slab.position.y - 5.0, slab.size.x - 8.0, 5.0), LabColors.HEAT.darkened(0.2))
	draw_circle(Vector2(slab.position.x + 12.0, slab.get_center().y), 4.5, LabColors.TEXT_ON_DARK)
	draw_circle(Vector2(slab.end.x - 12.0, slab.get_center().y), 3.0, LabColors.ACCENT)
