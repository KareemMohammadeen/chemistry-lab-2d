class_name EquipmentView
extends Node2D
## Draws one piece of equipment in the front view. It only displays the simulation state:
## it reads the object and its vessel every frame and never changes them. Liquid level and
## colour ease toward the true values so changes look calm instead of jumping.

## Speed (per second) at which the drawn liquid level approaches the true level.
const LEVEL_SMOOTHING := 5.0
const COLOR_SMOOTHING := 4.0
const READING_SMOOTHING := 4.0
const HIT_PADDING := 10.0
const THIN_HIT_PADDING := 16.0
const SHADOW_HEIGHT := 7.0
const CORNER_LENGTH := 16.0
const MIN_VISIBLE_ML := 0.01
const BUBBLE_COUNT := 6
const FONT_SIZE_SMALL := 14
const FONT_SIZE_LABEL := 13
const GRADUATION_MAJOR_EVERY := 2
const CAP_HEIGHT := 14.0
const SELECTION_GLOW_PAD := 26.0
const SELECTION_GLOW_HEIGHT := 11.0
const LABEL_HALF_WIDTH := 52.0
const LABEL_TOP := 98.0
const LABEL_HEIGHT := 74.0
const LABEL_BAND_HEIGHT := 9.0
const LABEL_PADDING := 5.0
const LABEL_NAME_SIZE := 17
const LABEL_FORMULA_SIZE := 15
const LABEL_MIN_SIZE := 12
const THERMOMETER_BULB_RADIUS := 8.0
const THERMOMETER_STEM_HALF_WIDTH := 4.0
const THERMOMETER_TICK_EVERY_C := 20.0
const RIM_HEIGHT := 5.0
const HEAT_START_C := 45.0
const HEAT_FULL_C := 95.0
const STEAM_START_C := 70.0
const STEAM_WISP_COUNT := 4
const CONVECTION_PARTICLES := 10
const SPECKLE_COUNT := 12
const ELLIPSE_STEPS := 28
const GLASS_TINT := Color(0.85, 0.93, 0.97)
const PLATE_GLOW := Color("#F0A04B")
const KNOB_SWEEP_RAD := 2.3
const DRAG_LIFT_PX := 22.0
const DRAG_SCALE_FACTOR := 1.045
const DRAG_EASE_SPEED := 14.0
const DROP_PULSE_SPEED := 3.6

var object_id: String = ""
## Equipment definition this view was built for. Geometry, drawing and the hit box are all cached from it
## in bind(), so the workspace must replace the view when the object behind `object_id` is not this equipment.
var bound_equipment_id: String = ""
var is_selected: bool = false
var is_hovered: bool = false
var is_being_dragged: bool = false
var is_drop_target: bool = false
var drop_target_valid: bool = false
var drag_tilt_target: float = 0.0
## Where the object stands (base point), set by the workspace.
var anchor: Vector2 = Vector2.ZERO
## Temporary displacement and tilt used by pour animations.
var visual_offset: Vector2 = Vector2.ZERO
var visual_tilt: float = 0.0
## Last visible contents colours, kept so a pour animation still has a colour after the
## source has been emptied.
var last_liquid_color: Color = Color(0.6, 0.8, 1.0, 0.8)
var last_solid_color: Color = Color(0.9, 0.9, 0.9, 1.0)

var _sim: LabSimulation
var _equipment: EquipmentDefinition
var _profile: Array = []
var _shown_level: float = 0.0
var _shown_solid_ml: float = 0.0
var _shown_color: Color = Color(1.0, 1.0, 1.0, 0.0)
var _shown_reading_c: float = 22.0
## Static tick marks [{height, width, major, label}], computed once because the geometry never changes.
var _graduations: Array = []
var _drag_progress: float = 0.0
var _drag_rotation: float = 0.0
## Fitted paper-label lines of a bottle, recomputed only when its contents' main chemical changes.
var _label_key: String = "?"
var _label_lines: Array = []
var _plate_style: StyleBoxFlat = _make_plate_style()
var _chip_style: StyleBoxFlat = _make_chip_style()


func bind(sim: LabSimulation, new_object_id: String) -> void:
	_sim = sim
	object_id = new_object_id
	var item := sim.state.get_object(object_id)
	bound_equipment_id = item.equipment_id
	_equipment = sim.database.get_equipment(item.equipment_id)
	_profile = _equipment.visual.get("profile", [])
	_graduations = _build_graduations()
	anchor = item.position
	if item.vessel != null:
		_shown_level = _target_level(item.vessel)
		_shown_solid_ml = _solid_volume_ml(item.vessel)
		_shown_color = SolutionAppearance.liquid_color(item.vessel, sim.database)
	_shown_reading_c = _current_reading()
	_remember_colors()
	queue_redraw()


func equipment_definition() -> EquipmentDefinition:
	return _equipment


# ---------------------------------------------------------------- geometry for other classes

func visual_height() -> float:
	return float(_equipment.visual.get("height", 100.0))


