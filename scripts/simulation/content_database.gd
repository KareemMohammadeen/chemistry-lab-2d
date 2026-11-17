class_name ContentDatabase
extends RefCounted
## Loads and indexes all data-driven content: chemicals, reactions, equipment, layout and
## simulation constants. Created once by Main and passed to the systems that need it.
## Adding a chemical, reaction or equipment item means adding a JSON file; no code changes.

const CHEMICALS_DIR := "res://data/chemicals"
const REACTIONS_DIR := "res://data/reactions"
const REACTION_REGISTRY_PATH := "res://data/reaction_registry_v3.json"
const EQUIPMENT_DIR := "res://data/equipment"
const ELEMENTS_PATH := "res://data/elements/elements.json"
const COMPOUNDS_DIR := "res://data/compounds"
const CONSTANTS_PATH := "res://data/simulation/simulation_constants.json"
const LAYOUT_PATH := "res://data/lab/layout.json"

var chemicals: Dictionary = {}
var reactions: Dictionary = {}
var reaction_registry: ReactionRegistryV3
var equipment: Dictionary = {}
var constants: Dictionary = {}
## Reference data: ElementDefinition by symbol, and by atomic number; CompoundDefinition by id.
var elements: Dictionary = {}
var elements_by_number: Dictionary = {}
var compounds: Dictionary = {}
var layout: LabLayout = null
## Human-readable problems found while loading. Empty when everything loaded cleanly.
var errors: PackedStringArray = PackedStringArray()

var _dissolution_by_solute: Dictionary = {}


func load_all() -> void:
	errors.clear()
	chemicals.clear()
	reactions.clear()
	equipment.clear()
	_dissolution_by_solute.clear()
	reaction_registry = null
	elements.clear()
	elements_by_number.clear()
	compounds.clear()
	constants = JsonDataLoader.load_dictionary(CONSTANTS_PATH).get("values", {})
	layout = LabLayout.from_dictionary(JsonDataLoader.load_dictionary(LAYOUT_PATH))
	for path in JsonDataLoader.list_json_files(CHEMICALS_DIR):
		var chemical := ChemicalDefinition.from_dictionary(JsonDataLoader.load_dictionary(path))
		_register(chemicals, chemical, path)
	for path in JsonDataLoader.list_json_files(EQUIPMENT_DIR):
		var item := EquipmentDefinition.from_dictionary(JsonDataLoader.load_dictionary(path))
		_register(equipment, item, path)
	for path in JsonDataLoader.list_json_files(REACTIONS_DIR):
		# Older builds briefly stored registry metadata beside reaction definitions. Ignore it:
		# this folder is reserved for actual ReactionDefinition JSON files.
		if path.get_file() == "reaction_registry.json":
			continue
		var reaction := ReactionDefinition.from_dictionary(JsonDataLoader.load_dictionary(path))
		_register(reactions, reaction, path)
	_load_reference_data()
	for reaction_id in reactions.keys():
		var reaction: ReactionDefinition = reactions[reaction_id]
		if reaction.type == "dissolution":
			_dissolution_by_solute[reaction.solute] = reaction
			if not chemicals.has(reaction.solute):
				errors.append("Reaction '%s' refers to unknown chemical '%s'." % [reaction.id, reaction.solute])
		_validate_reaction_metadata(reaction)

	reaction_registry = ReactionRegistryV3.new()
	var registry_errors: PackedStringArray = reaction_registry.load_from_dictionary(
		JsonDataLoader.load_dictionary(REACTION_REGISTRY_PATH), reactions)
	for registry_error in registry_errors:
		errors.append("Reaction Registry: %s" % registry_error)


