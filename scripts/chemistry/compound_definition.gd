class_name CompoundDefinition
extends RefCounted
## One reference compound, loaded from data/compounds/*.json. It describes what the substance
## is (properties, hazards, storage, reaction roles, notes). The playable version, with
## simulation fields, is a ChemicalDefinition named by `simulation_chemical_id`.

var id: String = ""
var display_name: String = ""
var formula_display: String = ""
var composition: Dictionary = {}
var molar_mass_g_mol: float = NAN
var state_at_20c: String = ""
var appearance: String = ""
var color: Color = Color.WHITE
var solution_color: Color = Color(0.0, 0.0, 0.0, 0.0)
var density_g_cm3: float = NAN
var melting_c: float = NAN
var boiling_c: float = NAN
## NAN when not given (see solubility_note).
var solubility_g_per_100ml: float = NAN
var solubility_note: String = ""
var hazard_classes: Array = []
var hazard_summary: String = ""
var storage: String = ""
## Each: {"role": String, "note": String}
var reactions: Array = []
var educational_notes: String = ""
var simulation_chemical_id: String = ""


static func from_dictionary(data: Dictionary) -> CompoundDefinition:
	var compound_id := str(data.get("id", ""))
	if compound_id.is_empty():
		push_error("CompoundDefinition: entry has no 'id': %s" % str(data))
		return null
	var compound := CompoundDefinition.new()
	compound.id = compound_id
	compound.display_name = str(data.get("name", compound_id))
	compound.formula_display = str(data.get("formula_display", ""))
	compound.composition = data.get("composition", {})
	compound.molar_mass_g_mol = DataValue.number(data, "molar_mass_g_mol", NAN)
	compound.state_at_20c = str(data.get("state_at_20c", ""))
	compound.appearance = str(data.get("appearance", ""))
	compound.color = Color.html(_hex(data.get("color_hex"), "#FFFFFF"))
	compound.solution_color = Color.html(_hex(data.get("solution_color_hex"), "#00000000"))
	compound.density_g_cm3 = DataValue.number(data, "density_g_cm3", NAN)
	compound.melting_c = DataValue.number(data, "melting_c", NAN)
	compound.boiling_c = DataValue.number(data, "boiling_c", NAN)
	var solubility: Dictionary = data.get("solubility_in_water", {})
	compound.solubility_g_per_100ml = DataValue.number(solubility, "g_per_100ml_at_20c", NAN)
	compound.solubility_note = str(solubility.get("note", ""))
	var hazards: Dictionary = data.get("hazards", {})
	compound.hazard_classes = hazards.get("classes", [])
	compound.hazard_summary = str(hazards.get("summary", ""))
	compound.storage = str(data.get("storage", ""))
	compound.reactions = data.get("reactions", [])
	compound.educational_notes = str(data.get("educational_notes", ""))
	var simulation: Dictionary = data.get("simulation", {})
	compound.simulation_chemical_id = str(simulation.get("chemical_id", "")) if simulation.get("chemical_id") != null else ""
	return compound


static func _hex(entry: Variant, fallback: String) -> String:
	if typeof(entry) == TYPE_DICTIONARY:
		return str((entry as Dictionary).get("value", fallback))
	return fallback