func half_width() -> float:
	var declared := float(_equipment.visual.get("half_width", 0.0))
	if declared > 0.0:
		return declared
	var from_profile := VesselGeometry.max_half_width(_profile)
	return from_profile if from_profile > 0.0 else THERMOMETER_STEM_HALF_WIDTH + THERMOMETER_BULB_RADIUS


func local_bounds() -> Rect2:
	var padding := THIN_HIT_PADDING if half_width() < THIN_HIT_PADDING else HIT_PADDING
	var width := half_width() + padding
	return Rect2(-width, -visual_height() - padding, width * 2.0, visual_height() + padding * 2.0)


func drag_visual_progress() -> float:
	return _drag_progress


func drag_lift_offset() -> Vector2:
	return Vector2.UP * DRAG_LIFT_PX * _drag_progress


func drag_rotation_offset() -> float:
	return _drag_rotation


## True when a point in laboratory pixels is on this object. The Views node sits at the
## workspace origin, so this view's own transform maps laboratory pixels to local ones even
## while the whole workspace is scaled to fit the stage.
func contains_point(point: Vector2) -> bool:
	return local_bounds().has_point(get_transform().affine_inverse() * point)


## The lip the contents leave from when tilted, in local pixels.
func pour_lip_local() -> Vector2:
	return _equipment.point("pour_lip", Vector2(half_width(), -visual_height()))


## The centre of the opening, in laboratory pixels (without animation offsets).
func opening_global() -> Vector2:
	return anchor + _equipment.point("opening", Vector2(0.0, -visual_height()))


## Height (laboratory pixels, y down) of the surface of the contents, for stream end points.
func surface_global_y() -> float:
	var item := _sim.state.get_object(object_id)
	if item == null or item.vessel == null:
		return anchor.y
	var solid_fraction := _solid_volume_ml(item.vessel) / maxf(item.vessel.capacity_ml, 1.0)
	var level := maxf(_shown_level, solid_fraction)
	return anchor.y - VesselGeometry.height_for_fraction(_profile, level)


# ---------------------------------------------------------------- per-frame state

func _process(delta: float) -> void:
	var drag_blend := 1.0 - exp(-DRAG_EASE_SPEED * delta)
	_drag_progress = lerpf(_drag_progress, 1.0 if is_being_dragged else 0.0, drag_blend)
	var wanted_drag_rotation := drag_tilt_target if is_being_dragged else 0.0
	_drag_rotation = lerpf(_drag_rotation, wanted_drag_rotation, drag_blend)
	scale = Vector2.ONE * lerpf(1.0, DRAG_SCALE_FACTOR, _drag_progress)
	if _sim == null:
		return
	var item := _sim.state.get_object(object_id)
	if item == null:
		return
	if item.vessel != null:
		_ease_vessel(item.vessel, delta)
	elif not _equipment.thermometer.is_empty():
		var reading := _current_reading()
		_shown_reading_c = lerpf(_shown_reading_c, reading, 1.0 - exp(-READING_SMOOTHING * delta))
	_remember_colors()
	queue_redraw()


func _ease_vessel(vessel: VesselState, delta: float) -> void:
	var blend := 1.0 - exp(-LEVEL_SMOOTHING * delta)
	_shown_level = lerpf(_shown_level, _target_level(vessel), blend)
	_shown_solid_ml = lerpf(_shown_solid_ml, _solid_volume_ml(vessel), blend)
	var target := SolutionAppearance.liquid_color(vessel, _sim.database)
	if target.a <= 0.0:
		target = Color(_shown_color.r, _shown_color.g, _shown_color.b, 0.0)
	elif _shown_color.a < 0.02:
		_shown_color = Color(target.r, target.g, target.b, _shown_color.a)
	_shown_color = _shown_color.lerp(target, 1.0 - exp(-COLOR_SMOOTHING * delta))


func _target_level(vessel: VesselState) -> float:
	return clampf(vessel.liquid_volume_ml() / maxf(vessel.capacity_ml, 1.0), 0.0, 1.0)


func _solid_volume_ml(vessel: VesselState) -> float:
	var total := 0.0
	for chemical_id in vessel.solids.keys():
		var chemical := _sim.database.get_chemical(str(chemical_id))
		var density := 1.0 if chemical == null else maxf(chemical.density_g_ml, 0.1)
		total += float(vessel.solids[chemical_id]) / density
	return total


func _current_reading() -> float:
	return _sim.thermometer_reading_c(object_id)


func _remember_colors() -> void:
	if _shown_color.a > 0.1:
		last_liquid_color = _shown_color
	var item := _sim.state.get_object(object_id)
	if item == null or item.vessel == null:
		return
	for chemical_id in item.vessel.solids.keys():
		var chemical := _sim.database.get_chemical(str(chemical_id))
		if chemical != null:
			last_solid_color = Color(chemical.color.r, chemical.color.g, chemical.color.b, 1.0)
			return


# ---------------------------------------------------------------- drawing helpers

