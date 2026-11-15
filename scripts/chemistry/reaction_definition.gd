class_name ReactionDefinition
extends RefCounted
## One reaction or physical process, loaded from data/reactions/*.json.
## Types in use: dissolution, neutralisation, boiling. The ReactionEngine interprets them.

var id: String = ""
var type: String = ""
var display_name: String = ""
## Dissolution: the dissolving substance. Boiling: the boiling substance.
var solute: String = ""
var substance: String = ""
var tier: String = "qualitative"
var equation: String = ""
var explanation: String = ""
var level: String = ""
var time_constant_s: float = 10.0
var enthalpy_kj_per_mol: float = 0.0
var observations: Dictionary = {}
## Forward-compatible reaction participants. These are descriptive until a validated handler executes them.
var reactants: Array = []
var products: Array = []
var conditions: Array = []
var safety_status: String = ""
var source_ids: Array = []
## Optional visual-only demonstration metadata; never interpreted as a real procedure.
var virtual_only: bool = false
var product_solid_id: String = ""
var illustrative_output_g: float = 0.0
var visual_effect: String = ""
var grade_suggestion: String = ""
var curriculum_alignment_status: String = ""


static func from_dictionary(data: Dictionary) -> ReactionDefinition:
	var reaction_id := str(data.get("id", ""))
	var reaction_type := str(data.get("type", ""))
	if reaction_id.is_empty() or reaction_type.is_empty():
		push_error("ReactionDefinition: entry needs 'id' and 'type': %s" % str(data))
		return null
	var reaction := ReactionDefinition.new()
	reaction.id = reaction_id
	reaction.type = reaction_type
	reaction.display_name = str(data.get("name", reaction_id))
	reaction.solute = str(data.get("solute", ""))
	reaction.substance = str(data.get("substance", ""))
	reaction.tier = str(data.get("tier", "qualitative"))
	reaction.equation = str(data.get("equation", ""))
	reaction.explanation = str(data.get("explanation", ""))
	reaction.level = str(data.get("level", ""))
	reaction.time_constant_s = DataValue.number(data, "time_constant_s", 10.0)
	reaction.enthalpy_kj_per_mol = DataValue.number(data, "enthalpy_kj_per_mol", 0.0)
	reaction.observations = data.get("observations", {})
	reaction.reactants = data.get("reactants", [])
	reaction.products = data.get("products", [])
	reaction.conditions = data.get("conditions", [])
	reaction.safety_status = str(data.get("safety_status", ""))
	reaction.source_ids = data.get("source_ids", [])
	reaction.virtual_only = bool(data.get("virtual_only", false))
	reaction.product_solid_id = str(data.get("product_solid_id", ""))
	reaction.illustrative_output_g = DataValue.number(data, "illustrative_output_g", 0.0)
	reaction.visual_effect = str(data.get("visual_effect", ""))
	reaction.grade_suggestion = str(data.get("grade_suggestion", ""))
	reaction.curriculum_alignment_status = str(data.get("curriculum_alignment_status", ""))
	return reaction


func observation(key: String) -> String:
	return str(observations.get(key, ""))
