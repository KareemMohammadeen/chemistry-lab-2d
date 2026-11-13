extends Window
## Read-only educational catalogue for every loaded element, compound, playable chemical and
## reaction/process. This window never creates reagents or invokes the simulation engine.

var _database: ContentDatabase


func bind(database: ContentDatabase) -> void:
	_database = database
	title = "Materials & Reactions Reference Explorer"
	size = Vector2i(1120, 780)
	min_size = Vector2i(840, 560)
	_build()


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var heading := Label.new()
	heading.text = "SCIENTIFIC REFERENCE EXPLORER"
	heading.add_theme_font_size_override("font_size", 20)
	root.add_child(heading)

	var notice := Label.new()
	notice.text = "Read-only learning reference. Only the separate classroom demo materials are usable in the guided simulation. Hazardous and advanced catalogue entries are not experiment instructions or playable reagents."
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(notice)

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)

	var element_entries: Array = _database.elements.values()
	element_entries.sort_custom(func(left: Variant, right: Variant) -> bool:
		return (left as ElementDefinition).atomic_number < (right as ElementDefinition).atomic_number)
	var element_labels: Array[String] = []
	for value in element_entries:
		var item := value as ElementDefinition
		element_labels.append("%03d  %s  %s" % [item.atomic_number, item.id, item.display_name])
	_add_tab(tabs, "Elements · 118", element_labels, element_entries, _format_element)

	var compound_entries: Array = _database.compounds.values()
	compound_entries.sort_custom(func(left: Variant, right: Variant) -> bool:
		return (left as CompoundDefinition).display_name.naturalnocasecmp_to((right as CompoundDefinition).display_name) < 0)
	var compound_labels: Array[String] = []
	for value in compound_entries:
		var item := value as CompoundDefinition
		compound_labels.append("%s  ·  %s" % [item.display_name, item.formula_display])
	_add_tab(tabs, "Compounds · %d" % compound_entries.size(), compound_labels, compound_entries, _format_compound)

	var chemical_entries: Array = _database.chemicals.values()
	chemical_entries.sort_custom(func(left: Variant, right: Variant) -> bool:
		return (left as ChemicalDefinition).display_name.naturalnocasecmp_to((right as ChemicalDefinition).display_name) < 0)
	var chemical_labels: Array[String] = []
	for value in chemical_entries:
		var item := value as ChemicalDefinition
		chemical_labels.append("%s  ·  %s" % [item.display_name, item.formula_display])
	_add_tab(tabs, "Simulation materials · %d" % chemical_entries.size(), chemical_labels, chemical_entries, _format_chemical)

	var reaction_entries: Array = _database.reactions.values()
	reaction_entries.sort_custom(func(left: Variant, right: Variant) -> bool:
		return (left as ReactionDefinition).display_name.naturalnocasecmp_to((right as ReactionDefinition).display_name) < 0)
	var reaction_labels: Array[String] = []
	for value in reaction_entries:
		var item := value as ReactionDefinition
		reaction_labels.append("%s  ·  %s" % [item.display_name, item.type.capitalize()])
	_add_tab(tabs, "Processes & reactions · %d" % reaction_entries.size(), reaction_labels, reaction_entries, _format_reaction)

	var sources := RichTextLabel.new()
	sources.bbcode_enabled = true
	sources.fit_content = true
	sources.custom_minimum_size.y = 76.0
	sources.meta_clicked.connect(_open_reference_link)
	sources.text = "[b]Reference sources[/b]  [url=https://iupac.org/what-we-do/periodic-table-of-elements/]IUPAC[/url]  ·  [url=https://pubchem.ncbi.nlm.nih.gov/ptable/]PubChem[/url]  ·  [url=https://www.nist.gov/pml/periodic-table-elements]NIST[/url]  ·  [url=https://openstax.org/books/chemistry-2e/pages/11-1-the-dissolution-process]OpenStax: dissolution[/url]  ·  [url=https://openstax.org/books/chemistry-2e/pages/10-3-phase-transitions]OpenStax: phase transitions[/url]  ·  [url=https://www.acs.org/education/policies/middle-and-high-school-chemistry/safety.html]ACS laboratory safety[/url]\nProperty records in this project include unverified and derived fields; do not treat every numeric entry as an authoritative measured value."
	root.add_child(sources)


func _add_tab(tabs: TabContainer, tab_title: String, labels: Array[String], entries: Array, formatter: Callable) -> void:
	var split := HSplitContainer.new()
	split.name = tab_title
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(split)

	var list := ItemList.new()
	list.custom_minimum_size.x = 290.0
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.select_mode = ItemList.SELECT_SINGLE
	split.add_child(list)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(scroll)

	var detail := RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.fit_content = true
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(620.0, 580.0)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.meta_clicked.connect(_open_reference_link)
	scroll.add_child(detail)

	for label in labels:
		list.add_item(label)
	list.item_selected.connect(func(index: int) -> void:
		if index >= 0 and index < entries.size():
			detail.text = str(formatter.call(entries[index])))
		)
	if not entries.is_empty():
		list.select(0)
		detail.text = str(formatter.call(entries[0]))
	else:
		detail.text = "No records are available in this category."


