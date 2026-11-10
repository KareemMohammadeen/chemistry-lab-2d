class_name LabWorkspace
extends Node2D
## The fixed front view of the laboratory: draws the wall, shelves and bench, keeps one
## EquipmentView per simulated object, and answers "what is under the pointer?" for the
## interaction controller. It displays the simulation and never changes it.

const DRAG_Z := 1500
const WALL_TILE_PX := 110.0
const BENCH_GRID_SPACING := 80.0
const SHELF_THICKNESS := 14.0
const SHELF_OVERHANG := 46.0
const SHELF_LABEL_SIZE := 13
## The backdrop is painted far beyond the laboratory canvas so a wide or tall window never shows bare edges.
const STAGE_EXTENT_X := 3000.0
const STAGE_EXTENT_UP := 700.0
const STAGE_EXTENT_DOWN := 700.0
const LIGHT_LAYERS := 7
const ELLIPSE_STEPS := 40
const BENCH_APRON_PX := 14.0
const DROP_BAND_HALF_HEIGHT := 6.0
const SUPPORT_REACH_ABOVE := 70.0
const SUPPORT_REACH_BELOW := 50.0
const BENCH_EDGE_THICKNESS := 6.0
const BENCH_SHADOW_PX := 46.0
const SHELF_SHADOW_PX := 40.0

@export var view_scene: PackedScene
@export var views_root: Node2D
@export var stream_overlay: StreamOverlay

var _host: SimulationHost
var _views: Dictionary = {}
var _selected_id: String = ""
var _hovered_id: String = ""
var _drag_id: String = ""
var _drag_anchor: Vector2 = Vector2.ZERO


func bind(host: SimulationHost) -> void:
	_host = host
	EventBus.object_selected.connect(_on_object_selected)
	queue_redraw()


func _process(_delta: float) -> void:
	if _host == null or _host.simulation == null:
		return
	var sim := _host.simulation
	_sync_view_set(sim)
	for object_id in _views.keys():
		var view: EquipmentView = _views[object_id]
		var item := sim.state.get_object(str(object_id))
		view.anchor = _anchor_for(sim, item)
		view.z_index = _z_for(sim, item)
		view.position = view.anchor + view.visual_offset
		view.rotation = view.visual_tilt
		view.is_selected = str(object_id) == _selected_id
		view.is_hovered = str(object_id) == _hovered_id


func _sync_view_set(sim: LabSimulation) -> void:
	for object_id in _views.keys():
		if sim.state.get_object(str(object_id)) == null:
			(_views[object_id] as EquipmentView).queue_free()
			_views.erase(object_id)
	for object_id in sim.state.objects.keys():
		if not _views.has(object_id):
			var view := view_scene.instantiate() as EquipmentView
			views_root.add_child(view)
			view.bind(sim, str(object_id))
			_views[object_id] = view


func _anchor_for(sim: LabSimulation, item: LabObject) -> Vector2:
	if item.id == _drag_id:
		return _drag_anchor
	if _drag_id != "" and item.inserted_in == _drag_id:
		return _drag_anchor + sim.insert_offset(item)
	return item.position


func _z_for(sim: LabSimulation, item: LabObject) -> int:
	if item.id == _drag_id:
		return DRAG_Z
	if _drag_id != "" and item.inserted_in == _drag_id:
		return DRAG_Z + 1
	var host_id := item.supported_by if item.supported_by != "" else item.inserted_in
	if host_id != "":
		var host_item := sim.state.get_object(host_id)
		if host_item != null:
			return _z_for(sim, host_item) + 1
	return int(item.position.y)


# ---------------------------------------------------------------- queries

