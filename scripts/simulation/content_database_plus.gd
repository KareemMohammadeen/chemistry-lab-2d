class_name ContentDatabasePlus extends ContentDatabase
## Extends the base content database with generated, per-chemical experiment suggestions.
## This keeps the project data-driven: adding a new chemical automatically creates a
## small set of virtual classroom experiments that can be shown in the UI.

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
		var chemical := get_chemical(chemical_id)
		if chemical == null:
			continue
		var generated := _generate_experiments_for_chemical(chemical)
		experiments_by_chemical[chemical_id] = generated
		experiment_list.append_array(generated)


func _generate_experiments_for_chemical(chemical: ChemicalDefinition) -> Array:
	var experiments: Array = []
	var category := chemical.category.to_lower()
	var name := chemical.display_name.to_lower()
	var short_name := chemical.short_name if not chemical.short_name.is_empty() else chemical.display_name
	var is_acid := _is_acid_like(chemical, category, name)
	var is_base := _is_base_like(chemical, category, name)
	var is_carbonate := _is_carbonate_like(chemical, category, name)
	var is_solution := chemical.is_aqueous_solvent or category.contains("solution") or category.contains("aqueous")
	var is_solid := chemical.state == "solid"
	var is_gas := chemical.state == "gas" or name.ends_with(" gas") or name.contains(" gas")
	var is_metal := _is_metal_like(chemical, category, name)
	var has_water_partner := get_chemical("water") != null

	experiments.append(_experiment_observation(chemical, short_name))

	if is_solid or category.contains("salt") or category.contains("crystal") or category.contains("powder"):
		experiments.append(_experiment_dissolve_or_suspect_solubility(chemical, short_name, has_water_partner))

	if is_acid:
		experiments.append(_experiment_neutralise_acid(chemical, short_name))
	if is_base:
		experiments.append(_experiment_neutralise_base(chemical, short_name))
	if is_carbonate:
		experiments.append(_experiment_acid_carbonate(chemical, short_name))
	if is_solution or category.contains("salt") or category.contains("precipitation") or category.contains("aqueous"):
		experiments.append(_experiment_precipitation_screen(chemical, short_name))
	if is_metal:
		experiments.append(_experiment_single_displacement(chemical, short_name))
	if is_gas:
		experiments.append(_experiment_gas_handling(chemical, short_name))
	if chemical.id == "water" or chemical.id == "ice" or chemical.id == "water_vapor" or chemical.id == "water_vapour":
		experiments.append(_experiment_phase_change(chemical, short_name))
	if chemical.id == "oxygen_gas":
		experiments.append(_experiment_combustion_context(chemical, short_name))

	var unique_experiments: Dictionary = {}
	var deduped: Array = []
	for experiment in experiments:
		if typeof(experiment) != TYPE_DICTIONARY:
			continue
		var exp: Dictionary = experiment
		var experiment_id := str(exp.get("id", ""))
		if experiment_id.is_empty() or unique_experiments.has(experiment_id):
			continue
		unique_experiments[experiment_id] = true
		deduped.append(exp)
	return deduped


func _experiment_observation(chemical: ChemicalDefinition, short_name: String) -> Dictionary:
	return _make_experiment(
		chemical,
		"observe",
		"Observe the sample",
		"A quick classroom observation to identify the substance before mixing it with anything else.",
		[
			"Read the label and formula.",
			"Record the visible state and colour.",
			"Compare the summary with the actual class label.",
		],
		"The sample can be identified by its label, state, and appearance.",
		[{"id": chemical.id, "name": short_name}],
		["observation", "baseline"],
	)


func _experiment_dissolve_or_suspect_solubility(chemical: ChemicalDefinition, short_name: String, has_water_partner: bool) -> Dictionary:
	var partner_name := "water" if has_water_partner else "a neutral solvent"
	return _make_experiment(
		chemical,
		"solubility_check",
		"Check solubility in %s" % partner_name,
		"A classroom screening for whether the sample tends to dissolve, form a solution, or remain partly undissolved.",
		[
			"Add a small virtual sample to the solvent.",
			"Stir gently and watch for dissolving or residue.",
			"Note whether a clear solution, cloudiness, or solid remains.",
		],
		"The sample either dissolves, partly dissolves, or leaves residue.",
		[{"id": chemical.id, "name": short_name}, {"id": "water", "name": "Water"}],
		["solubility", "screening"],
	)


