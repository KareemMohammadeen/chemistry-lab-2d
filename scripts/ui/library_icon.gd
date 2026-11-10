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


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result


static func _hash01(index: int, salt: float) -> float:
	return fposmod(sin(float(index) * 12.9898 + salt) * 43758.5453, 1.0)


func _profile_half_width_at(height: float) -> float:
	if profile.is_empty():
		return 0.0
	var first: Array = profile[0]
	if height <= float(first[0]):
		return float(first[1])
	for index in range(1, profile.size()):
		var lower: Array = profile[index - 1]
		var upper: Array = profile[index]
		if height <= float(upper[0]):
			var span := float(upper[0]) - float(lower[0])
			var blend := 0.0 if span <= 0.0 else (height - float(lower[0])) / span
			return lerpf(float(lower[1]), float(upper[1]), blend)
	var last: Array = profile[profile.size() - 1]
	return float(last[1])


## Builds a filled slice from the same equipment profile used by the full-size view.
## The liquid therefore follows the taper of an Erlenmeyer flask and the rounded end
## of a test tube instead of being painted as a rectangular block.
func _profile_slice_polygon(low_height: float, high_height: float, scale_factor: float,
		center_x: float, bottom: float) -> PackedVector2Array:
	var heights: Array = [low_height]
	for entry in profile:
		var point: Array = entry
		var height := float(point[0])
		if height > low_height and height < high_height:
			heights.append(height)
	heights.append(high_height)
	var polygon := PackedVector2Array()
	for height in heights:
		var half_width := _profile_half_width_at(float(height)) * scale_factor
		polygon.append(Vector2(center_x - half_width, bottom - float(height) * scale_factor))
	for index in range(heights.size() - 1, -1, -1):
		var height := float(heights[index])
		var half_width := _profile_half_width_at(height) * scale_factor
		polygon.append(Vector2(center_x + half_width, bottom - height * scale_factor))
	return polygon

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
	var body_height := box.size.y * BOTTLE_BODY_FRACTION
	var body := Rect2(box.position.x + 1.0, box.end.y - body_height, box.size.x - 2.0, body_height)
	var neck := Rect2(box.get_center().x - neck_width * 0.5, box.position.y + 6.0,
		neck_width, body.position.y - box.position.y - 4.0)

	# A compact modern reagent bottle: restrained glass tint, thin edge and a separate cap.
	draw_style_box(LabTheme.box(Color(LabColors.GLASS_FILL, 0.12), Color(LabColors.GLASS_EDGE, 0.86), 1, 6), body)
	draw_rect(neck, Color(LabColors.GLASS_FILL, 0.18))
	draw_line(Vector2(neck.position.x + 1.5, neck.position.y + 1.0),
		Vector2(neck.position.x + 1.5, neck.end.y), Color(1.0, 1.0, 1.0, 0.38), 1.0, true)
	draw_style_box(LabTheme.box(LabColors.METAL, LabColors.METAL.lightened(0.22), 1, 3),
		Rect2(neck.position.x - 1.0, box.position.y, neck.size.x + 2.0, 7.0))

	var fill := body.grow(-4.0)
	if kind == Kind.REAGENT_LIQUID:
		var liquid_top := fill.position.y + fill.size.y * 0.28
		var liquid := Rect2(fill.position.x + 1.0, liquid_top, fill.size.x - 2.0, fill.end.y - liquid_top - 1.0)
		draw_style_box(LabTheme.box(Color(tint, maxf(tint.a, 0.42)), Color(0.0, 0.0, 0.0, 0.0), 0, 4), liquid)
		var surface := _ellipse(Vector2(liquid.get_center().x, liquid.position.y + 1.0),
			maxf(liquid.size.x * 0.47, 0.5), 1.8)
		draw_colored_polygon(surface, Color(tint.lightened(0.12), minf(maxf(tint.a, 0.42) + 0.08, 0.68)))
		draw_polyline(_closed(surface), Color(1.0, 1.0, 1.0, 0.42), 0.8, true)
	else:
		var bed_top := fill.position.y + fill.size.y * 0.48
		var heap := PackedVector2Array([
			Vector2(fill.position.x + 1.0, fill.end.y - 1.0),
			Vector2(fill.position.x + 2.0, bed_top + 4.0),
			Vector2(fill.get_center().x, bed_top - 1.0),
			Vector2(fill.end.x - 2.0, bed_top + 4.0),
			Vector2(fill.end.x - 1.0, fill.end.y - 1.0)
		])
		draw_colored_polygon(heap, Color(tint, 0.84))
		for index in range(SPECKLE_COUNT):
			var fx := _hash01(index, 12.9898)
			var fy := _hash01(index, 78.233)
			var radius := 0.8 + _hash01(index, 4.17) * 1.0
			var x := lerpf(fill.position.x + 4.0, fill.end.x - 4.0, fx)
			var y := lerpf(bed_top + 3.0, fill.end.y - 4.0, fy)
			var grain := PackedVector2Array([
				Vector2(x - radius, y),
				Vector2(x, y - radius),
				Vector2(x + radius, y),
				Vector2(x, y + radius * 0.65)
			])
			draw_colored_polygon(grain, tint.lightened(0.16 if index % 3 == 0 else 0.03))

	# Highlights are inset from the body, so none can become a stray line outside the bottle.
	draw_line(Vector2(body.position.x + 5.0, body.position.y + 7.0),
		Vector2(body.position.x + 5.0, body.end.y - 7.0), Color(1.0, 1.0, 1.0, 0.30), 1.1, true)
	draw_line(Vector2(body.end.x - 4.5, body.position.y + 9.0),
		Vector2(body.end.x - 4.5, body.end.y - 9.0), Color(1.0, 1.0, 1.0, 0.12), 0.8, true)
	draw_style_box(LabTheme.box(Color(0.0, 0.0, 0.0, 0.0), LabColors.GLASS_EDGE, 1, 6), body)

