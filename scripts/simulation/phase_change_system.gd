class_name PhaseChangeSystem
extends RefCounted
## Physical phase changes of the contents of one vessel: melting and freezing (pure substances and
## the binary systems of data/materials/binary_systems.json), boiling, evaporation and
## condensation. It runs inside HeatSystem after heat has been exchanged, and conserves energy:
## every phase change absorbs or releases exactly its latent heat (see MeltEquilibrium).
##
## What it does not model (documented in docs/MATERIAL_THERMODYNAMICS.md): freezing-point
## depression and boiling-point elevation by dissolved solutes, supercooling, superheating,
## sublimation, pressure-dependent boiling in open vessels, and solid solutions.

const MIN_MASS_G := 1.0e-9
const MIN_AMOUNT_MOL := 1.0e-12
const FRACTION_EPSILON := 1.0e-9
const SOLVER_TOLERANCE_C := 1.0e-9
const GAS_CONSTANT := ThermalProfile.GAS_CONSTANT_J_PER_MOL_K
const MIN_VAPOUR_EVENT_G := 1.0e-4


## Advances the phase state of a vessel one step. capacity_j_per_k is the heat capacity of the
## vessel and its contents (glass included). Returns observation entries for the caller to record.
static func step(vessel: VesselState, db: ContentDatabase, capacity_j_per_k: float,
		ambient_c: float, dt: float) -> Array:
	var events: Array = []
	if capacity_j_per_k <= 0.0 or not is_finite(vessel.temperature_c):
		return events
	_melt_and_freeze(vessel, db, capacity_j_per_k, events)
	_boil_and_evaporate(vessel, db, capacity_j_per_k, ambient_c, dt, events)
	return events


# ---------------------------------------------------------------- melting and freezing

class Binding:
	extends RefCounted
	var entry: MeltEquilibrium.Entry
	## Set for a pure family.
	var profile: ThermalProfile
	## Set for a blend.
	var system: BinaryMeltSystem
	var mass_g: float = 0.0
	var mass_a_g: float = 0.0
	var mass_b_g: float = 0.0
	var x_b: float = 0.0
	var before_fraction: float = 0.0
	var label: String = ""


static func _melt_and_freeze(vessel: VesselState, db: ContentDatabase, capacity: float, events: Array) -> void:
	var bindings: Array = []
	var in_blend := {}
	for system_value in db.binary_systems:
		var system: BinaryMeltSystem = system_value
		var binding := _blend_binding(vessel, db, system)
		if binding != null:
			bindings.append(binding)
			in_blend[system.component_a] = true
			in_blend[system.component_b] = true
	for family_id in db.thermal_families.keys():
		if in_blend.has(family_id):
			continue
		var profile: ThermalProfile = db.thermal_families[family_id]
		var binding := _pure_binding(vessel, db, profile)
		if binding != null:
			bindings.append(binding)
	if bindings.is_empty():
		return

	var entries: Array = []
	for binding_value in bindings:
		entries.append((binding_value as Binding).entry)
	var enthalpy := MeltEquilibrium.enthalpy_j(entries, capacity, vessel.temperature_c)
	var new_temperature := MeltEquilibrium.solve(entries, capacity, enthalpy)
	if not is_finite(new_temperature):
		return
	vessel.temperature_c = new_temperature
	for binding_value in bindings:
		var binding: Binding = binding_value
		if binding.system != null:
			_write_blend(vessel, db, binding, new_temperature, events)
		else:
			_write_pure(vessel, db, binding, events)


static func _liquid_density(db: ContentDatabase, chemical_id: String) -> float:
	return db.liquid_density_g_ml(chemical_id)


