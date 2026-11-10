class_name LabObject
extends RefCounted
## One piece of equipment on the bench or a shelf. Plain data.

var id: String = ""
var equipment_id: String = ""
## Base point (bottom centre) in laboratory pixels.
var position: Vector2 = Vector2.ZERO
## Null for equipment that cannot hold contents.
var vessel: VesselState = null
## Id of the appliance this object stands on, or "".
var supported_by: String = ""
## Id of the vessel this object (a thermometer) is placed in, or "".
var inserted_in: String = ""
## Heater state (used only by heat sources).
var power_on: bool = false
var target_temperature_c: float = 80.0
var surface_temperature_c: float = 22.0


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"equipment_id": equipment_id,
		"position": [position.x, position.y],
		"vessel": null if vessel == null else vessel.to_dictionary(),
		"supported_by": supported_by,
		"inserted_in": inserted_in,
		"power_on": power_on,
		"target_temperature_c": target_temperature_c,
		"surface_temperature_c": surface_temperature_c,
	}


static func from_dictionary(data: Dictionary) -> LabObject:
	var item := LabObject.new()
	item.id = str(data.get("id", ""))
	item.equipment_id = str(data.get("equipment_id", ""))
	var coordinates: Array = data.get("position", [0.0, 0.0])
	item.position = Vector2(float(coordinates[0]), float(coordinates[1]))
	var vessel_data: Variant = data.get("vessel")
	if typeof(vessel_data) == TYPE_DICTIONARY:
		item.vessel = VesselState.from_dictionary(vessel_data)
	item.supported_by = str(data.get("supported_by", ""))
	item.inserted_in = str(data.get("inserted_in", ""))
	item.power_on = bool(data.get("power_on", false))
	item.target_temperature_c = float(data.get("target_temperature_c", 80.0))
	item.surface_temperature_c = float(data.get("surface_temperature_c", 22.0))
	return item
