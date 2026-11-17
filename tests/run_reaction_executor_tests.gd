extends SceneTree
## Headless coverage for the generic reaction executor. This verifies that the new
## ReactionEngine entry point can execute registered dissolution, neutralisation and
## boiling reactions without relying on the GUI.

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
	print("\n%d check(s), %d failure(s)" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_boiling_executor() -> void:
	print("-- generic executor: boiling")
	var sim := LabSimulation.new(_content)
	var vessel := VesselState.new()
	vessel.capacity_ml = 250.0
	vessel.temperature_c = 105.0
	vessel.add_liquid("water", 100.0)
	var result := sim.engine.execute_registered_reaction("boil_water", vessel)
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
	var result := sim.engine.execute_registered_reaction("dissolve_sodium_chloride", beaker.vessel)
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
	var result := sim.engine.execute_registered_reaction("neutralisation_strong_acid_strong_base", flask.vessel)
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


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error(label)
