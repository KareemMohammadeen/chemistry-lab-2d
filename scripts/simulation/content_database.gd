class_name ContentDatabase
extends RefCounted
## Loads and indexes all data-driven content: chemicals, reactions, equipment, layout and
## simulation constants. Created once by Main and passed to the systems that need it.
## Adding a chemical, reaction or equipment item means adding a JSON file; no code changes.

const CHEMICALS_DIR := "res://data/chemicals"
const GENERATED_CHEMICAL_SERIES_PATH := "res://data/generated/chemical_series_1000.json"
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
var element_catalog: Dictionary = {}
var compounds: Dictionary = {}
var layout: LabLayout = null
## Human-readable problems found while loading. Empty when everything loaded cleanly.
var errors: PackedStringArray = []

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
	element_catalog.clear()
	compounds.clear()
	constants = JsonDataLoader.load_dictionary(CONSTANTS_PATH).get("values", {})
	layout = LabLayout.from_dictionary(JsonDataLoader.load_dictionary(LAYOUT_PATH))
	for path in JsonDataLoader.list_json_files(CHEMICALS_DIR):
		var chemical := ChemicalDefinition.from_dictionary(JsonDataLoader.load_dictionary(path))
		_register(chemicals, chemical, path)
	_load_generated_chemical_series()
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

	element_catalog = ElementCatalog.build_index(elements_by_number)


## Expands a generated bulk JSON series into actual playable chemical definitions.
## The file stays compact, but the loaded content becomes part of the simulation database.
func _load_generated_chemical_series() -> void:
	var series := JsonDataLoader.load_dictionary(GENERATED_CHEMICAL_SERIES_PATH)
	if series.is_empty():
		return
	var bases: Array = series.get("bases", [])
	var concentrations: Array = series.get("concentrations", [])
	if bases.is_empty() or concentrations.is_empty():
		errors.append("Generated chemical series file is missing bases or concentrations.")
		return
	var generated_count := 0
	for base_value in bases:
		if typeof(base_value) != TYPE_DICTIONARY:
			continue
		var base: Dictionary = base_value
		var base_id := str(base.get("id", "")).strip_edges()
		if base_id.is_empty():
			continue
		var base_name := str(base.get("name", base_id))
		var base_formula := str(base.get("formula", ""))
		var base_formula_display := str(base.get("formula_display", base_formula))
		var category := str(base.get("category", "classroom solution series"))
		for concentration_value in concentrations:
			var concentration := float(concentration_value)
			var concentration_token := _concentration_token(concentration)
			var generated_id := "%s_%s" % [base_id, concentration_token]
			if chemicals.has(generated_id):
				continue
			var display_concentration := _format_concentration_label(concentration)
			var payload := {
				"id": generated_id,
				"name": "%s, %s mol/L" % [base_name, display_concentration],
				"short_name": base_name,
				"formula": base_formula,
				"formula_display": base_formula_display,
				"state": "liquid",
				"category": category,
				"color": [0.96, 0.98, 1.0, 0.35],
				"solution_color": [0.85, 0.92, 1.0, 0.48],
				"density_g_ml": {
					"value": 1.0,
					"unit": "g/mL",
					"status": "derived",
					"source": "Generated classroom solution series."
				},
				"is_aqueous_solvent": true,
				"label_lines": [base_name, "%s mol/L" % display_concentration],
				"safety": {
					"status": "unverified_reference",
					"summary": "Generated classroom solution for simulation and catalog breadth.",
					"storage": "Model-only classroom solution series.",
					"source": "Auto-generated educational content."
				},
				"display": {
					"summary": "%s at %s mol/L generated for classroom use." % [base_name, display_concentration]
				},
				"simulation": {
					"enabled": true,
					"role": "classroom_reagent",
					"scope": "generated classroom solution series"
				}
			}
			var chemical := ChemicalDefinition.from_dictionary(payload)
			_register(chemicals, chemical, GENERATED_CHEMICAL_SERIES_PATH + "#" + generated_id)
			generated_count += 1
	if generated_count < bases.size() * concentrations.size():
		errors.append("Generated chemical series produced %d entries, expected %d." % [generated_count, bases.size() * concentrations.size()])


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
	var reaction := _dissolution_by_solute.get(solute_id) as ReactionDefinition
	if reaction == null:
		return null
	if reaction_registry != null and reaction_registry.has_reaction(reaction.id) and not reaction_registry.is_enabled(reaction.id):
		return null
	return reaction


## The first reaction of a type (for example "neutralisation"), or null.
func first_reaction_of_type(type: String) -> ReactionDefinition:
	for reaction_id in reactions.keys():
		var reaction: ReactionDefinition = reactions[reaction_id]
		if reaction.type == type:
			return reaction
	return null


## The first enabled reaction of a type (for example "boiling"), or null.
func first_enabled_reaction_of_type(type: String) -> ReactionDefinition:
	var reaction_ids := enabled_reaction_ids_of_type(type)
	if reaction_ids.is_empty():
		return null
	return reactions.get(reaction_ids[0]) as ReactionDefinition


## All reaction ids of a specific type, sorted by id for deterministic lookup.
func reaction_ids_of_type(type: String) -> Array[String]:
	var result: Array[String] = []
	for reaction_id_value in reactions.keys():
		var reaction_id := str(reaction_id_value)
		var reaction: ReactionDefinition = reactions[reaction_id]
		if reaction != null and reaction.type == type:
			result.append(reaction_id)
	result.sort()
	return result


## Enabled reaction ids of a specific type, sorted by id for deterministic lookup.
func enabled_reaction_ids_of_type(type: String) -> Array[String]:
	if reaction_registry != null:
		return reaction_registry.get_enabled_reaction_ids_by_type(type)
	var result: Array[String] = []
	for reaction_id in reaction_ids_of_type(type):
		result.append(reaction_id)
	return result


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


static func _concentration_token(concentration: float) -> String:
	var token := "%0.3f" % concentration
	while token.ends_with("0"):
		token = token.substr(0, token.length() - 1)
	if token.ends_with("."):
		token = token.substr(0, token.length() - 1)
	return token.replace(".", "_")


static func _format_concentration_label(concentration: float) -> String:
	var label := "%0.3f" % concentration
	while label.ends_with("0"):
		label = label.substr(0, label.length() - 1)
	if label.ends_with("."):
		label = label.substr(0, label.length() - 1)
	return label