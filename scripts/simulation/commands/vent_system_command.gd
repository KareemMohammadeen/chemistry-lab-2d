class_name VentSystemCommand
extends LabCommand
## Returns a closed virtual vessel to ambient conditions and clears its retained gas ledger.

func command_name() -> String:
	return "vent_system"


func validate(sim: LabSimulation) -> InteractionResult:
	var reason := _missing_object_reason(sim, context.source)
	if not reason.is_empty():
		return InteractionResult.failure(reason)
	var item := sim.state.get_object(context.source)
	if item.vessel == null or not item.vessel.is_closed_system:
		return InteractionResult.failure("This vessel is already an open system.")
	return InteractionResult.success()


func execute(sim: LabSimulation) -> InteractionResult:
	var item := sim.state.get_object(context.source)
	var released := item.vessel.open_system()
	description = "Returned %s to the open-system model" % sim.object_label(item)
	var entry := {
		"key": "system_vented_%s" % item.id,
		"kind": "system",
		"text": "The virtual vessel is open again; its gas ledger has been cleared and pressure returns to ambient.",
		"explanation": "This is a state change inside the simulation only.",
	}
	sim.record_observation(item.id, entry)
	return InteractionResult.success("The virtual vessel is open again.", {"gas_species_cleared": released.size()})