static func _pure_binding(vessel: VesselState, db: ContentDatabase, profile: ThermalProfile) -> Binding:
	if not profile.can_melt():
		return null
	var solid_id := profile.id_for_phase("solid")
	var liquid_id := profile.id_for_phase("liquid")
	var density := _liquid_density(db, liquid_id)
	var solid_g := float(vessel.solids.get(solid_id, 0.0))
	var liquid_g := float(vessel.liquids.get(liquid_id, 0.0)) * density
	var total := solid_g + liquid_g
	if total <= MIN_MASS_G:
		return null
	var fraction := liquid_g / total
	# A solution is not pure water: it would freeze lower than the model's 0 degC, which is not
	# modelled yet. A fully liquid solution therefore stays liquid instead of freezing wrongly.
	if fraction >= 1.0 - FRACTION_EPSILON and _has_solute(vessel, db, liquid_id):
		return null
	var binding := Binding.new()
	binding.profile = profile
	binding.mass_g = total
	binding.before_fraction = fraction
	binding.label = db.get_chemical(profile.family_id).short_name if db.get_chemical(profile.family_id) != null else profile.family_id
	var entry := MeltEquilibrium.Entry.new()
	entry.tag = profile.family_id
	entry.latent_j = total * profile.fusion_j_per_g
	entry.jump_c = profile.melting_point_c
	entry.liquid_c = profile.melting_point_c
	entry.f_jump = 1.0
	entry.fraction = fraction
	binding.entry = entry
	return binding


## True when anything else is dissolved in, or mixed with, an aqueous liquid.
static func _has_solute(vessel: VesselState, db: ContentDatabase, liquid_id: String) -> bool:
	var chemical := db.get_chemical(liquid_id)
	if chemical == null or not chemical.is_aqueous_solvent:
		return false
	for dissolved_id in vessel.dissolved.keys():
		if float(vessel.dissolved[dissolved_id]) > MIN_MASS_G:
			return true
	for other_id in vessel.liquids.keys():
		if str(other_id) != liquid_id and float(vessel.liquids[other_id]) > MIN_MASS_G:
			return true
	return false


static func _blend_binding(vessel: VesselState, db: ContentDatabase, system: BinaryMeltSystem) -> Binding:
	var density_a := _liquid_density(db, system.component_a)
	var density_b := _liquid_density(db, system.component_b)
	var solid_a := float(vessel.solids.get(system.component_a, 0.0))
	var solid_b := float(vessel.solids.get(system.component_b, 0.0))
	var liquid_a := float(vessel.liquids.get(system.component_a, 0.0)) * density_a
	var liquid_b := float(vessel.liquids.get(system.component_b, 0.0)) * density_b
	var mass_a := solid_a + liquid_a
	var mass_b := solid_b + liquid_b
	if mass_a <= MIN_MASS_G or mass_b <= MIN_MASS_G:
		return null
	var total := mass_a + mass_b
	var x := mass_b / total
	var binding := Binding.new()
	binding.system = system
	binding.mass_g = total
	binding.mass_a_g = mass_a
	binding.mass_b_g = mass_b
	binding.x_b = x
	binding.before_fraction = (liquid_a + liquid_b) / total
	binding.label = system.product_name
	var entry := MeltEquilibrium.Entry.new()
	entry.tag = system.id
	entry.latent_j = total * system.fusion_j_per_g(x)
	entry.jump_c = system.eutectic_c
	entry.liquid_c = system.liquidus_c(x)
	entry.f_jump = system.liquid_fraction(x, system.eutectic_c)
	entry.fraction = binding.before_fraction
	entry.continuous = func(temperature_c: float) -> float: return system.liquid_fraction(x, temperature_c)
	binding.entry = entry
	return binding


static func _write_pure(vessel: VesselState, db: ContentDatabase, binding: Binding, events: Array) -> void:
	var profile := binding.profile
	var fraction := _snap(binding.entry.fraction)
	if absf(fraction - binding.before_fraction) < 1.0e-12:
		_report_state(vessel, "phase:%s" % profile.family_id, binding.before_fraction, fraction, binding.label, events)
		return
	var solid_id := profile.id_for_phase("solid")
	var liquid_id := profile.id_for_phase("liquid")
	var density := _liquid_density(db, liquid_id)
	_set_ledger(vessel.solids, solid_id, (1.0 - fraction) * binding.mass_g)
	_set_ledger(vessel.liquids, liquid_id, fraction * binding.mass_g / maxf(density, 1.0e-9))
	_report_state(vessel, "phase:%s" % profile.family_id, binding.before_fraction, fraction,
		binding.label, events)


