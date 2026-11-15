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
var _drag_tilt_target: float = 0.0
var _drop_preview_id: String = ""
var _drop_preview_valid: bool = false
var _drop_preview_surface_id: String = ""
signal view_changed(zoom_percent: int)

var _stage_rect: Rect2 = Rect2()
var _base_zoom: float = 1.0
var _zoom_factor: float = 1.0
var _pan_active: bool = false


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
		view.is_being_dragged = str(object_id) == _drag_id
		view.is_drop_target = str(object_id) == _drop_preview_id
		view.drop_target_valid = _drop_preview_valid
		view.drag_tilt_target = _drag_tilt_target if str(object_id) == _drag_id else 0.0
		var inherited_lift := Vector2.ZERO
		if _drag_id != "" and item.inserted_in == _drag_id:
			var dragged_view := _views.get(_drag_id) as EquipmentView
			if dragged_view != null:
				inherited_lift = dragged_view.drag_lift_offset()
		view.position = view.anchor + view.visual_offset + view.drag_lift_offset() + inherited_lift
		view.rotation = view.visual_tilt + view.drag_rotation_offset()
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


## Fits the starting lab coordinate area into the stage once, then the operator can pan/zoom
## freely. The original canvas only defines the starting camera view, not a placement boundary.
func fit_to_rect(rect: Rect2) -> void:
	if _host == null or _host.database == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	_stage_rect = rect
	var canvas := _host.database.layout.canvas_size
	_base_zoom = maxf(minf(rect.size.x / canvas.x, rect.size.y / canvas.y), 0.01)
	_zoom_factor = 1.0
	scale = Vector2.ONE * _base_zoom
	position = rect.position + (rect.size - canvas * _base_zoom) * 0.5
	view_changed.emit(100)
	queue_redraw()


func screen_to_workspace(screen_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_position


func update_stage_rect(rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	if _stage_rect.size.x > 0.0:
		var screen_delta := rect.position - _stage_rect.position
		position += get_viewport().get_canvas_transform().basis_xform_inv(screen_delta)
	_stage_rect = rect
	queue_redraw()


func zoom_by(factor: float) -> void:
	if _stage_rect.size.x > 0.0 and is_finite(factor) and factor > 0.0:
		zoom_at_screen(_stage_rect.get_center(), factor)


func zoom_at_screen(screen_position: Vector2, factor: float) -> void:
	if not is_finite(factor) or factor <= 0.0:
		return
	var anchor := screen_to_workspace(screen_position)
	var wanted := clampf(scale.x * factor, _base_zoom * 0.30, _base_zoom * 4.0)
	if is_equal_approx(wanted, scale.x):
		return
	scale = Vector2.ONE * wanted
	var after_screen := get_global_transform_with_canvas() * anchor
	var screen_delta := screen_position - after_screen
	position += get_viewport().get_canvas_transform().basis_xform_inv(screen_delta)
	_zoom_factor = wanted / _base_zoom
	view_changed.emit(roundi(_zoom_factor * 100.0))
	queue_redraw()


func reset_view() -> void:
	if _stage_rect.size.x > 0.0:
		fit_to_rect(_stage_rect)


func _unhandled_input(event: InputEvent) -> void:
	if _stage_rect.size.x <= 0.0:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			if mouse_event.pressed and _stage_rect.has_point(mouse_event.position):
				_pan_active = true
				Input.set_default_cursor_shape(Input.CURSOR_MOVE)
			elif not mouse_event.pressed:
				_pan_active = false
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
				get_viewport().set_input_as_handled()
			if _pan_active:
				get_viewport().set_input_as_handled()
			return
		if mouse_event.pressed and _stage_rect.has_point(mouse_event.position):
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_at_screen(mouse_event.position, 1.12)
				get_viewport().set_input_as_handled()
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_at_screen(mouse_event.position, 1.0 / 1.12)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _pan_active:
		var motion := event as InputEventMouseMotion
		var screen_delta := motion.relative
		position += get_viewport().get_canvas_transform().basis_xform_inv(screen_delta)
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_HOME:
			reset_view()
			get_viewport().set_input_as_handled()


func get_view_position(object_id: String) -> Vector2:
	var view := _views.get(object_id) as EquipmentView
	return Vector2.ZERO if view == null else view.anchor


# ---------------------------------------------------------------- feedback from the controller

func set_hovered(object_id: String) -> void:
	_hovered_id = object_id


func begin_drag(object_id: String) -> void:
	_drag_id = object_id
	_drag_anchor = get_view_position(object_id)
	_drag_tilt_target = 0.0
	set_drop_preview("", false)
	queue_redraw()


func set_drag_position(object_id: String, base_point: Vector2) -> void:
	if object_id == _drag_id:
		var horizontal_motion := base_point.x - _drag_anchor.x
		_drag_anchor = base_point
		_drag_tilt_target = clampf(-horizontal_motion * 0.0035, -0.07, 0.07)
		queue_redraw()


func set_drop_preview(target_id: String, target_valid: bool, surface_id: String = "") -> void:
	if target_id == _drop_preview_id and target_valid == _drop_preview_valid \
			and surface_id == _drop_preview_surface_id:
		return
	_drop_preview_id = target_id
	_drop_preview_valid = target_valid
	_drop_preview_surface_id = surface_id
	queue_redraw()


func end_drag(object_id: String) -> void:
	if object_id == _drag_id:
		_drag_id = ""
		_drag_tilt_target = 0.0
		set_drop_preview("", false)
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
	if layout.infinite_workbench:
		_draw_infinite_workbench()
	else:
		_draw_wall(layout)
		_draw_wall_light(layout)
		for surface in layout.surfaces:
			if str(surface["kind"]) == "shelf":
				_draw_shelf(surface)
			_draw_bench(layout)
	if _drag_id != "":
		_draw_drop_zones(layout)
		_draw_drag_shadow()


## Draws only the visible portion of a limitless dark-resin work surface.
func _draw_infinite_workbench() -> void:
	if _stage_rect.size.x <= 0.0:
		return
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var p1 := inverse * _stage_rect.position
	var p2 := inverse * Vector2(_stage_rect.end.x, _stage_rect.position.y)
	var p3 := inverse * Vector2(_stage_rect.position.x, _stage_rect.end.y)
	var p4 := inverse * _stage_rect.end
	var left := minf(minf(p1.x, p2.x), minf(p3.x, p4.x))
	var right := maxf(maxf(p1.x, p2.x), maxf(p3.x, p4.x))
	var top := minf(minf(p1.y, p2.y), minf(p3.y, p4.y))
	var bottom := maxf(maxf(p1.y, p2.y), maxf(p3.y, p4.y))
	var bounds := Rect2(Vector2(left, top), Vector2(right - left, bottom - top)).grow(160.0)
	draw_rect(bounds, LabColors.BENCH_TOP.darkened(0.26))
	var step := 80.0
	var x := floorf(bounds.position.x / step) * step
	while x <= bounds.end.x:
		var major_x := int(round(x / (step * 5.0))) % 2 == 0
		var grid_tint_x := LabColors.BENCH_GRID
		grid_tint_x.a = 0.24 if major_x else 0.11
		draw_line(Vector2(x, bounds.position.y), Vector2(x, bounds.end.y),
			grid_tint_x, 1.0 if major_x else 0.7)
		x += step
	var y := floorf(bounds.position.y / step) * step
	while y <= bounds.end.y:
		var major_y := int(round(y / (step * 5.0))) % 2 == 0
		var grid_tint_y := LabColors.BENCH_GRID
		grid_tint_y.a = 0.24 if major_y else 0.11
		draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y),
			grid_tint_y, 1.0 if major_y else 0.7)
		y += step
	var mark_x := floorf(bounds.position.x / 400.0) * 400.0
	while mark_x <= bounds.end.x:
		var mark_y := floorf(bounds.position.y / 400.0) * 400.0
		while mark_y <= bounds.end.y:
			draw_circle(Vector2(mark_x, mark_y), 2.0, Color(LabColors.ACCENT, 0.26))
			mark_y += 400.0
		mark_x += 400.0


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


