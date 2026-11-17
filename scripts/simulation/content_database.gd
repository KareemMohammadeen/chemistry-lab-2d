class_name ContentDatabase
extends RefCounted
## Loads and indexes all data-driven content: chemicals, reactions, equipment, layout and
## simulation constants. Created once by Main and passed to the systems that need it.
## Adding a chemical, reaction or equipment item means adding a JSON file; no code changes.

const CHEMICALS_DIR := "res://data/chemicals"
const REACTIONS_DIR := "res://data/reactions"
const EQUIPMENT_DIR := "res://data/equipment"
const ELEMENTS_PATH := "res://data/elements/elements.json"
const COMPOUNDS_DIR := "res://data/compounds"
const CONSTANTS_PATH := "res://data/simulation/simulation_constants.json"
const LAYOUT_PATH := "res://data/lab/layout.json"

var chemicals: Dictionary = {}
var reactions: Dictionary = {}
var equipment: Dictionary = {}
var constants: Dictionary = {}
## Reference data: ElementDefinition by symbol, and by atomic number; CompoundDefinition by id.
var elements: Dictionary = {}
var elements_by_number: Dictionary = {}
var element_catalog: Dictionary = {}
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
	elements.clear()
	elements_by_number.clear()
	element_catalog.clear()
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
		var reaction := ReactionDefinition.from_dictionary(JsonDataLoader.load_dictionary(path))
		_register(reactions, reaction, path)
	_load_reference_data()
	for reaction_id in reactions.keys():
		var reaction: ReactionDefinition = reactions[reaction_id]
		if reaction.type == "dissolution":
			_dissolution_by_solute[reaction.solute] = reaction
			if not chemicals.has(reaction.solute):
				errors.append("Reaction '%s' refers to unknown chemical '%s'." % [reaction.id, reaction.solute])
	
	element_catalog = ElementCatalog.build_index(elements_by_number)


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


func get_element_card(symbol: String) -> Dictionary:
	return (element_catalog.get("by_symbol", {}) as Dictionary).get(symbol, {}) as Dictionary


func get_element_card_by_number(atomic_number: int) -> Dictionary:
	return (element_catalog.get("by_number", {}) as Dictionary).get(atomic_number, {}) as Dictionary


func get_element_cards() -> Array:
	return element_catalog.get("list", []) as Array


func get_compound(compound_id: String) -> CompoundDefinition:
	return compounds.get(compound_id) as CompoundDefinition


func get_chemical(chemical_id: String) -> ChemicalDefinition:
	return chemicals.get(chemical_id) as ChemicalDefinition


func get_equipment(equipment_id: String) -> EquipmentDefinition:
	return equipment.get(equipment_id) as EquipmentDefinition


## The dissolution reaction for a solid substance, or null when none is defined.
func find_dissolution(solute_id: String) -> ReactionDefinition:
	return _dissolution_by_solute.get(solute_id) as ReactionDefinition


## The first reaction of a type (for example "neutralisation"), or null.
func first_reaction_of_type(type: String) -> ReactionDefinition:
	for reaction_id in reactions.keys():
		var reaction: ReactionDefinition = reactions[reaction_id]
		if reaction.type == type:
			return reaction
	return null


func constant(key: String, fallback: float) -> float:
	return float(constants.get(key, fallback))


func _register(target: Dictionary, item: Object, path: String) -> void:
	if item == null:
		errors.append("Could not load %s" % path)
		return
	var item_id: String = item.id
	if target.has(item_id):
		errors.append("Duplicate id '%s' in %s" % [item_id, path])
		return
	target[item_id] = item