static func _write_blend(vessel: VesselState, db: ContentDatabase, binding: Binding,
		temperature_c: float, events: Array) -> void:
	var system := binding.system
	var fraction := _snap(binding.entry.fraction)
	var total := binding.mass_g
	var unchanged := absf(fraction - binding.before_fraction) < 1.0e-12
	var liquid_b := 0.0
	var liquid_a := 0.0
	if fraction >= 1.0:
		liquid_a = binding.mass_a_g
		liquid_b = binding.mass_b_g
	elif fraction > 0.0:
		var liquid_x := system.eutectic_x_b if temperature_c <= system.eutectic_c + SOLVER_TOLERANCE_C \
			else system.liquid_composition(binding.x_b, temperature_c)
		liquid_b = minf(fraction * total * liquid_x, binding.mass_b_g)
		liquid_a = minf(fraction * total * (1.0 - liquid_x), binding.mass_a_g)
	if not unchanged:
		_set_ledger(vessel.solids, system.component_a, binding.mass_a_g - liquid_a)
		_set_ledger(vessel.solids, system.component_b, binding.mass_b_g - liquid_b)
		_set_ledger(vessel.liquids, system.component_a, liquid_a / maxf(_liquid_density(db, system.component_a), 1.0e-9))
		_set_ledger(vessel.liquids, system.component_b, liquid_b / maxf(_liquid_density(db, system.component_b), 1.0e-9))
	var name_a := _short_name(db, system.component_a)
	var name_b := _short_name(db, system.component_b)
	if liquid_a > MIN_MASS_G and liquid_b > MIN_MASS_G and not vessel.fused_systems.has(system.id):
		vessel.fused_systems[system.id] = true
		events.append({
			"key": "alloy_formed:%s" % system.id, "kind": "phase_change",
			"text": "%s and %s have melted together into one liquid." % [name_a, name_b],
			"explanation": "Mixed in the liquid state they form a single solution. When it freezes it is one material, a %s, not the two separate metals." % system.product_name.to_lower(),
		})
	_report_state(vessel, "phase:%s" % system.id, binding.before_fraction, fraction,
		"The %s–%s mixture" % [name_a, name_b], events)


static func _short_name(db: ContentDatabase, chemical_id: String) -> String:
	var chemical := db.get_chemical(chemical_id)
	return chemical_id if chemical == null else chemical.short_name


static func _snap(fraction: float) -> float:
	if fraction <= FRACTION_EPSILON:
		return 0.0
	if fraction >= 1.0 - FRACTION_EPSILON:
		return 1.0
	return fraction


static func _set_ledger(ledger: Dictionary, chemical_id: String, amount: float) -> void:
	if amount <= MIN_MASS_G:
		ledger.erase(chemical_id)
	else:
		ledger[chemical_id] = amount


## Emits an observation when a melt entry changes between solid, partly melted and liquid.
## The state is remembered in fired_observations so a session restore never repeats an event.
## The first time an entry is seen its state is recorded silently (a beaker that starts as liquid
## water has not "just melted").
static func _report_state(vessel: VesselState, key: String, before: float, after: float, label: String,
		events: Array) -> void:
	var state := "solid" if after <= 0.0 else ("liquid" if after >= 1.0 else "melting")
	var previous := str(vessel.fired_observations.get(key, ""))
	vessel.fired_observations[key] = state
	if previous == state or (previous.is_empty() and state != "melting"):
		return
	match state:
		"melting":
			events.append({"key": "%s:melting" % key, "kind": "phase_change",
				"text": "%s is %s." % [label, "partly melted" if after >= before else "partly frozen"],
				"explanation": "A phase change absorbs or releases latent heat, so the temperature holds steady while it happens."})
		"liquid":
			events.append({"key": "%s:liquid" % key, "kind": "phase_change",
				"text": "%s has completely melted." % label,
				"explanation": "All of the solid has absorbed its heat of fusion; further heat raises the temperature again."})
		_:
			events.append({"key": "%s:solid" % key, "kind": "phase_change",
				"text": "%s has completely frozen." % label,
				"explanation": "The liquid released its heat of fusion as it solidified."})


