class_name ChemicalDefinition
extends RefCounted
## One substance, loaded from data/chemicals/*.json. Read-only after loading.
## Systems query this class; no script holds substance properties of its own.

var id: String = ""
var display_name: String = ""
var short_name: String = ""
var formula_display: String = ""
var state: String = "liquid"
var category: String = ""
## Appearance of the substance itself (display value, not a measurement).
var color: Color = Color.WHITE
var has_solution_color: bool = false
## Colour of a concentrated solution of this substance in water.
var solution_color: Color = Color.WHITE
## Dissolved concentration (g per 100 mL) at which the solution colour is fully shown.
var color_full_at_g_per_100ml: float = 1.0
var density_g_ml: float = 1.0
## NAN when unknown.
var boiling_point_c: float = NAN
var is_aqueous_solvent: bool = false
var h_plus_mol_per_l: float = 0.0
var oh_minus_mol_per_l: float = 0.0
## [[temperature_c, grams_per_100_ml], ...] sorted by temperature. Empty when unknown.
var solubility_curve: Array = []
var label_lines: Array = []
var safety: Dictionary = {}
var summary: String = ""
## Names of data fields whose provenance status is not "reference" (see DataValue).
var unreviewed_fields: Array = []


static func from_dictionary(data: Dictionary) -> ChemicalDefinition:
	var chemical_id := str(data.get("id", ""))
	if chemical_id.is_empty():
		push_error("ChemicalDefinition: entry has no 'id': %s" % str(data))
		return null
	var chemical := ChemicalDefinition.new()
	chemical.id = chemical_id
	chemical.display_name = str(data.get("name", chemical_id))
	chemical.short_name = str(data.get("short_name", chemical.display_name))
	chemical.formula_display = str(data.get("formula_display", data.get("formula", "")))
	chemical.state = str(data.get("state", "liquid"))
	chemical.category = str(data.get("category", ""))
	chemical.color = DataValue.color(data.get("color"), Color.WHITE)
	if data.has("solution_color"):
		chemical.has_solution_color = true
		chemical.solution_color = DataValue.color(data["solution_color"], Color.WHITE)
	chemical.color_full_at_g_per_100ml = float(data.get("color_full_at_g_per_100ml", 1.0))
	chemical.density_g_ml = DataValue.number(data, "density_g_ml", 1.0)
	chemical.boiling_point_c = DataValue.number(data, "boiling_point_c", NAN)
	chemical.is_aqueous_solvent = bool(data.get("is_aqueous_solvent", false))
	var acid_base: Dictionary = data.get("acid_base", {})
	chemical.h_plus_mol_per_l = float(acid_base.get("h_plus_mol_per_l", 0.0))
	chemical.oh_minus_mol_per_l = float(acid_base.get("oh_minus_mol_per_l", 0.0))
	var solubility: Dictionary = data.get("solubility_in_water", {})
	chemical.solubility_curve = solubility.get("curve", [])
	chemical.label_lines = data.get("label_lines", [])
	chemical.safety = data.get("safety", {})
	var display: Dictionary = data.get("display", {})
	chemical.summary = str(display.get("summary", ""))
	for key in data.keys():
		if typeof(data[key]) == TYPE_DICTIONARY and data[key].has("status") and not DataValue.is_trusted(data, key):
			chemical.unreviewed_fields.append(str(key))
	return chemical


## Solubility in water (g per 100 mL) at a temperature, interpolated linearly along the data
## curve and held constant outside it. Returns 0 when the substance has no solubility data.
func solubility_g_per_100ml(temperature_c: float) -> float:
	if solubility_curve.is_empty():
		return 0.0
	var first: Array = solubility_curve[0]
	if temperature_c <= float(first[0]):
		return float(first[1])
	for index in range(1, solubility_curve.size()):
		var lower: Array = solubility_curve[index - 1]
		var upper: Array = solubility_curve[index]
		if temperature_c <= float(upper[0]):
			var span := float(upper[0]) - float(lower[0])
			var fraction := 0.0 if span <= 0.0 else (temperature_c - float(lower[0])) / span
			return lerpf(float(lower[1]), float(upper[1]), fraction)
	var last: Array = solubility_curve[solubility_curve.size() - 1]
	return float(last[1])


## Text for the label of a reagent bottle (up to two lines).
func get_label_lines() -> Array:
	if label_lines.is_empty():
		return [short_name, formula_display]
	return label_lines
