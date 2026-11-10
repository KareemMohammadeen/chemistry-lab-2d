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
	var neck_width := box.size.x * 0.42
	var body := Rect2(box.position.x, box.end.y - box.size.y * BOTTLE_BODY_FRACTION, box.size.x, box.size.y * BOTTLE_BODY_FRACTION)
	var neck := Rect2(box.get_center().x - neck_width * 0.5, box.position.y + 6.0, neck_width, body.position.y - box.position.y - 4.0)
	draw_rect(neck, Color(LabColors.GLASS_FILL, 0.3))
	draw_rect(Rect2(neck.position.x - 1.0, box.position.y, neck.size.x + 2.0, 7.0), LabColors.METAL)
	draw_style_box(LabTheme.box(Color(LabColors.GLASS_FILL, 0.25), LabColors.GLASS_EDGE, 2, 8), body)
	var fill := body.grow(-3.0)
	if kind == Kind.REAGENT_LIQUID:
		fill.position.y += fill.size.y * 0.25
		fill.size.y *= 0.75
		draw_style_box(LabTheme.box(Color(tint, maxf(tint.a, 0.55)), Color(0, 0, 0, 0), 0, 5), fill)
	else:
		var heap := Rect2(fill.position.x, fill.end.y - fill.size.y * 0.5, fill.size.x, fill.size.y * 0.5)
		draw_style_box(LabTheme.box(Color(tint, 1.0), Color(0, 0, 0, 0), 0, 5), heap)
		for index in range(SPECKLE_COUNT):
			var fx := fmod(float(index) * 0.618, 1.0)
			var fy := fmod(float(index) * 0.381 + 0.2, 1.0)
			draw_circle(Vector2(heap.position.x + 3.0 + fx * (heap.size.x - 6.0), heap.position.y + 2.0 + fy * (heap.size.y - 4.0)),
				1.4, Color(1.0, 1.0, 1.0, 0.35))
	draw_rect(Rect2(body.position.x + 6.0, body.position.y + 6.0, 3.0, body.size.y - 12.0), Color(1.0, 1.0, 1.0, 0.3))


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
