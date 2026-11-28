class_name HeatCommand
extends LabCommand
## Switches a heat source on or off and sets its target temperature.
## The source may be the heater itself or a vessel standing on it.
## payload["power"]: "on", "off" or "toggle" (default). payload["target_c"]: setpoint (optional).

var _heater_id: String = ""


func command_name() -> String:
	return "heat"


func validate(sim: LabSimulation) -> InteractionResult:
	var reason := _missing_object_reason(sim, context.source)
	if not reason.is_empty():
		return InteractionResult.failure(reason)
	var source := sim.state.get_object(context.source)
	var source_equipment := sim.database.get_equipment(source.equipment_id)
	var heater := source
	if not source_equipment.is_heater():
		if not source_equipment.supports("heat"):
			return InteractionResult.failure("The %s cannot be heated on the hot plate." % source_equipment.display_name)
		if source.supported_by == "":
			return InteractionResult.failure("The %s is not on a heat source. Place it on the hot plate first." % sim.object_label(source))
		heater = sim.state.get_object(source.supported_by)
		if heater == null:
			return InteractionResult.failure("The heat source is no longer on the bench.")
	_heater_id = heater.id
	var heater_equipment := sim.database.get_equipment(heater.equipment_id)
	var target := float(context.payload.get("target_c", heater.target_temperature_c))
	var maximum := float(heater_equipment.heater.get("max_surface_temperature_c", 300.0))
	var ambient := sim.database.constant("ambient_temperature_c", 22.0)
	# A cooling plate declares how far below room temperature it can go; a hot plate cannot.
	var minimum := float(heater_equipment.heater.get("min_surface_temperature_c", ambient))
	if target > maximum:
		return InteractionResult.failure("The %s cannot go above %.0f °C." % [heater_equipment.display_name, maximum])
	if target < minimum:
		if minimum >= ambient:
			return InteractionResult.failure("The setpoint cannot be below room temperature (%.0f °C)." % ambient)
		return InteractionResult.failure("The %s cannot go below %.0f °C." % [heater_equipment.display_name, minimum])
	return InteractionResult.success()


func execute(sim: LabSimulation) -> InteractionResult:
	var heater := sim.state.get_object(_heater_id)
	var heater_equipment := sim.database.get_equipment(heater.equipment_id)
	heater.target_temperature_c = float(context.payload.get("target_c", heater.target_temperature_c))
	match str(context.payload.get("power", "toggle")):
		"on":
			heater.power_on = true
		"off":
			heater.power_on = false
		_:
			heater.power_on = not heater.power_on
	var note := ""
	if heater.power_on:
		description = "Switched the %s on (setpoint %.0f °C)" % [heater_equipment.display_name, heater.target_temperature_c]
		var ambient_c := sim.database.constant("ambient_temperature_c", 22.0)
		if heater.target_temperature_c < ambient_c:
			note = "The surface cools toward %.0f °C and stays cold after it is switched off." % heater.target_temperature_c
		else:
			note = "The surface heats toward %.0f °C and stays hot after it is switched off." % heater.target_temperature_c
	else:
		description = "Switched the %s off" % heater_equipment.display_name
		note = "The %s is off; its surface drifts back to room temperature." % heater_equipment.display_name
	return InteractionResult.success(note, {"heater_id": heater.id, "power_on": heater.power_on})
