class_name ObjectInspector
extends RefCounted
## Builds the information shown in the Inspector panel for one object, as plain data.
## All chemistry and formatting decisions happen here so the UI only has to display it.

## Number of recent observations listed per object.
const MAX_OBSERVATIONS_SHOWN := 8
const MIN_AMOUNT_ML := 0.05
const MIN_AMOUNT_G := 0.1
const MAX_AMOUNT_G := 500.0


## Returns {} if the object does not exist. Keys: object_id, title, material, summary, rows,
## contents, observations, actions, safety, heater, amount.
static func inspect(sim: LabSimulation, object_id: String) -> Dictionary:
	var item := sim.state.get_object(object_id)
	if item == null:
		return {}
	var db := sim.database
	var equipment := db.get_equipment(item.equipment_id)
	var data := {
		"object_id": object_id,
		"title": sim.object_label(item),
		"material": equipment.material,
		"summary": "",
		"rows": [],
		"contents": [],
		"observations": [],
		"actions": [],
		"safety": [],
		"heater": {"available": false},
		"amount": {"visible": false},
	}
	var rows: Array = data["rows"]
	rows.append({"label": "State", "value": _state_text(sim, item, equipment)})

	if equipment.is_heater():
		rows.append({"label": "Surface temperature", "value": UnitFormat.temperature_c(item.surface_temperature_c)})
		data["heater"] = {
			"available": true,
			"power_on": item.power_on,
			"target_c": item.target_temperature_c,
			"min_c": db.constant("ambient_temperature_c", 22.0),
			"max_c": float(equipment.heater.get("max_surface_temperature_c", 300.0)),
		}
		data["summary"] = "Hot surfaces stay hot after switching off. Check the surface temperature before touching."
	elif not equipment.thermometer.is_empty():
		rows.append({"label": "Reading", "value": UnitFormat.temperature_c(sim.thermometer_reading_c(object_id))})
		data["summary"] = "Put it into a vessel to measure the temperature of its contents."
	elif item.vessel != null:
		_describe_vessel(sim, item, equipment, data)
	return data


