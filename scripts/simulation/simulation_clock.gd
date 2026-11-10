class_name SimulationClock
extends RefCounted
## Converts real frame time into whole fixed simulation steps. Pause and speed live here.
## The simulation always advances in constant steps, so results do not depend on frame rate.

var paused: bool = false
var speed: float = 1.0
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