## The top-most object under a point in laboratory pixels, or "". When `exclude_id` is set
## the caller is looking for a drop target: inserted items (a thermometer in a beaker) are
## skipped so that the vessel itself can be targeted.
func object_id_at(point: Vector2, exclude_id: String = "") -> String:
	var hits: Array = []
	for object_id in _views.keys():
		var view: EquipmentView = _views[object_id]
		if str(object_id) == exclude_id or str(object_id) == _drag_id:
			continue
		if view.contains_point(point):
			hits.append(view)
	if hits.is_empty():
		return ""
	hits.sort_custom(func(a: EquipmentView, b: EquipmentView) -> bool: return a.z_index > b.z_index)
	if exclude_id != "":
		for candidate in hits:
			var item := _host.simulation.state.get_object((candidate as EquipmentView).object_id)
			if item != null and item.inserted_in == "":
				return (candidate as EquipmentView).object_id
	return (hits[0] as EquipmentView).object_id


## The appliance (hot plate) whose top the dragged object's base point is over, or "".
func support_target_at(source_id: String, base_point: Vector2) -> String:
	var sim := _host.simulation
	var source := sim.state.get_object(source_id)
	var source_equipment := sim.database.get_equipment(source.equipment_id)
	if not bool(source_equipment.placement.get("support", false)):
		return ""
	for object_id in sim.state.objects.keys():
		var candidate: LabObject = sim.state.objects[object_id]
		if candidate.id == source_id:
			continue
		var candidate_equipment := sim.database.get_equipment(candidate.equipment_id)
		if candidate_equipment.support.is_empty():
			continue
		var accepted: Array = candidate_equipment.support.get("accepts_categories", [])
		if not accepted.has(source_equipment.category):
			continue
		var top := candidate.position.y + float(candidate_equipment.support.get("top_offset_y", 0.0))
		var half := float(candidate_equipment.support.get("half_width", 0.0))
		if absf(base_point.x - candidate.position.x) <= half \
				and base_point.y >= top - SUPPORT_REACH_ABOVE and base_point.y <= top + SUPPORT_REACH_BELOW:
			return candidate.id
	return ""


## Scales and centres the whole laboratory inside the stage area left between the side panels.
## `rect` is in screen (viewport) coordinates; laboratory pixels are not changed by this.
func fit_to_rect(rect: Rect2) -> void:
	if _host == null or _host.database == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var canvas := _host.database.layout.canvas_size
	var fit := minf(rect.size.x / canvas.x, rect.size.y / canvas.y)
	scale = Vector2(fit, fit)
	position = rect.position + (rect.size - canvas * fit) * 0.5


func get_view_position(object_id: String) -> Vector2:
	var view := _views.get(object_id) as EquipmentView
	return Vector2.ZERO if view == null else view.anchor


# ---------------------------------------------------------------- feedback from the controller

func set_hovered(object_id: String) -> void:
	_hovered_id = object_id


func begin_drag(object_id: String) -> void:
	_drag_id = object_id
	_drag_anchor = get_view_position(object_id)
	queue_redraw()


func set_drag_position(object_id: String, base_point: Vector2) -> void:
	if object_id == _drag_id:
		_drag_anchor = base_point


func end_drag(object_id: String) -> void:
	if object_id == _drag_id:
		_drag_id = ""
		queue_redraw()


## Animates a pour. kind is "liquid" or "solid".
func play_pour(source_id: String, target_id: String, kind: String) -> void:
	var source := _views.get(source_id) as EquipmentView
	var target := _views.get(target_id) as EquipmentView
	if source != null and target != null:
		stream_overlay.start(source, target, kind)


func _on_object_selected(object_id: String) -> void:
	_selected_id = object_id


# ---------------------------------------------------------------- background

func _draw() -> void:
	if _host == null or _host.database == null:
		return
	var layout := _host.database.layout
	_draw_wall(layout)
	_draw_wall_light(layout)
	for surface in layout.surfaces:
		if str(surface["kind"]) == "shelf":
			_draw_shelf(surface)
	_draw_bench(layout)
	if _drag_id != "":
		_draw_drop_zones(layout)


