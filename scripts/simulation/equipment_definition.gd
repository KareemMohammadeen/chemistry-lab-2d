class_name EquipmentDefinition
extends RefCounted
## One kind of equipment, loaded from data/equipment/*.json. Read-only after loading.
## Equipment never decides chemical results; it only describes what the item is and
## how it can be used.

var id: String = ""
var display_name: String = ""
var category: String = ""
var material: String = ""
## 0 for items that cannot hold contents.
var capacity_ml: float = 0.0
var default_state: String = ""
var movable: bool = true
var interactions: PackedStringArray = PackedStringArray()
var default_pour_ml: float = 0.0
var default_solid_g: float = 0.0
var glass_mass_g: float = 0.0
## {"surface": bool, "support": bool, "insert_into_vessel": bool}
var placement: Dictionary = {}
## Set for appliances that can hold vessels on top: accepts_categories, half_width, top_offset_y.
var support: Dictionary = {}
## Set for heat sources: temperatures, rates and heat transfer (see HeatSystem).
var heater: Dictionary = {}
## Set for thermometers: min_c, max_c, insert_offset.
var thermometer: Dictionary = {}
## Named points in local pixels (origin at the bottom centre): base, opening, pour_lip, support_top.
var interaction_points: Dictionary = {}
var visual: Dictionary = {}


static func from_dictionary(data: Dictionary) -> EquipmentDefinition:
	var equipment_id := str(data.get("id", ""))
	if equipment_id.is_empty():
		push_error("EquipmentDefinition: entry has no 'id': %s" % str(data))
		return null
	var equipment := EquipmentDefinition.new()
	equipment.id = equipment_id
	equipment.display_name = str(data.get("name", equipment_id))
	equipment.category = str(data.get("category", ""))
	equipment.material = str(data.get("material", ""))
	equipment.capacity_ml = DataValue.number(data, "capacity_ml", 0.0)
	equipment.default_state = str(data.get("default_state", ""))
	equipment.movable = bool(data.get("movable", true))
	for interaction in data.get("interactions", []):
		equipment.interactions.append(str(interaction))
	equipment.default_pour_ml = float(data.get("default_pour_ml", 0.0))
	equipment.default_solid_g = float(data.get("default_solid_g", 0.0))
	equipment.glass_mass_g = DataValue.number(data, "glass_mass_g", 0.0)
	equipment.placement = data.get("placement", {})
	equipment.support = data.get("support", {})
	equipment.heater = data.get("heater", {})
	equipment.thermometer = data.get("thermometer", {})
	equipment.interaction_points = data.get("interaction_points", {})
	equipment.visual = data.get("visual", {})
	return equipment


## True for items that can hold liquids and solids.
func is_vessel() -> bool:
	return category == "vessel"


func is_heater() -> bool:
	return not heater.is_empty()


func supports(interaction_id: String) -> bool:
	return interactions.has(interaction_id)


func style() -> String:
	return str(visual.get("style", "vessel"))


## A named interaction point as a Vector2 (local pixels), or the fallback when it is not defined.
func point(point_name: String, fallback: Vector2) -> Vector2:
	var entry: Variant = interaction_points.get(point_name)
	if typeof(entry) != TYPE_ARRAY:
		return fallback
	var parts: Array = entry
	if parts.size() < 2:
		return fallback
	return Vector2(float(parts[0]), float(parts[1]))
