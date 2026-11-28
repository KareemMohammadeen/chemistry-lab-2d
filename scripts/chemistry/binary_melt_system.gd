class_name BinaryMeltSystem
extends RefCounted
## Melting behaviour of two solids that are heated together, loaded from
## data/materials/binary_systems.json. Only the "eutectic" kind is implemented.
##
## Model (all of it is documented in docs/MATERIAL_THERMODYNAMICS.md):
##  - composition x is the mass fraction of component B in the pair;
##  - the liquid first appears at the eutectic temperature T_e, with the eutectic composition x_e;
##  - on the A-rich side (x < x_e) the primary solid is pure A and the liquidus runs in a straight
##    line from T_e (at x_e) to the melting point of A (at x = 0); the B-rich side is symmetric;
##  - the liquid fraction follows the lever rule on that liquidus;
##  - terminal solid solubility and the heat of mixing are neglected.
## The straight liquidus is an approximation: only the two melting points and the eutectic point
## were found in fetched sources, and real liquidus curves are curved.

var id: String = ""
var kind: String = "eutectic"
var component_a: String = ""
var component_b: String = ""
var product_name: String = ""
var melting_a_c: float = NAN
var melting_b_c: float = NAN
var eutectic_c: float = NAN
## Eutectic composition as the mass fraction of B.
var eutectic_x_b: float = NAN
var fusion_a_j_per_g: float = NAN
var fusion_b_j_per_g: float = NAN
var data_status: String = ""


## Builds a system from its JSON entry. Returns null and appends to errors when it is unusable.
static func from_dictionary(data: Dictionary, db: ContentDatabase, errors: Array) -> BinaryMeltSystem:
	var system := BinaryMeltSystem.new()
	system.id = str(data.get("id", ""))
	system.kind = str(data.get("kind", ""))
	system.component_a = str(data.get("component_a", ""))
	system.component_b = str(data.get("component_b", ""))
	system.product_name = str(data.get("product_name", system.id))
	system.data_status = str(data.get("status", ""))
	if system.id.is_empty() or system.component_a.is_empty() or system.component_b.is_empty():
		errors.append("Binary system needs an id and two components: %s" % str(data))
		return null
	if system.kind != "eutectic":
		errors.append("Binary system '%s' has kind '%s'; only 'eutectic' is implemented." % [system.id, system.kind])
		return null
	var profile_a := _profile(db, system.component_a)
	var profile_b := _profile(db, system.component_b)
	if profile_a == null or profile_b == null or not profile_a.can_melt() or not profile_b.can_melt():
		errors.append("Binary system '%s': both components need a melting point and heat of fusion." % system.id)
		return null
	system.melting_a_c = profile_a.melting_point_c
	system.melting_b_c = profile_b.melting_point_c
	system.fusion_a_j_per_g = profile_a.fusion_j_per_g
	system.fusion_b_j_per_g = profile_b.fusion_j_per_g
	system.eutectic_c = DataValue.number(data, "eutectic_temperature_c", NAN)
	system.eutectic_x_b = DataValue.number(data, "eutectic_mass_fraction_b", NAN)
	if not is_finite(system.eutectic_c) or not is_finite(system.eutectic_x_b) \
			or system.eutectic_x_b <= 0.0 or system.eutectic_x_b >= 1.0:
		errors.append("Binary system '%s' needs a eutectic temperature and a composition strictly between 0 and 1." % system.id)
		return null
	if system.eutectic_c >= minf(system.melting_a_c, system.melting_b_c):
		errors.append("Binary system '%s': the eutectic must lie below both melting points." % system.id)
		return null
	return system


static func _profile(db: ContentDatabase, chemical_id: String) -> ThermalProfile:
	var chemical := db.get_chemical(chemical_id)
	if chemical == null:
		return null
	return chemical.thermal


func involves(chemical_id: String) -> bool:
	return chemical_id == component_a or chemical_id == component_b


## Liquidus temperature (degC) of a mixture with B mass fraction x.
func liquidus_c(x: float) -> float:
	if x <= eutectic_x_b:
		return melting_a_c + (eutectic_c - melting_a_c) * (x / eutectic_x_b)
	return eutectic_c + (melting_b_c - eutectic_c) * ((x - eutectic_x_b) / (1.0 - eutectic_x_b))


## Composition (B mass fraction) of the liquid in equilibrium with the primary solid at a
## temperature between the eutectic and the liquidus, on the side of x.
func liquid_composition(x: float, temperature_c: float) -> float:
	if temperature_c <= eutectic_c:
		return eutectic_x_b
	if x <= eutectic_x_b:
		return eutectic_x_b * (melting_a_c - temperature_c) / (melting_a_c - eutectic_c)
	return 1.0 - (1.0 - eutectic_x_b) * (melting_b_c - temperature_c) / (melting_b_c - eutectic_c)


## Liquid mass fraction (lever rule) at a temperature at or above the eutectic. This is the value
## just above the eutectic temperature; below it the mixture is fully solid (fraction 0).
func liquid_fraction(x: float, temperature_c: float) -> float:
	if temperature_c >= liquidus_c(x):
		return 1.0
	var liquid_x := liquid_composition(x, temperature_c)
	if x <= eutectic_x_b:
		return clampf(x / liquid_x, 0.0, 1.0)
	return clampf((1.0 - x) / (1.0 - liquid_x), 0.0, 1.0)


## Heat of fusion (J per gram of mixture) of a mixture with B mass fraction x, assuming ideal mixing.
func fusion_j_per_g(x: float) -> float:
	return (1.0 - x) * fusion_a_j_per_g + x * fusion_b_j_per_g
