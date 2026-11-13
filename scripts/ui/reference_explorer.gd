class_name ReferenceExplorer
extends Window
## Read-only educational catalogue for every loaded element, compound, playable chemical and
## reaction/process. This window never creates reagents or invokes the simulation engine.

var _database: ContentDatabase
var _current_kind: String = ""
var _current_entry: Variant = null
var _current_formatter: Callable
var _current_pin_button: Button
var _current_detail: RichTextLabel


func bind(database: ContentDatabase) -> void:
	_database = database
	title = "Materials & Reactions Reference Explorer"
	transient = true
	size = Vector2i(1160, 820)
	min_size = Vector2i(860, 580)
	theme = LabTheme.build()
	_build()


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 18)
	root.add_theme_constant_override("margin_top", 16)
	root.add_theme_constant_override("margin_right", 18)
	root.add_theme_constant_override("margin_bottom", 16)
	add_child(root)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 10)
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(shell)

	var heading := Label.new()
	heading.text = "SCIENTIFIC REFERENCE EXPLORER"
	heading.theme_type_variation = &"TitleLabel"
	shell.add_child(heading)

	var notice := Label.new()
	notice.text = "Read-only learning reference. Only the separate classroom demo materials are usable in the guided simulation. Hazardous and advanced catalogue entries are not experiment instructions or playable reagents."
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.theme_type_variation = &"MutedLabel"
	shell.add_child(notice)

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(tabs)

	var element_entries: Array = _database.elements.values()
	element_entries.sort_custom(func(left: Variant, right: Variant) -> bool:
		return (left as ElementDefinition).atomic_number < (right as ElementDefinition).atomic_number)
	var element_labels: Array[String] = []
	for value in element_entries:
		var item := value as ElementDefinition
		element_labels.append("%03d  %s  %s" % [item.atomic_number, item.id, item.display_name])
	_add_tab(tabs, "Elements · 118", "element", element_labels, element_entries, _format_element)

	var compound_entries: Array = _database.compounds.values()
	compound_entries.sort_custom(func(left: Variant, right: Variant) -> bool:
		return (left as CompoundDefinition).display_name.naturalnocasecmp_to((right as CompoundDefinition).display_name) < 0)
	var compound_labels: Array[String] = []
	for value in compound_entries:
		var item := value as CompoundDefinition
		compound_labels.append("%s  ·  %s" % [item.display_name, item.formula_display])
	_add_tab(tabs, "Compounds · %d" % compound_entries.size(), "compound", compound_labels, compound_entries, _format_compound)

	var chemical_entries: Array = _database.chemicals.values()
	chemical_entries.sort_custom(func(left: Variant, right: Variant) -> bool:
		return (left as ChemicalDefinition).display_name.naturalnocasecmp_to((right as ChemicalDefinition).display_name) < 0)
	var chemical_labels: Array[String] = []
	for value in chemical_entries:
		var item := value as ChemicalDefinition
		chemical_labels.append("%s  ·  %s" % [item.display_name, item.formula_display])
	_add_tab(tabs, "Simulation materials · %d" % chemical_entries.size(), "chemical", chemical_labels, chemical_entries, _format_chemical)

	var reaction_entries: Array = _database.reactions.values()
	reaction_entries.sort_custom(func(left: Variant, right: Variant) -> bool:
		return (left as ReactionDefinition).display_name.naturalnocasecmp_to((right as ReactionDefinition).display_name) < 0)
	var reaction_labels: Array[String] = []
	for value in reaction_entries:
		var item := value as ReactionDefinition
		reaction_labels.append("%s  ·  %s" % [item.display_name, item.type.capitalize()])
	_add_tab(tabs, "Processes & reactions · %d" % reaction_entries.size(), "reaction", reaction_labels, reaction_entries, _format_reaction)

	var sources := RichTextLabel.new()
	sources.bbcode_enabled = true
	sources.fit_content = true
	sources.custom_minimum_size.y = 80.0
	sources.meta_clicked.connect(_open_reference_link)
	sources.text = "[b]Reference sources[/b]  [url=https://iupac.org/what-we-do/periodic-table-of-elements/]IUPAC[/url]  ·  [url=https://pubchem.ncbi.nlm.nih.gov/ptable/]PubChem[/url]  ·  [url=https://www.nist.gov/pml/periodic-table-elements]NIST[/url]  ·  [url=https://openstax.org/books/chemistry-2e/pages/11-1-the-dissolution-process]OpenStax: dissolution[/url]  ·  [url=https://openstax.org/books/chemistry-2e/pages/10-3-phase-transitions]OpenStax: phase transitions[/url]  ·  [url=https://www.acs.org/education/policies/middle-and-high-school-chemistry/safety.html]ACS laboratory safety[/url]\nProperty records in this project include unverified and derived fields; do not treat every numeric entry as an authoritative measured value."
	shell.add_child(sources)


