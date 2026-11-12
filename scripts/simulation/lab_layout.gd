class_name LabLayout
extends RefCounted
## Where objects may stand in the laboratory: shelves and the bench (data/lab/layout.json).
## The simulation owns these rules; the workspace view draws them.

var canvas_size: Vector2 = Vector2(1600.0, 900.0)
var wall_bottom_y: float = 640.0
var bench_top_y: float = 640.0
var bench_front_y: float = 820.0
## Each: {id, kind, label, x_min, x_max, y_min, y_max, accept_margin}
var surfaces: Array = []


static func from_dictionary(data: Dictionary) -> LabLayout:
	var layout := LabLayout.new()
	var canvas: Array = data.get("canvas", [1600, 900])
	layout.canvas_size = Vector2(float(canvas[0]), float(canvas[1]))
	var wall: Dictionary = data.get("wall", {})
	layout.wall_bottom_y = float(wall.get("bottom_y", layout.wall_bottom_y))
	var bench: Dictionary = data.get("bench", {})
	layout.bench_top_y = float(bench.get("top_y", layout.bench_top_y))
	layout.bench_front_y = float(bench.get("front_y", layout.bench_front_y))
	for entry in data.get("surfaces", []):
		var surface: Dictionary = entry
		layout.surfaces.append({
			"id": str(surface.get("id", "")),
			"kind": str(surface.get("kind", "bench")),
			"label": str(surface.get("label", "")),
			"x_min": float(surface.get("x_min", 0.0)),
			"x_max": float(surface.get("x_max", 0.0)),
			"y_min": float(surface.get("y_min", 0.0)),
			"y_max": float(surface.get("y_max", 0.0)),
			"accept_margin": float(surface.get("accept_margin", 0.0)),
		})
	return layout


## Finds the surface an object standing at `position` (its base point) belongs on.
## Returns {"surface_id": String, "position": Vector2} with the position snapped onto the
## surface, or an empty dictionary when the position is not on any surface.
func resolve_surface(position: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for surface in surfaces:
		var margin: float = surface["accept_margin"]
		if position.x < float(surface["x_min"]) - margin or position.x > float(surface["x_max"]) + margin:
			continue
		if position.y < float(surface["y_min"]) - margin or position.y > float(surface["y_max"]) + margin:
			continue
		var snapped_position := Vector2(
			clampf(position.x, float(surface["x_min"]), float(surface["x_max"])),
			clampf(position.y, float(surface["y_min"]), float(surface["y_max"])))
		var distance := position.distance_to(snapped_position)
		if distance < best_distance:
			best_distance = distance
			best = {"surface_id": surface["id"], "position": snapped_position}
	return best
