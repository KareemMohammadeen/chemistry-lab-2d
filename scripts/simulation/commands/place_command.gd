class_name PlaceCommand
extends LabCommand
## Puts an object down. payload["mode"] selects where:
##   "surface" - on a shelf or the bench; payload["position"] is the base point (Vector2)
##   "support" - on top of an appliance (target), for example a beaker on the hot plate
##   "insert"  - into a vessel (target), for example a thermometer in a beaker

const MODE_SURFACE := "surface"
const MODE_SUPPORT := "support"
const MODE_INSERT := "insert"

var _resolved_position: Vector2 = Vector2.ZERO


func command_name() -> String:
	return "place"


func validate(sim: LabSimulation) -> InteractionResult:
	var reason := _missing_object_reason(sim, context.source)
	if not reason.is_empty():
		return InteractionResult.failure(reason)
	var item := sim.state.get_object(context.source)
	var equipment := sim.database.get_equipment(item.equipment_id)
	var mode := str(context.payload.get("mode", MODE_SURFACE))
	match mode:
		MODE_SURFACE:
			if not bool(equipment.placement.get("surface", false)):
				return InteractionResult.failure("The %s cannot be put down on a surface." % equipment.display_name)
			var position: Vector2 = context.payload.get("position", item.position)
			var resolved := sim.database.layout.resolve_surface(position)
			if resolved.is_empty():
				return InteractionResult.failure("Objects can only be placed on the shelves or on the bench.")
			_resolved_position = resolved["position"]
		MODE_SUPPORT:
			return _validate_support(sim, item, equipment)
		MODE_INSERT:
			return _validate_insert(sim, item, equipment)
		_:
			return InteractionResult.failure("Unknown way of placing an object: %s" % mode)
	return InteractionResult.success()


func execute(sim: LabSimulation) -> InteractionResult:
	var item := sim.state.get_object(context.source)
	var mode := str(context.payload.get("mode", MODE_SURFACE))
	var label := sim.object_label(item)
	match mode:
		MODE_SURFACE:
			item.supported_by = ""
			item.inserted_in = ""
			sim.move_object(item.id, _resolved_position)
			description = "Placed %s on the %s" % [label, _surface_name(sim, _resolved_position)]
		MODE_SUPPORT:
			var support_object := sim.state.get_object(context.target)
			var support_equipment := sim.database.get_equipment(support_object.equipment_id)
			item.inserted_in = ""
			item.supported_by = support_object.id
			var top := float(support_equipment.support.get("top_offset_y", 0.0))
			sim.move_object(item.id, support_object.position + Vector2(0.0, top))
			description = "Placed %s on the %s" % [label, support_equipment.display_name]
		MODE_INSERT:
			var vessel_object := sim.state.get_object(context.target)
			item.supported_by = ""
			item.inserted_in = vessel_object.id
			item.position = vessel_object.position + sim.insert_offset(item)
			description = "Put %s into %s" % [label, sim.object_label(vessel_object)]
	sim.release_held()
	return InteractionResult.success()


func _validate_support(sim: LabSimulation, item: LabObject, equipment: EquipmentDefinition) -> InteractionResult:
	var support_object := sim.state.get_object(context.target)
	if support_object == null:
		return InteractionResult.failure("There is nothing to put it on.")
	var support_equipment := sim.database.get_equipment(support_object.equipment_id)
	if support_equipment.support.is_empty():
		return InteractionResult.failure("The %s cannot hold other objects." % support_equipment.display_name)
	var accepted: Array = support_equipment.support.get("accepts_categories", [])
	if not bool(equipment.placement.get("support", false)) or not accepted.has(equipment.category):
		return InteractionResult.failure("The %s cannot stand on the %s." % [equipment.display_name, support_equipment.display_name])
	for other_id in sim.state.objects.keys():
		var other: LabObject = sim.state.objects[other_id]
		if other.supported_by == support_object.id and other.id != item.id:
			return InteractionResult.failure("The %s already has something on it." % support_equipment.display_name)
	return InteractionResult.success()


func _validate_insert(sim: LabSimulation, item: LabObject, equipment: EquipmentDefinition) -> InteractionResult:
	var vessel_object := sim.state.get_object(context.target)
	if vessel_object == null or vessel_object.vessel == null:
		return InteractionResult.failure("There is no vessel to put it into.")
	if not bool(equipment.placement.get("insert_into_vessel", false)) or not equipment.supports("insert"):
		return InteractionResult.failure("The %s cannot be put inside a vessel." % equipment.display_name)
	if vessel_object.id == item.id:
		return InteractionResult.failure("An object cannot be put inside itself.")
	return InteractionResult.success()


func _surface_name(sim: LabSimulation, position: Vector2) -> String:
	var resolved := sim.database.layout.resolve_surface(position)
	if resolved.is_empty():
		return "bench"
	for surface in sim.database.layout.surfaces:
		if surface["id"] == resolved["surface_id"]:
			return String(surface["label"]).to_lower()
	return "bench"