# ---------------------------------------------------------------- boiling, evaporation, condensation

static func _boil_and_evaporate(vessel: VesselState, db: ContentDatabase, capacity: float,
		ambient_c: float, dt: float, events: Array) -> void:
	for family_id in db.thermal_families.keys():
		var profile: ThermalProfile = db.thermal_families[family_id]
		if not profile.can_boil():
			continue
		var liquid_id := profile.id_for_phase("liquid")
		var density := _liquid_density(db, liquid_id)
		var liquid_g := float(vessel.liquids.get(liquid_id, 0.0)) * density
		if vessel.is_closed_system:
			_closed_equilibrium(vessel, db, profile, liquid_id, liquid_g, density, capacity, events)
		elif liquid_g > MIN_MASS_G:
			_open_vaporisation(vessel, db, profile, liquid_id, liquid_g, density, capacity, ambient_c, dt, events)


## Open vessel: above the boiling point the surplus heat boils liquid away; below it a warm
## liquid evaporates slowly. Vapour leaves the vessel and is not tracked.
static func _open_vaporisation(vessel: VesselState, db: ContentDatabase, profile: ThermalProfile,
		liquid_id: String, liquid_g: float, density: float, capacity: float, ambient_c: float,
		dt: float, events: Array) -> void:
	var latent := profile.vaporization_j_per_g
	var vaporised := 0.0
	var key := "phase:boiling:%s" % profile.family_id
	var label := _short_name(db, liquid_id)
	if vessel.temperature_c > profile.boiling_point_c:
		var surplus_j := capacity * (vessel.temperature_c - profile.boiling_point_c)
		vaporised = minf(surplus_j / latent, liquid_g)
		vessel.temperature_c -= vaporised * latent / capacity
		if vaporised > 0.0 and str(vessel.fired_observations.get(key, "")) != "boiling":
			vessel.fired_observations[key] = "boiling"
			events.append({"key": key + ":boiling", "kind": "phase_change",
				"text": "%s is boiling and its vapour escapes from the open vessel." % label,
				"explanation": "At the boiling point the heat supplied goes into vaporising the liquid, so the temperature holds steady and the liquid level falls."})
	else:
		if str(vessel.fired_observations.get(key, "")) == "boiling":
			vessel.fired_observations[key] = "stopped"
		var rate := db.constant("evaporation_mass_transfer_g_per_s_per_kpa", 0.0)
		if rate > 0.0 and vessel.temperature_c > ambient_c:
			var driving_kpa := profile.vapor_pressure_kpa(vessel.temperature_c) - profile.vapor_pressure_kpa(ambient_c)
			if is_finite(driving_kpa) and driving_kpa > 0.0:
				vaporised = minf(rate * driving_kpa * dt, liquid_g)
				vessel.temperature_c -= vaporised * latent / capacity
				_report_vapour_flow(vessel, profile, label, "evaporating", vaporised, events)
	if vaporised > 0.0:
		_set_ledger(vessel.liquids, liquid_id, (liquid_g - vaporised) / maxf(density, 1.0e-9))