func _draw_drag_shadow() -> void:
	var view := _views.get(_drag_id) as EquipmentView
	if view == null:
		return
	var progress := view.drag_visual_progress()
	if progress <= 0.01:
		return
	var width := view.half_width()
	for layer in range(4):
		var spread := float(layer) * 4.0 + progress * 5.0
		var alpha := (0.10 - float(layer) * 0.018) * progress
		draw_colored_polygon(_ellipse(_drag_anchor + Vector2(0.0, 4.0 + float(layer)), width * 0.82 + spread,
				4.0 + spread * 0.22), Color(0.0, 0.0, 0.0, alpha))


func _draw_drop_zones(layout: LabLayout) -> void:
	if layout.infinite_workbench:
		draw_circle(_drag_anchor, 20.0, Color(LabColors.ACCENT, 0.18), false, 2.0)
		draw_line(_drag_anchor + Vector2(-30.0, 0.0), _drag_anchor + Vector2(30.0, 0.0), Color(LabColors.ACCENT, 0.48), 1.0)
		draw_line(_drag_anchor + Vector2(0.0, -30.0), _drag_anchor + Vector2(0.0, 30.0), Color(LabColors.ACCENT, 0.48), 1.0)
		return
	for surface in layout.surfaces:
		var margin := float(surface["accept_margin"])
		var rect := Rect2(float(surface["x_min"]) - margin, float(surface["y_min"]) - DROP_BAND_HALF_HEIGHT - margin * 0.5,
			float(surface["x_max"]) - float(surface["x_min"]) + margin * 2.0,
			float(surface["y_max"]) - float(surface["y_min"]) + DROP_BAND_HALF_HEIGHT * 2.0 + margin)
		var surface_id := str(surface.get("id", ""))
		var is_preview := surface_id != "" and surface_id == _drop_preview_surface_id
		var zone_color: Color = LabColors.ACCENT
		if is_preview:
			zone_color = LabColors.SUCCESS if _drop_preview_valid else LabColors.DANGER
		var fill_alpha := 0.15 if is_preview else 0.045
		var border_alpha := 0.82 if is_preview else 0.28
		draw_rect(rect, Color(zone_color, fill_alpha))
		draw_rect(rect, Color(zone_color, border_alpha), false, 2.5 if is_preview else 1.0)
		var corner_length := 20.0 if is_preview else 10.0
		var corner_alpha := 0.95 if is_preview else 0.32
		var corners := [rect.position, Vector2(rect.end.x, rect.position.y),
			Vector2(rect.position.x, rect.end.y), rect.end]
		for corner in corners:
			var point: Vector2 = corner
			var dx := corner_length if point.x == rect.position.x else -corner_length
			var dy := corner_length if point.y == rect.position.y else -corner_length
			draw_line(point, point + Vector2(dx, 0.0), Color(zone_color, corner_alpha), 3.0, true)
			draw_line(point, point + Vector2(0.0, dy), Color(zone_color, corner_alpha), 3.0, true)
		if is_preview:
			var hint := "DROP HERE" if _drop_preview_valid else "NOT A VALID SURFACE"
			var font := ThemeDB.fallback_font
			var hint_width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(font, Vector2(rect.end.x - hint_width - 14.0, rect.position.y + 20.0), hint,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, zone_color)
