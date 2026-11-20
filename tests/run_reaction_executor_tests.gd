extends SceneTree
## Headless coverage for the generic reaction executor. This verifies that the new
## ReactionEngine entry point can execute registered dissolution, neutralisation,
## boiling and generic family reactions without relying on the GUI.

const SETUP_PATH := "res://data/setups/first_demo.json"

var _content: ContentDatabase
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_content = ContentDatabase.new()
	_content.load_all()
	_check(_content.errors.is_empty(), "content loads without errors: %s" % str(_content.errors))
	_test_boiling_executor()
	_test_dissolution_executor()
	_test_neutralisation_executor()
	_test_precipitation_executor()
	_test_double_displacement_executor()
	_test_gas_evolution_executor()
	_test_single_displacement_executor()
	_test_combustion_executor()
	_test_phase_change_executor()
	_test_generic_executor()
	_test_step_dispatch()
	print("\n%d check(s), %d failure(s)" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_boiling_executor() -> void:
	print("-- generic executor: boiling")
	var sim := LabSimulation.new(_content)
	var vessel := VesselState.new()
	vessel.capacity_ml = 250.0
	vessel.temperature_c = 105.0
	vessel.add_liquid("water", 100.0)
	var result: ReactionResult = sim.engine.execute_registered_reaction("boil_water", vessel)
	_check(result.status == ReactionResult.Status.EXECUTED, "boiling executor returns EXECUTED")
	_check(result.observations.size() > 0, "boiling executor returns observations")
	_check(result.effects.size() > 0, "boiling executor returns visual effects")
	_check(is_equal_approx(vessel.temperature_c, 100.0), "boiling clamps the vessel at the water boiling point")
	_check(_contains_observation(result.observations, "boiling"), "boiling observation is recorded by the executor")
	_check(_contains_effect(result.effects, "boiling_bubbles"), "boiling exposes bubble feedback")


func _test_dissolution_executor() -> void:
	print("-- generic executor: dissolution")
	var sim := LabSimulation.new(_content)
	_check(sim.load_setup(SETUP_PATH), "first demo setup loads for dissolution")
	var beaker := _find(sim, "beaker_250ml")
	_check(beaker != null and beaker.vessel != null, "beaker found for dissolution test")
	if beaker == null or beaker.vessel == null:
		return
	beaker.vessel.add_liquid("water", 100.0)
	beaker.vessel.add_solid("sodium_chloride", 5.0)
	var before_snapshot := sim.capture_snapshot()
	var result: ReactionResult = sim.engine.execute_registered_reaction("dissolve_sodium_chloride", beaker.vessel)
	_check(result.status == ReactionResult.Status.EXECUTED, "dissolution executor returns EXECUTED")
	_check(result.effects.size() > 0, "dissolution executor returns visual effects")
	_check(float(beaker.vessel.dissolved.get("sodium_chloride", 0.0)) > 0.0, "salt moves into the dissolved ledger")
	_check(float(beaker.vessel.solids.get("sodium_chloride", 0.0)) < 5.0, "solid salt is consumed by the executor")
	_check(result.produced.has("dissolved"), "dissolution result reports produced dissolved material")
	_check(result.consumed.has("solids"), "dissolution result reports consumed solid material")
	_check(before_snapshot != sim.capture_snapshot(), "the executor mutates the simulation snapshot")


func _test_neutralisation_executor() -> void:
	print("-- generic executor: neutralisation")
	var sim := LabSimulation.new(_content)
	_check(sim.load_setup(SETUP_PATH), "first demo setup loads for neutralisation")
	var flask := _find(sim, "erlenmeyer_flask_250ml")
	_check(flask != null and flask.vessel != null, "flask found for neutralisation test")
	if flask == null or flask.vessel == null:
		return
	flask.vessel.add_liquid("hydrochloric_acid_0_1m", 50.0)
	flask.vessel.add_liquid("sodium_hydroxide_0_1m", 50.0)
	var before_temperature := flask.vessel.temperature_c
	var result: ReactionResult = sim.engine.execute_registered_reaction("neutralisation_strong_acid_strong_base", flask.vessel)
	_check(result.status == ReactionResult.Status.EXECUTED, "neutralisation executor returns EXECUTED")
	_check(result.effects.size() > 0, "neutralisation executor returns visual effects")
	_check(result.temperature_delta_c >= 0.0, "neutralisation reports a non-negative temperature change")
	_check(flask.vessel.temperature_c >= before_temperature, "neutralisation warms the vessel or keeps it stable")
	_check(result.consumed.has("acid_mol") and result.consumed.has("base_mol"), "neutralisation reports the consumed acid and base")
	_check(result.produced.has("liquid") and result.produced.has("dissolved"), "neutralisation reports the produced water and salt")
	var has_heat_wave := false
	for effect in result.effects:
		if str(effect.get("effect_id", "")) == "heat_wave":
			has_heat_wave = true
	_check(has_heat_wave, "neutralisation includes a heat-wave effect")


func _test_precipitation_executor() -> void:
	print("-- generic executor: precipitation")
	var sim := LabSimulation.new(_content)
	var vessel := VesselState.new()
	vessel.capacity_ml = 250.0
	vessel.add_liquid("calcium_chloride_0_1m", 50.0)
	vessel.add_liquid("sodium_carbonate_0_1m", 50.0)
	var result: ReactionResult = sim.engine.execute_registered_reaction("precipitation_calcium_chloride_sodium_carbonate", vessel)
	_check(result.status == ReactionResult.Status.EXECUTED, "precipitation executor returns EXECUTED")
	_check(float(vessel.solids.get("calcium_carbonate", 0.0)) > 0.0, "precipitation forms calcium carbonate")
	_check(float(vessel.dissolved.get("sodium_chloride", 0.0)) > 0.0, "precipitation leaves dissolved salt behind")
	_check(_contains_observation(result.observations, "generic_reaction:precipitation_calcium_chloride_sodium_carbonate"), "precipitation records a generic observation")


func _test_double_displacement_executor() -> void:
	print("-- generic executor: double displacement")
	var sim := LabSimulation.new(_content)
	var vessel := VesselState.new()
	vessel.capacity_ml = 250.0
	vessel.add_liquid("calcium_chloride_0_1m", 50.0)
	vessel.add_liquid("sodium_carbonate_0_1m", 50.0)
	var result: ReactionResult = sim.engine.execute_registered_reaction("double_displacement_calcium_chloride_sodium_carbonate", vessel)
	_check(result.status == ReactionResult.Status.EXECUTED, "double displacement executor returns EXECUTED")
	_check(float(vessel.solids.get("calcium_carbonate", 0.0)) > 0.0, "double displacement forms a precipitate")
	_check(_contains_effect(result.effects, "precipitate_cloud"), "double displacement returns precipitate feedback")


func _test_gas_evolution_executor() -> void:
	print("-- generic executor: gas evolution")
	var sim := LabSimulation.new(_content)
	var vessel := VesselState.new()
	vessel.capacity_ml = 250.0
	vessel.add_solid("zinc", 2.0)
	vessel.add_liquid("hydrochloric_acid_0_1m", 50.0)
	var result: ReactionResult = sim.engine.execute_registered_reaction("gas_evolution_zinc_hydrochloric_acid", vessel)
	_check(result.status == ReactionResult.Status.EXECUTED, "gas evolution returns EXECUTED")
	_check(float(vessel.gases.get("hydrogen_gas", 0.0)) > 0.0, "gas evolution releases hydrogen")
	_check(_contains_effect(result.effects, "gas_bubbles"), "gas evolution returns gas feedback")


func _test_single_displacement_executor() -> void:
	print("-- generic executor: single displacement")
	var sim := LabSimulation.new(_content)
	var vessel := VesselState.new()
	vessel.capacity_ml = 250.0
	vessel.add_solid("magnesium", 2.0)
	vessel.add_liquid("hydrochloric_acid_0_1m", 50.0)
	var result: ReactionResult = sim.engine.execute_registered_reaction("single_displacement_magnesium_hydrochloric_acid", vessel)
	_check(result.status == ReactionResult.Status.EXECUTED, "single displacement returns EXECUTED")
	_check(float(vessel.gases.get("hydrogen_gas", 0.0)) > 0.0, "single displacement produces hydrogen gas")
	_check(result.produced.has("dissolved"), "single displacement reports dissolved product")


func _test_combustion_executor() -> void:
	print("-- generic executor: combustion")
	var sim := LabSimulation.new(_content)
	var vessel := VesselState.new()
	vessel.capacity_ml = 250.0
	vessel.add_solid("magnesium", 2.0)
	vessel.add_gas("oxygen_gas", 1.0)
	var result: ReactionResult = sim.engine.execute_registered_reaction("combustion_magnesium_oxygen", vessel)
	_check(result.status == ReactionResult.Status.EXECUTED, "combustion returns EXECUTED")
	_check(float(vessel.solids.get("magnesium_oxide", 0.0)) > 0.0, "combustion forms magnesium oxide")
	_check(_contains_observation(result.observations, "generic_reaction:combustion_magnesium_oxygen"), "combustion records a generic observation")


func _test_phase_change_executor() -> void:
	print("-- generic executor: phase change")
	var sim := LabSimulation.new(_content)
	var vessel := VesselState.new()
	vessel.capacity_ml = 250.0
	vessel.add_solid("ice", 5.0)
	var result: ReactionResult = sim.engine.execute_registered_reaction("phase_change_ice_melting", vessel)
	_check(result.status == ReactionResult.Status.EXECUTED, "phase change returns EXECUTED")
	_check(float(vessel.liquids.get("water", 0.0)) > 0.0, "phase change creates liquid water")
	_check(_contains_observation(result.observations, "generic_reaction:phase_change_ice_melting"), "phase change records a generic observation")


func _test_generic_executor() -> void:
	print("-- generic executor: acid-carbonate")
	var sim := LabSimulation.new(_content)
	var vessel := VesselState.new()
	vessel.capacity_ml = 250.0
	vessel.add_liquid("hydrochloric_acid_0_1m", 50.0)
	vessel.add_solid("sodium_bicarbonate", 2.0)
	var result: ReactionResult = sim.engine.execute_registered_reaction("acid_carbonate_hydrochloric_sodium_bicarbonate", vessel)
	_check(result.status == ReactionResult.Status.EXECUTED, "acid-carbonate reaction returns EXECUTED")
	_check(float(vessel.gases.get("carbon_dioxide", 0.0)) > 0.0, "acid-carbonate produces carbon dioxide gas")
	_check(float(vessel.dissolved.get("sodium_chloride", 0.0)) > 0.0, "acid-carbonate produces dissolved salt")
	_check(result.effects.size() > 0, "acid-carbonate returns visual feedback")
	_check(_contains_observation(result.observations, "generic_reaction:acid_carbonate_hydrochloric_sodium_bicarbonate"), "acid-carbonate records a generic observation")


func _test_step_dispatch() -> void:
	print("-- generic executor: step dispatch")
	var sim := LabSimulation.new(_content)
	var vessel := VesselState.new()
	vessel.capacity_ml = 250.0
	vessel.temperature_c = 105.0
	vessel.add_liquid("water", 100.0)
	var results: Array[ReactionResult] = sim.engine.execute_step_reactions(vessel)
	_check(results.size() >= 1, "step dispatch returns at least one result")
	_check(_contains_result(results, "boil_water"), "step dispatch includes boiling")
	var boiling := _find_result(results, "boil_water")
	_check(boiling != null and boiling.status == ReactionResult.Status.EXECUTED, "boiling is executed by the generic step dispatcher")
	_check(is_equal_approx(vessel.temperature_c, 100.0), "step dispatch clamps the vessel at the water boiling point")


func _find(sim: LabSimulation, equipment_id: String, chemical_id: String = "") -> LabObject:
	for item_value in sim.state.objects.values():
		var item: LabObject = item_value
		if item.equipment_id != equipment_id:
			continue
		if chemical_id.is_empty():
			return item
		if item.vessel == null:
			continue
		if item.vessel.liquids.has(chemical_id) or item.vessel.solids.has(chemical_id) or item.vessel.dissolved.has(chemical_id) or item.vessel.gases.has(chemical_id):
			return item
	return null


func _contains_observation(entries: Array, key: String) -> bool:
	for entry in entries:
		if typeof(entry) == TYPE_DICTIONARY and str((entry as Dictionary).get("key", "")) == key:
			return true
	return false


func _contains_effect(entries: Array, effect_id: String) -> bool:
	for entry in entries:
		if typeof(entry) == TYPE_DICTIONARY and str((entry as Dictionary).get("effect_id", "")) == effect_id:
			return true
	return false


func _contains_result(results: Array, reaction_id: String) -> bool:
	return _find_result(results, reaction_id) != null


func _find_result(results: Array, reaction_id: String) -> ReactionResult:
	for entry in results:
		if entry is ReactionResult and str((entry as ReactionResult).reaction_id) == reaction_id:
			return entry
	return null


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error(message)
