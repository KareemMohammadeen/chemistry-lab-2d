class_name ContentDatabasePlus
extends ContentDatabase
## Compatibility wrapper around the core content database.
## It keeps the project data-driven and generates a compact experiment catalog
## that can be shown in the UI without requiring a separate hand-maintained file.

var experiments_by_chemical: Dictionary = {}
var experiment_list: Array = []


func load_all() -> void:
	super.load_all()
	experiments_by_chemical.clear()
	experiment_list.clear()
	_build_experiment_catalog()


func get_experiments_for_chemical(chemical_id: String) -> Array:
	return experiments_by_chemical.get(chemical_id, []) as Array


func get_all_experiments() -> Array:
	return experiment_list


func _build_experiment_catalog() -> void:
	var chemical_ids: Array = chemicals.keys()
	chemical_ids.sort()
	for chemical_id_value in chemical_ids:
		var chemical_id := str(chemical_id_value)
		var chemical := chemicals.get(chemical_id) as ChemicalDefinition
		if chemical == null:
			continue
		var generated := _generate_experiments_for_chemical(chemical)
		if generated.is_empty():
			continue
		experiments_by_chemical[chemical_id] = generated
		experiment_list.append_array(generated)


func _generate_experiments_for_chemical(chemical: ChemicalDefinition) -> Array:
	var experiments: Array = []
	var display_name := chemical.short_name if not chemical.short_name.is_empty() else chemical.display_name
	var category := chemical.category.to_lower()
	var state := chemical.state.to_lower()
	var is_acid := category.contains("acid") or chemical.h_plus_mol_per_l > 0.0
	var is_base := category.contains("base") or chemical.oh_minus_mol_per_l > 0.0
	var is_solid := state == "solid" or category.contains("salt") or category.contains("powder") or category.contains("crystal")
	var is_gas := state == "gas" or category.contains("gas")
	var is_water_like := chemical.id == "water" or chemical.id == "ice" or category.contains("water")

	experiments.append(_make_experiment(
		chemical,
		"observe",
		"Observe the sample",
		"A short classroom observation to identify the substance before any mixing.",
		[
			"Read the label and formula.",
			"Record the visible state and appearance.",
			"Compare the summary with the class label.",
		],
		"The sample can be identified by its label, state, and appearance.",
		[display_name],
		["observation", "baseline"],
	))

	if is_solid:
		experiments.append(_make_experiment(
			chemical,
			"solubility_check",
			"Check solubility",
			"A classroom screening for whether the sample dissolves or leaves residue.",
			[
				"Add a small virtual sample to water.",
				"Stir gently and watch for dissolving or residue.",
				"Note whether the result is clear, cloudy, or still solid.",
			],
			"The sample either dissolves, partly dissolves, or leaves residue.",
			[display_name, "Water"],
			["solubility", "screening"],
		))

	if is_acid:
		experiments.append(_make_experiment(
			chemical,
			"neutralise_as_acid",
			"Neutralise with a dilute base",
			"A virtual neutralisation test showing how an acid responds to a safe base in the classroom model.",
			[
				"Place the acid sample in a vessel.",
				"Add the base slowly while mixing.",
				"Watch the calculated pH move toward neutral.",
			],
			"The pH rises toward neutral and the model shows salt and water forming.",
			[display_name, "Dilute base"],
			["neutralisation", "acid"],
		))

	if is_base:
		experiments.append(_make_experiment(
			chemical,
			"neutralise_as_base",
			"Neutralise with a dilute acid",
			"A virtual neutralisation test showing how a base responds to a safe acid in the classroom model.",
			[
				"Place the base sample in a vessel.",
				"Add the acid slowly while mixing.",
				"Watch the calculated pH move toward neutral.",
			],
			"The pH falls toward neutral and the model shows salt and water forming.",
			[display_name, "Dilute acid"],
			["neutralisation", "base"],
		))

	if is_gas:
		experiments.append(_make_experiment(
			chemical,
			"gas_handling",
			"Handle as a gas sample",
			"A simple classroom check for collecting, comparing, and observing a gas sample.",
			[
				"Transfer the gas to a virtual container.",
				"Observe the fill level and confinement.",
				"Compare the gas to the surrounding vessel.",
			],
			"The model records the gas as a contained sample.",
			[display_name],
			["gas", "handling"],
		))

	if is_water_like:
		experiments.append(_make_experiment(
			chemical,
			"phase_change",
			"Demonstrate a phase change",
			"A classroom demo that shows the sample moving between solid, liquid, and gas states.",
			[
				"Apply heat or remove heat.",
				"Watch the visible state update.",
				"Record the observed phase change.",
			],
			"The model shows a phase transition when temperature changes.",
			[display_name],
			["phase_change", "temperature"],
		))

	return _dedupe_experiments(experiments)


func _make_experiment(
	chemical: ChemicalDefinition,
	id_suffix: String,
	title: String,
	summary: String,
	steps: Array,
	explanation: String,
	reactants: Array,
	tags: Array,
) -> Dictionary:
	return {
		"id": "%s:%s" % [chemical.id, id_suffix],
		"chemical_id": chemical.id,
		"name": title,
		"title": title,
		"summary": summary,
		"description": summary,
		"steps": steps,
		"explanation": explanation,
		"reactants": reactants,
		"tags": tags,
		"virtual_only": true,
	}


func _dedupe_experiments(experiments: Array) -> Array:
	var seen: Dictionary = {}
	var deduped: Array = []
	for experiment in experiments:
		if typeof(experiment) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = experiment
		var experiment_id := str(entry.get("id", ""))
		if experiment_id.is_empty() or seen.has(experiment_id):
			continue
		seen[experiment_id] = true
		deduped.append(entry)
	return deduped