static func _make_plate_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = LabColors.METAL
	style.set_corner_radius_all(8)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	return style


static func _make_chip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = LabColors.WARNING
	style.set_corner_radius_all(6)
	return style


static func _ellipse(center: Vector2, radius_x: float, radius_y: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(ELLIPSE_STEPS):
		var angle := TAU * float(index) / float(ELLIPSE_STEPS)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	result.append(points[0])
	return result


## Pseudo-random 0..1 value that is stable for an index (for crystal speckles).
static func _hash01(index: int, salt: float) -> float:
	return fposmod(sin(float(index) * 12.9898 + salt) * 43758.5453, 1.0)


func _seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


## 0..1 how hot a liquid looks.
func _heat_factor(temperature_c: float) -> float:
	return clampf((temperature_c - HEAT_START_C) / (HEAT_FULL_C - HEAT_START_C), 0.0, 1.0)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if _sim == null or _equipment == null:
		return
	var item := _sim.state.get_object(object_id)
	if item == null:
		return
	_draw_shadow()
	match _equipment.style():
		"hot_plate":
			_draw_hot_plate(item)
		"thermometer":
			_draw_thermometer()
		"dropper":
			_draw_vessel_body(item.vessel)
			_draw_dropper_bulb()
		"bottle":
			_draw_vessel_body(item.vessel)
			_draw_bottle_parts(item.vessel)
		_:
			_draw_vessel_body(item.vessel)
	_draw_hot_label(item)
	_draw_marks()


## Soft contact shadow: three stacked ellipses fading outward.
func _draw_shadow() -> void:
	var width := half_width() + 6.0
	var shadow_alpha := lerpf(0.07, 0.018, _drag_progress)
	for layer in range(3):
		var grow := float(layer) * 5.0
		draw_colored_polygon(_ellipse(Vector2(0.0, 2.0), width + grow, SHADOW_HEIGHT + grow * 0.35),
			Color(0.0, 0.0, 0.0, shadow_alpha))


func _draw_vessel_body(vessel: VesselState) -> void:
	if _profile.is_empty():
		return
	var top := VesselGeometry.top_height(_profile)
	var glass := VesselGeometry.slice_polygon(_profile, 0.0, top)
	draw_polygon(glass, _glass_colors(glass))
	if vessel != null:
		_draw_contents(vessel)
		if vessel.has_gas():
			_draw_virtual_gas_particles(top)
	_draw_glass_details(top)
	if vessel != null and vessel.is_closed_system:
		_draw_virtual_stopper(top)
	_draw_graduations()
	if vessel != null and _shown_color.a > 0.1:
		_draw_steam(vessel.temperature_c, top)



## A visible plug makes the open/closed model state explicit in the scene.
func _draw_virtual_stopper(top: float) -> void:
	var rim_width := VesselGeometry.half_width_at(_profile, top)
	var stopper := Rect2(-rim_width - 5.0, -top - 8.0, rim_width * 2.0 + 10.0, 11.0)
	draw_style_box(LabTheme.box(LabColors.METAL.darkened(0.18), LabColors.METAL.lightened(0.2), 1, 4, 2, 2), stopper)
	draw_line(Vector2(-rim_width, -top - 3.0), Vector2(rim_width, -top - 3.0), Color(1.0, 1.0, 1.0, 0.6), 1.2, true)
	draw_string(ThemeDB.fallback_font, Vector2(-22.0, -top - 13.0), "SEALED", HORIZONTAL_ALIGNMENT_CENTER, 44.0, 9, LabColors.TEXT_PRIMARY)


func _draw_virtual_gas_particles(top: float) -> void:
	var time_s := _seconds()
	var width := VesselGeometry.half_width_at(_profile, top * 0.55) * 0.55
	for index in range(5):
		var phase := fposmod(time_s * 0.18 + float(index) * 0.19, 1.0)
		var x := sin(time_s * 0.55 + float(index) * 2.1) * width
		var y := -top * (0.20 + phase * 0.24)
		draw_circle(Vector2(x, y), 2.2, Color("#B8E7F1", 0.34))


## Glass is denser toward its edges, clearer in the middle.
func _glass_colors(polygon: PackedVector2Array) -> PackedColorArray:
	var widest := maxf(VesselGeometry.max_half_width(_profile), 1.0)
	var colors := PackedColorArray()
	for point in polygon:
		colors.append(Color(GLASS_TINT, lerpf(0.07, 0.28, clampf(absf(point.x) / widest, 0.0, 1.0))))
	return colors


func _draw_glass_details(top: float) -> void:
	var wall := maxf(float(_equipment.visual.get("wall_px", 3.0)), 1.5)
	var foot_height := minf(6.0, maxf(top * 0.06, 2.5))
	var foot := VesselGeometry.slice_polygon(_profile, 0.0, foot_height)
	draw_polygon(foot, _uniform_colors(foot, Color(LabColors.GLASS_EDGE, 0.16)))
	draw_polyline(VesselGeometry.wall_polyline(_profile), Color(LabColors.GLASS_EDGE, 0.88), wall, true)

	# A second, finer inner rim gives the opening a glass-wall thickness instead of a flat outline.
	var rim_width := VesselGeometry.half_width_at(_profile, top)
	var outer_rim := _ellipse(Vector2(0.0, -top), rim_width, RIM_HEIGHT)
	draw_colored_polygon(outer_rim, Color(LabColors.GLASS_EDGE, 0.10))
	draw_polyline(_closed(outer_rim), Color(LabColors.GLASS_EDGE, 0.92), 1.8, true)
	var inner_rim := _ellipse(Vector2(0.0, -top + 1.2), maxf(rim_width - wall * 1.6, 1.0), RIM_HEIGHT * 0.48)
	draw_polyline(_closed(inner_rim), Color(1.0, 1.0, 1.0, 0.34), 1.0, true)

	# Long, soft reflections and a heavier base reflection make the vessel read as borosilicate glass.
	var mid_width := VesselGeometry.half_width_at(_profile, top * 0.52)
	var inset := maxf(mid_width - wall - 5.0, 1.0)
	draw_line(Vector2(-inset, -top * 0.10), Vector2(-inset, -top * 0.88), Color(1.0, 1.0, 1.0, 0.48), 2.2, true)
	draw_line(Vector2(-inset + 5.0, -top * 0.22), Vector2(-inset + 5.0, -top * 0.70), Color(1.0, 1.0, 1.0, 0.17), 1.2, true)
	var right_inset := maxf(mid_width - wall * 2.0, 1.0)
	draw_line(Vector2(right_inset, -top * 0.20), Vector2(right_inset, -top * 0.54), Color(1.0, 1.0, 1.0, 0.20), 1.2, true)
	var base_width := VesselGeometry.half_width_at(_profile, 0.0)
	var base_reflection := _ellipse(Vector2(0.0, -2.0), maxf(base_width - 1.0, 1.0), 2.4)
	draw_polyline(_closed(base_reflection), Color(1.0, 1.0, 1.0, 0.30), 1.1, true)


func _uniform_colors(polygon: PackedVector2Array, color: Color) -> PackedColorArray:
	var colors := PackedColorArray()
	colors.resize(polygon.size())
	colors.fill(color)
	return colors


func _draw_contents(vessel: VesselState) -> void:
	var level_height := VesselGeometry.height_for_fraction(_profile, _shown_level)
	var heat := _heat_factor(vessel.temperature_c)
	if _shown_color.a > 0.01 and level_height > 0.5:
		_draw_liquid(level_height, vessel, heat)
	if _shown_solid_ml > MIN_VISIBLE_ML:
		_draw_solid(vessel)


func _draw_liquid(level_height: float, vessel: VesselState, heat: float) -> void:
	var body := VesselGeometry.slice_polygon(_profile, 0.0, level_height)
	var deep := _shown_color.darkened(0.22)
	var light := _shown_color.lightened(0.08)
	var colors := PackedColorArray()
	for point in body:
		var vertical := clampf(-point.y / maxf(level_height, 0.01), 0.0, 1.0)
		colors.append(deep.lerp(light, vertical))
	draw_polygon(body, colors)

	# The meniscus is deliberately subtle: a translucent surface, a fine bright edge and
	# a darker inner contour make the liquid feel contained by glass rather than painted on.
	var surface_width := VesselGeometry.half_width_at(_profile, level_height)
	var surface_height := RIM_HEIGHT * 0.72
	var surface := _ellipse(Vector2(0.0, -level_height), surface_width, surface_height)
	draw_colored_polygon(surface, Color(light, minf(_shown_color.a + 0.12, 0.58)))
	draw_polyline(_closed(surface), Color(1.0, 1.0, 1.0, 0.42), 1.2, true)
	var inner_surface := _ellipse(Vector2(0.0, -level_height + 1.0), surface_width * 0.82, surface_height * 0.38)
	draw_polyline(_closed(inner_surface), Color(deep, 0.38), 0.8, true)

	# Narrow side refractions stay inside the vessel profile, including tapered test tubes.
	var lower_y := level_height * 0.16
	var upper_y := level_height * 0.84
	var lower_x := VesselGeometry.half_width_at(_profile, lower_y) * 0.72
	var upper_x := VesselGeometry.half_width_at(_profile, upper_y) * 0.72
	draw_line(Vector2(-lower_x, -lower_y), Vector2(-upper_x, -upper_y), Color(1.0, 1.0, 1.0, 0.18), 1.0, true)
	draw_line(Vector2(lower_x, -lower_y), Vector2(upper_x, -upper_y), Color(1.0, 1.0, 1.0, 0.09), 1.0, true)

	if heat > 0.05:
		_draw_convection(level_height, heat)
	if HeatSystem.is_boiling(vessel, _sim.database):
		_draw_bubbles(level_height)


## Faint rising specks: warm liquid circulates, faster the hotter it is.
func _draw_convection(level_height: float, heat: float) -> void:
	var time_s := _seconds()
	var count := int(ceil(float(CONVECTION_PARTICLES) * heat))
	for index in range(count):
		var phase := fmod(time_s * (0.2 + heat * 0.6) + float(index) * 0.137, 1.0)
		var y := phase * level_height * 0.92
		var width := VesselGeometry.half_width_at(_profile, y) * 0.72
		var x := sin(float(index) * 4.1 + time_s * 0.7) * width
		draw_circle(Vector2(x, -y), 1.7, Color(1.0, 1.0, 1.0, 0.3 * (1.0 - phase * 0.5)))


func _draw_bubbles(level_height: float) -> void:
	var time_s := _seconds()
	for index in range(BUBBLE_COUNT * 2):
		var phase := fmod(time_s * 0.9 + float(index) * 0.31, 1.0)
		var bubble_height := phase * level_height
		var width := VesselGeometry.half_width_at(_profile, bubble_height) * 0.78
		var x := sin(float(index) * 2.3 + time_s * 1.3) * width
		var radius := 2.0 + float(index % 3)
		draw_circle(Vector2(x, -bubble_height), radius, Color(1.0, 1.0, 1.0, 0.18))
		draw_arc(Vector2(x, -bubble_height), radius, 0.0, TAU, 12, Color(1.0, 1.0, 1.0, 0.6), 1.0, true)


func _draw_solid(vessel: VesselState) -> void:
	var fraction := clampf(_shown_solid_ml / maxf(vessel.capacity_ml, 1.0), 0.0, 1.0)
	var solid_height := maxf(VesselGeometry.height_for_fraction(_profile, fraction), 2.0)
	var body := VesselGeometry.slice_polygon(_profile, 0.0, solid_height)
	var colors := PackedColorArray()
	for point in body:
		var vertical := clampf(-point.y / solid_height, 0.0, 1.0)
		colors.append(last_solid_color.darkened(0.34).lerp(last_solid_color.darkened(0.08), vertical))
	draw_polygon(body, colors)

	# Show each undissolved substance with its own colour. The bed remains display-only;
	# mass, dissolution and precipitation continue to come exclusively from VesselState.
	var chemical_ids: Array = vessel.solids.keys()
	chemical_ids.sort()
	var total_mass := 0.0
	for chemical_id in chemical_ids:
		total_mass += maxf(float(vessel.solids[chemical_id]), 0.0)
	if total_mass <= 0.0:
		return

	for chemical_index in range(chemical_ids.size()):
		var chemical_id := str(chemical_ids[chemical_index])
		var chemical := _sim.database.get_chemical(chemical_id)
		var grain_color := last_solid_color if chemical == null else chemical.color
		grain_color = Color(grain_color.r, grain_color.g, grain_color.b, 1.0)
		var share := maxf(float(vessel.solids[chemical_id]), 0.0) / total_mass
		var grain_count := clampi(int(round(6.0 + 22.0 * share)), 6, 28)
		var seed_value := float(chemical_index + 1) * 7919.0
		for index in range(grain_count):
			var y := solid_height * (0.08 + _hash01(index, seed_value + 78.233) * 0.78) + 0.8
			var half_width_at_y := VesselGeometry.half_width_at(_profile, y) * 0.78
			var x := (_hash01(index, seed_value + 12.9898) * 2.0 - 1.0) * half_width_at_y
			var radius := 1.0 + _hash01(index, seed_value + 4.17) * 1.8
			var grain := PackedVector2Array([
				Vector2(x - radius, -y),
				Vector2(x, -y - radius * 0.9),
				Vector2(x + radius, -y),
				Vector2(x, -y + radius * 0.65)
			])
			draw_colored_polygon(grain, grain_color.darkened(0.10))
			draw_line(Vector2(x - radius * 0.45, -y - radius * 0.15),
				Vector2(x, -y - radius * 0.78), Color(1.0, 1.0, 1.0, 0.38), 0.8, true)


## Heat shimmer and steam above the rim of a hot vessel.
func _draw_steam(temperature_c: float, top: float) -> void:
	var heat := _heat_factor(temperature_c)
	if temperature_c < STEAM_START_C:
		return
	var strength := clampf((temperature_c - STEAM_START_C) / (HEAT_FULL_C - STEAM_START_C), 0.0, 1.0)
	var time_s := _seconds()
	var width := VesselGeometry.half_width_at(_profile, top)
	for index in range(STEAM_WISP_COUNT):
		var phase := fmod(time_s * 0.3 + float(index) / float(STEAM_WISP_COUNT), 1.0)
		var x := sin(time_s * 1.6 + float(index) * 2.1 + phase * 6.0) * 9.0 + (float(index) - 1.5) * width * 0.4
		draw_circle(Vector2(x, -top - 8.0 - phase * 56.0), 5.0 + phase * 10.0, Color(1.0, 1.0, 1.0, 0.22 * strength * heat * (1.0 - phase)))


func _build_graduations() -> Array:
	var marks: Array = []
	var step_ml := float(_equipment.visual.get("graduation_ml", 0.0))
	if step_ml <= 0.0 or _equipment.capacity_ml <= 0.0 or _profile.is_empty():
		return marks
	var count := int(floor(_equipment.capacity_ml / step_ml))
	for index in range(1, count + 1):
		var height := VesselGeometry.height_for_fraction(_profile, float(index) * step_ml / _equipment.capacity_ml)
		if height >= VesselGeometry.top_height(_profile) - 4.0:
			continue
		marks.append({"height": height, "width": VesselGeometry.half_width_at(_profile, height),
			"major": index % GRADUATION_MAJOR_EVERY == 0, "label": "%d" % int(float(index) * step_ml)})
	return marks


func _draw_graduations() -> void:
	var font := ThemeDB.fallback_font
	for mark in _graduations:
		var height := float(mark["height"])
		var width := float(mark["width"])
		var major := bool(mark["major"])
		var length := 14.0 if major else 8.0
		draw_line(Vector2(width - length, -height), Vector2(width - 3.0, -height), Color(LabColors.GLASS_EDGE, 0.9), 1.5)
		if major and width > 30.0:
			draw_string(font, Vector2(width - length - 34.0, -height + 4.0), str(mark["label"]),
				HORIZONTAL_ALIGNMENT_RIGHT, 30.0, FONT_SIZE_LABEL, LabColors.TEXT_SECONDARY)


func _draw_bottle_parts(vessel: VesselState) -> void:
	var top := VesselGeometry.top_height(_profile)
	var neck := VesselGeometry.half_width_at(_profile, top)
	var cap := Rect2(-neck - 3.0, -top - CAP_HEIGHT, (neck + 3.0) * 2.0, CAP_HEIGHT)
	draw_rect(cap, LabColors.METAL)
	draw_rect(Rect2(cap.position.x, cap.position.y, cap.size.x, 4.0), LabColors.METAL.lightened(0.25))
	for index in range(1, 4):
		var x := cap.position.x + cap.size.x * float(index) / 4.0
		draw_line(Vector2(x, cap.position.y + 4.0), Vector2(x, cap.end.y), LabColors.METAL.darkened(0.25), 1.0)
	var chemical := _main_chemical(vessel)
	var label_rect := Rect2(-LABEL_HALF_WIDTH, -LABEL_TOP, LABEL_HALF_WIDTH * 2.0, LABEL_HEIGHT)
	draw_rect(label_rect, Color(0.97, 0.98, 0.99, 0.97))
	var band := LabColors.TEXT_MUTED if chemical == null else _band_color(chemical)
	draw_rect(Rect2(label_rect.position.x, label_rect.position.y, label_rect.size.x, LABEL_BAND_HEIGHT), band)
	draw_rect(label_rect, Color(0.0, 0.0, 0.0, 0.25), false, 1.0)
	var font := ThemeDB.fallback_font
	var label_key := "" if chemical == null else chemical.id
	if label_key != _label_key or _label_lines.is_empty():
		_label_key = label_key
		var lines: Array = ["EMPTY"]
		if chemical != null:
			lines = chemical.get_label_lines()
		_label_lines = _fit_label_lines(font, lines, label_rect.size.x - LABEL_PADDING * 2.0)
	var y := label_rect.position.y + LABEL_BAND_HEIGHT + 4.0
	for entry in _label_lines:
		var font_size: int = entry["size"]
		y += float(font_size) + 2.0
		draw_string(font, Vector2(label_rect.position.x + LABEL_PADDING, y), str(entry["text"]), HORIZONTAL_ALIGNMENT_CENTER,
			label_rect.size.x - LABEL_PADDING * 2.0, font_size, LabColors.INK if bool(entry["primary"]) else LabColors.INK.lightened(0.3))


## Shrinks each label line until it fits the paper, and wraps a long name onto two lines when
## even the smallest size is too wide, so no name is ever cut off.
func _fit_label_lines(font: Font, lines: Array, width: float) -> Array:
	var fitted: Array = []
	for index in range(lines.size()):
		var text := str(lines[index])
		var size := LABEL_NAME_SIZE if index == 0 else LABEL_FORMULA_SIZE
		while size > LABEL_MIN_SIZE and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			size -= 1
		var parts: Array = [text]
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and text.contains(" "):
			parts = _split_near_middle(text)
		for part in parts:
			var part_size := size
			while part_size > LABEL_MIN_SIZE and font.get_string_size(str(part), HORIZONTAL_ALIGNMENT_LEFT, -1, part_size).x > width:
				part_size -= 1
			fitted.append({"text": str(part), "size": part_size, "primary": index == 0})
	return fitted


static func _split_near_middle(text: String) -> Array:
	var best := -1
	var best_distance := INF
	var middle := float(text.length()) / 2.0
	for index in range(text.length()):
		if text[index] == " " and absf(float(index) - middle) < best_distance:
			best = index
			best_distance = absf(float(index) - middle)
	if best < 0:
		return [text]
	return [text.substr(0, best), text.substr(best + 1)]


## Colour of the label's top band: the chemical's own colour when it has one, else teal.
func _band_color(chemical: ChemicalDefinition) -> Color:
	if chemical.has_solution_color:
		return chemical.solution_color
	return LabColors.ACCENT


func _main_chemical(vessel: VesselState) -> ChemicalDefinition:
	if vessel == null:
		return null
	for chemical_id in vessel.liquids.keys():
		return _sim.database.get_chemical(str(chemical_id))
	for chemical_id in vessel.solids.keys():
		return _sim.database.get_chemical(str(chemical_id))
	return null


func _draw_dropper_bulb() -> void:
	var top := VesselGeometry.top_height(_profile)
	draw_rect(Rect2(-9.0, -top - 5.0, 18.0, 5.0), LabColors.METAL)
	var center := Vector2(0.0, -top - 24.0)
	draw_colored_polygon(_ellipse(center, 13.0, 22.0), LabColors.RUBBER)
	draw_colored_polygon(_ellipse(center + Vector2(4.0, 5.0), 9.0, 16.0), LabColors.RUBBER.darkened(0.2))
	draw_colored_polygon(_ellipse(center + Vector2(-5.0, -9.0), 3.0, 8.0), Color(1.0, 1.0, 1.0, 0.3))


func _draw_thermometer() -> void:
	var height := visual_height()
	var stem := Rect2(-THERMOMETER_STEM_HALF_WIDTH, -height, THERMOMETER_STEM_HALF_WIDTH * 2.0, height - THERMOMETER_BULB_RADIUS)
	draw_rect(stem, Color(GLASS_TINT, 0.3))
	draw_circle(Vector2(0.0, -THERMOMETER_BULB_RADIUS), THERMOMETER_BULB_RADIUS, LabColors.LIQUID_THERMOMETER)
	draw_circle(Vector2(-2.5, -THERMOMETER_BULB_RADIUS - 2.5), 2.5, Color(1.0, 1.0, 1.0, 0.45))
	var minimum := float(_equipment.thermometer.get("min_c", -10.0))
	var maximum := float(_equipment.thermometer.get("max_c", 110.0))
	var scale_bottom := THERMOMETER_BULB_RADIUS * 2.0
	var scale_top := height - 10.0
	var fraction := clampf((_shown_reading_c - minimum) / (maximum - minimum), 0.0, 1.0)
	var column_top := lerpf(scale_bottom, scale_top, fraction)
	draw_rect(Rect2(-2.0, -column_top, 4.0, column_top - THERMOMETER_BULB_RADIUS), LabColors.LIQUID_THERMOMETER)
	draw_line(Vector2(-THERMOMETER_STEM_HALF_WIDTH + 1.5, -height + 6.0), Vector2(-THERMOMETER_STEM_HALF_WIDTH + 1.5, -scale_bottom - 6.0),
		Color(1.0, 1.0, 1.0, 0.5), 1.5)
	draw_rect(stem, LabColors.GLASS_EDGE, false, 2.0)
	var mark := minimum
	while mark <= maximum:
		var y := -lerpf(scale_bottom, scale_top, (mark - minimum) / (maximum - minimum))
		draw_line(Vector2(THERMOMETER_STEM_HALF_WIDTH, y), Vector2(THERMOMETER_STEM_HALF_WIDTH + 6.0, y), LabColors.TEXT_SECONDARY, 1.0)
		mark += THERMOMETER_TICK_EVERY_C
	draw_string(ThemeDB.fallback_font, Vector2(-30.0, -height - 8.0), "%.1f °C" % _shown_reading_c,
		HORIZONTAL_ALIGNMENT_CENTER, 60.0, FONT_SIZE_SMALL, LabColors.TEXT_PRIMARY)


func _draw_hot_plate(item: LabObject) -> void:
	var height := visual_height()
	var width := half_width()
	var ambient := _sim.database.constant("ambient_temperature_c", 22.0)
	var maximum := float(_equipment.heater.get("max_surface_temperature_c", 300.0))
	var heat := clampf((item.surface_temperature_c - ambient) / maxf(maximum - ambient, 1.0), 0.0, 1.0)
	draw_style_box(_plate_style, Rect2(-width, -height, width * 2.0, height))
	draw_rect(Rect2(-width + 4.0, -height + 12.0, width * 2.0 - 8.0, 3.0), Color(1.0, 1.0, 1.0, 0.1))
	var plate_color := LabColors.METAL.lightened(0.35).lerp(PLATE_GLOW, heat)
	var disc := _ellipse(Vector2(0.0, -height), width - 10.0, 9.0)
	draw_colored_polygon(disc, plate_color)
	draw_polyline(_closed(_ellipse(Vector2(0.0, -height), width * 0.6, 6.0)), plate_color.darkened(0.25), 1.5, true)
	draw_polyline(_closed(_ellipse(Vector2(0.0, -height), width * 0.3, 3.5)), plate_color.darkened(0.25), 1.5, true)
	draw_polyline(_closed(disc), LabColors.METAL.darkened(0.3), 2.0, true)
	if heat > 0.05:
		for layer in range(3):
			draw_colored_polygon(_ellipse(Vector2(0.0, -height - 4.0 - float(layer) * 5.0), width - 14.0 - float(layer) * 8.0, 7.0),
				Color(PLATE_GLOW, 0.12 * heat))
	var knob_center := Vector2(-width + 26.0, -height * 0.4)
	var setpoint := clampf((item.target_temperature_c - ambient) / maxf(maximum - ambient, 1.0), 0.0, 1.0)
	var angle := lerpf(-KNOB_SWEEP_RAD, KNOB_SWEEP_RAD, setpoint)
	draw_circle(knob_center, 10.0, LabColors.TEXT_ON_DARK.darkened(0.1))
	draw_circle(knob_center, 7.0, LabColors.TEXT_ON_DARK)
	draw_line(knob_center, knob_center + Vector2(sin(angle), -cos(angle)) * 8.0, LabColors.METAL, 2.0, true)
	var led_center := Vector2(width - 20.0, -height * 0.4)
	if item.power_on:
		draw_circle(led_center, 9.0, Color(LabColors.ACCENT, 0.25))
	draw_circle(led_center, 5.0, LabColors.ACCENT if item.power_on else LabColors.TEXT_SECONDARY)
	var status := "ON" if item.power_on else "OFF"
	draw_string(ThemeDB.fallback_font, Vector2(-width + 46.0, -height * 0.4 + 5.0), "%s  %.0f °C" % [status, item.surface_temperature_c],
		HORIZONTAL_ALIGNMENT_LEFT, width * 2.0 - 96.0, FONT_SIZE_SMALL, LabColors.TEXT_ON_DARK)


## Hot things are labelled with text as well as colour (Design Bible, accessibility rule).
func _draw_hot_label(item: LabObject) -> void:
	var threshold := _sim.database.constant("temperature_hot_label_c", 60.0)
	var temperature := -INF
	if item.vessel != null and not item.vessel.is_empty():
		temperature = item.vessel.temperature_c
	elif _equipment.is_heater():
		temperature = item.surface_temperature_c
	if temperature < threshold:
		return
	var text := "HOT  %.0f °C" % temperature
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL)
	var top := -visual_height() - 22.0 - (CAP_HEIGHT if _equipment.style() == "bottle" else 0.0)
	var box := Rect2(-text_size.x * 0.5 - 8.0, top - text_size.y + 2.0, text_size.x + 16.0, text_size.y + 6.0)
	draw_style_box(_chip_style, box)
	draw_string(font, Vector2(box.position.x + 8.0, box.position.y + text_size.y - 2.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SMALL, LabColors.INK)


func _draw_marks() -> void:
	var bounds := local_bounds()
	if is_drop_target:
		var target_color: Color = LabColors.SUCCESS if drop_target_valid else LabColors.DANGER
		var pulse := 0.5 + 0.5 * sin(_seconds() * DROP_PULSE_SPEED)
		draw_colored_polygon(_ellipse(Vector2(0.0, 4.0), half_width() + 20.0, SHADOW_HEIGHT + 8.0),
			Color(target_color, 0.12 + pulse * 0.07))
		draw_rect(bounds.grow(7.0), Color(target_color, 0.62 + pulse * 0.22), false, 2.5)
	if _drag_progress > 0.02:
		var drag_alpha := _drag_progress
		draw_rect(bounds.grow(7.0), Color(LabColors.CYAN, 0.07 * drag_alpha))
		draw_rect(bounds.grow(5.0), Color(LabColors.CYAN, 0.72 * drag_alpha), false, 2.0)
	if is_hovered and not is_selected:
		draw_rect(bounds, Color(LabColors.ACCENT, 0.12))
		draw_rect(bounds, Color(LabColors.ACCENT, 0.5), false, 2.0)
	if not is_selected:
		return
	# A soft pool of light on the work surface under the selected object.
	draw_colored_polygon(_ellipse(Vector2(0.0, 3.0), half_width() + SELECTION_GLOW_PAD, SELECTION_GLOW_HEIGHT), Color(LabColors.ACCENT, 0.3))
	var left := bounds.position.x
	var right := bounds.end.x
	var up := bounds.position.y
	var down := bounds.end.y
	for corner in [Vector2(left, up), Vector2(right, up), Vector2(left, down), Vector2(right, down)]:
		var point: Vector2 = corner
		var dx := CORNER_LENGTH if point.x == left else -CORNER_LENGTH
		var dy := CORNER_LENGTH if point.y == up else -CORNER_LENGTH
		draw_line(point, point + Vector2(dx, 0.0), LabColors.ACCENT, 3.0, true)
		draw_line(point, point + Vector2(0.0, dy), LabColors.ACCENT, 3.0, true)
