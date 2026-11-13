class_name LibraryPanel
extends PanelContainer
## The left panel: the substances that can actually be used in the simulation and the
## equipment that exists on the bench, grouped by category. Only the playable chemicals loaded
## from data/chemicals are listed here; the 118-element and 38-compound reference tables are
## not playable and are never shown as such. Picking an item selects the matching object, so
## the Inspector shows it and the workspace highlights it. The panel displays; it never changes
## the simulation.

signal object_focus_requested(object_id: String)

const REFRESH_INTERVAL_S := 0.5
const GROUP_GAP_PX := 6
## Display titles for the data categories; an unknown category shows its own name.
const CHEMICAL_GROUP_TITLES := {"solvent": "Solvents", "salt": "Salts", "dilute acid": "Acids", "dilute base": "Bases"}
const CHEMICAL_GROUP_ORDER: Array = ["solvent", "salt", "dilute acid", "dilute base"]
const EQUIPMENT_GROUP_TITLES := {"vessel": "Glassware", "appliance": "Heating", "tool": "Instruments"}
const EQUIPMENT_GROUP_ORDER: Array = ["vessel", "appliance", "tool"]
## Equipment whose style is listed here is a container for reagents, shown through the reagent cards.
const HIDDEN_EQUIPMENT_STYLES: Array = ["bottle"]
## The classroom-facing Library deliberately exposes only this safe teaching subset.
const CLASSROOM_CHEMICAL_IDS: Array[String] = ["water", "sodium_chloride"]
const CLASSROOM_EQUIPMENT_IDS: Array[String] = ["beaker_250ml", "test_tube_20ml", "thermometer_general", "dropper_3ml", "hot_plate_basic"]
const SAFE_REFERENCE_COMPOUND_IDS: Array[String] = ["glucose", "sucrose", "starch"]
const LEARNING_GUIDE_PATH := "res://data/learning/learning_guide.json"
const TEACHER_PREVIEWS_PATH := "res://data/learning/teacher_previews.json"
const REFERENCE_EXPLORER_SCRIPT := preload("res://scripts/ui/reference_explorer.gd")

@export var subtitle_label: Label
@export var content_box: VBoxContainer

var _host: SimulationHost
var _cards: Array = []
var _selected_id: String = ""
var _refresh_left_s: float = 0.0
## Section headings ("REAGENTS", "EQUIPMENT") are written once, above their first group.
var _section_written: Dictionary = {}
var _curriculum_profile: Dictionary = {}
var _guide_window: Window
var _guide_rich_text: RichTextLabel
var _reference_window: ReferenceExplorer


func bind(host: SimulationHost) -> void:
	_host = host
	EventBus.object_selected.connect(_on_object_selected)
	_build()
	_refresh()


## Updates the curriculum label without changing which reagents the simulation can use.
func set_curriculum_profile(profile: Dictionary) -> void:
	_curriculum_profile = profile.duplicate(true)
	if _host != null:
		_build()
		_refresh()
		if is_instance_valid(_guide_window) and is_instance_valid(_guide_rich_text):
			var guide_data := JsonDataLoader.load_dictionary(LEARNING_GUIDE_PATH)
			_guide_rich_text.text = _build_learning_guide_text(guide_data)


func _process(delta: float) -> void:
	_refresh_left_s -= delta
	if _refresh_left_s <= 0.0:
		_refresh_left_s = REFRESH_INTERVAL_S
		_refresh()


# ---------------------------------------------------------------- building

