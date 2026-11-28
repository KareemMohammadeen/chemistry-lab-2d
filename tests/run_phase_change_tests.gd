extends Node
## Headless regression tests for Phase 1: per-material thermal profiles, energy-conserving melting
## and freezing, boiling / evaporation / condensation, binary alloys, the cooling plate, and
## compatibility with save/load and snapshots (undo/redo).
##
## Run (as a scene so the EventBus / InputManager autoloads exist before any script compiles):
##   godot --headless --path . res://tests/run_phase_change_tests.tscn
## Exit code is 0 when every check passes.
## These tests had NOT been executed when they were written (no Godot binary was available); the
## maths they check is cross-checked by tests/test_phase_model.py. See docs/TESTING.md.

const WATER_FUSION_J_PER_G := 333.55
const WATER_VAPORISATION_J_PER_G := 2257.0

var _db: ContentDatabase
var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_db = ContentDatabase.new()
	_db.load_all()
	_check(_db.errors.is_empty(), "content loads without errors: %s" % str(_db.errors))
	_test_profiles()
	_test_vapour_pressure()
	_test_solver_pure()
	_test_solver_conservation_random()
	_test_binary_system_geometry()
	_test_ice_melts_with_latent_heat()
	_test_water_freezes_but_solution_does_not()
	_test_open_boiling_and_evaporation()
	_test_closed_vessel_equilibrium()
	_test_tin_bismuth_alloy()
	_test_unlisted_pair_is_a_mixture()
	_test_capacity_uses_profiles()
	_test_save_load_and_legacy()
	_test_snapshot_round_trip()
	_test_cooling_plate_command()
	_test_freeze_on_cooling_plate()
	print("\n%d check(s), %d failure(s)" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------- data and profiles

func _test_profiles() -> void:
	print("-- thermal profiles")
	var water := _db.get_chemical("water")
	var ice := _db.get_chemical("ice")
	var vapour := _db.get_chemical("water_vapor")
	_check(water.thermal != null, "water has a thermal profile")
	_check(ice.thermal == water.thermal and vapour.thermal == water.thermal, "ice and water vapour share the water profile object")
	_check(_db.thermal_families.has("water") and not _db.thermal_families.has("ice"), "only the family root is indexed")
	_check(water.thermal.id_for_phase("solid") == "ice" and water.thermal.id_for_phase("gas") == "water_vapor", "water names its phase ids")
	_check(water.thermal.can_melt() and water.thermal.can_boil(), "water can melt and boil")
	_near(water.thermal.fusion_j_per_g, WATER_FUSION_J_PER_G, 1e-9, "water heat of fusion")
	_near(water.thermal.vaporization_j_per_g, WATER_VAPORISATION_J_PER_G, 1e-9, "water heat of vaporisation")
	var tin := _db.get_chemical("tin")
	_check(tin != null and tin.thermal != null and tin.thermal.can_melt(), "tin can melt")
	_check(tin.thermal.id_for_phase("liquid") == "tin", "molten tin keeps the tin id")
	_near(_db.liquid_density_g_ml("tin"), 6.99, 1e-9, "molten tin uses the liquid density, not the solid one")
	_check(is_nan(tin.thermal.cp_liquid_j_per_g_k) and is_finite(tin.thermal.cp_for_phase("liquid")),
		"a missing liquid heat capacity falls back to the solid value instead of being invented")
	var glycerol := _db.get_chemical("glycerol")
	_check(glycerol.thermal.can_melt() and not glycerol.thermal.can_boil(), "glycerol cannot boil: no sourced heat of vaporisation")
	var salt := _db.get_chemical("sodium_chloride")
	_check(salt.thermal.can_melt() and not salt.thermal.can_boil(), "sodium chloride melts but boiling is not modelled")
	_check(is_finite(_db.molar_mass_g_mol("ethanol")) and _db.get_chemical("ethanol").thermal.molar_mass_g_mol > 0.0,
		"ethanol takes its molar mass from the compound record")
	_check(_db.get_chemical("sucrose").thermal == null, "a substance without sourced thermal data has no profile")


func _test_vapour_pressure() -> void:
	print("-- vapour pressure")
	var profile := _db.get_chemical("water").thermal
	_near(profile.vapor_pressure_kpa(25.0), 3.17, 0.1, "water vapour pressure at 25 degC (Antoine)")
	_near(profile.vapor_pressure_kpa(99.9), 101.325, 3.0, "water vapour pressure near 100 degC (Antoine)")
	var ethanol := _db.get_chemical("ethanol").thermal
	_near(ethanol.vapor_pressure_kpa(78.4), 101.325, 1e-6, "Clausius-Clapeyron fallback gives 1 atm at the boiling point")
	_check(ethanol.vapor_pressure_kpa(60.0) < 101.325 and ethanol.vapor_pressure_kpa(60.0) > ethanol.vapor_pressure_kpa(30.0),
		"vapour pressure rises with temperature")
	_check(is_nan(_db.get_chemical("glycerol").thermal.vapor_pressure_kpa(100.0)), "no vapour pressure without data")


# ---------------------------------------------------------------- solver

func _pure_entry(latent_j: float, point_c: float, fraction: float) -> MeltEquilibrium.Entry:
	var entry := MeltEquilibrium.Entry.new()
	entry.latent_j = latent_j
	entry.jump_c = point_c
	entry.liquid_c = point_c
	entry.f_jump = 1.0
	entry.fraction = fraction
	return entry


func _test_solver_pure() -> void:
	print("-- melt solver: pure substance")
	var entry := _pure_entry(1000.0, 0.0, 0.0)
	var capacity := 10.0
	# 5 degC of excess heat (50 J) melts 5 % of the latent heat and the temperature stays at 0.
	var t := MeltEquilibrium.solve([entry], capacity, MeltEquilibrium.enthalpy_j([entry], capacity, 5.0))
	_near(t, 0.0, 1e-9, "the temperature holds at the melting point")
	_near(entry.fraction, 0.05, 1e-9, "excess heat melts exactly its latent-heat share")
	# Cooling the half-melted body by 20 J refreezes 2 %.
	entry.fraction = 0.5
	t = MeltEquilibrium.solve([entry], capacity, MeltEquilibrium.enthalpy_j([entry], capacity, -2.0))
	_near(t, 0.0, 1e-9, "freezing also holds the melting point")
	_near(entry.fraction, 0.48, 1e-9, "cooling refreezes exactly its latent-heat share")
	# Plenty of heat: fully melted, remainder warms the liquid.
	entry.fraction = 0.0
	t = MeltEquilibrium.solve([entry], capacity, MeltEquilibrium.enthalpy_j([entry], capacity, 200.0))
	_near(entry.fraction, 1.0, 1e-9, "all melted")
	_near(t, 200.0 - 1000.0 / capacity, 1e-9, "the surplus heat raises the temperature")
	# Cold solid just warms.
	entry.fraction = 0.0
	t = MeltEquilibrium.solve([entry], capacity, MeltEquilibrium.enthalpy_j([entry], capacity, -30.0))
	_near(t, -30.0, 1e-9, "a cold solid below its melting point is unchanged")
	_near(entry.fraction, 0.0, 1e-12, "and stays solid")


func _test_solver_conservation_random() -> void:
	print("-- melt solver: energy conservation")
	var random := RandomNumberGenerator.new()
	random.seed = 4321
	var worst := 0.0
	for _i in range(500):
		var entries: Array = []
		for _k in range(random.randi_range(1, 3)):
			entries.append(_pure_entry(random.randf_range(10.0, 5000.0), random.randf_range(-20.0, 250.0), random.randf()))
		var capacity := random.randf_range(5.0, 800.0)
		var start := random.randf_range(-40.0, 300.0)
		var before := MeltEquilibrium.enthalpy_j(entries, capacity, start)
		var solved := MeltEquilibrium.solve(entries, capacity, before)
		var after := MeltEquilibrium.enthalpy_j(entries, capacity, solved)
		worst = maxf(worst, absf(after - before) / maxf(absf(before), 1.0))
	_check(worst < 1.0e-9, "solver conserves enthalpy over random states (worst relative error %e)" % worst)


func _test_binary_system_geometry() -> void:
	print("-- binary system geometry")
	var system := _tin_bismuth()
	_check(system != null, "the tin-bismuth system is loaded")
	_near(system.liquidus_c(0.0), system.melting_a_c, 1e-9, "liquidus at pure tin is the tin melting point")
	_near(system.liquidus_c(1.0), system.melting_b_c, 1e-9, "liquidus at pure bismuth is the bismuth melting point")
	_near(system.liquidus_c(system.eutectic_x_b), system.eutectic_c, 1e-9, "liquidus at the eutectic composition is the eutectic temperature")
	_near(system.liquid_fraction(system.eutectic_x_b, system.eutectic_c), 1.0, 1e-9, "the eutectic composition melts completely at the eutectic temperature")
	var f_e := system.liquid_fraction(0.3, system.eutectic_c)
	_near(f_e, 0.3 / system.eutectic_x_b, 1e-9, "lever rule at the eutectic temperature, tin-rich side")
	_check(system.liquid_fraction(0.3, system.liquidus_c(0.3)) >= 1.0 - 1e-9, "fully liquid at the liquidus")
	_check(system.liquid_fraction(0.3, 0.5 * (system.eutectic_c + system.liquidus_c(0.3))) > f_e, "liquid fraction rises above the eutectic")
	_check(system.eutectic_c < minf(system.melting_a_c, system.melting_b_c), "the eutectic is below both melting points")


# ---------------------------------------------------------------- vessel phase changes

func _vessel(capacity_ml: float = 250.0, temperature_c: float = 22.0) -> VesselState:
	var vessel := VesselState.new()
	vessel.capacity_ml = capacity_ml
	vessel.temperature_c = temperature_c
	return vessel


func _mass_g(vessel: VesselState, chemical_id: String) -> float:
	return float(vessel.solids.get(chemical_id, 0.0)) + float(vessel.liquids.get(chemical_id, 0.0)) * _db.liquid_density_g_ml(chemical_id)


func _test_ice_melts_with_latent_heat() -> void:
	print("-- ice melts and absorbs latent heat")
	var vessel := _vessel()
	vessel.add_solid("ice", 50.0)
	var capacity := 100.0
	vessel.temperature_c = 5.0
	var start_energy := capacity * 5.0
	var events := PhaseChangeSystem.step(vessel, _db, capacity, 22.0, 0.1)
	_near(vessel.temperature_c, 0.0, 1e-9, "melting holds the temperature at 0 degC")
	var melted := _mass_g(vessel, "water")
	_near(melted, capacity * 5.0 / WATER_FUSION_J_PER_G, 1e-6, "5 degC of excess heat melts exactly its latent-heat share")
	var energy := capacity * vessel.temperature_c + melted * WATER_FUSION_J_PER_G
	_near(energy, start_energy, 1e-6, "energy is conserved across the melt")
	_near(melted + float(vessel.solids.get("ice", 0.0)), 50.0, 1e-9, "mass is conserved across the melt")
	_check(_has_event(events, "melting"), "a partial-melt observation is emitted")
	# Lots of heat: all melted, mass conserved, water volume uses the liquid density.
	vessel.temperature_c = 40.0
	events = PhaseChangeSystem.step(vessel, _db, capacity, 22.0, 0.1)
	_check(not vessel.solids.has("ice"), "all of the ice melted")
	_near(float(vessel.liquids["water"]) * _db.liquid_density_g_ml("water"), 50.0, 1e-6, "melted water mass equals the ice mass")
	_check(vessel.temperature_c > 0.0 and vessel.temperature_c < 40.0, "the surplus heat after melting warms the water, less than before")
	_check(_has_event(events, "liquid"), "a completely-melted observation is emitted")
	# Stability: a second step with no new heat changes nothing.
	var temperature_before := vessel.temperature_c
	PhaseChangeSystem.step(vessel, _db, capacity, 22.0, 0.1)
	_near(vessel.temperature_c, temperature_before, 1e-9, "a settled vessel is left alone")


func _test_water_freezes_but_solution_does_not() -> void:
	print("-- freezing")
	var vessel := _vessel()
	vessel.add_liquid("water", 100.0)
	vessel.temperature_c = -3.0
	var capacity := 500.0
	var mass := 100.0 * _db.liquid_density_g_ml("water")
	var start_energy := capacity * -3.0 + mass * WATER_FUSION_J_PER_G
	PhaseChangeSystem.step(vessel, _db, capacity, 22.0, 0.1)
	_near(vessel.temperature_c, 0.0, 1e-9, "freezing holds the temperature at 0 degC")
	var ice_g := float(vessel.solids.get("ice", 0.0))
	_near(ice_g, capacity * 3.0 / WATER_FUSION_J_PER_G, 1e-6, "3 degC of undercooling freezes exactly its latent-heat share")
	_near(capacity * vessel.temperature_c + (mass - ice_g) * WATER_FUSION_J_PER_G, start_energy, 1e-6, "energy is conserved across freezing")
	# A salt solution is not pure water; its freezing point is not modelled yet, so it is not frozen wrongly.
	var salty := _vessel()
	salty.add_liquid("water", 100.0)
	salty.dissolved["sodium_chloride"] = 5.0
	salty.temperature_c = -3.0
	PhaseChangeSystem.step(salty, _db, 500.0, 22.0, 0.1)
	_check(not salty.solids.has("ice"), "water with a dissolved solute is not frozen at 0 degC (freezing-point depression is not modelled)")
	_near(salty.temperature_c, -3.0, 1e-9, "its temperature is left unchanged")


func _test_open_boiling_and_evaporation() -> void:
	print("-- boiling and evaporation in an open vessel")
	var vessel := _vessel()
	vessel.add_liquid("water", 100.0)
	var density := _db.liquid_density_g_ml("water")
	var capacity := 500.0
	vessel.temperature_c = 105.0
	var before_g := 100.0 * density
	var events := PhaseChangeSystem.step(vessel, _db, capacity, 22.0, 0.1)
	var boiled := before_g - float(vessel.liquids["water"]) * density
	_near(vessel.temperature_c, _db.get_chemical("water").boiling_point_c, 1e-9, "boiling holds the boiling point")
	_near(boiled, capacity * 5.0 / WATER_VAPORISATION_J_PER_G, 1e-6, "surplus heat vaporises exactly its latent-heat share")
	_check(not vessel.has_gas(), "vapour leaves an open vessel and is not retained")
	_check(_has_event(events, "boiling"), "a boiling observation is emitted")
	# Warm water below the boiling point evaporates slowly and cools.
	var warm := _vessel()
	warm.add_liquid("water", 100.0)
	warm.temperature_c = 60.0
	PhaseChangeSystem.step(warm, _db, capacity, 22.0, 1.0)
	_check(float(warm.liquids["water"]) < 100.0, "warm open water loses a little mass")
	_check(warm.temperature_c < 60.0, "evaporation cools it")
	# Water at room temperature does not drift.
	var cool := _vessel()
	cool.add_liquid("water", 100.0)
	PhaseChangeSystem.step(cool, _db, capacity, 22.0, 1.0)
	_near(float(cool.liquids["water"]), 100.0, 1e-12, "water at room temperature is not evaporated")


func _test_closed_vessel_equilibrium() -> void:
	print("-- closed vessel vapour equilibrium")
	var vessel := _vessel(250.0, 80.0)
	vessel.add_liquid("water", 50.0)
	vessel.seal_system()
	var capacity := 300.0
	var density := _db.liquid_density_g_ml("water")
	var mass_before := 50.0 * density
	var temperature_before := vessel.temperature_c
	PhaseChangeSystem.step(vessel, _db, capacity, 22.0, 0.1)
	var vapour_mol := float(vessel.gases.get("water_vapor", 0.0))
	_check(vapour_mol > 0.0, "a hot sealed vessel fills with water vapour")
	_check(vessel.temperature_c < temperature_before, "evaporation cools the liquid")
	var liquid_g := float(vessel.liquids["water"]) * density
	_near(liquid_g + vapour_mol * 18.015, mass_before, 1e-6, "mass is conserved between liquid and vapour")
	var profile := _db.get_chemical("water").thermal
	var expected_mol := profile.vapor_pressure_kpa(vessel.temperature_c) * vessel.headspace_l() \
		/ (ThermalProfile.GAS_CONSTANT_J_PER_MOL_K * (vessel.temperature_c + ThermalProfile.KELVIN_OFFSET))
	_near(vapour_mol, expected_mol, expected_mol * 1.0e-6, "the vapour amount equals the saturation amount")
	_near(capacity * (temperature_before - vessel.temperature_c), vapour_mol * 18.015 * WATER_VAPORISATION_J_PER_G, 1e-4,
		"the heat taken equals the latent heat of the vapour formed")
	# Cooling a vessel full of vapour condenses it back and warms the liquid.
	vessel.temperature_c = 30.0
	var vapour_before := float(vessel.gases["water_vapor"])
	var events := PhaseChangeSystem.step(vessel, _db, capacity, 22.0, 0.1)
	_check(float(vessel.gases.get("water_vapor", 0.0)) < vapour_before, "cooling condenses the excess vapour")
	_check(_has_event(events, "condensing"), "a condensation observation is emitted")
	_check(vessel.is_closed_system and vessel.pressure_kpa() < _db.constant("max_virtual_pressure_kpa", 300.0) + 1.0, "pressure stays within the virtual limit")


# ---------------------------------------------------------------- alloys and mixtures

func _tin_bismuth() -> BinaryMeltSystem:
	for system_value in _db.binary_systems:
		if (system_value as BinaryMeltSystem).id == "tin_bismuth":
			return system_value
	return null


func _test_tin_bismuth_alloy() -> void:
	print("-- tin and bismuth: mixture, melt, one alloy")
	var system := _tin_bismuth()
	var vessel := _vessel()
	vessel.add_solid("tin", 5.0)
	vessel.add_solid("bismuth", 5.0)
	var mixed_text := ObjectInspector.material_state_text(vessel, _db)
	_check(mixed_text.begins_with("Physical mixture of"), "unmelted tin and bismuth are a physical mixture: '%s'" % mixed_text)
	var capacity := 100.0
	var total_before := _mass_g(vessel, "tin") + _mass_g(vessel, "bismuth")
	# Below the eutectic nothing melts.
	vessel.temperature_c = system.eutectic_c - 20.0
	PhaseChangeSystem.step(vessel, _db, capacity, 22.0, 0.1)
	_check(not vessel.liquids.has("tin") and not vessel.liquids.has("bismuth"), "nothing melts below the eutectic temperature")
	_check(not vessel.fused_systems.has("tin_bismuth"), "they are not fused yet")
	# Above the eutectic: melting starts at the eutectic temperature, not at the pure melting points.
	vessel.temperature_c = system.eutectic_c + 5.0
	var events := PhaseChangeSystem.step(vessel, _db, capacity, 22.0, 0.1)
	_check(vessel.temperature_c <= system.eutectic_c + 5.0 and vessel.temperature_c >= system.eutectic_c - 1e-9,
		"the melt absorbs heat: the temperature falls back toward the eutectic (%.2f)" % vessel.temperature_c)
	_check(vessel.liquids.has("tin") and vessel.liquids.has("bismuth"), "both metals are partly liquid far below either melting point")
	_check(vessel.fused_systems.has("tin_bismuth"), "melting them together records the alloy")
	_check(_has_event(events, "alloy_formed"), "an alloy-formed observation is emitted")
	_near(_mass_g(vessel, "tin") + _mass_g(vessel, "bismuth"), total_before, 1e-9, "mass is conserved")
	_near(_mass_g(vessel, "bismuth"), 5.0, 1e-9, "the bismuth mass is conserved")
	# Enough heat to melt everything.
	vessel.temperature_c = 300.0
	PhaseChangeSystem.step(vessel, _db, capacity, 22.0, 0.1)
	_check(not vessel.solids.has("tin") and not vessel.solids.has("bismuth"), "everything melts with enough heat")
	_check(ObjectInspector.material_state_text(vessel, _db).begins_with("Molten"), "the melt is described as one liquid solution")
	# Cooling freezes it into a single alloy.
	vessel.temperature_c = 60.0
	PhaseChangeSystem.step(vessel, _db, capacity, 22.0, 0.1)
	_check(not vessel.liquids.has("tin") and not vessel.liquids.has("bismuth"), "cooling freezes the melt completely")
	_check(vessel.solids.has("tin") and vessel.solids.has("bismuth"), "the frozen masses are conserved")
	var solid_text := ObjectInspector.material_state_text(vessel, _db)
	_check(solid_text.contains("one fused solid material"), "the frozen result is one fused alloy: '%s'" % solid_text)
	_near(_mass_g(vessel, "tin") + _mass_g(vessel, "bismuth"), total_before, 1e-9, "mass is conserved through melt and freeze")


func _test_unlisted_pair_is_a_mixture() -> void:
	print("-- an unlisted pair is only a mixture")
	var vessel := _vessel()
	vessel.add_solid("tin", 5.0)
	vessel.add_solid("zinc", 5.0)
	vessel.temperature_c = 300.0
	PhaseChangeSystem.step(vessel, _db, 100.0, 22.0, 0.1)
	_check(vessel.fused_systems.is_empty(), "tin and zinc have no alloy data and are never fused")
	_check(vessel.liquids.has("tin") and not vessel.liquids.has("zinc"), "each melts on its own: tin melts at 300 degC, zinc does not")
	_check(ObjectInspector.material_state_text(vessel, _db).contains("Physical mixture of solids") or vessel.solids.has("zinc"),
		"zinc stays a separate solid")


func _test_capacity_uses_profiles() -> void:
	print("-- heat capacity")
	var vessel := _vessel()
	vessel.add_liquid("water", 100.0)
	var water_capacity := ThermalProperties.contents_capacity_j_per_k(vessel, _db)
	_near(water_capacity, 100.0 * _db.liquid_density_g_ml("water") * 4.182, 1e-6, "water uses its sourced specific heat")
	var ethanol := _vessel()
	ethanol.add_liquid("ethanol", 100.0)
	_check(ThermalProperties.contents_capacity_j_per_k(ethanol, _db) < water_capacity * 0.7,
		"ethanol has a lower heat capacity than water (it no longer pretends to be water)")
	var ice := _vessel()
	ice.add_solid("ice", 10.0)
	_near(ThermalProperties.contents_capacity_j_per_k(ice, _db), 10.0 * 2.030, 1e-6, "ice has its own heat capacity")
	var sucrose := _vessel()
	sucrose.add_solid("sucrose", 10.0)
	_near(ThermalProperties.contents_capacity_j_per_k(sucrose, _db), 0.0, 1e-12, "a solid without data is ignored as before")


# ---------------------------------------------------------------- save, load, undo

func _test_save_load_and_legacy() -> void:
	print("-- save / load compatibility")
	var sim := LabSimulation.new(_db)
	var beaker := sim.spawn_object("beaker_250ml", Vector2(100.0, 100.0), {"solids": {"tin": 5.0, "bismuth": 5.0}})
	beaker.vessel.temperature_c = 160.0
	PhaseChangeSystem.step(beaker.vessel, _db, 100.0, 22.0, 0.1)
	_check(beaker.vessel.liquids.has("tin") and beaker.vessel.fused_systems.has("tin_bismuth"), "a molten, fused vessel exists to save")
	var snapshot := sim.capture_snapshot()
	_check(LabSessionStore._validate_snapshot(snapshot, _db).is_empty(),
		"a snapshot with molten tin and a fused alloy passes session validation: '%s'" % LabSessionStore._validate_snapshot(snapshot, _db))
	var restored := VesselState.from_dictionary(beaker.vessel.to_dictionary())
	_check(restored.fused_systems.has("tin_bismuth"), "the alloy record survives a round trip")
	_near(float(restored.liquids.get("tin", 0.0)), float(beaker.vessel.liquids.get("tin", 0.0)), 1e-12, "molten amounts survive a round trip")
	# Sessions saved before this feature have no fused_systems key.
	var legacy := beaker.vessel.to_dictionary()
	legacy.erase("fused_systems")
	var legacy_vessel := VesselState.from_dictionary(legacy)
	_check(legacy_vessel.fused_systems.is_empty(), "a legacy vessel record loads with no alloys")
	var legacy_snapshot := snapshot.duplicate(true)
	for object_key in (legacy_snapshot["objects"] as Dictionary).keys():
		var object_data: Dictionary = legacy_snapshot["objects"][object_key]
		if object_data.get("vessel") != null:
			(object_data["vessel"] as Dictionary).erase("fused_systems")
			(object_data["vessel"] as Dictionary)["liquids"] = {}
			(object_data["vessel"] as Dictionary)["solids"] = {}
	_check(LabSessionStore._validate_snapshot(legacy_snapshot, _db).is_empty(), "a legacy-shaped snapshot still validates")
	# An unknown alloy id is rejected.
	var corrupt := snapshot.duplicate(true)
	for object_key in (corrupt["objects"] as Dictionary).keys():
		var corrupt_object: Dictionary = corrupt["objects"][object_key]
		if corrupt_object.get("vessel") != null:
			(corrupt_object["vessel"] as Dictionary)["fused_systems"] = {"made_up_system": true}
	_check(not LabSessionStore._validate_snapshot(corrupt, _db).is_empty(), "an unknown alloy system id is rejected")
	# Hot sealed vapour above the old 0.01 mol demo limit is accepted.
	var big := LabSimulation.new(_db)
	var flask := big.spawn_object("erlenmeyer_flask_250ml", Vector2(0.0, 0.0), {"liquids": {"water": 20.0}})
	flask.vessel.temperature_c = 110.0
	flask.vessel.seal_system()
	PhaseChangeSystem.step(flask.vessel, _db, 200.0, 22.0, 0.1)
	_check(LabSessionStore._validate_snapshot(big.capture_snapshot(), _db).is_empty(),
		"a sealed vessel holding water vapour validates: '%s'" % LabSessionStore._validate_snapshot(big.capture_snapshot(), _db))


func _test_snapshot_round_trip() -> void:
	print("-- undo / redo snapshots")
	var sim := LabSimulation.new(_db)
	var beaker := sim.spawn_object("beaker_250ml", Vector2(0.0, 0.0), {"solids": {"ice": 30.0}})
	var before := sim.capture_snapshot()
	beaker.vessel.temperature_c = 10.0
	PhaseChangeSystem.step(beaker.vessel, _db, 150.0, 22.0, 0.1)
	var after := sim.capture_snapshot()
	_check(after != before, "melting changes the state")
	sim.restore_snapshot(before)
	var restored := sim.state.get_object(beaker.id)
	_near(float(restored.vessel.solids.get("ice", 0.0)), 30.0, 1e-12, "undo restores the ice")
	_check(not restored.vessel.liquids.has("water"), "undo removes the melt water")
	sim.restore_snapshot(after)
	_check(sim.state.get_object(beaker.id).vessel.liquids.has("water"), "redo restores the melt water")


# ---------------------------------------------------------------- equipment

func _test_cooling_plate_command() -> void:
	print("-- cooling plate")
	var sim := LabSimulation.new(_db)
	var plate := sim.spawn_object("cold_plate_basic", Vector2(0.0, 0.0))
	var hot := sim.spawn_object("hot_plate_basic", Vector2(300.0, 0.0))
	_check(plate != null and plate.target_temperature_c < _db.constant("ambient_temperature_c", 22.0), "the cooling plate defaults to a sub-ambient setpoint")
	_check(_heat_validates(sim, plate.id, -10.0), "a cooling plate accepts -10 degC")
	_check(not _heat_validates(sim, plate.id, -80.0), "a cooling plate refuses a setpoint below its limit")
	_check(not _heat_validates(sim, hot.id, 10.0), "a hot plate still refuses a setpoint below room temperature")
	_check(_heat_validates(sim, hot.id, 80.0), "a hot plate still accepts 80 degC")
	var inspected := ObjectInspector.inspect(sim, plate.id)
	_near(float((inspected["heater"] as Dictionary)["min_c"]), -20.0, 1e-9, "the inspector offers the cooling range")


func _heat_validates(sim: LabSimulation, object_id: String, target_c: float) -> bool:
	var command := HeatCommand.new()
	command.context = InteractionContext.create(&"heat", object_id, "", {"device": "test"}, {"power": "on", "target_c": target_c}, sim.state.time_s)
	return command.validate(sim).is_success


func _test_freeze_on_cooling_plate() -> void:
	print("-- freezing water on the cooling plate (full simulation steps)")
	var sim := LabSimulation.new(_db)
	var plate := sim.spawn_object("cold_plate_basic", Vector2(0.0, 0.0))
	var beaker := sim.spawn_object("beaker_250ml", Vector2(0.0, -60.0), {"liquids": {"water": 50.0}})
	beaker.supported_by = plate.id
	plate.target_temperature_c = -10.0
	plate.power_on = true
	var plateau_steps := 0
	var minimum_temperature := 100.0
	var frozen_at_end := false
	var worst_mass_error := 0.0
	for _step in range(9000):
		sim.step(0.1)
		var vessel := beaker.vessel
		minimum_temperature = minf(minimum_temperature, vessel.temperature_c)
		var liquid_g := float(vessel.liquids.get("water", 0.0)) * _db.liquid_density_g_ml("water")
		var ice_g := float(vessel.solids.get("ice", 0.0))
		if ice_g > 0.5 and liquid_g > 0.5 and absf(vessel.temperature_c) < 0.05:
			plateau_steps += 1
		worst_mass_error = maxf(worst_mass_error, absf(liquid_g + ice_g - 50.0))
		frozen_at_end = liquid_g < 1e-6 and ice_g > 49.9
	_check(worst_mass_error < 1.0e-6, "the water plus ice mass stays constant while freezing (worst error %e g)" % worst_mass_error)
	_check(plateau_steps > 50, "the temperature plateaus at 0 degC while the water freezes (%d steps)" % plateau_steps)
	_check(frozen_at_end, "all of the water has frozen after enough time")
	_check(minimum_temperature < -1.0, "the ice keeps cooling below 0 degC once frozen (%.2f)" % minimum_temperature)
	_check(LabSessionStore._validate_snapshot(sim.capture_snapshot(), _db).is_empty(), "the frozen state validates for saving")


# ---------------------------------------------------------------- helpers

func _has_event(events: Array, fragment: String) -> bool:
	for event in events:
		if str((event as Dictionary).get("key", "")).contains(fragment):
			return true
	return false


func _near(actual: float, expected: float, tolerance: float, message: String) -> void:
	_check(absf(actual - expected) <= tolerance, "%s (got %s, expected %s)" % [message, str(actual), str(expected)])


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error(message)
