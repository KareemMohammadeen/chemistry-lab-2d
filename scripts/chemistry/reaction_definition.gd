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
	return reaction


func observation(key: String) -> String:
	return str(observations.get(key, ""))