func _build() -> void:
	for child in content_box.get_children():
		content_box.remove_child(child)
		child.queue_free()
	_cards.clear()
	_section_written.clear()
	var database := _host.database

	var explorer_button := Button.new()
	explorer_button.text = "Open periodic table & encyclopedia"
	explorer_button.tooltip_text = "Open the full periodic table. Drag any element tile onto the workbench as a visual learning token."
	explorer_button.theme_type_variation = &"ToolButton"
	explorer_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	explorer_button.focus_mode = Control.FOCUS_NONE
	explorer_button.pressed.connect(_on_reference_explorer_pressed)
	content_box.add_child(explorer_button)

	var guide_button := Button.new()
	guide_button.text = "Learning guide & sources"
	guide_button.tooltip_text = "Open explanations for classroom materials, safe concepts and curriculum sources."
	guide_button.theme_type_variation = &"ToolButton"
	guide_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_button.focus_mode = Control.FOCUS_NONE
	guide_button.pressed.connect(_on_guide_button_pressed)
	content_box.add_child(guide_button)

	var classroom_chemicals: Array = []
	for chemical_id in CLASSROOM_CHEMICAL_IDS:
		var chemical: ChemicalDefinition = database.get_chemical(chemical_id)
		if chemical != null:
			classroom_chemicals.append(chemical)
	var by_group := _group_by(classroom_chemicals, func(item: Variant) -> String: return (item as ChemicalDefinition).category)
	var reagent_count := 0
	for group in _ordered_groups(by_group, CHEMICAL_GROUP_ORDER):
		_add_heading(str(CHEMICAL_GROUP_TITLES.get(group, str(group).capitalize())), "REAGENTS")
		for chemical in by_group[group]:
			_add_reagent_card(chemical as ChemicalDefinition)
			reagent_count += 1

	var equipment_items: Array = []
	for equipment_id in _equipment_ids_for_current_profile():
		var equipment: EquipmentDefinition = database.get_equipment(equipment_id)
		if equipment != null and not HIDDEN_EQUIPMENT_STYLES.has(equipment.style()):
			equipment_items.append(equipment)
	var equipment_groups := _group_by(equipment_items, func(item: Variant) -> String: return (item as EquipmentDefinition).category)
	var equipment_count := 0
	for group in _ordered_groups(equipment_groups, EQUIPMENT_GROUP_ORDER):
		_add_heading(str(EQUIPMENT_GROUP_TITLES.get(group, str(group).capitalize())), "EQUIPMENT")
		for equipment in equipment_groups[group]:
			_add_equipment_card(equipment as EquipmentDefinition)
			equipment_count += 1

	_add_safe_reference_materials_section(database)
	_add_element_reference_section(database)

	var profile_label := str(_curriculum_profile.get("label", "No grade selected"))
	var subject_label := str(_curriculum_profile.get("subject", "Select a grade"))
	var mapping_note := str(_curriculum_profile.get("note", "Choose a grade to view its curriculum context."))
	if str(_curriculum_profile.get("topic_mapping_status", "")) == "pending_official_textbook_review":
		mapping_note = "Lesson-by-lesson mapping is pending direct review of the matching official textbook. " + mapping_note
	subtitle_label.text = "%d classroom reagents  •  %d instruments  •  118 read-only elements\n%s — %s\n%s" % [reagent_count, equipment_count, profile_label, subject_label, mapping_note]


func _equipment_ids_for_current_profile() -> Array[String]:
	if _curriculum_profile.is_empty():
		return CLASSROOM_EQUIPMENT_IDS.duplicate()
	var preview_data := JsonDataLoader.load_dictionary(TEACHER_PREVIEWS_PATH)
	for preview_value in preview_data.get("grade_previews", []):
		var preview: Dictionary = preview_value
		if str(preview.get("profile_id", "")) != str(_curriculum_profile.get("id", "")):
			continue
		var selected: Array[String] = []
		for raw_id in preview.get("equipment_ids", []):
			var equipment_id := str(raw_id)
			if CLASSROOM_EQUIPMENT_IDS.has(equipment_id) and not selected.has(equipment_id):
				selected.append(equipment_id)
		return selected if not selected.is_empty() else CLASSROOM_EQUIPMENT_IDS.duplicate()
	return CLASSROOM_EQUIPMENT_IDS.duplicate()


func _add_safe_reference_materials_section(database: ContentDatabase) -> void:
	_add_heading("Safe reference compounds · not playable", "REFERENCE")
	for compound_id in SAFE_REFERENCE_COMPOUND_IDS:
		var compound: CompoundDefinition = database.get_compound(compound_id)
		if compound == null:
			continue
		var label := Label.new()
		label.text = "%s  •  %s  •  reference only" % [compound.display_name, compound.formula_display]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", LabColors.TEXT_SECONDARY)
		content_box.add_child(label)


func _on_guide_button_pressed() -> void:
	open_learning_guide(_curriculum_profile)


func _on_reference_explorer_pressed() -> void:
	if _host == null:
		return
	if is_instance_valid(_reference_window):
		_reference_window.popup_centered(Vector2i(1480, 900))
		return
	_reference_window = REFERENCE_EXPLORER_SCRIPT.new() as ReferenceExplorer
	_reference_window.close_requested.connect(_on_reference_explorer_closed)
	add_child(_reference_window)
	_reference_window.bind(_host.database)
	_reference_window.popup_centered(Vector2i(1120, 780))


