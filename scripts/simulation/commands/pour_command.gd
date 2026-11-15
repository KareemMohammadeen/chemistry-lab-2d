class_name PourCommand
extends LabCommand
## Pours liquid from the source vessel into the target vessel.
## payload["amount_ml"] is the requested volume; less is poured if the source runs out or
## the target fills up. Dissolved substances travel with the liquid, undissolved solids stay
## behind (decanting). Which chemistry follows is decided by the ReactionEngine, not here.


func command_name() -> String:
	return "pour"


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
		return InteractionResult.failure("A vessel cannot be poured into itself.")
	if source.vessel == null or not source_equipment.supports("pour"):
		return InteractionResult.failure("The %s cannot be used for pouring." % source_equipment.display_name)
	if target.vessel == null or not target_equipment.is_vessel():
		return InteractionResult.failure("The %s cannot receive a liquid." % target_equipment.display_name)
	if source.vessel.is_closed_system or target.vessel.is_closed_system:
		return InteractionResult.failure("Open the virtual stopper before pouring between vessels.")
	if not source.vessel.has_liquid():
		if source.vessel.has_solids():
			return InteractionResult.failure("The %s contains only solid, not liquid." % sim.object_label(source))
		return InteractionResult.failure("The %s is empty, so there is nothing to pour." % sim.object_label(source))
	if target.vessel.free_volume_ml() <= VesselState.EPSILON:
		return InteractionResult.failure("The %s is full." % sim.object_label(target))
	return InteractionResult.success()


func execute(sim: LabSimulation) -> InteractionResult:
	var source := sim.state.get_object(context.source)
	var target := sim.state.get_object(context.target)
	var source_equipment := sim.database.get_equipment(source.equipment_id)
	var requested := float(context.payload.get("amount_ml", 0.0))
	if requested <= 0.0:
		requested = source_equipment.default_pour_ml
	var available := source.vessel.liquid_volume_ml()
	var free := target.vessel.free_volume_ml()
	var amount := minf(requested, minf(available, free))
	var fraction := amount / available

	var target_volume_before := target.vessel.liquid_volume_ml()
	var removed := source.vessel.take_liquid_fraction(fraction)
	for chemical_id in removed.keys():
		target.vessel.add_liquid(str(chemical_id), float(removed[chemical_id]))
	_move_dissolved(source.vessel, target.vessel, fraction)
	var neutralised_moved := source.vessel.neutralised_mol * fraction
	source.vessel.neutralised_mol -= neutralised_moved
	target.vessel.neutralised_mol += neutralised_moved
	# volume-weighted mixing of temperatures
	target.vessel.temperature_c = (target.vessel.temperature_c * target_volume_before
		+ source.vessel.temperature_c * amount) / (target_volume_before + amount)

	description = "Poured %s from %s into %s" % [
		UnitFormat.volume_ml(amount), sim.object_label(source), sim.object_label(target)]
	sim.release_held()
	var note := ""
	if free < requested and free <= available:
		note = "Only %s fit in the %s." % [UnitFormat.volume_ml(amount), sim.object_label(target)]
	elif available < requested:
		note = "The %s only had %s left." % [sim.object_label(source), UnitFormat.volume_ml(amount)]
	return InteractionResult.success(note, {"amount_ml": amount, "kind": "liquid"})


func _move_dissolved(from_vessel: VesselState, to_vessel: VesselState, fraction: float) -> void:
	for chemical_id in from_vessel.dissolved.keys():
		var moved := float(from_vessel.dissolved[chemical_id]) * fraction
		var remaining := float(from_vessel.dissolved[chemical_id]) - moved
		if remaining <= VesselState.EPSILON:
			from_vessel.dissolved.erase(chemical_id)
		else:
			from_vessel.dissolved[chemical_id] = remaining
		to_vessel.dissolved[chemical_id] = float(to_vessel.dissolved.get(chemical_id, 0.0)) + moved
