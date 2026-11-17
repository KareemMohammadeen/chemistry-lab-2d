class_name AddGasCommand
extends LabCommand
## Adds a small approved gas sample to a virtual vessel. The first addition seals the model.

const MAX_MOLES_PER_ADDITION := 0.002
const DEFAULT_MOLES := 0.002


func command_name() -> String:
	return "add_gas"


func validate(sim: LabSimulation) -> InteractionResult:
	var reason := _missing_object_reason(sim, context.source)
	if not reason.is_empty():
		return InteractionResult.failure(reason)
	var target := sim.state.get_object(context.source)
	var equipment := sim.database.get_equipment(target.equipment_id)
	if target.vessel == null or equipment == null or not equipment.is_vessel():
		return InteractionResult.failure("Drop a virtual gas sample onto a beaker, flask or test tube.")
	if target.vessel.free_volume_ml() <= VesselState.EPSILON:
		return InteractionResult.failure("There is no free headspace in this vessel for a virtual gas sample.")
	var chemical_id := str(context.payload.get("chemical_id", ""))
	var chemical := sim.database.get_chemical(chemical_id)
	if chemical == null or chemical.state != "gas" or not chemical.virtual_simulation_enabled:
		return InteractionResult.failure("This gas has no approved virtual simulation model.")
	var amount_value: Variant = context.payload.get("amount_mol", DEFAULT_MOLES)
	if (typeof(amount_value) != TYPE_INT and typeof(amount_value) != TYPE_FLOAT) \
			or not is_finite(float(amount_value)) or float(amount_value) <= 0.0 \
			or float(amount_value) > MAX_MOLES_PER_ADDITION:
		return InteractionResult.failure("The virtual gas amount is outside the supported model range.")
	var ambient := sim.database.constant("ambient_pressure_kpa", 101.325)
	var pressure_limit := sim.database.constant("max_virtual_pressure_kpa", 300.0)
	var projected := target.vessel.pressure_after_adding_gas(float(amount_value), ambient)
	if not is_finite(projected) or projected > pressure_limit:
		return InteractionResult.failure("The virtual pressure limit would be exceeded. No gas was added.")
	return InteractionResult.success()


func execute(sim: LabSimulation) -> InteractionResult:
	var target := sim.state.get_object(context.source)
	var chemical_id := str(context.payload.get("chemical_id", ""))
	var chemical := sim.database.get_chemical(chemical_id)
	var amount := float(context.payload.get("amount_mol", DEFAULT_MOLES))
	var was_open := not target.vessel.is_closed_system
	if not sim.engine.add_gas_product(target.vessel, chemical_id, amount):
		return InteractionResult.failure("The chemistry engine refused this virtual gas entry.")
	description = "Added a virtual sample of %s; vessel sealed automatically" % chemical.short_name
	return InteractionResult.success(
		"Added the virtual gas sample. The vessel is now sealed and retains the gas.",
		{"chemical_id": chemical_id, "amount_mol": amount, "system_sealed": was_open,
			"pressure_kpa": target.vessel.pressure_kpa()})