func _on_reference_explorer_closed() -> void:
	if is_instance_valid(_reference_window):
		_reference_window.queue_free()
	_reference_window = null


func open_learning_guide(profile: Dictionary = {}) -> void:
	if not profile.is_empty():
		_curriculum_profile = profile.duplicate(true)
	var data := JsonDataLoader.load_dictionary(LEARNING_GUIDE_PATH)
	if is_instance_valid(_guide_window):
		if is_instance_valid(_guide_rich_text):
			_guide_rich_text.text = _build_learning_guide_text(data)
		_guide_window.popup_centered(Vector2i(780, 680))
		return
	if data.is_empty():
		EventBus.feedback_message_requested.emit("The learning guide could not be loaded.", &"warning")
		return

	_guide_window = Window.new()
	_guide_window.title = "Teacher Mode · Learning Guide & Sources"
	_guide_window.size = Vector2i(780, 680)
	_guide_window.transient = true
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	_guide_window.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.custom_minimum_size = Vector2(710, 980)
	rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.meta_clicked.connect(_open_guide_link)
	rich.text = _build_learning_guide_text(data)
	_guide_rich_text = rich
	scroll.add_child(rich)

	add_child(_guide_window)
	_guide_window.close_requested.connect(_close_learning_guide)
	_guide_window.popup_centered(Vector2i(780, 680))


func _build_learning_guide_text(data: Dictionary) -> String:
	var output := "[b]CLASSROOM LEARNING GUIDE[/b]\n"
	output += "This guide describes the virtual model only. It is not a set of instructions for real-world experiments.\n\n"
	output += "[b]Selected grade[/b]\n"
	output += "%s — %s\n" % [str(_curriculum_profile.get("label", "Not selected")), str(_curriculum_profile.get("subject", "Select a grade"))]
	output += "%s\n\n" % str(_curriculum_profile.get("note", "Choose a grade in the top bar."))
	output += _build_grade_preview_text(str(_curriculum_profile.get("id", "")))
	output += "[b]Materials available in this classroom demo[/b]\n"
	for material_value in data.get("materials", []):
		var material: Dictionary = material_value
		if not CLASSROOM_CHEMICAL_IDS.has(str(material.get("id", ""))) and not SAFE_REFERENCE_COMPOUND_IDS.has(str(material.get("id", ""))):
			continue
		output += "[b]%s (%s)[/b] — %s\n" % [str(material.get("name", "")), str(material.get("formula", "")), str(material.get("concept", ""))]
		output += "%s\n" % str(material.get("explanation", ""))
		for goal in material.get("learning_goals", []):
			output += "• %s\n" % str(goal)
		output += "Status: %s\n\n" % ("playable in the virtual demo" if str(material.get("status", "")) == "playable_classroom_demo" else "reference only")
	output += "[b]Processes and reactions explained[/b]\n"
	for process_value in data.get("processes", []):
		var process_entry: Dictionary = process_value
		output += "[b]%s[/b] (%s)\n" % [str(process_entry.get("name", "")), str(process_entry.get("mode", ""))]
		output += "%s\n" % str(process_entry.get("explanation", process_entry.get("summary", "")))
		for limitation in process_entry.get("model_limitations", []):
			output += "Model note: %s\n" % str(limitation)
		output += "\n"
	var data_quality: Dictionary = data.get("data_quality", {})
	output += "[b]Data quality[/b]\n%s\n\n" % str(data_quality.get("summary", ""))
	output += "[b]Curriculum status[/b]\nPrep 1–3: exact units remain pending direct review of the official 2026–2027 student books. Senior 1: Integrated Science. Senior 2: pathway-dependent; do not assume one Chemistry syllabus for all students.\n\n"
	output += "[b]Trusted learning and safety sources[/b]\n"
	for source_value in data.get("sources", []):
		var source: Dictionary = source_value
		var source_url := str(source.get("url", ""))
		if source_url.begins_with("https://"):
			output += "[url=%s]%s[/url] — %s\n" % [source_url, str(source.get("title", "Source")), str(source.get("supports", ""))]
	output += "\n[b]Reference boundary[/b]\nAll 118 elements remain read-only periodic-table references. Other advanced catalogue records are intentionally not exposed as classroom reagents or given operational descriptions."
	return output


