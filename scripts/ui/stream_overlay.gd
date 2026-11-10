class_name StreamOverlay
extends Node2D
## Plays the pour animation: the source vessel tilts over the target and a stream (liquid) or
## falling grains (solid) is drawn between them. Display only. The simulation has already
## applied the transfer when this starts, and the views ease their drawn levels toward it.

const DURATION_S := 1.2
const APPROACH_FRACTION := 0.25
const RETURN_START_FRACTION := 0.75
## Tilt of the source in radians (about 62 degrees).
const TILT_RADIANS := 1.08
const STREAM_WIDTH := 5.0
const SPLASH_RADIUS := 6.0
const GRAIN_COUNT := 14
const GRAIN_SIZE := 4.0
const GRAIN_SPEED := 2.2
const LIP_HEIGHT_ABOVE_OPENING := 26.0
const LIP_OFFSET_FRACTION := 0.35
const MIN_FALL_PX := 6.0
const CURVE_SEGMENTS := 10
## Sideways travel of the stream from the lip to where it lands, in pixels; gravity bends the path down.
const CURVE_DRIFT_PX := 14.0
const RIPPLE_COUNT := 2
const RIPPLE_SPEED := 1.4
const RIPPLE_RADIUS_PX := 26.0

## Each job: {source: EquipmentView, target: EquipmentView, kind: String, color: Color,
## elapsed: float, direction: float}
var _jobs: Array = []


## kind is "liquid" or "solid".
func start(source: EquipmentView, target: EquipmentView, kind: String) -> void:
	_cancel_for(source)
	var color := source.last_liquid_color if kind == "liquid" else source.last_solid_color
	var direction := 1.0 if target.anchor.x >= source.anchor.x else -1.0
	_jobs.append({"source": source, "target": target, "kind": kind, "color": color,
		"elapsed": 0.0, "direction": direction})


func is_playing() -> bool:
	return not _jobs.is_empty()


func _process(delta: float) -> void:
	if _jobs.is_empty():
		return
	var finished: Array = []
	for job in _jobs:
		job["elapsed"] = float(job["elapsed"]) + delta
		if not _is_job_valid(job) or float(job["elapsed"]) >= DURATION_S:
			finished.append(job)
			continue
		_pose_source(job)
	for job in finished:
		_reset_source(job)
		_jobs.erase(job)
	queue_redraw()


func _draw() -> void:
	for job in _jobs:
		if not _is_job_valid(job) or _tilt_amount(job) < 0.95:
			continue
		var lip := _lip_position(job)
		var target: EquipmentView = job["target"]
		var end_y := maxf(target.surface_global_y(), lip.y + MIN_FALL_PX)
		var color: Color = job["color"]
		if job["kind"] == "liquid":
			_draw_liquid_stream(lip, end_y, color, float(job["direction"]), float(job["elapsed"]))
		else:
			_draw_grains(lip, end_y, color, float(job["elapsed"]))


## A stream that leaves the lip sideways and bends down, with ripples where it lands.
func _draw_liquid_stream(lip: Vector2, end_y: float, color: Color, direction: float, elapsed: float) -> void:
	var points := PackedVector2Array()
	var fall := end_y - lip.y
	for index in range(CURVE_SEGMENTS + 1):
		var t := float(index) / float(CURVE_SEGMENTS)
		points.append(Vector2(lip.x + direction * CURVE_DRIFT_PX * t, lip.y + fall * t * t))
	draw_polyline(points, Color(color.r, color.g, color.b, color.a * 0.5), STREAM_WIDTH + 3.0, true)
	draw_polyline(points, color, STREAM_WIDTH, true)
	draw_polyline(points, Color(1.0, 1.0, 1.0, 0.35), 1.5, true)
	var landing := points[points.size() - 1]
	for ring in range(RIPPLE_COUNT):
		var phase := fmod(elapsed * RIPPLE_SPEED + float(ring) / float(RIPPLE_COUNT), 1.0)
		var radius := SPLASH_RADIUS + phase * RIPPLE_RADIUS_PX
		draw_arc(landing, radius, 0.0, TAU, 20, Color(1.0, 1.0, 1.0, 0.5 * (1.0 - phase)), 1.5, true)
	draw_circle(landing, SPLASH_RADIUS, Color(color.r, color.g, color.b, color.a * 0.6))


func _draw_grains(lip: Vector2, end_y: float, color: Color, elapsed: float) -> void:
	for index in range(GRAIN_COUNT):
		var phase := fmod(elapsed * GRAIN_SPEED + float(index) / float(GRAIN_COUNT), 1.0)
		var x := lip.x + sin(float(index) * 7.3) * 5.0
		draw_rect(Rect2(x - GRAIN_SIZE * 0.5, lerpf(lip.y, end_y, phase), GRAIN_SIZE, GRAIN_SIZE), color)


func _is_job_valid(job: Dictionary) -> bool:
	return is_instance_valid(job["source"]) and is_instance_valid(job["target"])


## 0 at rest, 1 fully tilted: eases in, holds, eases out.
func _tilt_amount(job: Dictionary) -> float:
	var t := float(job["elapsed"]) / DURATION_S
	if t < APPROACH_FRACTION:
		return smoothstep(0.0, 1.0, t / APPROACH_FRACTION)
	if t < RETURN_START_FRACTION:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (t - RETURN_START_FRACTION) / (1.0 - RETURN_START_FRACTION))


func _mirrored_lip(job: Dictionary) -> Vector2:
	var source: EquipmentView = job["source"]
	var lip := source.pour_lip_local()
	return Vector2(lip.x * float(job["direction"]), lip.y)


## Where the lip must be at full tilt: just above the target's opening, slightly on the near side.
func _desired_lip(job: Dictionary) -> Vector2:
	var target: EquipmentView = job["target"]
	var opening := target.opening_global()
	return opening + Vector2(-float(job["direction"]) * target.half_width() * LIP_OFFSET_FRACTION, -LIP_HEIGHT_ABOVE_OPENING)


func _pose_source(job: Dictionary) -> void:
	var source: EquipmentView = job["source"]
	var amount := _tilt_amount(job)
	var tilt := TILT_RADIANS * float(job["direction"]) * amount
	var resting_lip := source.anchor + _mirrored_lip(job).rotated(tilt)
	source.visual_tilt = tilt
	source.visual_offset = (_desired_lip(job) - resting_lip) * amount


func _lip_position(job: Dictionary) -> Vector2:
	var source: EquipmentView = job["source"]
	return source.anchor + source.visual_offset + _mirrored_lip(job).rotated(source.visual_tilt)


func _reset_source(job: Dictionary) -> void:
	var source: EquipmentView = job["source"]
	if is_instance_valid(source):
		source.visual_tilt = 0.0
		source.visual_offset = Vector2.ZERO


func _cancel_for(source: EquipmentView) -> void:
	for job in _jobs.duplicate():
		if job["source"] == source:
			_reset_source(job)
			_jobs.erase(job)
