class_name ReactionResult
extends RefCounted
## Immutable-by-convention result envelope shared by the matcher and future executor.
## The matcher only reports readiness; it never consumes or creates materials.

enum Status {
	INVALID,
	REJECTED,
	NOT_MATCHED,
	MATCHED,
	EXECUTED,
}

var status: int = Status.INVALID
var reaction_id: String = ""
var reaction_name: String = ""
var reaction_type: String = ""
var message: String = ""
var matched_reactants: Array = []
var missing_reactants: Array = []
var observations: Array = []
var effects: Array = []
var consumed: Dictionary = {}
var produced: Dictionary = {}
var energy_kj: float = 0.0
var temperature_delta_c: float = 0.0
var errors: Array = []
var warnings: Array = []


func is_match() -> bool:
	return status == Status.MATCHED or status == Status.EXECUTED


func is_success() -> bool:
	return is_match()


func status_name() -> String:
	match status:
		Status.REJECTED:
			return "rejected"
		Status.NOT_MATCHED:
			return "not_matched"
		Status.MATCHED:
			return "matched"
		Status.EXECUTED:
			return "executed"
		_:
			return "invalid"


func to_dictionary() -> Dictionary:
	return {
		"status": status_name(),
		"reaction_id": reaction_id,
		"reaction_name": reaction_name,
		"reaction_type": reaction_type,
		"message": message,
		"matched_reactants": matched_reactants.duplicate(true),
		"missing_reactants": missing_reactants.duplicate(true),
		"observations": observations.duplicate(true),
		"effects": effects.duplicate(true),
		"consumed": consumed.duplicate(true),
		"produced": produced.duplicate(true),
		"energy_kj": energy_kj,
		"temperature_delta_c": temperature_delta_c,
		"errors": errors.duplicate(true),
		"warnings": warnings.duplicate(true),
	}