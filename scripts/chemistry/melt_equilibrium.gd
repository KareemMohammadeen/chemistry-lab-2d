class_name MeltEquilibrium
extends RefCounted
## Energy-conserving solver for melting and freezing (the enthalpy method).
##
## The contents of a vessel are described by a constant heat capacity C (J/K) and by melt entries.
## Each entry has a latent heat M (J, the heat needed to melt all of it) and a liquid fraction
## F(T) that rises with temperature: it is 0 below jump_c, may jump to f_jump at jump_c, then
## rises continuously to 1 at liquid_c. A pure substance is the special case jump_c == liquid_c
## and f_jump == 1: it melts at one temperature while the vessel stays at that temperature.
##
## The total enthalpy H = C*T + sum(M_k * f_k) is conserved by a heat-neutral state change, so
## the new temperature and fractions are found by inverting Phi(T) = C*T + sum(M_k * F_k(T)).
## Phi never decreases, so the answer is unique. Phase transitions therefore absorb or release
## exactly their latent heat and never create or destroy energy.
##
## Simplification: C is held constant over the step (it is evaluated before the phase change).


class Entry:
	extends RefCounted
	## Opaque handle for the caller (what this entry stands for).
	var tag: Variant = null
	var latent_j: float = 0.0
	var jump_c: float = 0.0
	var liquid_c: float = 0.0
	var f_jump: float = 1.0
	## Current liquid fraction (input), and the solved fraction (output).
	var fraction: float = 0.0
	## Returns the liquid fraction strictly between jump_c and liquid_c. Pure substances never call it.
	var continuous: Callable = Callable()

	## Liquid fraction just below the temperature (left limit).
	func f_below(temperature_c: float) -> float:
		if temperature_c <= jump_c:
			return 0.0
		return f_above_open(temperature_c)

	## Liquid fraction just above the temperature (right limit).
	func f_above(temperature_c: float) -> float:
		if temperature_c < jump_c:
			return 0.0
		if temperature_c == jump_c:
			return f_jump
		return f_above_open(temperature_c)

	func f_above_open(temperature_c: float) -> float:
		if temperature_c >= liquid_c:
			return 1.0
		if continuous.is_valid():
			return clampf(float(continuous.call(temperature_c)), f_jump, 1.0)
		return f_jump

	func has_jump() -> bool:
		return f_jump > 0.0


## Total enthalpy (J, relative to 0 degC) of the state described by the entries' current fractions.
static func enthalpy_j(entries: Array, capacity_j_per_k: float, temperature_c: float) -> float:
	var total := capacity_j_per_k * temperature_c
	for entry_value in entries:
		var entry: Entry = entry_value
		total += entry.latent_j * entry.fraction
	return total


## Solves for the equilibrium temperature at the given total enthalpy and writes the solved
## fraction into each entry. Returns the new temperature in degC.
static func solve(entries: Array, capacity_j_per_k: float, enthalpy: float) -> float:
	if capacity_j_per_k <= 0.0:
		return NAN
	var breakpoints: Array = []
	for entry_value in entries:
		var entry: Entry = entry_value
		for point in [entry.jump_c, entry.liquid_c]:
			if not breakpoints.has(point):
				breakpoints.append(point)
	breakpoints.sort()
	if breakpoints.is_empty():
		return enthalpy / capacity_j_per_k

	# Below every breakpoint nothing is liquid, so Phi(T) = C*T.
	var first: float = breakpoints[0]
	if enthalpy <= _phi_below(entries, capacity_j_per_k, first):
		_assign(entries, 0.0, true)
		return enthalpy / capacity_j_per_k

	for index in range(breakpoints.size()):
		var point: float = breakpoints[index]
		var low := _phi_below(entries, capacity_j_per_k, point)
		var high := _phi_above(entries, capacity_j_per_k, point)
		if enthalpy >= low and enthalpy <= high:
			# Inside a jump: the temperature stays at the breakpoint, the fractions absorb the heat.
			_fill_jump(entries, point, enthalpy - low)
			return point
		var next_point := INF if index + 1 >= breakpoints.size() else float(breakpoints[index + 1])
		var next_low := INF if is_inf(next_point) else _phi_below(entries, capacity_j_per_k, next_point)
		if enthalpy > high and enthalpy < next_low:
			if is_inf(next_point):
				var temperature := (enthalpy - (high - capacity_j_per_k * point)) / capacity_j_per_k
				_assign(entries, temperature, false)
				return temperature
			var lower := point
			var upper := next_point
			for _i in range(80):
				var middle := 0.5 * (lower + upper)
				if _phi_open(entries, capacity_j_per_k, middle) < enthalpy:
					lower = middle
				else:
					upper = middle
			var solved := 0.5 * (lower + upper)
			_assign(entries, solved, false)
			return solved
	# Unreachable for finite input; keep the temperature consistent rather than guessing.
	return enthalpy / capacity_j_per_k


static func _phi_below(entries: Array, capacity: float, temperature: float) -> float:
	var total := capacity * temperature
	for entry_value in entries:
		var entry: Entry = entry_value
		total += entry.latent_j * entry.f_below(temperature)
	return total


static func _phi_above(entries: Array, capacity: float, temperature: float) -> float:
	var total := capacity * temperature
	for entry_value in entries:
		var entry: Entry = entry_value
		total += entry.latent_j * entry.f_above(temperature)
	return total


## Phi inside an open interval between breakpoints, where every fraction is continuous.
static func _phi_open(entries: Array, capacity: float, temperature: float) -> float:
	var total := capacity * temperature
	for entry_value in entries:
		var entry: Entry = entry_value
		total += entry.latent_j * entry.f_above_open(temperature)
	return total


static func _assign(entries: Array, temperature: float, all_solid: bool) -> void:
	for entry_value in entries:
		var entry: Entry = entry_value
		entry.fraction = 0.0 if all_solid else entry.f_above_open(temperature) if temperature > entry.jump_c else 0.0


## Distributes heat absorbed inside a jump over the entries that jump at that temperature.
static func _fill_jump(entries: Array, point: float, heat: float) -> void:
	var remaining := maxf(heat, 0.0)
	for entry_value in entries:
		var entry: Entry = entry_value
		var base := entry.f_below(point)
		entry.fraction = base
		if entry.jump_c == point and entry.latent_j > 0.0:
			var capacity_here := entry.latent_j * (entry.f_above(point) - base)
			var used := minf(remaining, capacity_here)
			entry.fraction = base + used / entry.latent_j
			remaining -= used
