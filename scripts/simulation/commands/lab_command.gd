class_name LabCommand
extends RefCounted
## Base class of every operator action that matters (pick up, place, pour, mix, heat).
## A command validates first (returning a reason when it cannot run), then executes.
## Commands are recorded by the CommandStack, which gives undo, redo, replay and reports.

var context: InteractionContext
## False for actions that change no laboratory state (for example picking an object up).
var undoable: bool = true
## Human-readable summary of what happened, filled in by execute() for the command log.
var description: String = ""


func with_context(new_context: InteractionContext) -> LabCommand:
	context = new_context
	return self


func command_name() -> String:
	return "command"


## Returns a failure with an operator-facing reason when the action cannot be done.
func validate(_sim: LabSimulation) -> InteractionResult:
	return InteractionResult.success()


func execute(_sim: LabSimulation) -> InteractionResult:
	return InteractionResult.failure("This command has no implementation.")


## Looks up an object and its equipment definition. Returns null entries as a failure reason.
func _missing_object_reason(sim: LabSimulation, object_id: String) -> String:
	if sim.state.get_object(object_id) == null:
		return "That object is no longer on the bench."
	return ""
