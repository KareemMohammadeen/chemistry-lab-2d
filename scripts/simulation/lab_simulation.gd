class_name LabSimulation
extends RefCounted
## The laboratory simulation: owns the LabState, runs the fixed simulation step and offers
## the few operations commands need. It has no nodes and draws nothing.
## Simulation controls truth; views and UI only read it.

signal observation_added(object_id: String, entry: Dictionary)
## Emitted after the state was replaced (setup loaded, undo, redo, reset).
signal state_restored

var database: ContentDatabase
var state: LabState = LabState.new()
var engine: ReactionEngine
## Object the operator is currently holding (dragging), or "".
var held_object_id: String = ""
var setup_title: String = ""


func _init(content: ContentDatabase) -> void:
	database = content
	engine = ReactionEngine.new(content)


## Replaces the state with the objects described in a setup file (data/setups/*.json).
func load_setup(path: String) -> bool:
	var data := JsonDataLoader.load_dictionary(path)
	if data.is_empty():
		return false
	state = LabState.new()
	held_object_id = ""
	setup_title = str(data.get("title", ""))
	for entry in data.get("objects", []):
		var object_data: Dictionary = entry
		var coordinates: Array = object_data.get("position", [0, 0])
		var created := spawn_object(str(object_data.get("equipment", "")),
			Vector2(float(coordinates[0]), float(coordinates[1])), object_data.get("contents", {}))
		if created == null:
			push_error("LabSimulation: setup %s could not create %s" % [path, str(object_data)])
	state_restored.emit()
	return true


## Creates an object. contents: {"liquids": {id: mL}, "solids": {id: g}}.
func spawn_object(equipment_id: String, position: Vector2, contents: Dictionary = {}) -> LabObject:
	var equipment := database.get_equipment(equipment_id)
	if equipment == null:
		push_error("LabSimulation: unknown equipment '%s'" % equipment_id)
		return null
	var ambient := database.constant("ambient_temperature_c", 22.0)
	var created := state.create_object(equipment_id, equipment.capacity_ml, position, ambient)
	if equipment.is_heater():
		created.target_temperature_c = float(equipment.heater.get("default_setpoint_c", 80.0))
	if created.vessel != null:
		var liquids: Dictionary = contents.get("liquids", {})
		for chemical_id in liquids.keys():
			created.vessel.add_liquid(str(chemical_id), float(liquids[chemical_id]))
		var solids: Dictionary = contents.get("solids", {})
		for chemical_id in solids.keys():
			created.vessel.add_solid(str(chemical_id), float(solids[chemical_id]))
	elif not contents.is_empty():
		push_error("LabSimulation: %s cannot hold contents" % equipment_id)
	return created


## Advances the simulation by one fixed step (called by the SimulationHost).
func step(dt: float) -> void:
	state.time_s += dt
	for object_id in state.objects.keys():
		var item: LabObject = state.objects[object_id]
		if item.vessel == null:
			continue
		var glass := ThermalProperties.glass_capacity_j_per_k(database.get_equipment(item.equipment_id), database)
		for event in engine.step_vessel(item.vessel, dt, glass):
			_record_observation(item.id, event)
	for heat_event in HeatSystem.step(state, database, dt, held_object_id):
		_record_observation(str(heat_event["object_id"]), heat_event["entry"])


## Moves an object and everything inserted in it (thermometers).
func move_object(object_id: String, new_position: Vector2) -> void:
	var item := state.get_object(object_id)
	if item == null:
		return
	item.position = new_position
	for other_id in state.objects.keys():
		var attached: LabObject = state.objects[other_id]
		if attached.inserted_in == object_id:
			attached.position = new_position + insert_offset(attached)


## Offset of an inserted object (thermometer) from the vessel's base point.
func insert_offset(inserted: LabObject) -> Vector2:
	var equipment := database.get_equipment(inserted.equipment_id)
	if equipment == null:
		return Vector2.ZERO
	var entry: Array = equipment.thermometer.get("insert_offset", [0, 0])
	return Vector2(float(entry[0]), float(entry[1]))


func release_held() -> void:
	held_object_id = ""


## What a thermometer reads: the temperature of the vessel it is in, otherwise room temperature.
func thermometer_reading_c(object_id: String) -> float:
	var item := state.get_object(object_id)
	if item != null and item.inserted_in != "":
		var host_vessel := state.get_object(item.inserted_in)
		if host_vessel != null and host_vessel.vessel != null:
			return host_vessel.vessel.temperature_c
	return database.constant("ambient_temperature_c", 22.0)


## Operator-facing name of an object, including the main content of a reagent bottle.
func object_label(item: LabObject) -> String:
	var equipment := database.get_equipment(item.equipment_id)
	var base_name := item.equipment_id if equipment == null else equipment.display_name
	if equipment != null and equipment.style() == "bottle" and item.vessel != null:
		var main_content := _main_content_id(item.vessel)
		var chemical := database.get_chemical(main_content)
		if chemical != null:
			return "%s (%s)" % [base_name, chemical.short_name]
	return base_name


func capture_snapshot() -> Dictionary:
	return state.to_dictionary()


func restore_snapshot(snapshot: Dictionary) -> void:
	state.restore_from_dictionary(snapshot)
	held_object_id = ""
	state_restored.emit()


func _main_content_id(vessel: VesselState) -> String:
	var best_id := ""
	var best_amount := 0.0
	for chemical_id in vessel.liquids.keys():
		if float(vessel.liquids[chemical_id]) > best_amount:
			best_amount = float(vessel.liquids[chemical_id])
			best_id = str(chemical_id)
	for chemical_id in vessel.solids.keys():
		if float(vessel.solids[chemical_id]) > best_amount:
			best_amount = float(vessel.solids[chemical_id])
			best_id = str(chemical_id)
	return best_id


func record_observation(object_id: String, entry: Dictionary) -> void:
	_record_observation(object_id, entry)


func _record_observation(object_id: String, entry: Dictionary) -> void:
	var item := state.get_object(object_id)
	if item == null or item.vessel == null:
		return
	entry["time_s"] = state.time_s
	item.vessel.add_observation(entry)
	observation_added.emit(object_id, entry)