func _format_element(item: Variant) -> String:
	var element := item as ElementDefinition
	var group_text := "f-block" if element.group <= 0 else str(element.group)
	var output := "[b]%s (%s)[/b]\nAtomic number: %d\nCategory: %s\nPeriod: %d  ·  Group: %s  ·  Block: %s\n" % [
		element.display_name, element.id, element.atomic_number, element.category, element.period, group_text, element.block]
	if not element.electron_configuration.is_empty():
		output += "Electron configuration (derived reference): %s\n" % element.electron_configuration
	if not element.appearance.is_empty():
		output += "Appearance: %s\n" % element.appearance
	if not element.state_at_stp.is_empty():
		output += "State at STP: %s\n" % element.state_at_stp
	if not element.description.is_empty():
		output += "\n[b]Educational overview[/b]\n%s\n" % element.description
	if element.radioactive:
		output += "\n[b]Safety classification[/b]\nRadioactive element. This is a read-only reference entry, not a classroom reagent.\n"
	elif not element.hazards.is_empty():
		output += "\n[b]Safety classification[/b]\n%s\nThis is a read-only reference entry, not a classroom reagent.\n" % element.hazards
	output += "\n[i]Data note: some physical-property fields in the source catalogue are marked unverified_reference or derived. Verify against IUPAC, NIST or PubChem before using numeric values in teaching.[/i]"
	return output


func _format_compound(item: Variant) -> String:
	var compound := item as CompoundDefinition
	var output := "[b]%s[/b]\nFormula: %s\nState at 20 °C: %s\nAppearance: %s\n" % [
		compound.display_name, compound.formula_display, compound.state_at_20c, compound.appearance]
	var atoms: Array[String] = []
	for symbol in compound.composition.keys():
		atoms.append("%s: %s" % [str(symbol), str(compound.composition[symbol])])
	output += "Composition: %s\n" % ", ".join(PackedStringArray(atoms))
	if not compound.solubility_note.is_empty():
		output += "Solubility overview: %s\n" % compound.solubility_note
	if not compound.hazard_classes.is_empty():
		var classes: Array[String] = []
		for hazard in compound.hazard_classes:
			classes.append(str(hazard))
		output += "\n[b]Safety classification[/b]\n%s. Reference-only; not available for classroom experiments.\n" % ", ".join(PackedStringArray(classes))
	else:
		output += "\n[b]Availability[/b]\nReference catalogue entry. It is not automatically an approved classroom reagent.\n"
	output += "\n[i]Source quality: check each source record before relying on numerical properties. Some values in this catalogue are explicitly marked unverified_reference.[/i]"
	return output


func _format_chemical(item: Variant) -> String:
	var chemical := item as ChemicalDefinition
	var output := "[b]%s (%s)[/b]\nState: %s\nCategory: %s\n%s\n" % [
		chemical.display_name, chemical.formula_display, chemical.state, chemical.category, chemical.summary]
	if chemical.id == "water" or chemical.id == "sodium_chloride":
		output += "\n[b]Classroom demo status[/b]\nAvailable in the guided virtual classroom demonstration.\n"
	else:
		output += "\n[b]Classroom demo status[/b]\nReference only in Teacher Mode; not available in the guided classroom demonstration.\n"
	var safety_status := str(chemical.safety.get("status", "not recorded"))
	output += "Safety record status: %s\n" % safety_status
	if not chemical.unreviewed_fields.is_empty():
		output += "\n[i]Some numerical properties are unreviewed in the source data: %s.[/i]" % ", ".join(PackedStringArray(chemical.unreviewed_fields))
	output += "\nNo preparation, handling or experiment instructions are provided in this catalogue."
	return output


func _format_reaction(item: Variant) -> String:
	var reaction := item as ReactionDefinition
	var output := "[b]%s[/b]\nType: %s\n" % [reaction.display_name, reaction.type.capitalize()]
	if not reaction.equation.is_empty():
		output += "Concept equation: %s\n" % reaction.equation
	if not reaction.explanation.is_empty():
		output += "\n[b]Scientific explanation[/b]\n%s\n" % reaction.explanation
	if not reaction.observations.is_empty():
		output += "\n[b]Model observations[/b]\n"
		for key in reaction.observations.keys():
			var observation_text := str(reaction.observations[key])
			if not observation_text.is_empty():
				output += "• %s\n" % observation_text
	output += "\n[i]This entry explains a concept or an existing model behaviour. It is not a procedure for conducting a real experiment.[/i]"
	return output


func _open_reference_link(meta: Variant) -> void:
	var url := str(meta)
	if url.begins_with("https://"):
		OS.shell_open(url)