## Closed vessel: liquid and vapour exchange until the vapour pressure equals the equilibrium
## value for the temperature. The heat of vaporisation is taken from or returned to the vessel,
## so the temperature settles consistently (found by bisection, which converges for any step).
static func _closed_equilibrium(vessel: VesselState, db: ContentDatabase, profile: ThermalProfile,
		liquid_id: String, liquid_g: float, density: float, capacity: float, events: Array) -> void:
	var gas_id := profile.id_for_phase("gas")
	var molar_mass := profile.molar_mass_g_mol
	var latent_per_mol := profile.vaporization_j_per_g * molar_mass
	var gas_mol := float(vessel.gases.get(gas_id, 0.0))
	var liquid_mol := liquid_g / molar_mass
	var head_l := vessel.headspace_l()
	var start_c := vessel.temperature_c
	if liquid_mol <= MIN_AMOUNT_MOL and gas_mol <= MIN_AMOUNT_MOL:
		return
	var low := -gas_mol
	var high := liquid_mol
	var solved := 0.0
	var g_low := _vapour_balance(profile, gas_mol, low, start_c, latent_per_mol, capacity, head_l)
	var g_high := _vapour_balance(profile, gas_mol, high, start_c, latent_per_mol, capacity, head_l)
	if not is_finite(g_low) or not is_finite(g_high):
		return
	if g_high < 0.0:
		solved = high
	elif g_low > 0.0:
		solved = low
	else:
		for _i in range(80):
			var middle := 0.5 * (low + high)
			if _vapour_balance(profile, gas_mol, middle, start_c, latent_per_mol, capacity, head_l) < 0.0:
				low = middle
			else:
				high = middle
		solved = 0.5 * (low + high)
	# Never push the sealed vessel past the virtual pressure limit.
	var limit_kpa := db.constant("max_virtual_pressure_kpa", 300.0)
	var end_c := start_c - solved * latent_per_mol / capacity
	var air_and_gas := vessel.trapped_air_moles + vessel.total_gas_moles()
	var max_add := limit_kpa * head_l / (GAS_CONSTANT * (end_c + ThermalProfile.KELVIN_OFFSET)) - air_and_gas
	if solved > max_add:
		solved = maxf(max_add, 0.0)
		end_c = start_c - solved * latent_per_mol / capacity
	if absf(solved) <= MIN_AMOUNT_MOL:
		return
	vessel.temperature_c = end_c
	_set_ledger(vessel.liquids, liquid_id, (liquid_g - solved * molar_mass) / maxf(density, 1.0e-9))
	var new_gas := gas_mol + solved
	if new_gas <= MIN_AMOUNT_MOL:
		vessel.gases.erase(gas_id)
	else:
		vessel.gases[gas_id] = new_gas
	var label := _short_name(db, liquid_id)
	_report_vapour_flow(vessel, profile, label, "evaporating" if solved > 0.0 else "condensing",
		absf(solved) * molar_mass, events)


## Vapour left over (mol) after moving dn mol from liquid to gas: positive means the gas is
## supersaturated at the resulting temperature, negative means it could hold more.
static func _vapour_balance(profile: ThermalProfile, gas_mol: float, dn: float, start_c: float,
		latent_per_mol: float, capacity: float, head_l: float) -> float:
	var temperature_c := start_c - dn * latent_per_mol / capacity
	var pressure_kpa := profile.vapor_pressure_kpa(temperature_c)
	if not is_finite(pressure_kpa):
		return NAN
	var kelvin := temperature_c + ThermalProfile.KELVIN_OFFSET
	var equilibrium_mol := pressure_kpa * head_l / (GAS_CONSTANT * kelvin)
	return gas_mol + dn - equilibrium_mol


static func _report_vapour_flow(vessel: VesselState, profile: ThermalProfile, label: String,
		direction: String, mass_g: float, events: Array) -> void:
	if mass_g < MIN_VAPOUR_EVENT_G:
		return
	var key := "phase:vapour:%s" % profile.family_id
	if str(vessel.fired_observations.get(key, "")) == direction:
		return
	vessel.fired_observations[key] = direction
	if direction == "evaporating":
		events.append({"key": key + ":evaporating", "kind": "phase_change",
			"text": "%s is evaporating." % label,
			"explanation": "Liquid molecules escape into the gas; this takes in heat, which cools the liquid."})
	else:
		events.append({"key": key + ":condensing", "kind": "phase_change",
			"text": "%s vapour is condensing back to liquid." % label,
			"explanation": "Cooling makes the vapour pressure fall below the amount of vapour present, so the excess condenses and releases heat."})