func _build_grade_preview_text(profile_id: String) -> String:
	var data := JsonDataLoader.load_dictionary(TEACHER_PREVIEWS_PATH)
	if data.is_empty():
		return "[b]Teacher preview[/b]\nNo grade preview data is available.\n\n"
	for preview_value in data.get("grade_previews", []):
		var preview: Dictionary = preview_value
		if str(preview.get("profile_id", "")) != profile_id:
			continue
		var status := str(preview.get("curriculum_alignment_status", "suggested_not_verified_against_official_textbook"))
		var output := "[b]TEACHER PREVIEW[/b]\n"
		output += "[b]%s[/b]\n%s\n" % [str(preview.get("title", "")), str(preview.get("focus", ""))]
		output += "[i]Alignment status: %s[/i]\n\n" % status
		output += "[b]Learning goals[/b]\n"
		for goal in preview.get("learning_goals", []):
			output += "• %s\n" % str(goal)
		output += "\n[b]Materials and equipment[/b]\nMaterials: %s\nEquipment: %s\n\n" % [
			_format_preview_names(preview.get("material_ids", []), false),
			_format_preview_names(preview.get("equipment_ids", []), true)]
		output += "[b]Suggested virtual lesson flow[/b]\n"
		for step in preview.get("virtual_flow", []):
			output += "• %s\n" % str(step)
		output += "\n[b]Teacher prompt[/b]\n%s\n\n" % str(preview.get("teacher_prompt", ""))
		output += "This is a suggested software activity, not a claim about the official textbook's exact lesson order.\n\n"
		return output
	return "[b]Teacher preview[/b]\nNo preview is mapped to this profile yet.\n\n"


func _format_preview_names(ids: Array, equipment_items: bool) -> String:
	var names: Array[String] = []
	for raw_id in ids:
		var item_id := str(raw_id)
		var display := item_id.replace("_", " ").capitalize()
		if _host != null:
			if equipment_items:
				var equipment := _host.database.get_equipment(item_id)
				if equipment != null:
					display = equipment.display_name
			else:
				var chemical := _host.database.get_chemical(item_id)
				if chemical != null:
					display = chemical.display_name
				else:
					var compound := _host.database.get_compound(item_id)
					if compound != null:
						display = compound.display_name
		names.append(display)
	return ", ".join(PackedStringArray(names))


func _open_guide_link(meta: Variant) -> void:
	var url := str(meta)
	if url.begins_with("https://"):
		OS.shell_open(url)


func _close_learning_guide() -> void:
	if is_instance_valid(_guide_window):
		_guide_window.queue_free()
	_guide_window = null


func _add_heading(group_title: String, section: String) -> void:
	if not _section_written.has(section):
		_section_written[section] = true
		var section_label := Label.new()
		section_label.text = section
		section_label.theme_type_variation = &"HeadingLabel"
		content_box.add_child(section_label)
	else:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0.0, GROUP_GAP_PX)
		content_box.add_child(spacer)
	var title := Label.new()
	title.text = group_title
	title.theme_type_variation = &"CaptionLabel"
	content_box.add_child(title)


func _add_reagent_card(chemical: ChemicalDefinition) -> void:
	var tint := chemical.solution_color if chemical.has_solution_color else chemical.color
	var is_solid := chemical.state == "solid"
	var card := LibraryCard.new()
	content_box.add_child(card)
	var subtitle := chemical.state.capitalize()
	if chemical.formula_display != "":
		subtitle = "%s  •  %s" % [chemical.formula_display, subtitle]
	card.setup("reagent", chemical.id, chemical.display_name, subtitle, chemical.summary if chemical.summary != "" else chemical.display_name,
		LibraryIcon.Kind.REAGENT_SOLID if is_solid else LibraryIcon.Kind.REAGENT_LIQUID, tint)
	card.activated.connect(_on_card_activated)
	_cards.append(card)


func _add_equipment_card(equipment: EquipmentDefinition) -> void:
	var icon_kind := LibraryIcon.Kind.VESSEL
	match equipment.style():
		"dropper":
			icon_kind = LibraryIcon.Kind.DROPPER
		"thermometer":
			icon_kind = LibraryIcon.Kind.THERMOMETER
		"hot_plate":
			icon_kind = LibraryIcon.Kind.HOT_PLATE
	var subtitle := equipment.material.capitalize()
	if equipment.capacity_ml > 0.0:
		subtitle = "%s  •  %s" % [UnitFormat.volume_ml(equipment.capacity_ml), equipment.material.capitalize()]
	var card := LibraryCard.new()
	content_box.add_child(card)
	card.setup("equipment", equipment.id, equipment.display_name, subtitle, equipment.display_name,
		icon_kind, Color.WHITE, equipment.visual.get("profile", []))
	card.activated.connect(_on_card_activated)
	_cards.append(card)


