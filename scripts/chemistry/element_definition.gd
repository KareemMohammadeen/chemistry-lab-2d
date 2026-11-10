class_name ElementDefinition
extends RefCounted
## One chemical element, loaded from data/elements/elements.json. Read-only reference data.
## Unknown values are NAN (numbers) or empty (text); they are never guessed.

## The element symbol doubles as the id used by ContentDatabase.
var id: String = ""
var atomic_number: int = 0
var display_name: String = ""
var period: int = 0
## 0 for the f block, which has no group number.
var group: int = 0
var block: String = ""
var category: String = ""
var atomic_mass_u: float = NAN
var atomic_mass_is_mass_number: bool = false
var state_at_stp: String = ""
var melting_c: float = NAN
var boiling_c: float = NAN
var density_g_cm3: float = NAN
var electronegativity: float = NAN
var electron_configuration: String = ""
var electrons_per_shell: Array = []
var oxidation_states: Array = []
var appearance: String = ""
var hazards: String = ""
var description: String = ""
var radioactive: bool = false


static func from_dictionary(data: Dictionary) -> ElementDefinition:
	var symbol := str(data.get("symbol", ""))
	if symbol.is_empty():
		push_error("ElementDefinition: entry has no 'symbol': %s" % str(data))
		return null
	var element := ElementDefinition.new()
	element.id = symbol
	element.atomic_number = int(data.get("atomic_number", 0))
	element.display_name = str(data.get("name", symbol))
	element.period = int(data.get("period", 0))
	element.group = int(data.get("group", 0)) if data.get("group") != null else 0
	element.block = str(data.get("block", ""))
	element.category = str(data.get("category", ""))
	element.atomic_mass_u = DataValue.number(data, "atomic_mass_u", NAN)
	element.atomic_mass_is_mass_number = bool(data.get("atomic_mass_is_mass_number", false))
	element.melting_c = DataValue.number(data, "melting_c", NAN)
	element.boiling_c = DataValue.number(data, "boiling_c", NAN)
	element.density_g_cm3 = DataValue.number(data, "density_g_cm3", NAN)
	element.electronegativity = DataValue.number(data, "electronegativity_pauling", NAN)
	element.state_at_stp = _text_value(data.get("state_at_stp"))
	element.electron_configuration = _text_value(data.get("electron_configuration"))
	element.electrons_per_shell = data.get("electrons_per_shell", [])
	var oxidation: Variant = data.get("oxidation_states_common")
	if typeof(oxidation) == TYPE_DICTIONARY:
		element.oxidation_states = (oxidation as Dictionary).get("value", [])
	element.appearance = str(data.get("appearance", "")) if data.get("appearance") != null else ""
	element.hazards = str(data.get("hazards", "")) if data.get("hazards") != null else ""
	element.description = str(data.get("description", ""))
	element.radioactive = bool(data.get("radioactive", false))
	return element


static func _text_value(entry: Variant) -> String:
	if typeof(entry) == TYPE_DICTIONARY:
		return str((entry as Dictionary).get("value", ""))
	return ""