func _add_tab(tabs: TabContainer, tab_title: String, kind: String, labels: Array[String], entries: Array, formatter: Callable) -> void:
	var split := HSplitContainer.new()
	split.name = tab_title
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(split)

	var list := ItemList.new()
	list.custom_minimum_size.x = 250.0
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.select_mode = ItemList.SELECT_SINGLE
	split.add_child(list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	split.add_child(right)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)

	var detail := RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.fit_content = true
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(500.0, 500.0)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.meta_clicked.connect(_open_reference_link)
	scroll.add_child(detail)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	right.add_child(actions)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var pin_button := Button.new()
	pin_button.text = "Pin to dashboard"
	pin_button.theme_type_variation = &"AccentButton"
	pin_button.focus_mode = Control.FOCUS_NONE
	pin_button.disabled = true
	actions.add_child(pin_button)

	for label in labels:
		list.add_item(label)

	var current_index := -1
	var select_entry := func(index: int) -> void:
		if index < 0 or index >= entries.size():
			return
		current_index = index
		_current_kind = kind
		_current_entry = entries[index]
		_current_formatter = formatter
		detail.text = str(formatter.call(entries[index]))
		pin_button.disabled = false
		_current_detail = detail
		_current_pin_button = pin_button
		pin_button.tooltip_text = "Pin this %s into the classroom dashboard as a draggable reference badge." % kind
		pin_button.pressed.connect(_pin_current_entry, CONNECT_ONE_SHOT)
	
	list.item_selected.connect(select_entry)
	if not entries.is_empty():
		list.select(0)
		select_entry.call(0)
	else:
		detail.text = "No records are available in this category."
		pin_button.disabled = true


func _pin_current_entry() -> void:
	if _current_entry == null:
		return
	var reference := _reference_from_current_entry(_current_kind, _current_entry, _current_formatter)
	if reference.is_empty():
		return
	EventBus.reference_pin_requested.emit(reference)


func _reference_from_current_entry(kind: String, entry: Variant, formatter: Callable) -> Dictionary:
	var reference: Dictionary = {"kind": kind}
	if kind == "element":
		var element := entry as ElementDefinition
		reference["id"] = element.id
		reference["title"] = "%s (%s)" % [element.display_name, element.id]
		reference["subtitle"] = "Atomic number %d • %s • %s" % [element.atomic_number, ("f-block" if element.group <= 0 else str(element.group)), element.block]
		reference["body"] = formatter.call(entry)
		reference["accent"] = Color("#63D5F0")
	elif kind == "compound":
		var compound := entry as CompoundDefinition
		reference["id"] = compound.id
		reference["title"] = compound.display_name
		reference["subtitle"] = "Formula %s" % compound.formula_display
		reference["body"] = formatter.call(entry)
		reference["accent"] = Color("#8C87FF")
	elif kind == "chemical":
		var chemical := entry as ChemicalDefinition
		reference["id"] = chemical.id
		reference["title"] = chemical.display_name
		reference["subtitle"] = "%s • %s" % [chemical.formula_display, chemical.category]
		reference["body"] = formatter.call(entry)
		reference["accent"] = Color("#40D0C0")
	elif kind == "reaction":
		var reaction := entry as ReactionDefinition
		reference["id"] = reaction.id
		reference["title"] = reaction.display_name
		reference["subtitle"] = reaction.type.capitalize()
		reference["body"] = formatter.call(entry)
		reference["accent"] = Color("#F4C34D")
	return reference


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
	output += "\n[b]How to read this element[/b]\nThe atomic number identifies the element by its number of protons. The period is its row in the periodic table; the group and block describe its position in the table's organisation.\n"
	if not element.description.is_empty():
		output += "\n[b]Additional reference note[/b]\n%s\n" % element.description
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
	output += "\n[b]Educational overview[/b]\nA chemical formula identifies the elements that make up a compound and the relative count of each element in the formula. The composition above is shown as a reference, not as a recipe.\n"
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
	var summary_text := chemical.summary if not chemical.summary.is_empty() else "This entry is a substance record in the simulation catalogue."
	var output := "[b]%s (%s)[/b]\nState: %s\nCategory: %s\n%s\n" % [
		chemical.display_name, chemical.formula_display, chemical.state, chemical.category, summary_text]
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
