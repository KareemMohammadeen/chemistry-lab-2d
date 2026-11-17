class_name HeatSystem
extends RefCounted
## Heat sources and heat exchange (lumped-body model: one temperature per object).
## Hot plates ramp toward their setpoint; vessels standing on them exchange heat by
## conduction and lose heat to the room. Exchange never overshoots equilibrium, so large
## time steps (high simulation speed) stay stable. Boiling is only partly simulated:
## the temperature is held at the boiling point.

const DEFAULT_BOILING_POINT_C := 100.0
const DEFAULT_TRANSFER_W_PER_K := 5.0


## Advances heat by dt seconds. Returns [{"object_id", "entry"}] observation records.
static func step(state: LabState, db: ContentDatabase, dt: float, held_object_id: String) -> Array:
	var events: Array = []
	var ambient := db.constant("ambient_temperature_c", 22.0)
	for object_id in state.objects.keys():
		var source: LabObject = state.objects[object_id]
		var source_equipment := db.get_equipment(source.equipment_id)
		if source_equipment != null and source_equipment.is_heater():
			_step_heater(source, source_equipment, ambient, dt)
	for object_id in state.objects.keys():
		var item: LabObject = state.objects[object_id]
		if item.vessel == null:
			continue
		var equipment := db.get_equipment(item.equipment_id)
		if equipment != null:
			_step_vessel(state, db, item, equipment, ambient, dt, held_object_id, events)
	return events


static func boiling_point_c(db: ContentDatabase) -> float:
	var water := db.get_chemical("water")
	if water == null or is_nan(water.boiling_point_c):
		return DEFAULT_BOILING_POINT_C
	return water.boiling_point_c


## True when an aqueous vessel is at its boiling point.
static func is_boiling(vessel: VesselState, db: ContentDatabase) -> bool:
	if AcidBase.aqueous_volume_ml(vessel, db) <= 0.0:
		return false
	return vessel.temperature_c >= boiling_point_c(db) - db.constant("boil_margin_c", 0.5)


static func _step_heater(heater: LabObject, equipment: EquipmentDefinition, ambient: float, dt: float) -> void:
	var maximum := float(equipment.heater.get("max_surface_temperature_c", 300.0))
	var heating_rate := float(equipment.heater.get("heating_rate_c_per_s", 1.0))
	var cooling_rate := float(equipment.heater.get("cooling_rate_c_per_s", 0.2))
	var goal := ambient
	if heater.power_on:
		goal = minf(heater.target_temperature_c, maximum)
	var rate := heating_rate if goal > heater.surface_temperature_c else cooling_rate
	heater.surface_temperature_c = move_toward(heater.surface_temperature_c, goal, rate * dt)


static func _step_vessel(state: LabState, db: ContentDatabase, item: LabObject, equipment: EquipmentDefinition,
		ambient: float, dt: float, held_object_id: String, events: Array) -> void:
	var vessel := item.vessel
	var capacity := ThermalProperties.total_capacity_j_per_k(vessel, equipment, db)
	if capacity <= 0.0:
		return
	if item.supported_by != "" and item.id != held_object_id:
		var plate := state.get_object(item.supported_by)
		var plate_equipment: EquipmentDefinition = null
		if plate != null:
			plate_equipment = db.get_equipment(plate.equipment_id)
		if plate_equipment != null and plate_equipment.is_heater():
			var conductance := float(plate_equipment.heater.get("heat_transfer_w_per_k", DEFAULT_TRANSFER_W_PER_K))
			vessel.temperature_c = _exchange(vessel.temperature_c, plate.surface_temperature_c, conductance, capacity, dt)
	var room_loss := db.constant("ambient_loss_w_per_k", 0.3)
	vessel.temperature_c = _exchange(vessel.temperature_c, ambient, room_loss, capacity, dt)

	var boiling_point := boiling_point_c(db)
	if AcidBase.aqueous_volume_ml(vessel, db) > 0.0 and vessel.temperature_c > boiling_point:
		vessel.temperature_c = boiling_point
	if vessel.is_closed_system:
		var pressure_limit := db.constant("max_virtual_pressure_kpa", 300.0)
		vessel.temperature_c = minf(vessel.temperature_c, vessel.max_temperature_c_for_pressure_limit(pressure_limit))
	# Boiling observations are now emitted by the generic reaction executor so the chemistry
	# layer owns the event. HeatSystem only keeps the thermal clamp.


## Moves a temperature toward another by conduction, never past it.
static func _exchange(temperature: float, other: float, conductance_w_per_k: float,
		capacity_j_per_k: float, dt: float) -> float:
	var result := temperature + conductance_w_per_k * (other - temperature) * dt / capacity_j_per_k
	if other >= temperature:
		return minf(result, other)
	return maxf(result, other)