func _experiment_neutralise_acid(chemical: ChemicalDefinition, short_name: String) -> Dictionary:
	var partner := _pick_partner(["sodium_hydroxide_0_1m", "potassium_hydroxide_0_1m"])
	var partner_name := partner.display_name if partner != null else "a dilute base"
	return _make_experiment(
		chemical,
		"neutralise_as_acid",
		"Neutralise with %s" % partner_name,
		"A virtual neutralisation test that shows how an acid responds to a safe base in the classroom model.",
		[
			"Place the acid sample in a vessel.",
			"Add the base slowly while mixing.",
			"Watch the calculated pH move toward neutral.",
		],
		"The pH rises toward neutral and the reaction produces a salt and water in the model.",
		[{"id": chemical.id, "name": short_name}] + _partner_entry(partner, "Sodium hydroxide"),
		["neutralisation", "acid"],
	)


func _experiment_neutralise_base(chemical: ChemicalDefinition, short_name: String) -> Dictionary:
	var partner := _pick_partner(["hydrochloric_acid_0_1m", "nitric_acid_0_1m", "acetic_acid_0_1m"])
	var partner_name := partner.display_name if partner != null else "a dilute acid"
	return _make_experiment(
		chemical,
		"neutralise_as_base",
		"Neutralise with %s" % partner_name,
		"A virtual neutralisation test that shows how a base responds to a safe acid in the classroom model.",
		[
			"Place the base sample in a vessel.",
			"Add the acid slowly while mixing.",
			"Watch the calculated pH move toward neutral.",
		],
		"The pH falls toward neutral and the reaction produces a salt and water in the model.",
		[{"id": chemical.id, "name": short_name}] + _partner_entry(partner, "Hydrochloric acid"),
		["neutralisation", "base"],
	)


func _experiment_acid_carbonate(chemical: ChemicalDefinition, short_name: String) -> Dictionary:
	var partner := _pick_partner(["sodium_bicarbonate", "sodium_carbonate_0_1m", "sodium_bicarbonate_0_1m"])
	var partner_name := partner.display_name if partner != null else "a carbonate or bicarbonate"
	return _make_experiment(
		chemical,
		"acid_carbonate",
		"Add to %s" % partner_name,
		"A gas-evolution demo that shows a carbonate reacting with an acid inside the virtual lab.",
		[
			"Put the acid sample in the vessel.",
			"Add a carbonate source slowly.",
			"Observe the calculated gas release and bubbling.",
		],
		"The model shows carbon dioxide bubbles and a salt solution.",
		[{"id": chemical.id, "name": short_name}] + _partner_entry(partner, "Sodium bicarbonate"),
		["gas_evolution", "carbonates"],
	)


func _experiment_precipitation_screen(chemical: ChemicalDefinition, short_name: String) -> Dictionary:
	var partner := _pick_partner(["silver_nitrate_0_1m", "calcium_chloride_0_1m", "sodium_carbonate_0_1m"])
	var partner_name := partner.display_name if partner != null else "a precipitation reagent"
	return _make_experiment(
		chemical,
		"precipitation_screen",
		"Screen with %s" % partner_name,
		"A teaching test that looks for an insoluble solid when the sample is mixed with a common reagent.",
		[
			"Place both samples in a virtual vessel.",
			"Mix gently and wait for the result.",
			"Check whether a visible precipitate appears.",
		],
		"The model can show a clear solution or a visible precipitate depending on the ions present.",
		[{"id": chemical.id, "name": short_name}] + _partner_entry(partner, "Silver nitrate"),
		["precipitation", "screening"],
	)


func _experiment_single_displacement(chemical: ChemicalDefinition, short_name: String) -> Dictionary:
	var partner := _pick_partner(["hydrochloric_acid_0_1m", "nitric_acid_0_1m"])
	var partner_name := partner.display_name if partner != null else "a dilute acid"
	return _make_experiment(
		chemical,
		"single_displacement",
		"React with %s" % partner_name,
		"A displacement-style classroom model that lets a reactive metal show gas release and a salt forming.",
		[
			"Place the metal sample in a virtual vessel.",
			"Add the acid slowly.",
			"Watch for gas formation and the metal dissolving in the model.",
		],
		"The model shows hydrogen gas and a dissolved metal salt if the metal is reactive enough.",
		[{"id": chemical.id, "name": short_name}] + _partner_entry(partner, "Hydrochloric acid"),
		["single_displacement", "metals"],
	)