## Validates the forward-compatible participant schema without executing it. A future
## reaction handler must still opt in by type and pass its own condition/safety checks.
func _validate_reaction_metadata(reaction: ReactionDefinition) -> void:
	for participant_group in [
		{"name": "reactants", "entries": reaction.reactants},
		{"name": "products", "entries": reaction.products},
	]:
		var entries: Variant = participant_group["entries"]
		if typeof(entries) != TYPE_ARRAY:
			errors.append("Reaction '%s' has invalid %s metadata." % [reaction.id, participant_group["name"]])
			continue
		for participant_value in entries:
			if typeof(participant_value) != TYPE_DICTIONARY:
				errors.append("Reaction '%s' contains an invalid participant." % reaction.id)
				continue
			var participant: Dictionary = participant_value
			var coefficient: Variant = participant.get("coefficient", 1)
			if (typeof(coefficient) != TYPE_INT and typeof(coefficient) != TYPE_FLOAT) \
					or not is_finite(float(coefficient)) or float(coefficient) <= 0.0:
				errors.append("Reaction '%s' has an invalid participant coefficient." % reaction.id)
			var chemical_id := str(participant.get("chemical_id", ""))
			var element_symbol := str(participant.get("reference_element_symbol", ""))
			if chemical_id.is_empty() and element_symbol.is_empty():
				errors.append("Reaction '%s' participant must name a chemical or reference element." % reaction.id)
			if not chemical_id.is_empty() and get_chemical(chemical_id) == null:
				errors.append("Reaction '%s' refers to unknown chemical '%s'." % [reaction.id, chemical_id])
			if not element_symbol.is_empty() and get_element(element_symbol) == null:
				errors.append("Reaction '%s' refers to unknown reference element '%s'." % [reaction.id, element_symbol])
	if reaction.type == "visual_demo" and (not reaction.virtual_only or reaction.safety_status != "virtual_observation_only"):
		errors.append("Visual demo '%s' must be marked virtual-only and observation-only." % reaction.id)


func _load_reference_data() -> void:
	var element_file := JsonDataLoader.load_dictionary(ELEMENTS_PATH)
	for entry in element_file.get("elements", []):
		var element := ElementDefinition.from_dictionary(entry)
		_register(elements, element, ELEMENTS_PATH)
		if element != null:
			elements_by_number[element.atomic_number] = element
	for path in JsonDataLoader.list_json_files(COMPOUNDS_DIR):
		var compound := CompoundDefinition.from_dictionary(JsonDataLoader.load_dictionary(path))
		_register(compounds, compound, path)
		if compound != null and not compound.simulation_chemical_id.is_empty() and not chemicals.has(compound.simulation_chemical_id):
			errors.append("Compound '%s' refers to unknown chemical '%s'." % [compound.id, compound.simulation_chemical_id])


func get_element(symbol: String) -> ElementDefinition:
	return elements.get(symbol) as ElementDefinition


func get_element_by_number(atomic_number: int) -> ElementDefinition:
	return elements_by_number.get(atomic_number) as ElementDefinition


func get_compound(compound_id: String) -> CompoundDefinition:
	return compounds.get(compound_id) as CompoundDefinition


func get_chemical(chemical_id: String) -> ChemicalDefinition:
	return chemicals.get(chemical_id) as ChemicalDefinition


func get_equipment(equipment_id: String) -> EquipmentDefinition:
	return equipment.get(equipment_id) as EquipmentDefinition


## The dissolution reaction for a solid substance, or null when none is defined.
func find_dissolution(solute_id: String) -> ReactionDefinition:
	var reaction := _dissolution_by_solute.get(solute_id) as ReactionDefinition
	if not _reaction_is_executable(reaction):
		return null
	return reaction


## The first reaction of a type (for example "neutralisation"), or null.
func first_reaction_of_type(type: String) -> ReactionDefinition:
	for reaction_id in reactions.keys():
		var reaction: ReactionDefinition = reactions[reaction_id]
		if reaction.type == type:
			return reaction
	return null


## The first reaction of a type that is explicitly enabled in the registry, or null.
func first_enabled_reaction_of_type(type: String) -> ReactionDefinition:
	for reaction_id in reactions.keys():
		var reaction: ReactionDefinition = reactions[reaction_id]
		if reaction.type == type and _reaction_is_executable(reaction):
			return reaction
	return null


func constant(key: String, fallback: float) -> float:
	return float(constants.get(key, fallback))


func _reaction_is_executable(reaction: ReactionDefinition) -> bool:
	if reaction == null:
		return false
	if reaction_registry == null:
		return true
	if not reaction_registry.has_reaction(reaction.id):
		return false
	return reaction_registry.is_enabled(reaction.id)


func _register(target: Dictionary, item: Object, path: String) -> void:
	if item == null:
		errors.append("Could not load %s" % path)
		return
	var item_id: String = item.id
	if target.has(item_id):
		errors.append("Duplicate id '%s' in %s" % [item_id, path])
		return
	target[item_id] = item