func _draw_profile(with_bulb: bool) -> void:
	if profile.size() < 2:
		return
	var total_height := float(profile[profile.size() - 1][0])
	var max_width := 1.0
	for entry in profile:
		max_width = maxf(max_width, float(entry[1]))
	var bulb_space := 12.0 if with_bulb else 0.0
	var scale_factor := minf(
		(size.y - MARGIN_PX * 2.0 - bulb_space) / maxf(total_height, 1.0),
		(size.x * 0.5 - MARGIN_PX) / max_width
	)
	var center_x := size.x * 0.5
	var bottom := size.y - MARGIN_PX
	var outline := _profile_slice_polygon(0.0, total_height, scale_factor, center_x, bottom)
	if outline.is_empty():
		return

	# Frosted edge tint and a fine outline give all vessel thumbnails one consistent style.
	draw_colored_polygon(outline, Color(LabColors.GLASS_FILL, 0.14))

	# The sample liquid is drawn from the actual profile, not a rectangular fill.
	var liquid_height := total_height * 0.35
	var liquid := _profile_slice_polygon(0.0, liquid_height, scale_factor, center_x, bottom)
	draw_colored_polygon(liquid, Color(LabColors.CYAN, 0.30))
	var surface_width := _profile_half_width_at(liquid_height) * scale_factor
	var surface := _ellipse(Vector2(center_x, bottom - liquid_height * scale_factor),
		maxf(surface_width - 0.8, 0.5), 1.5)
	draw_colored_polygon(surface, Color(LabColors.CYAN.lightened(0.16), 0.32))
	draw_polyline(_closed(surface), Color(1.0, 1.0, 1.0, 0.38), 0.7, true)

	# Profile-following highlights remain inside a narrow test tube or a flask neck.
	var left_glint := PackedVector2Array()
	var right_glint := PackedVector2Array()
	for index in range(11):
		var fraction := lerpf(0.15, 0.90, float(index) / 10.0)
		var height := total_height * fraction
		var half_width := _profile_half_width_at(height) * scale_factor
		var inset := minf(2.0, half_width * 0.42)
		if half_width - inset > 0.8:
			var y := bottom - height * scale_factor
			left_glint.append(Vector2(center_x - half_width + inset, y))
			right_glint.append(Vector2(center_x + half_width - inset, y))
	if not left_glint.is_empty():
		draw_polyline(left_glint, Color(1.0, 1.0, 1.0, 0.42), 1.0, true)
	if not right_glint.is_empty():
		draw_polyline(right_glint, Color(1.0, 1.0, 1.0, 0.15), 0.7, true)

	draw_polyline(_closed(outline), Color(LabColors.GLASS_EDGE, 0.94), 1.25, true)

	if with_bulb:
		var top_y := bottom - total_height * scale_factor
		draw_style_box(LabTheme.box(LabColors.METAL, LabColors.METAL.lightened(0.18), 1, 2),
			Rect2(center_x - 4.5, top_y - 3.0, 9.0, 3.0))
		var bulb := _ellipse(Vector2(center_x, top_y - 8.0), 5.0, 6.0)
		draw_colored_polygon(bulb, LabColors.RUBBER)
		draw_arc(Vector2(center_x - 1.0, top_y - 9.0), 2.4, PI * 1.1, PI * 1.85, 8,
			Color(1.0, 1.0, 1.0, 0.24), 0.7, true)

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
