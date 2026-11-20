class_name RunVirtualDemoCommand
extends LabCommand
## Plays a qualitative, observation-only school demonstration. It is not a real procedure.

const REACTION_ID := "magnesium_combustion_virtual_demo"

func command_name() -> String:
	return "run_virtual_demo"


func validate(sim: LabSimulation) -> InteractionResult:
	var reason := _missing_object_reason(sim, context.source)
	if not reason.is_empty():
		return InteractionResult.failure(reason)
	var item := sim.state.get_object(context.source)
	if item.vessel == null:
		return InteractionResult.failure("Choose a vessel to display the virtual demonstration.")
	var reaction := sim.database.reactions.get(REACTION_ID) as ReactionDefinition
	if reaction == null or reaction.type != "visual_demo" or not reaction.virtual_only:
		return InteractionResult.failure("The approved virtual demonstration is not available.")
	if item.vessel.fired_observations.has("visual_demo:%s" % REACTION_ID):
		return InteractionResult.failure("This demonstration has already been shown in this vessel. Reset it to replay.")
	if sim.database.get_chemical(reaction.product_solid_id) == null:
		return InteractionResult.failure("The demonstration product is missing from the chemistry database.")
	return InteractionResult.success()


func execute(sim: LabSimulation) -> InteractionResult:
	var item := sim.state.get_object(context.source)
	var reaction := sim.database.reactions.get(REACTION_ID) as ReactionDefinition
	var entry: Dictionary = sim.engine.run_visual_demo(item.vessel, REACTION_ID)
	if entry.is_empty():
		return InteractionResult.failure("The qualitative demonstration could not run.")
	sim.record_observation(item.id, entry)
	description = "Viewed the virtual magnesium-combustion model in %s" % sim.object_label(item)
	return InteractionResult.success("Virtual demonstration completed. The illustrative white product is shown in the vessel.")