## Groups items by a key function, keeping the original order inside each group.
static func _group_by(items: Array, key_of: Callable) -> Dictionary:
	var groups: Dictionary = {}
	for item in items:
		var group_key := str(key_of.call(item))
		if not groups.has(group_key):
			groups[group_key] = []
		(groups[group_key] as Array).append(item)
	return groups


## Known groups first in the given order, then any other group alphabetically.
static func _ordered_groups(groups: Dictionary, preferred: Array) -> Array:
	var ordered: Array = []
	for group in preferred:
		if groups.has(group):
			ordered.append(group)
	var others: Array = []
	for group in groups.keys():
		if not preferred.has(group):
			others.append(group)
	others.sort()
	ordered.append_array(others)
	return ordered


# ---------------------------------------------------------------- state shown on the cards

func _refresh() -> void:
	if _host == null or _host.simulation == null:
		return
	var sim := _host.simulation
	for entry in _cards:
		var card := entry as LibraryCard
		var object_id := _object_for(sim, card)
		card.set_active(object_id != "" and object_id == _selected_id)
		card.set_tag(_tag_for(sim, card))


## The object a card stands for: the first object holding that substance, or of that equipment.
func _object_for(sim: LabSimulation, card: LibraryCard) -> String:
	var ids: Array = sim.state.objects.keys()
	ids.sort()
	for object_id in ids:
		var item: LabObject = sim.state.objects[object_id]
		if card.kind == "equipment" and item.equipment_id == card.key:
			return str(object_id)
		if card.kind == "reagent" and item.vessel != null \
				and (item.vessel.liquids.has(card.key) or item.vessel.solids.has(card.key)):
			return str(object_id)
	return ""


func _tag_for(sim: LabSimulation, card: LibraryCard) -> String:
	if card.kind == "equipment":
		var count := 0
		for item in sim.state.objects.values():
			if (item as LabObject).equipment_id == card.key:
				count += 1
		if count == 0:
			return "Not available"
		return "Available" if count == 1 else "×%d available" % count
	var liquid_ml := 0.0
	var solid_g := 0.0
	for item in sim.state.objects.values():
		var vessel := (item as LabObject).vessel
		if vessel == null:
			continue
		liquid_ml += float(vessel.liquids.get(card.key, 0.0))
		solid_g += float(vessel.solids.get(card.key, 0.0))
	if liquid_ml > 0.0:
		return "%s in stock" % UnitFormat.volume_ml(liquid_ml)
	if solid_g > 0.0:
		return "%s in stock" % UnitFormat.mass_g(solid_g)
	return "Not in stock"


func _on_card_activated(card: LibraryCard) -> void:
	if _host == null or _host.simulation == null:
		return
	var object_id := _object_for(_host.simulation, card)
	if object_id == "":
		EventBus.feedback_message_requested.emit("None of that is on the bench right now.", &"warning")
		return
	object_focus_requested.emit(object_id)


func _on_object_selected(object_id: String) -> void:
	_selected_id = object_id
	_refresh()



## All 118 entries are shown as read-only reference cards; they are not spawnable reagents.
func _add_element_reference_section(database: ContentDatabase) -> void:
	_add_heading("Periodic table · 118 reference elements", "ELEMENTS")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	content_box.add_child(grid)
	for atomic_number in range(1, 119):
		var element := database.get_element_by_number(atomic_number)
		if element == null:
			continue
		var card := ElementReferenceCard.new()
		grid.add_child(card)
		card.setup(element)
		card.activated.connect(_on_element_reference_activated)


func _on_element_reference_activated(element: ElementDefinition) -> void:
	var group_label := "f-block" if element.group <= 0 else str(element.group)
	var config := element.electron_configuration if element.electron_configuration != "" else "Not listed"
	var message := "%s (%s), atomic number %d. %s; period %d, group %s, block %s. Electron configuration: %s. Reference-only entry." % [
		element.display_name, element.id, element.atomic_number, element.category, element.period, group_label, element.block, config]
	EventBus.feedback_message_requested.emit(message, &"info")
