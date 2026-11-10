class_name SimulationHost
extends Node
## Scene-tree owner of the simulation: creates it, drives its fixed steps from the frame loop
## and exposes the command stack. This is the only node that advances simulated time.

var database: ContentDatabase
var simulation: LabSimulation
var clock: SimulationClock = SimulationClock.new()
var commands: CommandStack = CommandStack.new()

var _setup_path: String = ""


## Builds the simulation from a setup file. Returns false (after logging) on failure.
func initialise(content: ContentDatabase, setup_path: String) -> bool:
	database = content
	_setup_path = setup_path
	simulation = LabSimulation.new(content)
	simulation.observation_added.connect(_on_observation_added)
	clock.configure(content.constant("fixed_step_s", 0.1), int(content.constant("max_steps_per_frame", 8.0)))
	return simulation.load_setup(setup_path)


func _process(delta: float) -> void:
	if simulation == null:
		return
	for _step in range(clock.advance(delta)):
		simulation.step(clock.fixed_step_s)


## Runs a command through the stack (validation, execution, logging, undo bookkeeping).
func submit(command: LabCommand) -> InteractionResult:
	return commands.execute(command, simulation)


func undo() -> InteractionResult:
	return commands.undo(simulation)


func redo() -> InteractionResult:
	return commands.redo(simulation)


## Restores the starting bench and forgets the undo history.
func reset() -> void:
	commands.clear()
	simulation.load_setup(_setup_path)


func _on_observation_added(object_id: String, entry: Dictionary) -> void:
	EventBus.observation_added.emit(object_id, entry)