func _experiment_gas_handling(chemical: ChemicalDefinition, short_name: String) -> Dictionary:
	return _make_experiment(
		chemical,
		"gas_handling",
		"Observe gas behaviour",
		"A non-contact classroom experiment that focuses on how the gas behaves in the model.",
		[
			"Place the gas in a closed virtual vessel.",
			"Compare how it behaves with air and water.",
			"Record whether it is collected, retained, or escapes.",
		],
		"The model shows a gas phase behaviour suitable for classroom observation only.",
		[{"id": chemical.id, "name": short_name}],
		["gas", "observation"],
	)


func _experiment_phase_change(chemical: ChemicalDefinition, short_name: String) -> Dictionary:
	return _make_experiment(
		chemical,
		"phase_change",
		"Study phase change",
		"A heating and cooling classroom demo for water, ice, or water vapour inside the virtual lab.",
		[
			"Change the temperature gradually.",
			"Watch the state move between solid, liquid, and gas.",
			"Note the modelled phase-change point.",
		],
		"The state changes according to the simulated heating or cooling path.",
		[{"id": chemical.id, "name": short_name}],
		["phase_change", "thermal"],
	)


func _experiment_combustion_context(chemical: ChemicalDefinition, short_name: String) -> Dictionary:
	return _make_experiment(
		chemical,
		"combustion_context",
		"Combustion context demo",
		"A safe classroom demo that uses oxygen as the reference atmosphere for combustion discussion.",
		[
			"Place the oxygen reference in the vessel.",
			"Introduce a pre-approved virtual burning example.",
			"Observe how the combustion model responds.",
		],
		"The model shows why oxygen supports combustion in the classroom example.",
		[{"id": chemical.id, "name": short_name}],
		["combustion", "oxygen"],
	)


func _make_experiment(
	chemical: ChemicalDefinition,
	experiment_type: String,
	title: String,
	summary: String,
	steps: Array,
	expected_observation: String,
	required_chemicals: Array,
	tags: Array,
) -> Dictionary:
	return {
		"id": "%s__%s" % [chemical.id, experiment_type],
		"chemical_id": chemical.id,
		"chemical_name": chemical.display_name,
		"title": title,
		"summary": summary,
		"steps": steps,
		"expected_observation": expected_observation,
		"required_chemicals": required_chemicals,
		"tags": tags,
		"virtual_only": true,
		"auto_generated": true,
		"safety_note": "Virtual classroom model only.",
	}


func _pick_partner(preferred_ids: Array) -> ChemicalDefinition:
	for partner_id_value in preferred_ids:
		var partner_id := str(partner_id_value)
		var partner := get_chemical(partner_id)
		if partner != null:
			return partner
	return null


func _partner_entry(partner: ChemicalDefinition, fallback_name: String) -> Array:
	if partner == null:
		return []
	return [{"id": partner.id, "name": partner.display_name if not partner.display_name.is_empty() else fallback_name}]


static func _is_acid_like(chemical: ChemicalDefinition, category: String, name: String) -> bool:
	return chemical.h_plus_mol_per_l > 0.0 or category.contains("acid") or name.contains("acid") or chemical.id.contains("acid")


static func _is_base_like(chemical: ChemicalDefinition, category: String, name: String) -> bool:
	return chemical.oh_minus_mol_per_l > 0.0 or category.contains("base") or category.contains("alkali") or name.contains("base") or name.contains("alkali")


static func _is_carbonate_like(chemical: ChemicalDefinition, category: String, name: String) -> bool:
	return category.contains("carbonate") or name.contains("carbonate") or name.contains("bicarbonate") or chemical.id.contains("carbonate") or chemical.id.contains("bicarbonate")


static func _is_metal_like(chemical: ChemicalDefinition, category: String, name: String) -> bool:
	if category.contains("metal") or name.contains("metal"):
		return true
	return chemical.id in ["zinc", "magnesium", "iron", "copper", "aluminium", "aluminum", "calcium", "potassium", "sodium"]
