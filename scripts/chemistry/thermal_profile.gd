class_name ThermalProfile
extends RefCounted
## Thermal and phase data of one substance family, read from the "thermal" block of a chemical
## file plus its top-level melting and boiling point. This is the single place the simulation
## reads these properties from; no system keeps its own copy (see docs/MATERIAL_THERMODYNAMICS.md).
##
## A family is the set of phases of one substance. Most substances are one chemical id for every
## phase (zinc is "zinc" whether solid or molten). Water is split over three ids, so its profile
## names them in "phases": {"solid": "ice", "liquid": "water", "gas": "water_vapor"}.
##
## All specific quantities are per gram so they combine with the gram/millilitre ledgers of a
## VesselState. Any value that is not known stays NAN and the system that needs it declines to
## model that behaviour; nothing is guessed (see can_melt, can_boil).

const GAS_CONSTANT_J_PER_MOL_K := 8.314462618
const KELVIN_OFFSET := 273.15
const STANDARD_PRESSURE_KPA := 101.325

var family_id: String = ""
## Phase -> chemical id ("solid", "liquid", "gas"). Missing phases use the family id.
var phase_ids: Dictionary = {}
var melting_point_c: float = NAN
var boiling_point_c: float = NAN
## J per gram. NAN when unknown.
var fusion_j_per_g: float = NAN
var vaporization_j_per_g: float = NAN
## J per gram per kelvin. NAN when unknown.
var cp_solid_j_per_g_k: float = NAN
var cp_liquid_j_per_g_k: float = NAN
var cp_gas_j_per_g_k: float = NAN
## g per mL. NAN means "use the chemical's own density".
var density_solid_g_ml: float = NAN
var density_liquid_g_ml: float = NAN
## Molar mass in g/mol (needed for vapour amounts and vapour pressure); NAN when unknown.
var molar_mass_g_mol: float = NAN
## Antoine data: {"a","b","c","t_min_k","t_max_k"} (log10 of pressure in bar, T in kelvin), or empty.
var antoine: Dictionary = {}
## Names of fields whose provenance status is not "reference" (see DataValue).
var unreviewed_fields: PackedStringArray = PackedStringArray()


static func from_dictionary(family: String, thermal: Dictionary, top_level: Dictionary,
		molar_mass: float) -> ThermalProfile:
	var profile := ThermalProfile.new()
	profile.family_id = family
	var phases: Variant = thermal.get("phases", {})
	if typeof(phases) == TYPE_DICTIONARY:
		profile.phase_ids = (phases as Dictionary).duplicate()
	profile.molar_mass_g_mol = molar_mass
	profile.melting_point_c = DataValue.number(top_level, "melting_point_c", NAN)
	profile.boiling_point_c = DataValue.number(top_level, "boiling_point_c", NAN)
	profile.fusion_j_per_g = DataValue.number(thermal, "enthalpy_fusion_j_per_g", NAN)
	profile.vaporization_j_per_g = DataValue.number(thermal, "enthalpy_vaporization_j_per_g", NAN)
	profile.cp_solid_j_per_g_k = DataValue.number(thermal, "specific_heat_solid_j_per_g_k", NAN)
	profile.cp_liquid_j_per_g_k = DataValue.number(thermal, "specific_heat_liquid_j_per_g_k", NAN)
	profile.cp_gas_j_per_g_k = DataValue.number(thermal, "specific_heat_gas_j_per_g_k", NAN)
	profile.density_solid_g_ml = DataValue.number(thermal, "density_solid_g_ml", NAN)
	profile.density_liquid_g_ml = DataValue.number(thermal, "density_liquid_g_ml", NAN)
	var vapor: Variant = thermal.get("vapor_pressure", {})
	if typeof(vapor) == TYPE_DICTIONARY and str((vapor as Dictionary).get("model", "")) == "antoine_log10_bar_kelvin":
		var source: Dictionary = vapor
		profile.antoine = {
			"a": float(source.get("a", NAN)), "b": float(source.get("b", NAN)), "c": float(source.get("c", NAN)),
			"t_min_k": float(source.get("t_min_k", NAN)), "t_max_k": float(source.get("t_max_k", NAN)),
		}
	for key in thermal.keys():
		if typeof(thermal[key]) == TYPE_DICTIONARY and (thermal[key] as Dictionary).has("status") \
				and not DataValue.is_trusted(thermal, str(key)):
			profile.unreviewed_fields.append(str(key))
	return profile


func id_for_phase(phase: String) -> String:
	return str(phase_ids.get(phase, family_id))


## Every chemical id this family uses.
func member_ids() -> Array:
	var ids: Array = [family_id]
	for phase in ["solid", "liquid", "gas"]:
		var member := id_for_phase(phase)
		if not ids.has(member):
			ids.append(member)
	return ids


## True when melting and freezing can be simulated: a melting point and a heat of fusion are known.
func can_melt() -> bool:
	return is_finite(melting_point_c) and is_finite(fusion_j_per_g) and fusion_j_per_g > 0.0


## True when boiling can be simulated: a boiling point and a heat of vaporisation are known,
## along with the molar mass that converts the boiled mass to gas moles.
func can_boil() -> bool:
	return is_finite(boiling_point_c) and is_finite(vaporization_j_per_g) and vaporization_j_per_g > 0.0 \
		and is_finite(molar_mass_g_mol) and molar_mass_g_mol > 0.0


## Specific heat (J/g/K) of a phase. A phase without data falls back to the nearest phase that
## has it (solid <-> liquid), and NAN is returned only when the family has no heat capacity at all.
func cp_for_phase(phase: String) -> float:
	var primary := NAN
	var fallback := NAN
	match phase:
		"solid":
			primary = cp_solid_j_per_g_k
			fallback = cp_liquid_j_per_g_k
		"liquid":
			primary = cp_liquid_j_per_g_k
			fallback = cp_solid_j_per_g_k
		"gas":
			primary = cp_gas_j_per_g_k
	if is_finite(primary):
		return primary
	return fallback


func has_heat_capacity() -> bool:
	return is_finite(cp_solid_j_per_g_k) or is_finite(cp_liquid_j_per_g_k)


## Vapour pressure in kPa at a temperature. Uses the Antoine fit inside its valid range;
## elsewhere the integrated Clausius-Clapeyron relation anchored at the normal boiling point
## (constant heat of vaporisation, ideal gas), which needs can_boil(). NAN when neither applies.
func vapor_pressure_kpa(temperature_c: float) -> float:
	var kelvin := temperature_c + KELVIN_OFFSET
	if kelvin <= 0.0:
		return 0.0
	if not antoine.is_empty() and kelvin >= float(antoine["t_min_k"]) and kelvin <= float(antoine["t_max_k"]):
		var log_bar := float(antoine["a"]) - float(antoine["b"]) / (kelvin + float(antoine["c"]))
		return pow(10.0, log_bar) * 100.0
	if not can_boil():
		return NAN
	var molar_heat := vaporization_j_per_g * molar_mass_g_mol
	var boiling_k := boiling_point_c + KELVIN_OFFSET
	var exponent := -(molar_heat / GAS_CONSTANT_J_PER_MOL_K) * (1.0 / kelvin - 1.0 / boiling_k)
	return STANDARD_PRESSURE_KPA * exp(exponent)
