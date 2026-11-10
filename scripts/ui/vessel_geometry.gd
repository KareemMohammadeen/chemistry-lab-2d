class_name VesselGeometry
extends RefCounted
## Geometry of a vessel's inside, used only for drawing. A profile is a list of
## [height_px, half_width_px] pairs with ascending height (data/equipment/*.json).
## Liquid volume is proportional to the integral of width squared (a body of revolution), so
## the fill height of a vessel with a rounded bottom or a shoulder is drawn correctly.

const INTEGRATION_STEPS := 64
const BISECTION_STEPS := 24


static func top_height(profile: Array) -> float:
	if profile.is_empty():
		return 0.0
	var last: Array = profile[profile.size() - 1]
	return float(last[0])


static func half_width_at(profile: Array, height: float) -> float:
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
			var t := 0.0 if span <= 0.0 else (height - float(lower[0])) / span
			return lerpf(float(lower[1]), float(upper[1]), t)
	var last: Array = profile[profile.size() - 1]
	return float(last[1])


static func max_half_width(profile: Array) -> float:
	var widest := 0.0
	for entry in profile:
		var point: Array = entry
		widest = maxf(widest, float(point[1]))
	return widest


## Relative volume below `height` (arbitrary units; only ratios are meaningful).
static func volume_units(profile: Array, height: float) -> float:
	if height <= 0.0:
		return 0.0
	var step := height / float(INTEGRATION_STEPS)
	var total := 0.0
	for index in range(INTEGRATION_STEPS):
		var width := half_width_at(profile, (float(index) + 0.5) * step)
		total += width * width * step
	return total


## Height at which the liquid reaches `fraction` (0..1) of the vessel's capacity.
static func height_for_fraction(profile: Array, fraction: float) -> float:
	var top := top_height(profile)
	if fraction <= 0.0 or top <= 0.0:
		return 0.0
	if fraction >= 1.0:
		return top
	var target := fraction * volume_units(profile, top)
	var low := 0.0
	var high := top
	for _iteration in range(BISECTION_STEPS):
		var middle := (low + high) * 0.5
		if volume_units(profile, middle) < target:
			low = middle
		else:
			high = middle
	return (low + high) * 0.5


## Closed polygon of the inside between two heights (local pixels, y grows downward, so a
## point at height h has y = -h).
static func slice_polygon(profile: Array, low: float, high: float) -> PackedVector2Array:
	var heights: Array = [low]
	for entry in profile:
		var point: Array = entry
		var h := float(point[0])
		if h > low and h < high:
			heights.append(h)
	heights.append(high)
	var polygon := PackedVector2Array()
	for h in heights:
		polygon.append(Vector2(-half_width_at(profile, float(h)), -float(h)))
	for index in range(heights.size() - 1, -1, -1):
		var h2 := float(heights[index])
		polygon.append(Vector2(half_width_at(profile, h2), -h2))
	return polygon


## Open polyline of the wall: down the left side, across the bottom, up the right side.
static func wall_polyline(profile: Array) -> PackedVector2Array:
	var line := PackedVector2Array()
	for index in range(profile.size() - 1, -1, -1):
		var point: Array = profile[index]
		line.append(Vector2(-float(point[1]), -float(point[0])))
	for entry in profile:
		var point2: Array = entry
		line.append(Vector2(float(point2[1]), -float(point2[0])))
	return line
