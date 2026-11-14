class_name AddReagentCommand
extends LabCommand
## Adds one of the two classroom-demo reagents directly to a receiving vessel.
## This is a virtual teaching interaction, not a real-world lab procedure.

const ALLOWED_REAGENTS: Array[String] = ["water", "sodium_chloride"]


func command_name() -> String:
	return "add_reagent"


func validate(sim: LabSimulation) -> InteractionResult:
	var reason := _missing_object_reason(sim, context.source)
	if not reason.is_empty():
		return InteractionResult.failure(reason)
	var target := sim.state.get_object(context.source)
	var equipment := sim.database.get_equipment(target.equipment_id)
	if target.vessel == null or equipment == null or not equipment.is_vessel():
		return InteractionResult.failure("Drop a classroom reagent onto a beaker, flask or test tube.")
	var chemical_id := str(context.payload.get("chemical_id", ""))
	if not ALLOWED_REAGENTS.has(chemical_id):
		return InteractionResult.failure("Only classroom water and sodium chloride can be added from the Library.")
	var chemical := sim.database.get_chemical(chemical_id)
	if chemical == null:
		return InteractionResult.failure("That classroom reagent is not in the chemistry database.")
	var amount_value: Variant = context.payload.get("amount", 0.0)
	if (typeof(amount_value) != TYPE_INT and typeof(amount_value) != TYPE_FLOAT) \
			or not is_finite(float(amount_value)) or float(amount_value) <= 0.0:
		return InteractionResult.failure("Choose a positive, finite reagent amount.")
	if chemical.state == "liquid" and float(amount_value) > target.vessel.free_volume_ml() + VesselState.EPSILON:
		return InteractionResult.failure("There is not enough free volume in the %s." % sim.object_label(target))
	if chemical.state != "liquid" and chemical.state != "solid":
		return InteractionResult.failure("This teaching reagent has an unsupported physical state.")
	return InteractionResult.success()


func execute(sim: LabSimulation) -> InteractionResult:
	var target := sim.state.get_object(context.source)
	var chemical_id := str(context.payload.get("chemical_id", ""))
	var chemical := sim.database.get_chemical(chemical_id)
	var amount := float(context.payload.get("amount", 0.0))
	if chemical.state == "liquid":
		target.vessel.add_liquid(chemical_id, amount)
		description = "Added %.1f mL of %s directly to %s" % [amount, chemical.short_name, sim.object_label(target)]
		return InteractionResult.success("Added %.1f mL of %s." % [amount, chemical.short_name],
			{"chemical_id": chemical_id, "amount": amount, "unit": "mL"})
	target.vessel.add_solid(chemical_id, amount)
	description = "Added %.1f g of %s directly to %s" % [amount, chemical.short_name, sim.object_label(target)]
	return InteractionResult.success("Added %.1f g of %s." % [amount, chemical.short_name],
		{"chemical_id": chemical_id, "amount": amount, "unit": "g"})
