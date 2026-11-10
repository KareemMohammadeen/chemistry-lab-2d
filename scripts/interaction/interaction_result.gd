class_name InteractionResult
extends RefCounted
## Outcome of an interaction attempt. Failures always carry an operator-facing reason, so
## invalid actions are never silent. Successes may carry an informational note.

var is_success: bool = false
## Failure: the reason. Success: an optional note (for example "Only 20 mL fit").
var message: String = ""
var data: Dictionary = {}


static func success(info: String = "", result_data: Dictionary = {}) -> InteractionResult:
	var result := InteractionResult.new()
	result.is_success = true
	result.message = info
	result.data = result_data
	return result


static func failure(reason: String) -> InteractionResult:
	var result := InteractionResult.new()
	result.message = reason
	return result