static func _describe_vessel(sim: LabSimulation, item: LabObject, equipment: EquipmentDefinition, data: Dictionary) -> void:
	var db := sim.database
	var vessel := item.vessel
	var rows: Array = data["rows"]
	rows.append({"label": "Temperature", "value": UnitFormat.temperature_c(vessel.temperature_c)})
	rows.append({"label": "Volume", "value": "%s of %s" % [
		UnitFormat.volume_ml(vessel.liquid_volume_ml()), UnitFormat.volume_ml(vessel.capacity_ml)]})
	var ph := AcidBase.compute_ph(vessel, db)
	if not is_nan(ph):
		rows.append({"label": "pH (calculated)", "value": "%.1f" % ph})

	var contents: Array = data["contents"]
	var chemical_ids: Array = []
	for chemical_id in vessel.liquids.keys():
		var liquid := db.get_chemical(str(chemical_id))
		contents.append({"name": _name_of(liquid, str(chemical_id)),
			"amount": UnitFormat.volume_ml(float(vessel.liquids[chemical_id])), "detail": ""})
		chemical_ids.append(str(chemical_id))
	var solute_ids: Array = []
	for chemical_id in vessel.solids.keys():
		solute_ids.append(str(chemical_id))
	for chemical_id in vessel.dissolved.keys():
		if not solute_ids.has(str(chemical_id)):
			solute_ids.append(str(chemical_id))
	for solute_id in solute_ids:
		var solute := db.get_chemical(str(solute_id))
		var undissolved := float(vessel.solids.get(solute_id, 0.0))
		var dissolved_g := float(vessel.dissolved.get(solute_id, 0.0))
		var detail := ""
		if vessel.has_liquid():
			detail = "%s dissolved, %s undissolved" % [UnitFormat.mass_g(dissolved_g), UnitFormat.mass_g(undissolved)]
		contents.append({"name": _name_of(solute, str(solute_id)),
			"amount": UnitFormat.mass_g(undissolved + dissolved_g), "detail": detail})
		chemical_ids.append(str(solute_id))

	var safety: Array = data["safety"]
	for chemical_id in chemical_ids:
		var chemical := db.get_chemical(str(chemical_id))
		if chemical != null:
			safety.append("%s: %s" % [chemical.short_name, str(chemical.safety.get("summary", "No safety information."))])

	var observations: Array = data["observations"]
	var first := maxi(vessel.observations.size() - MAX_OBSERVATIONS_SHOWN, 0)
	for index in range(vessel.observations.size() - 1, first - 1, -1):
		var entry: Dictionary = vessel.observations[index]
		observations.append({
			"time_text": "t = %s" % UnitFormat.time_mmss(float(entry.get("time_s", 0.0))),
			"text": str(entry.get("text", "")),
			"explanation": str(entry.get("explanation", "")),
		})

	var actions: Array = data["actions"]
	if equipment.supports("pour"):
		var verb := "Add solid" if (not vessel.has_liquid() and vessel.has_solids()) else "Pour"
		actions.append({"id": "pour", "label": verb,
			"hint": "Then click the vessel to pour into, or drag this vessel onto another one."})
	if equipment.supports("mix"):
		actions.append({"id": "mix", "label": "Mix", "hint": "Stir the contents."})
	if equipment.supports("heat"):
		actions.append({"id": "heat", "label": "Heat", "hint": "Switch the hot plate under this vessel on or off."})

	if equipment.supports("pour"):
		var use_grams := not vessel.has_liquid() and vessel.has_solids()
		data["amount"] = {
			"visible": true,
			"unit": "g" if use_grams else "mL",
			"value": equipment.default_solid_g if use_grams else equipment.default_pour_ml,
			"min": MIN_AMOUNT_G if use_grams else MIN_AMOUNT_ML,
			"max": MAX_AMOUNT_G if use_grams else maxf(equipment.capacity_ml, 1.0),
			"step": MIN_AMOUNT_G if use_grams else MIN_AMOUNT_ML,
		}
	var main_chemical := _first_chemical(db, chemical_ids)
	data["summary"] = main_chemical.summary if main_chemical != null else "Empty. Drag a bottle onto it to fill it."


static func _state_text(sim: LabSimulation, item: LabObject, equipment: EquipmentDefinition) -> String:
	if equipment.is_heater():
		if item.power_on:
			return "On (setpoint %.0f °C)" % item.target_temperature_c
		return "Off"
	if not equipment.thermometer.is_empty():
		if item.inserted_in != "":
			var host_object := sim.state.get_object(item.inserted_in)
			if host_object != null:
				return "In the %s" % sim.object_label(host_object)
		return "Not in a vessel"
	var vessel := item.vessel
	if vessel == null:
		return equipment.default_state
	var parts := PackedStringArray()
	if vessel.is_empty():
		parts.append("Empty")
	elif HeatSystem.is_boiling(vessel, sim.database):
		parts.append("Boiling")
	elif vessel.has_liquid():
		if vessel.has_solids():
			parts.append("Liquid with undissolved solid")
		elif not vessel.dissolved.is_empty():
			parts.append("Solution")
		else:
			parts.append("Contains liquid")
	else:
		parts.append("Contains solid")
	if vessel.stir_time_left_s > 0.0:
		parts.append("being stirred")
	if item.supported_by != "":
		var support_object := sim.state.get_object(item.supported_by)
		if support_object != null:
			parts.append("on the %s" % sim.database.get_equipment(support_object.equipment_id).display_name.to_lower())
	return ", ".join(parts)


static func _name_of(chemical: ChemicalDefinition, fallback: String) -> String:
	return fallback if chemical == null else chemical.display_name


static func _first_chemical(db: ContentDatabase, chemical_ids: Array) -> ChemicalDefinition:
	for chemical_id in chemical_ids:
		var chemical := db.get_chemical(str(chemical_id))
		if chemical != null:
			return chemical
	return null