static func _ellipse(center: Vector2, radius_x: float, radius_y: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(ELLIPSE_STEPS):
		var angle := TAU * float(index) / float(ELLIPSE_STEPS)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


func _draw_wall(layout: LabLayout) -> void:
	var left := -STAGE_EXTENT_X
	var right := layout.canvas_size.x + STAGE_EXTENT_X
	var top := -STAGE_EXTENT_UP
	var bottom := layout.wall_bottom_y
	draw_polygon(PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom)]),
		PackedColorArray([LabColors.WALL_TOP, LabColors.WALL_TOP, LabColors.WALL_BOTTOM, LabColors.WALL_BOTTOM]))
	# Back-splash tiles: a quiet grid that gives the wall scale without competing with the glassware.
	var x := -WALL_TILE_PX * 12.0
	while x < layout.canvas_size.x + WALL_TILE_PX * 12.0:
		draw_line(Vector2(x, 0.0), Vector2(x, bottom), LabColors.WALL_LINE, 1.0)
		x += WALL_TILE_PX
	var y := bottom - WALL_TILE_PX
	while y > 0.0:
		draw_line(Vector2(-WALL_TILE_PX * 12.0, y), Vector2(layout.canvas_size.x + WALL_TILE_PX * 12.0, y), LabColors.WALL_LINE, 1.0)
		y -= WALL_TILE_PX
	# Shadow where the wall meets the bench.
	draw_polygon(PackedVector2Array([Vector2(left, bottom - BENCH_SHADOW_PX), Vector2(right, bottom - BENCH_SHADOW_PX), Vector2(right, bottom), Vector2(left, bottom)]),
		PackedColorArray([Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.3), Color(0.0, 0.0, 0.0, 0.3)]))


## A soft pool of light behind the shelves: stacked translucent ellipses, drawn once.
func _draw_wall_light(layout: LabLayout) -> void:
	var center := Vector2(layout.canvas_size.x * 0.5, layout.wall_bottom_y * 0.55)
	for layer in range(LIGHT_LAYERS):
		var fraction := 1.0 - float(layer) / float(LIGHT_LAYERS)
		draw_colored_polygon(_ellipse(center, 300.0 + 700.0 * fraction, 120.0 + 330.0 * fraction),
			Color(LabColors.WALL_LIGHT, 0.028))


