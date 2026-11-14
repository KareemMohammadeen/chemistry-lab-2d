extends SceneTree
## Headless scenario tests for the simulation core. No window, no views: it drives the same
## commands the interface uses and checks the laboratory state.
##
## One-time setup (creates the class cache; also done by opening the project in the editor):
##   godot --headless --path . --import
## Run:
##   godot --headless --path . -s tests/run_simulation_tests.gd
## Exit code is 0 when every check passes.

const SETUP_PATH := "res://data/setups/first_demo.json"
const STEP_S := 0.1
const TOLERANCE_ML := 0.01
const SESSION_TEST_PATH := "user://session_roundtrip_test.json"
const INVALID_SESSION_TEST_PATH := "user://invalid_lab_session.json"

var _host: SimulationHost
var _checks: int = 0
var _failures: int = 0


## Autoloads (EventBus) exist by the time _initialize runs, which the command stack needs.
func _initialize() -> void:
	var content := ContentDatabase.new()
	content.load_all()
	_check(content.errors.is_empty(), "content loads without errors: %s" % str(content.errors))
	_host = SimulationHost.new()
	_check(_host.initialise(content, SETUP_PATH), "first demo setup loads")

	_test_setup()
	_test_infinite_spawn_and_reagents()
	_test_invalid_actions_explain_themselves()
	_test_water_and_copper_sulfate_demo()
	_test_undo_and_redo()
	_test_neutralisation()
	_test_heating_and_thermometer()
	_test_pour_moves_dissolved_substance()
	_test_reference_data()
	_test_save_load_session()

	print("\n%d check(s), %d failure(s)" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------- scenarios

func _test_setup() -> void:
	_fresh()
	print("-- setup")
	_check(_sim().state.objects.size() == 11, "11 objects on the starting bench (found %d)" % _sim().state.objects.size())
	for equipment_id in ["beaker_250ml", "test_tube_20ml", "erlenmeyer_flask_250ml", "reagent_bottle_500ml",
			"dropper_3ml", "thermometer_general", "hot_plate_basic"]:
		_check(_find(equipment_id) != null, "equipment present: %s" % equipment_id)
	for chemical_id in ["water", "sodium_chloride", "copper_sulfate_pentahydrate", "hydrochloric_acid_0_1m", "sodium_hydroxide_0_1m"]:
		_check(_find("reagent_bottle_500ml", chemical_id) != null, "a bottle holds %s" % chemical_id)


func _test_infinite_spawn_and_reagents() -> void:
	_fresh()
	print("-- infinite workbench, spawning and direct reagents")
	var spawn := SpawnObjectCommand.new()
	spawn.context = InteractionContext.create(&"spawn", "", "", {"device": "test"}, {
		"equipment_id": "beaker_250ml",
		"position": Vector2(-12500.0, 34200.0),
		"contents": {},
	}, _sim().state.time_s)
	var spawn_result := _host.submit(spawn)
	_check(spawn_result.is_success, "spawn a new beaker anywhere on the infinite workbench")
	var beaker := _sim().state.get_object(spawn.created_object_id)
	_check(beaker != null and beaker.position.is_equal_approx(Vector2(-12500.0, 34200.0)),
		"the new beaker keeps its world position far beyond the original canvas")
	_check(_sim().state.objects.size() == 12, "spawning adds one object without rebuilding the setup")

	var water := AddReagentCommand.new()
	water.context = InteractionContext.create(&"add_reagent", beaker.id, "", {"device": "test"},
		{"chemical_id": "water", "amount": 50.0}, _sim().state.time_s)
	var water_result := _host.submit(water)
	_check(water_result.is_success, "add classroom water directly from the Library")
	_near(beaker.vessel.liquid_volume_ml(), 50.0, "the beaker receives 50 mL of water")

	var salt := AddReagentCommand.new()
	salt.context = InteractionContext.create(&"add_reagent", beaker.id, "", {"device": "test"},
		{"chemical_id": "sodium_chloride", "amount": 5.0}, _sim().state.time_s)
	var salt_result := _host.submit(salt)
	_check(salt_result.is_success, "add table salt directly from the Library")
	_check(absf(float(beaker.vessel.solids.get("sodium_chloride", 0.0)) - 5.0) < 0.001,
		"the beaker receives 5 g of table salt")
	_expect_success(MixCommand.new(), &"mix", beaker.id, "", {}, "mix the water and table salt")
	_check(beaker.vessel.stir_time_left_s > 0.0, "mix starts the stirring period")
	_check(_host.undo().is_success, "undo reverses the latest workbench operation")
	beaker = _sim().state.get_object(spawn.created_object_id)
	_check(beaker.vessel.stir_time_left_s <= 0.0, "undo restores the state before stirring")
	_check(_host.redo().is_success, "redo restores the mixing operation")


func _test_invalid_actions_explain_themselves() -> void:
	_fresh()
	print("-- invalid actions")
	var beaker := _find("beaker_250ml")
	var tube := _find("test_tube_20ml")
	var bottle := _find("reagent_bottle_500ml", "water")
	_expect_failure(PourCommand.new(), &"pour", beaker.id, beaker.id, {}, "pour into itself")
	_expect_failure(PourCommand.new(), &"pour", tube.id, beaker.id, {}, "pour from an empty tube")
	_expect_success(PlaceCommand.new(), &"place", bottle.id, "",
		{"mode": PlaceCommand.MODE_SURFACE, "position": Vector2(-2400.0, 5300.0)}, "place anywhere on the infinite workbench")
	_expect_failure(HeatCommand.new(), &"heat", beaker.id, "", {}, "heat a vessel that is not on the hot plate")
	_expect_failure(PlaceCommand.new(), &"place", bottle.id, _find("hot_plate_basic").id,
		{"mode": PlaceCommand.MODE_SUPPORT}, "put a reagent bottle on the hot plate")
	var failed := 0
	for entry in _host.commands.history:
		if not bool(entry["ok"]) and str(entry["reason"]) != "":
			failed += 1
	_check(failed == 4, "all four rejected commands are in the command log with a reason (%d)" % failed)


func _test_water_and_copper_sulfate_demo() -> void:
	_fresh()
	print("-- demo: water + copper sulfate")
	var beaker := _find("beaker_250ml")
	var water_bottle := _find("reagent_bottle_500ml", "water")
	var salt_bottle := _find("reagent_bottle_500ml", "copper_sulfate_pentahydrate")

	_expect_success(PickUpCommand.new(), &"pick_up", beaker.id, "", {}, "pick up the beaker")
	_check(_sim().held_object_id == beaker.id, "the beaker is held")
	_expect_success(PlaceCommand.new(), &"place", beaker.id, "",
		{"mode": PlaceCommand.MODE_SURFACE, "position": Vector2(600.0, 740.0)}, "place the beaker on the bench")
	_check(_sim().held_object_id == "", "nothing is held after placing")
	_check(beaker.position.is_equal_approx(Vector2(600.0, 740.0)), "the beaker stands where it was put")

	_expect_success(PourCommand.new(), &"pour", water_bottle.id, beaker.id, {"amount_ml": 100.0}, "pour 100 mL of water")
	_near(beaker.vessel.liquid_volume_ml(), 100.0, "the beaker holds 100 mL of liquid")
	_near(water_bottle.vessel.liquid_volume_ml(), 350.0, "the bottle lost 100 mL")
	_check(SolutionAppearance.liquid_color(beaker.vessel, _host.database).b > 0.0, "water has a colour value")
	var clear_color := SolutionAppearance.liquid_color(beaker.vessel, _host.database)

	_expect_success(AddSolidCommand.new(), &"add_solid", salt_bottle.id, beaker.id, {"amount_g": 5.0}, "add 5 g of copper sulfate")
	_near(float(beaker.vessel.solids.get("copper_sulfate_pentahydrate", 0.0)), 5.0, "5 g of crystals lie in the beaker")
	_run_seconds(2.0)
	_check(float(beaker.vessel.dissolved.get("copper_sulfate_pentahydrate", 0.0)) > 0.0, "crystals have started to dissolve")
	_run_seconds(120.0)
	_near(float(beaker.vessel.dissolved.get("copper_sulfate_pentahydrate", 0.0)), 5.0, "all 5 g dissolved (well below the solubility limit)")
	_check(float(beaker.vessel.solids.get("copper_sulfate_pentahydrate", 0.0)) < 0.05, "no crystals remain")

	var blue := SolutionAppearance.liquid_color(beaker.vessel, _host.database)
	_check(blue.b > blue.r + 0.1, "the solution is blue (%s)" % str(blue))
	_check(blue != clear_color, "the colour changed from plain water")
	var texts: Array = []
	for entry in beaker.vessel.observations:
		texts.append(str(entry["text"]))
	_check(texts.any(func(t: String) -> bool: return t.to_lower().contains("blue")), "an observation mentions the blue colour: %s" % str(texts))

	var data := ObjectInspector.inspect(_sim(), beaker.id)
	_check(not data.is_empty() and data["title"] == "Beaker 250 mL", "the inspector names the beaker")
	_check(data["contents"].size() == 2, "the inspector lists water and copper sulfate")
	_check(data["observations"].size() >= 1, "the inspector explains what happened")
	var action_ids: Array = []
	for action in data["actions"]:
		action_ids.append(action["id"])
	_check(action_ids.has("pour") and action_ids.has("mix") and action_ids.has("heat"), "the inspector offers Pour, Mix and Heat")


func _test_undo_and_redo() -> void:
	_fresh()
	print("-- undo and redo")
	var beaker := _find("beaker_250ml")
	var bottle := _find("reagent_bottle_500ml", "water")
	_expect_success(PourCommand.new(), &"pour", bottle.id, beaker.id, {"amount_ml": 60.0}, "pour 60 mL")
	_run_seconds(1.0)
	_check(_host.undo().is_success, "undo succeeds")
	beaker = _find("beaker_250ml")
	bottle = _find("reagent_bottle_500ml", "water")
	_near(beaker.vessel.liquid_volume_ml(), 0.0, "undo empties the beaker")
	_near(bottle.vessel.liquid_volume_ml(), 450.0, "undo refills the bottle")
	_check(_host.redo().is_success, "redo succeeds")
	beaker = _find("beaker_250ml")
	_near(beaker.vessel.liquid_volume_ml(), 60.0, "redo pours again")
	_check(not _host.redo().is_success, "a second redo is refused")
	_check(_host.undo().is_success and not _host.undo().is_success, "undo twice: the second has nothing to undo")


func _test_neutralisation() -> void:
	_fresh()
	print("-- neutralisation")
	var flask := _find("erlenmeyer_flask_250ml")
	var acid := _find("reagent_bottle_500ml", "hydrochloric_acid_0_1m")
	var base := _find("reagent_bottle_500ml", "sodium_hydroxide_0_1m")
	_expect_success(PourCommand.new(), &"pour", acid.id, flask.id, {"amount_ml": 50.0}, "pour 50 mL of acid")
	var acid_ph := AcidBase.compute_ph(flask.vessel, _host.database)
	_check(absf(acid_ph - 1.0) < 0.1, "0.1 M strong acid has pH about 1 (%.2f)" % acid_ph)
	_expect_success(PourCommand.new(), &"pour", base.id, flask.id, {"amount_ml": 50.0}, "pour 50 mL of base")
	_run_seconds(2.0)
	var ph := AcidBase.compute_ph(flask.vessel, _host.database)
	_check(absf(ph - 7.0) < 0.5, "equal amounts of strong acid and base give pH about 7 (%.2f)" % ph)
	var ambient := _host.database.constant("ambient_temperature_c", 22.0)
	_check(flask.vessel.temperature_c > ambient + 0.2, "neutralisation warms the mixture (%.2f degC)" % flask.vessel.temperature_c)


func _test_heating_and_thermometer() -> void:
	_fresh()
	print("-- heating and thermometer")
	var beaker := _find("beaker_250ml")
	var bottle := _find("reagent_bottle_500ml", "water")
	var plate := _find("hot_plate_basic")
	var thermometer := _find("thermometer_general")
	_expect_success(PourCommand.new(), &"pour", bottle.id, beaker.id, {"amount_ml": 100.0}, "pour 100 mL of water")
	_expect_success(PlaceCommand.new(), &"place", beaker.id, plate.id, {"mode": PlaceCommand.MODE_SUPPORT}, "put the beaker on the hot plate")
	_check(beaker.supported_by == plate.id, "the beaker stands on the hot plate")
	_expect_success(PlaceCommand.new(), &"insert", thermometer.id, beaker.id, {"mode": PlaceCommand.MODE_INSERT}, "put the thermometer in the beaker")
	_expect_success(HeatCommand.new(), &"heat", beaker.id, "", {"power": "on", "target_c": 80.0}, "switch the hot plate on")
	var ambient := _host.database.constant("ambient_temperature_c", 22.0)
	_run_seconds(120.0)
	_check(plate.surface_temperature_c > ambient + 30.0, "the plate surface heated up (%.1f degC)" % plate.surface_temperature_c)
	_check(beaker.vessel.temperature_c > ambient + 25.0, "the water heated up (%.1f degC)" % beaker.vessel.temperature_c)
	_check(beaker.vessel.temperature_c < HeatSystem.boiling_point_c(_host.database) + 0.01, "the water never exceeds the boiling point")
	_near(_sim().thermometer_reading_c(thermometer.id), beaker.vessel.temperature_c, "the thermometer reads the water temperature")
	_expect_success(HeatCommand.new(), &"heat", beaker.id, "", {"power": "off"}, "switch the hot plate off")
	_check(not plate.power_on, "the plate is off")
	_run_seconds(30.0)
	_check(plate.surface_temperature_c > ambient + 5.0, "the plate is still warm after switching off")


func _test_pour_moves_dissolved_substance() -> void:
	_fresh()
	print("-- pouring a solution")
	var beaker := _find("beaker_250ml")
	var flask := _find("erlenmeyer_flask_250ml")
	var water := _find("reagent_bottle_500ml", "water")
	var salt := _find("reagent_bottle_500ml", "sodium_chloride")
	_expect_success(PourCommand.new(), &"pour", water.id, beaker.id, {"amount_ml": 100.0}, "pour 100 mL of water")
	_expect_success(AddSolidCommand.new(), &"add_solid", salt.id, beaker.id, {"amount_g": 10.0}, "add 10 g of sodium chloride")
	_run_seconds(120.0)
	_expect_success(PourCommand.new(), &"pour", beaker.id, flask.id, {"amount_ml": 50.0}, "pour half of the solution into the flask")
	var in_beaker := float(beaker.vessel.dissolved.get("sodium_chloride", 0.0))
	var in_flask := float(flask.vessel.dissolved.get("sodium_chloride", 0.0))
	_near(in_beaker + in_flask, 10.0, "no sodium chloride is lost or created by pouring")
	_check(in_flask > 3.0 and in_flask < 7.0, "about half of the salt moved with the water (%.2f g)" % in_flask)


func _test_reference_data() -> void:
	print("-- reference data")
	var db := _host.database
	_check(db.elements.size() == 118, "118 elements are loaded (found %d)" % db.elements.size())
	var numbers_ok := true
	for number in range(1, 119):
		if db.get_element_by_number(number) == null:
			numbers_ok = false
	_check(numbers_ok, "atomic numbers 1 to 118 are all present")
	var iron := db.get_element("Fe")
	_check(iron != null and iron.atomic_number == 26 and iron.group == 8 and iron.block == "d", "iron: Z 26, group 8, d block")
	_check(iron != null and iron.electron_configuration == "[Ar] 3d6 4s2", "iron configuration is [Ar] 3d6 4s2 (%s)" % (iron.electron_configuration if iron != null else ""))
	var oganesson := db.get_element("Og")
	_check(oganesson != null and is_nan(oganesson.melting_c), "unknown values stay unknown (oganesson melting point is NAN)")
	_check(db.get_element("Dy") != null and is_nan(db.get_element("Dy").melting_c), "a value known to be wrong in the source is withheld (dysprosium melting point)")
	_check(db.compounds.size() >= 30, "at least 30 reference compounds are loaded (found %d)" % db.compounds.size())
	var copper_sulfate := db.get_compound("copper_sulfate_pentahydrate")
	_check(copper_sulfate != null and absf(copper_sulfate.molar_mass_g_mol - 249.68) < 0.05, "copper sulfate pentahydrate molar mass is about 249.68 g/mol")
	_check(copper_sulfate != null and db.get_chemical(copper_sulfate.simulation_chemical_id) != null, "the compound links to its playable chemical")
	for compound_id in db.compounds.keys():
		var compound: CompoundDefinition = db.compounds[compound_id]
		_check(compound.hazard_summary != "" and compound.storage != "", "%s has hazard and storage text" % compound.display_name)



func _test_save_load_session() -> void:
	_fresh()
	print("-- session save and load")
	var beaker := _find("beaker_250ml")
	var water_bottle := _find("reagent_bottle_500ml", "water")
	_expect_success(PourCommand.new(), &"pour", water_bottle.id, beaker.id,
		{"amount_ml": 50.0}, "prepare a session with 50 mL of water")
	var expected_state: Dictionary = _sim().capture_snapshot()
	var expected_history_size := _host.commands.history.size()
	var save_result := LabSessionStore.save_to_path(_sim(), _host.commands, SESSION_TEST_PATH)
	_check(bool(save_result.get("ok", false)), "session save succeeds: %s" % str(save_result.get("message", "")))

	_check(_host.undo().is_success, "change the session state before reloading")
	beaker = _find("beaker_250ml")
	_near(beaker.vessel.liquid_volume_ml(), 0.0, "the changed session is now empty")

	var load_result := LabSessionStore.load_from_path(_sim(), _host.commands, _host.database, SESSION_TEST_PATH)
	_check(bool(load_result.get("ok", false)), "session load succeeds: %s" % str(load_result.get("message", "")))
	beaker = _find("beaker_250ml")
	_near(beaker.vessel.liquid_volume_ml(), 50.0, "loading restores vessel contents")
	_check(_sim().capture_snapshot() == expected_state, "loading restores the complete simulation snapshot")
	_check(_host.commands.history.size() == expected_history_size, "loading restores the experiment action log")
	_check(not _host.commands.can_undo() and not _host.commands.can_redo(),
		"loaded history is reportable without stale undo snapshots")

	var invalid_file := FileAccess.open(INVALID_SESSION_TEST_PATH, FileAccess.WRITE)
	invalid_file.store_string("{\"not_a_session\":true}")
	invalid_file.close()
	var before_invalid_load: Dictionary = _sim().capture_snapshot()
	var invalid_result := LabSessionStore.load_from_path(_sim(), _host.commands, _host.database, INVALID_SESSION_TEST_PATH)
	_check(not bool(invalid_result.get("ok", false)), "an invalid session is refused")
	_check(_sim().capture_snapshot() == before_invalid_load, "an invalid session cannot replace the live laboratory")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_TEST_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(INVALID_SESSION_TEST_PATH))


