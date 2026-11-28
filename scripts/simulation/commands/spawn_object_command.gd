class_name SpawnObjectCommand
extends LabCommand
## Creates one movable, safe teaching item on the infinite workbench.
## All state changes still pass through CommandStack snapshots for undo/redo.

const ALLOWED_EQUIPMENT: Array[String] = [
	"beaker_250ml", "erlenmeyer_flask_250ml", "test_tube_20ml",
	"reagent_bottle_500ml", "dropper_3ml", "thermometer_general", "hot_plate_basic", "cold_plate_basic"
]
const ALLOWED_REAGENTS: Array[String] = ["water", "ice", "sodium_chloride", "tin", "bismuth"]
const MAX_COORDINATE := 1000000.0

var created_object_id: String = ""


func command_name() -> String:
	return "spawn_object"


func validate(sim: LabSimulation) -> InteractionResult:
	var equipment_id := str(context.payload.get("equipment_id", ""))
	if not ALLOWED_EQUIPMENT.has(equipment_id):
		return InteractionResult.failure("That equipment is not available in the classroom workbench.")
	var equipment := sim.database.get_equipment(equipment_id)
	if equipment == null or not equipment.movable:
		return InteractionResult.failure("That equipment cannot be placed on the workbench.")
	var raw_position: Variant = context.payload.get("position")
	if typeof(raw_position) != TYPE_VECTOR2:
		return InteractionResult.failure("The placement position is invalid.")
	var position: Vector2 = raw_position
	if not is_finite(position.x) or not is_finite(position.y) \
			or absf(position.x) > MAX_COORDINATE or absf(position.y) > MAX_COORDINATE:
		return InteractionResult.failure("That position is outside the supported work area.")
	var raw_contents: Variant = context.payload.get("contents", {})
	if typeof(raw_contents) != TYPE_DICTIONARY:
		return InteractionResult.failure("The starting contents are invalid.")
	var contents: Dictionary = raw_contents
	if not contents.is_empty() and not equipment.is_vessel():
		return InteractionResult.failure("Only a vessel can contain a reagent.")
	var liquids: Variant = contents.get("liquids", {})
	var solids: Variant = contents.get("solids", {})
	if typeof(liquids) != TYPE_DICTIONARY or typeof(solids) != TYPE_DICTIONARY:
		return InteractionResult.failure("The starting reagent list is invalid.")
	var liquid_total := 0.0
	for bucket in [{"name": "liquids", "items": liquids}, {"name": "solids", "items": solids}]:
		var amounts: Dictionary = bucket["items"]
		for chemical_key in amounts.keys():
			var chemical_id := str(chemical_key)
			if not ALLOWED_REAGENTS.has(chemical_id) or sim.database.get_chemical(chemical_id) == null:
				return InteractionResult.failure("Only the classroom reagents (water, ice, sodium chloride, tin, bismuth) can be spawned.")
			var amount: Variant = amounts[chemical_key]
			if typeof(amount) != TYPE_INT and typeof(amount) != TYPE_FLOAT:
				return InteractionResult.failure("A starting reagent amount is invalid.")
			if not is_finite(float(amount)) or float(amount) <= 0.0:
				return InteractionResult.failure("A starting reagent amount must be a positive finite number.")
			if str(bucket["name"]) == "liquids":
				liquid_total += float(amount)
	if liquid_total > equipment.capacity_ml:
		return InteractionResult.failure("The starting liquid is larger than the vessel capacity.")
	return InteractionResult.success()


func execute(sim: LabSimulation) -> InteractionResult:
	var equipment_id := str(context.payload.get("equipment_id", ""))
	var position: Vector2 = context.payload["position"]
	var contents: Dictionary = context.payload.get("contents", {})
	var created := sim.spawn_object(equipment_id, position, contents)
	if created == null:
		return InteractionResult.failure("The equipment could not be added.")
	created_object_id = created.id
	var equipment := sim.database.get_equipment(equipment_id)
	var display_name := equipment.display_name if equipment != null else equipment_id
	description = "Added %s to the infinite workbench" % display_name
	sim.release_held()
	return InteractionResult.success("%s added to the workbench." % display_name)
