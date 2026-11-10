class_name PickUpCommand
extends LabCommand
## The operator takes hold of an object. Changes no laboratory state, so it is logged but
## not undoable.


func _init() -> void:
	undoable = false


func command_name() -> String:
	return "pick_up"


func validate(sim: LabSimulation) -> InteractionResult:
	var reason := _missing_object_reason(sim, context.source)
	if not reason.is_empty():
		return InteractionResult.failure(reason)
	var item := sim.state.get_object(context.source)
	var equipment := sim.database.get_equipment(item.equipment_id)
	if not equipment.movable:
		return InteractionResult.failure("The %s is fixed to the bench and cannot be moved." % equipment.display_name)
	if not equipment.supports("pick_up"):
		return InteractionResult.failure("The %s cannot be picked up." % equipment.display_name)
	if sim.held_object_id != "" and sim.held_object_id != item.id:
		return InteractionResult.failure("Put down what you are holding first.")
	return InteractionResult.success()


func execute(sim: LabSimulation) -> InteractionResult:
	sim.held_object_id = context.source
	description = "Picked up %s" % sim.object_label(sim.state.get_object(context.source))
	return InteractionResult.success()
