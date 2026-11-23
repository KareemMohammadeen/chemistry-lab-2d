class_name SimulationClock
extends RefCounted
## Converts real frame time into whole fixed simulation steps. Pause and speed live here.
## The simulation always advances in constant steps, so results do not depend on frame rate.

const MIN_SPEED := 0.05
const MAX_SPEED := 16.0
const NORMAL_SPEED := 1.0

var paused: bool = false
var speed: float = NORMAL_SPEED
var fixed_step_s: float = 0.1
var max_steps_per_frame: int = 8
## True when the last frame could not keep up and simulated time was dropped.
var throttled: bool = false

var _accumulator: float = 0.0


func configure(step_s: float, max_steps: int) -> void:
	fixed_step_s = maxf(step_s, 0.001)
	max_steps_per_frame = maxi(max_steps, 1)


## Returns how many fixed steps to run for this frame.
func advance(real_delta: float) -> int:
	throttled = false
	if paused:
		return 0
	_accumulator += real_delta * speed
	var steps := int(_accumulator / fixed_step_s)
	if steps > max_steps_per_frame:
		steps = max_steps_per_frame
		_accumulator = 0.0
		throttled = true
	else:
		_accumulator -= float(steps) * fixed_step_s
	return steps


## Sets the speed multiplier. Non-finite or non-positive values are ignored so a bad request
## can never freeze or flood the simulation; the result is clamped to the supported range.
func set_speed(value: float) -> void:
	if not is_finite(value) or value <= 0.0:
		return
	speed = clampf(value, MIN_SPEED, MAX_SPEED)


## Moves to the next faster (direction > 0) or slower (direction < 0) preset. The presets come
## from data/simulation/simulation_constants.json. Returns the speed that is now active.
func step_speed(direction: int, presets: Array) -> float:
	var ordered: Array[float] = []
	for entry in presets:
		var value := float(entry)
		if is_finite(value) and value > 0.0:
			ordered.append(value)
	if ordered.is_empty() or direction == 0:
		return speed
	ordered.sort()
	var chosen := speed
	if direction > 0:
		chosen = ordered[ordered.size() - 1]
		for value in ordered:
			if value > speed + 0.0001:
				chosen = value
				break
	else:
		chosen = ordered[0]
		for index in range(ordered.size() - 1, -1, -1):
			if ordered[index] < speed - 0.0001:
				chosen = ordered[index]
				break
	set_speed(chosen)
	return speed