func _draw_shelf(surface: Dictionary) -> void:
	var left := float(surface["x_min"]) - SHELF_OVERHANG
	var right := float(surface["x_max"]) + SHELF_OVERHANG
	var y := float(surface["y_min"])
	# Shadow cast on the wall below the board.
	draw_polygon(PackedVector2Array([Vector2(left, y + SHELF_THICKNESS), Vector2(right, y + SHELF_THICKNESS),
		Vector2(right, y + SHELF_THICKNESS + SHELF_SHADOW_PX), Vector2(left, y + SHELF_THICKNESS + SHELF_SHADOW_PX)]),
		PackedColorArray([Color(0.0, 0.0, 0.0, 0.34), Color(0.0, 0.0, 0.0, 0.34), Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0)]))
	# Board: lit top edge, darker front face.
	draw_polygon(PackedVector2Array([Vector2(left, y), Vector2(right, y), Vector2(right, y + SHELF_THICKNESS), Vector2(left, y + SHELF_THICKNESS)]),
		PackedColorArray([LabColors.SHELF_BOARD.lightened(0.25), LabColors.SHELF_BOARD.lightened(0.25), LabColors.SHELF_BOARD.darkened(0.25), LabColors.SHELF_BOARD.darkened(0.25)]))
	draw_line(Vector2(left, y + 0.5), Vector2(right, y + 0.5), Color(1.0, 1.0, 1.0, 0.45), 1.5)
	draw_line(Vector2(left, y + SHELF_THICKNESS), Vector2(right, y + SHELF_THICKNESS), Color(0.0, 0.0, 0.0, 0.4), 1.5)
	for bracket_x in [left + 36.0, right - 36.0]:
		var x := float(bracket_x)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 5.0, y + SHELF_THICKNESS), Vector2(x + 5.0, y + SHELF_THICKNESS),
			Vector2(x + 5.0, y + SHELF_THICKNESS + 30.0)]), LabColors.SHELF_BOARD.darkened(0.35))
	draw_string(ThemeDB.fallback_font, Vector2(left + 6.0, y + SHELF_THICKNESS + 22.0), str(surface["label"]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, SHELF_LABEL_SIZE, LabColors.TEXT_MUTED)


func _draw_bench(layout: LabLayout) -> void:
	var left := -STAGE_EXTENT_X
	var right := layout.canvas_size.x + STAGE_EXTENT_X
	var top := layout.bench_top_y
	var front := layout.bench_front_y
	# Work surface: darker at the back, lighter toward the viewer, like a resin top under a ceiling light.
	draw_polygon(PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, front), Vector2(left, front)]),
		PackedColorArray([LabColors.BENCH_TOP.darkened(0.3), LabColors.BENCH_TOP.darkened(0.3), LabColors.BENCH_TOP.lightened(0.04), LabColors.BENCH_TOP.lightened(0.04)]))
	# A broad soft reflection of the light above.
	draw_colored_polygon(_ellipse(Vector2(layout.canvas_size.x * 0.5, top + (front - top) * 0.42), 620.0, 90.0), Color(1.0, 1.0, 1.0, 0.035))
	draw_colored_polygon(_ellipse(Vector2(layout.canvas_size.x * 0.5, top + (front - top) * 0.42), 380.0, 55.0), Color(1.0, 1.0, 1.0, 0.035))
	var x := 0.0
	while x <= layout.canvas_size.x:
		draw_line(Vector2(x, top), Vector2(x, front), LabColors.BENCH_GRID, 1.0)
		x += BENCH_GRID_SPACING
	var y := top
	while y < front:
		draw_line(Vector2(left, y), Vector2(right, y), LabColors.BENCH_GRID, 1.0)
		y += BENCH_GRID_SPACING
	draw_line(Vector2(left, top), Vector2(right, top), Color(0.0, 0.0, 0.0, 0.4), 2.0)
	# Front edge with a highlight, then the dark apron under the work surface.
	draw_rect(Rect2(left, front, right - left, BENCH_APRON_PX), LabColors.BENCH_EDGE.darkened(0.15))
	draw_line(Vector2(left, front + 1.0), Vector2(right, front + 1.0), Color(1.0, 1.0, 1.0, 0.55), 1.5)
	var apron_top := front + BENCH_APRON_PX
	var apron_bottom := layout.canvas_size.y + STAGE_EXTENT_DOWN
	draw_polygon(PackedVector2Array([Vector2(left, apron_top), Vector2(right, apron_top), Vector2(right, apron_bottom), Vector2(left, apron_bottom)]),
		PackedColorArray([LabColors.BENCH_APRON.lightened(0.05), LabColors.BENCH_APRON.lightened(0.05), LabColors.BENCH_APRON.darkened(0.3), LabColors.BENCH_APRON.darkened(0.3)]))
	for surface in layout.surfaces:
		if str(surface["kind"]) != "bench":
			continue
		var area := Rect2(float(surface["x_min"]), float(surface["y_min"]) - 14.0,
			float(surface["x_max"]) - float(surface["x_min"]), float(surface["y_max"]) - float(surface["y_min"]) + 28.0)
		draw_rect(area, Color(1.0, 1.0, 1.0, 0.045), false, 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(area.position.x + 10.0, area.position.y + 18.0), str(surface["label"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, SHELF_LABEL_SIZE, LabColors.TEXT_MUTED)


func _draw_drop_zones(layout: LabLayout) -> void:
	for surface in layout.surfaces:
		var margin := float(surface["accept_margin"])
		var rect := Rect2(float(surface["x_min"]) - margin, float(surface["y_min"]) - DROP_BAND_HALF_HEIGHT - margin * 0.5,
			float(surface["x_max"]) - float(surface["x_min"]) + margin * 2.0,
			float(surface["y_max"]) - float(surface["y_min"]) + DROP_BAND_HALF_HEIGHT * 2.0 + margin)
		draw_rect(rect, Color(LabColors.ACCENT, 0.12))
		draw_rect(rect, Color(LabColors.ACCENT, 0.55), false, 2.0)
