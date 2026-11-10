class_name LabState
extends RefCounted
## The complete, serialisable truth of the laboratory: simulated time and every object.
## Only commands and the simulation step change it. Views read it and never write to it.

var time_s: float = 0.0
## object id -> LabObject (insertion order is kept)
var objects: Dictionary = {}

var _next_index: int = 1


func create_object(equipment_id: String, capacity_ml: float, position: Vector2, ambient_c: float) -> LabObject:
	var item := LabObject.new()
	item.id = "obj_%d" % _next_index
	_next_index += 1
	item.equipment_id = equipment_id
	item.position = position
	item.surface_temperature_c = ambient_c
	if capacity_ml > 0.0:
		item.vessel = VesselState.new()
		item.vessel.capacity_ml = capacity_ml
		item.vessel.temperature_c = ambient_c
	objects[item.id] = item
	return item


func get_object(object_id: String) -> LabObject:
	return objects.get(object_id) as LabObject


func to_dictionary() -> Dictionary:
	var serialised: Dictionary = {}
	for object_id in objects.keys():
		var item: LabObject = objects[object_id]
		serialised[object_id] = item.to_dictionary()
	return {"time_s": time_s, "next_index": _next_index, "objects": serialised}


func restore_from_dictionary(data: Dictionary) -> void:
	time_s = float(data.get("time_s", 0.0))
	_next_index = int(data.get("next_index", 1))
	objects.clear()
	var serialised: Dictionary = data.get("objects", {})
	for object_id in serialised.keys():
		objects[str(object_id)] = LabObject.from_dictionary(serialised[object_id])
