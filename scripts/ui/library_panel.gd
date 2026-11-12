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

@export var subtitle_label: Label
@export var content_box: VBoxContainer

var _host: SimulationHost
var _cards: Array = []
var _selected_id: String = ""
var _refresh_left_s: float = 0.0
## Section headings ("REAGENTS", "EQUIPMENT") are written once, above their first group.
var _section_written: Dictionary = {}
var _curriculum_profile: Dictionary = {}


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
	var reagent_count := 0
	var by_group := _group_by(database.chemicals.values(), func(item: Variant) -> String: return (item as ChemicalDefinition).category)
	for group in _ordered_groups(by_group, CHEMICAL_GROUP_ORDER):
		_add_heading(str(CHEMICAL_GROUP_TITLES.get(group, str(group).capitalize())), "REAGENTS")
		for chemical in by_group[group]:
			_add_reagent_card(chemical as ChemicalDefinition)
			reagent_count += 1
	var equipment_items: Array = []
	for item in database.equipment.values():
		if not HIDDEN_EQUIPMENT_STYLES.has((item as EquipmentDefinition).style()):
			equipment_items.append(item)
	var equipment_groups := _group_by(equipment_items, func(item: Variant) -> String: return (item as EquipmentDefinition).category)
	var equipment_count := 0
	for group in _ordered_groups(equipment_groups, EQUIPMENT_GROUP_ORDER):
		_add_heading(str(EQUIPMENT_GROUP_TITLES.get(group, str(group).capitalize())), "EQUIPMENT")
		for equipment in equipment_groups[group]:
			_add_equipment_card(equipment as EquipmentDefinition)
			equipment_count += 1
	_add_element_reference_section(database)
	var profile_label := str(_curriculum_profile.get("label", "No grade selected"))
	var subject_label := str(_curriculum_profile.get("subject", "Select a grade"))
	var mapping_note := str(_curriculum_profile.get("note", "Choose a grade to view its curriculum context."))
	if str(_curriculum_profile.get("topic_mapping_status", "")) == "pending_official_textbook_review":
		mapping_note = "Lesson-by-lesson mapping pending review of the matching official textbook. " + mapping_note
	subtitle_label.text = "%d playable reagents  •  %d instruments\n%s — %s\n%s" % [reagent_count, equipment_count, profile_label, subject_label, mapping_note]


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
	grid.columns = 4
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
