class_name MixCommand
extends LabCommand
## Stirs the contents of a vessel. Stirring speeds up dissolving (see ReactionEngine); this
## command only starts the stirring period.


func command_name() -> String:
	return "mix"


func validate(sim: LabSimulation) -> InteractionResult:
	var reason := _missing_object_reason(sim, context.source)
	if not reason.is_empty():
		return InteractionResult.failure(reason)
	var item := sim.state.get_object(context.source)
	var equipment := sim.database.get_equipment(item.equipment_id)
	if item.vessel == null or not equipment.supports("mix"):
		return InteractionResult.failure("The %s cannot be stirred." % equipment.display_name)
	if not item.vessel.has_liquid():
		return InteractionResult.failure("There is no liquid in the %s to mix." % sim.object_label(item))
	return InteractionResult.success()


func execute(sim: LabSimulation) -> InteractionResult:
	var item := sim.state.get_object(context.source)
	var duration := sim.database.constant("stir_duration_s", 10.0)
	item.vessel.stir_time_left_s = maxf(item.vessel.stir_time_left_s, duration)
	description = "Stirred %s" % sim.object_label(item)
	return InteractionResult.success()