# ---------------------------------------------------------------- helpers

func _sim() -> LabSimulation:
	return _host.simulation


func _fresh() -> void:
	_host.reset()


func _find(equipment_id: String, content_id: String = "") -> LabObject:
	for object_id in _sim().state.objects.keys():
		var item: LabObject = _sim().state.objects[object_id]
		if item.equipment_id != equipment_id:
			continue
		if content_id == "":
			return item
		if item.vessel != null and (item.vessel.liquids.has(content_id) or item.vessel.solids.has(content_id)):
			return item
	return null


func _run_seconds(seconds: float) -> void:
	var steps := int(round(seconds / STEP_S))
	for _step in range(steps):
		_sim().step(STEP_S)


func _submit(command: LabCommand, interaction: StringName, source: String, target: String, payload: Dictionary) -> InteractionResult:
	var context := InteractionContext.create(interaction, source, target, {"device": "test"}, payload, _sim().state.time_s)
	return _host.submit(command.with_context(context))


func _expect_success(command: LabCommand, interaction: StringName, source: String, target: String, payload: Dictionary, label: String) -> void:
	var result := _submit(command, interaction, source, target, payload)
	_check(result.is_success, "%s%s" % [label, "" if result.is_success else " -> refused: %s" % result.message])


func _expect_failure(command: LabCommand, interaction: StringName, source: String, target: String, payload: Dictionary, label: String) -> void:
	var result := _submit(command, interaction, source, target, payload)
	_check(not result.is_success and result.message != "", "refused with a reason: %s (%s)" % [label, result.message])


func _near(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) <= maxf(TOLERANCE_ML, absf(expected) * 0.001), "%s (%.3f, expected %.3f)" % [label, actual, expected])


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  PASS  %s" % label)
	else:
		_failures += 1
		print("  FAIL  %s" % label)
