class_name CommandStack
extends RefCounted
## Executes commands and records them. Undo and redo restore full-state snapshots taken
## around each undoable command (the simulation is small, so snapshots are cheap and exactly
## correct, including every chemical consequence). Undo rewinds simulated time to the
## moment of the command. The history list is the raw material for replay and lab reports.

signal changed

## Maximum number of undoable steps kept.
const MAX_UNDO_STEPS := 100

## Every attempted command, accepted or rejected, in order (plain dictionaries).
var history: Array = []

var _undo_stack: Array = []
var _redo_stack: Array = []


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func last_entry() -> Dictionary:
	if history.is_empty():
		return {}
	return history[history.size() - 1]


func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	history.clear()
	changed.emit()


func execute(command: LabCommand, sim: LabSimulation) -> InteractionResult:
	var validation := command.validate(sim)
	if not validation.is_success:
		_log(command, sim, validation)
		return validation
	var before: Dictionary = {}
	if command.undoable:
		before = sim.capture_snapshot()
	var result := command.execute(sim)
	if result.is_success and command.undoable:
		_undo_stack.append({"before": before, "after": sim.capture_snapshot(), "label": command.description})
		if _undo_stack.size() > MAX_UNDO_STEPS:
			_undo_stack.pop_front()
		_redo_stack.clear()
	_log(command, sim, result)
	changed.emit()
	return result


func undo(sim: LabSimulation) -> InteractionResult:
	if _undo_stack.is_empty():
		return InteractionResult.failure("Nothing to undo.")
	var step: Dictionary = _undo_stack.pop_back()
	sim.restore_snapshot(step["before"])
	_redo_stack.append(step)
	_log_history_move("undo", sim, str(step["label"]))
	changed.emit()
	return InteractionResult.success("Undone: %s" % step["label"])


func redo(sim: LabSimulation) -> InteractionResult:
	if _redo_stack.is_empty():
		return InteractionResult.failure("Nothing to redo.")
	var step: Dictionary = _redo_stack.pop_back()
	sim.restore_snapshot(step["after"])
	_undo_stack.append(step)
	_log_history_move("redo", sim, str(step["label"]))
	changed.emit()
	return InteractionResult.success("Redone: %s" % step["label"])


func _log(command: LabCommand, sim: LabSimulation, result: InteractionResult) -> void:
	var entry := {
		"index": history.size(),
		"command": command.command_name(),
		"ok": result.is_success,
		"description": command.description if result.is_success else "",
		"reason": "" if result.is_success else result.message,
		"sim_time_s": sim.state.time_s,
		"context": command.context.to_dictionary() if command.context != null else {},
	}
	history.append(entry)
	EventBus.command_logged.emit(entry)


func _log_history_move(kind: String, sim: LabSimulation, label: String) -> void:
	var entry := {
		"index": history.size(), "command": kind, "ok": true, "description": label,
		"reason": "", "sim_time_s": sim.state.time_s, "context": {},
	}
	history.append(entry)
	EventBus.command_logged.emit(entry)
