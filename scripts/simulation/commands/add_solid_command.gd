class_name AddSolidCommand
extends LabCommand
## Adds a solid (powder or crystals) from the source vessel into the target vessel.
## payload["amount_g"] is the requested mass; payload["solid_id"] optionally picks the solid.
## Whether and how fast it dissolves is decided later by the ReactionEngine.


func command_name() -> String:
	return "add_solid"


func validate(sim: LabSimulation) -> InteractionResult:
	var reason := _missing_object_reason(sim, context.source)
	if reason.is_empty():
		reason = _missing_object_reason(sim, context.target)
	if not reason.is_empty():
		return InteractionResult.failure(reason)
	var source := sim.state.get_object(context.source)
	var target := sim.state.get_object(context.target)
	var source_equipment := sim.database.get_equipment(source.equipment_id)
	var target_equipment := sim.database.get_equipment(target.equipment_id)
	if source.id == target.id:
		return InteractionResult.failure("A vessel cannot be emptied into itself.")
	if source.vessel == null or not source_equipment.supports("add_solid"):
		return InteractionResult.failure("The %s cannot be used to add a solid." % source_equipment.display_name)
	if target.vessel == null or not target_equipment.is_vessel():
		return InteractionResult.failure("The %s cannot receive a solid." % target_equipment.display_name)
	if source.vessel.is_closed_system or target.vessel.is_closed_system:
		return InteractionResult.failure("Open the virtual stopper before transferring a solid.")
	if _solid_id(source.vessel).is_empty():
		return InteractionResult.failure("The %s contains no solid." % sim.object_label(source))
	return InteractionResult.success()


func execute(sim: LabSimulation) -> InteractionResult:
	var source := sim.state.get_object(context.source)
	var target := sim.state.get_object(context.target)
	var source_equipment := sim.database.get_equipment(source.equipment_id)
	var solid_id := _solid_id(source.vessel)
	var requested := float(context.payload.get("amount_g", 0.0))
	if requested <= 0.0:
		requested = source_equipment.default_solid_g
	var available := float(source.vessel.solids[solid_id])
	var amount := minf(requested, available)
	if available - amount <= VesselState.EPSILON:
		source.vessel.solids.erase(solid_id)
	else:
		source.vessel.solids[solid_id] = available - amount
	target.vessel.add_solid(solid_id, amount)

	var chemical := sim.database.get_chemical(solid_id)
	var solid_name := solid_id if chemical == null else chemical.short_name
	description = "Added %s of %s from %s to %s" % [
		UnitFormat.mass_g(amount), solid_name, sim.object_label(source), sim.object_label(target)]
	sim.release_held()
	var note := ""
	if available < requested:
		note = "The %s only had %s left." % [sim.object_label(source), UnitFormat.mass_g(amount)]
	return InteractionResult.success(note, {"amount_g": amount, "kind": "solid", "solid_id": solid_id})


## The solid to move: payload["solid_id"] if it is present, otherwise the first solid.
func _solid_id(vessel: VesselState) -> String:
	var wanted := str(context.payload.get("solid_id", ""))
	if not wanted.is_empty():
		return wanted if float(vessel.solids.get(wanted, 0.0)) > VesselState.EPSILON else ""
	for chemical_id in vessel.solids.keys():
		if float(vessel.solids[chemical_id]) > VesselState.EPSILON:
			return str(chemical_id)
	return ""
