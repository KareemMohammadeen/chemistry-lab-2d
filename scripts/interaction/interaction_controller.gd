class_name InteractionController
extends Node
## Turns pointer input into interaction contexts and commands (select, pick up, drag, place,
## pour). It decides *what the operator is trying to do* and asks the simulation through
## commands; it never decides chemical results. Every refusal is shown with its reason.

## Pointer travel (pixels) before a press turns into a drag.
const DRAG_THRESHOLD_PX := 6.0
const DEVICE_MOUSE := "mouse"

var _host: SimulationHost
var _workspace: LabWorkspace
var _interface: LabInterface
var _registry: InteractionRegistry = InteractionRegistry.new()

var _selected_id: String = ""
var _hovered_id: String = ""
var _press_object_id: String = ""
var _press_position: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_object_id: String = ""
var _grab_offset: Vector2 = Vector2.ZERO
## While set, the next click on a vessel completes this action (currently only "pour").
var _armed_action: StringName = &""
## "<object id>:<unit>" -> amount chosen in the inspector.
var _amounts: Dictionary = {}


func setup(host: SimulationHost, workspace: LabWorkspace, lab_interface: LabInterface) -> void:
	_host = host
	_workspace = workspace
	_interface = lab_interface
	_registry.load_definitions()
	_interface.undo_requested.connect(_on_undo_requested)
	_interface.redo_requested.connect(_on_redo_requested)
	_interface.reset_requested.connect(_on_reset_requested)
	_interface.pause_toggled.connect(_on_pause_toggled)
	_interface.speed_selected.connect(_on_speed_selected)
	_interface.action_requested.connect(_on_action_requested)
	_interface.object_focus_requested.connect(_select)
	_host.simulation.state_restored.connect(_on_state_restored)


func _unhandled_input(event: InputEvent) -> void:
	if _host == null:
		return
	if event is InputEventMouseButton and event.pressed:
		if _is_over_interface():
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_press(_pointer_position())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_armed_action()
			_select(_workspace.object_id_at(_pointer_position()))
	elif event.is_action_pressed(InputActions.UNDO):
		_on_undo_requested()
	elif event.is_action_pressed(InputActions.REDO):
		_on_redo_requested()
	elif OS.is_debug_build() and event.is_action_pressed(InputActions.DIAGNOSE_POINTER):
		_print_pointer_diagnostic()
	elif event.is_action_pressed(InputActions.DESELECT):
		_cancel_armed_action()
		_select("")
	elif event.is_action_pressed(InputActions.TOGGLE_PAUSE):
		_on_pause_toggled(not _host.clock.paused)
	elif event.is_action_pressed(InputActions.SPEED_UP):
		_step_speed(1)
	elif event.is_action_pressed(InputActions.SPEED_DOWN):
		_step_speed(-1)
	elif event.is_action_pressed(InputActions.SPEED_NORMAL):
		_on_speed_selected(SimulationClock.NORMAL_SPEED)


func _process(_delta: float) -> void:
	if _host == null:
		return
	var pointer := _pointer_position()
	var left_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if _press_object_id != "":
		if not left_down:
			if _dragging:
				_finish_drag(pointer)
			_press_object_id = ""
		elif _dragging:
			var base_point := pointer + _grab_offset
			_workspace.set_drag_position(_drag_object_id, base_point)
			_update_drop_preview(pointer, base_point)
		elif pointer.distance_to(_press_position) > DRAG_THRESHOLD_PX:
			_begin_drag(pointer)
	_update_hover(pointer)


# ---------------------------------------------------------------- pointer handling

func _pointer_position() -> Vector2:
	# Position in laboratory pixels: the workspace is scaled to fit the stage, so the local
	# (not the global) mouse position is the one that matches object coordinates.
	return _workspace.get_local_mouse_position()


## True when the pointer is NOT over the visible stage, or is over a panel. Only the stage
## responds to the pointer: anything outside it (margins, header, status bar, objects hidden
## behind a panel) must never be picked, dragged or dropped on. The panels live in screen
## coordinates while `pointer` is in laboratory pixels (the stage is scaled to fit), so the
## screen position is used here.
func _is_over_interface() -> bool:
	var screen_point := _workspace.get_viewport().get_mouse_position()
	if not _workspace.is_screen_point_on_stage(screen_point):
		return true
	for rect in _interface.get_blocking_rects():
		if (rect as Rect2).has_point(screen_point):
			return true
	return false


func _on_press(pointer: Vector2) -> void:
	if _armed_action != &"":
		_complete_armed_action(pointer)
		return
	var hit := _workspace.object_id_at(pointer)
	_select(hit)
	if hit != "":
		_press_object_id = hit
		_press_position = pointer


func _update_hover(pointer: Vector2) -> void:
	var hit := ""
	if not _dragging and not _is_over_interface():
		hit = _workspace.object_id_at(pointer)
	if hit != _hovered_id:
		_hovered_id = hit
		_workspace.set_hovered(hit)
	var cursor := Input.CURSOR_ARROW
	if _dragging:
		cursor = Input.CURSOR_DRAG
	elif _armed_action != &"":
		cursor = Input.CURSOR_CROSS
	elif hit != "":
		cursor = Input.CURSOR_POINTING_HAND
	Input.set_default_cursor_shape(cursor)


## Forgets every transient interaction (press, drag, hover, armed action, selection).
func clear_selection() -> void:
	_cancel_armed_action()
	_press_object_id = ""
	_press_position = Vector2.ZERO
	var dragged_id := _drag_object_id
	_dragging = false
	_drag_object_id = ""
	if not dragged_id.is_empty():
		_workspace.end_drag(dragged_id)
	_host.simulation.release_held()
	_hovered_id = ""
	_workspace.set_hovered("")
	_select("")


## The whole lab was swapped for another one (Reset, Open experiment). Object ids are reused by
## unrelated objects afterwards, so nothing remembered by id (selection, chosen amounts) may survive,
## and the reference samples, which are not part of the saved state, are cleared with it.
func on_lab_replaced() -> void:
	clear_selection()
	_amounts.clear()
	_workspace.clear_reference_samples()


## The state was replaced (Undo, Redo, Reset, Open). Re-check everything remembered by object id: a
## stale id points at nothing (a later drop would dereference null) or, after a replacement, at an
## unrelated object that happens to reuse the id.
func _on_state_restored() -> void:
	var state := _host.simulation.state
	if _press_object_id != "" and state.get_object(_press_object_id) == null:
		_press_object_id = ""
	if _dragging and state.get_object(_drag_object_id) == null:
		var dragged_id := _drag_object_id
		_dragging = false
		_drag_object_id = ""
		_press_object_id = ""
		_workspace.end_drag(dragged_id)
	if _hovered_id != "" and state.get_object(_hovered_id) == null:
		_hovered_id = ""
		_workspace.set_hovered("")
	if _selected_id != "" and state.get_object(_selected_id) == null:
		_select("")
	if _selected_id == "":
		_cancel_armed_action()
	for key in _amounts.keys():
		if state.get_object(str(key).get_slice(":", 0)) == null:
			_amounts.erase(key)


## Debug builds only (F9): prints everything that decides what a click under the pointer would do.
func _print_pointer_diagnostic() -> void:
	var screen_point := _workspace.get_viewport().get_mouse_position()
	var report := _workspace.describe_pick(screen_point)
	var viewport := _workspace.get_viewport()
	var hovered: Variant = null
	if viewport.has_method("gui_get_hovered_control"):
		hovered = viewport.call("gui_get_hovered_control")
	report["gui_control_under_pointer"] = "(unavailable)" if not viewport.has_method("gui_get_hovered_control") \
		else ("(none)" if hovered == null else str((hovered as Node).get_path()))
	report["over_interface"] = _is_over_interface()
	report["selected"] = _selected_id
	report["dragging"] = _drag_object_id if _dragging else ""
	print("[pointer diagnostic] ", JSON.stringify(report, "  "))
	_say("Pointer diagnostic written to the Output log.", &"info")


func _select(object_id: String) -> void:
	if object_id == _selected_id:
		return
	_selected_id = object_id
	EventBus.object_selected.emit(object_id)


# ---------------------------------------------------------------- drag and drop

func _begin_drag(pointer: Vector2) -> void:
	var context := _make_context(&"pick_up", _press_object_id, "", {})
	var result := _host.submit(PickUpCommand.new().with_context(context))
	if not result.is_success:
		_say(result.message, &"warning")
		_press_object_id = ""
		return
	_dragging = true
	_drag_object_id = _press_object_id
	_grab_offset = _workspace.get_view_position(_drag_object_id) - pointer
	_workspace.begin_drag(_drag_object_id)
	_update_drop_preview(pointer, pointer + _grab_offset)


func _finish_drag(pointer: Vector2) -> void:
	var dragged_id := _drag_object_id
	_dragging = false
	_drag_object_id = ""
	_workspace.end_drag(dragged_id)
	if _is_over_interface():
		_host.simulation.release_held()
		_say("Drop objects on the workbench.", &"warning")
		return
	var plan := _plan_drop(dragged_id, pointer, pointer + _grab_offset)
	if plan["command"] == null:
		_host.simulation.release_held()
		_say(str(plan["reason"]), &"warning")
		return
	var result := _host.submit(plan["command"])
	if not result.is_success:
		_host.simulation.release_held()
		_say(result.message, &"warning")
		return
	if not result.message.is_empty():
		_say(result.message, &"info")
	_play_feedback(dragged_id, plan)


## Updates the visual target preview without executing or changing the simulation.
func _update_drop_preview(pointer: Vector2, base_point: Vector2) -> void:
	if _is_over_interface():
		_workspace.set_drop_preview("", false)
		return
	var target_id := _workspace.support_target_at(_drag_object_id, base_point)
	if target_id == "":
		target_id = _workspace.object_id_at(pointer, _drag_object_id)
	var plan: Dictionary = _plan_drop(_drag_object_id, pointer, base_point)
	var valid := false
	var command: LabCommand = plan.get("command") as LabCommand
	if command != null:
		var validation: InteractionResult = command.validate(_host.simulation)
		valid = validation.is_success
	var surface_id := ""
	if target_id == "":
		var resolved: Dictionary = _host.simulation.database.layout.resolve_surface(base_point)
		surface_id = str(resolved.get("surface_id", ""))
	_workspace.set_drop_preview(target_id, valid, surface_id)


## Decides what dropping an object here means. Returns {"command": LabCommand or null,
## "reason": String, "target": String, "kind": String}.
func _plan_drop(source_id: String, pointer: Vector2, base_point: Vector2) -> Dictionary:
	var pointer_data := _pointer_data(pointer)

	var support_id := _workspace.support_target_at(source_id, base_point)
	if support_id != "":
		var support_context := _make_context(&"place", source_id, support_id, {"mode": PlaceCommand.MODE_SUPPORT}, pointer_data)
		return {"command": PlaceCommand.new().with_context(support_context), "reason": "", "target": support_id, "kind": "place"}

	var target_id := _workspace.object_id_at(pointer, source_id)
	if target_id != "":
		return _plan_drop_on_object(source_id, target_id, pointer_data)

	var surface_context := _make_context(&"place", source_id, "",
		{"mode": PlaceCommand.MODE_SURFACE, "position": base_point}, pointer_data)
	return {"command": PlaceCommand.new().with_context(surface_context), "reason": "", "target": "", "kind": "place"}


func _plan_drop_on_object(source_id: String, target_id: String, pointer_data: Dictionary) -> Dictionary:
	var sim := _host.simulation
	var source := sim.state.get_object(source_id)
	var target := sim.state.get_object(target_id)
	var source_equipment := sim.database.get_equipment(source.equipment_id)
	var target_equipment := sim.database.get_equipment(target.equipment_id)
	if not target_equipment.is_vessel():
		return _no_plan("The %s cannot be used on the %s." % [source_equipment.display_name, target_equipment.display_name])
	if bool(source_equipment.placement.get("insert_into_vessel", false)):
		var insert_context := _make_context(&"insert", source_id, target_id, {"mode": PlaceCommand.MODE_INSERT}, pointer_data)
		return {"command": PlaceCommand.new().with_context(insert_context), "reason": "", "target": target_id, "kind": "place"}
	if source.vessel == null:
		return _no_plan("The %s cannot be used on the %s." % [source_equipment.display_name, target_equipment.display_name])
	return _plan_transfer(source_id, target_id, pointer_data)


## Liquid is poured when the source holds liquid; otherwise solid is added.
func _plan_transfer(source_id: String, target_id: String, pointer_data: Dictionary) -> Dictionary:
	var sim := _host.simulation
	var source := sim.state.get_object(source_id)
	if source.vessel.has_liquid():
		var amount := _amount_for(source_id, "mL")
		var context := _make_context(&"pour", source_id, target_id, {"amount_ml": amount}, pointer_data)
		return {"command": PourCommand.new().with_context(context), "reason": "", "target": target_id, "kind": "liquid"}
	if source.vessel.has_solids():
		var amount := _amount_for(source_id, "g")
		var context := _make_context(&"add_solid", source_id, target_id, {"amount_g": amount}, pointer_data)
		return {"command": AddSolidCommand.new().with_context(context), "reason": "", "target": target_id, "kind": "solid"}
	return _no_plan("The %s is empty, so there is nothing to pour." % sim.object_label(source))


func _no_plan(reason: String) -> Dictionary:
	return {"command": null, "reason": reason, "target": "", "kind": ""}


## Shows the visual response to a command that was accepted.
func _play_feedback(source_id: String, plan: Dictionary) -> void:
	if plan["kind"] == "liquid" or plan["kind"] == "solid":
		_workspace.play_pour(source_id, str(plan["target"]), str(plan["kind"]))
	_select(str(plan["target"]) if str(plan["target"]) != "" and plan["kind"] != "place" else source_id)


# ---------------------------------------------------------------- library drag/drop

func on_library_item_dropped(payload: Dictionary, screen_position: Vector2) -> void:
	if _host == null or _host.simulation == null or payload.is_empty():
		return
	var kind := str(payload.get("kind", ""))
	var item_id := str(payload.get("id", ""))
	var world_position := _workspace.screen_to_workspace(screen_position)
	if kind == "equipment":
		_spawn_library_equipment(item_id, world_position, {})
	elif kind == "reagent":
		_add_or_spawn_reagent(item_id, world_position)


func _spawn_library_equipment(equipment_id: String, world_position: Vector2, contents: Dictionary) -> void:
	var equipment := _host.database.get_equipment(equipment_id)
	if equipment == null:
		_say("That equipment is not available in the classroom Library.", &"warning")
		return
	var height := float(equipment.visual.get("height", 100.0))
	var base_point := world_position + Vector2(0.0, height * 0.45)
	var command := SpawnObjectCommand.new()
	command.context = _make_context(&"spawn", "", "", {
		"equipment_id": equipment_id, "position": base_point, "contents": contents
	}, _pointer_data(world_position))
	var result := _host.submit(command)
	if not result.is_success:
		_say(result.message, &"warning")
		return
	_select(command.created_object_id)
	_say(result.message, &"info")


func _add_or_spawn_reagent(chemical_id: String, world_position: Vector2) -> void:
	var chemical := _host.database.get_chemical(chemical_id)
	if chemical == null or chemical_id not in ["water", "sodium_chloride", "carbon_dioxide"]:
		_say("Only approved virtual classroom materials can be added from this Library.", &"warning")
		return
	var target_id := _workspace.object_id_at(world_position)
	if chemical.state == "gas":
		var gas_target := _host.simulation.state.get_object(target_id)
		if gas_target == null or gas_target.vessel == null:
			_say("Drop the virtual gas card directly onto a beaker, flask or test tube.", &"warning")
			return
		var gas_command := AddGasCommand.new()
		gas_command.context = _make_context(&"add_gas", target_id, "", {
			"chemical_id": chemical_id, "amount_mol": 0.002
		}, _pointer_data(world_position))
		var gas_result := _host.submit(gas_command)
		if not gas_result.is_success:
			_say(gas_result.message, &"warning")
			return
		_select(target_id)
		_say(gas_result.message, &"info")
		return
	if target_id != "":
		var target := _host.simulation.state.get_object(target_id)
		if target != null and target.vessel != null:
			var amount := 50.0 if chemical.state == "liquid" else 5.0
			var command := AddReagentCommand.new()
			command.context = _make_context(&"add_reagent", target_id, "", {
				"chemical_id": chemical_id, "amount": amount
			}, _pointer_data(world_position))
			var result := _host.submit(command)
			if not result.is_success:
				_say(result.message, &"warning")
				return
			_select(target_id)
			_say(result.message, &"info")
			return
	var contents: Dictionary = {"liquids": {}, "solids": {}}
	if chemical.state == "liquid":
		contents["liquids"][chemical_id] = 400.0
	else:
		contents["solids"][chemical_id] = 80.0
	_spawn_library_equipment("reagent_bottle_500ml", world_position, contents)


# ---------------------------------------------------------------- inspector actions

func _on_action_requested(action_id: StringName, payload: Dictionary) -> void:
	match action_id:
		&"pour":
			_arm_pour()
		&"mix":
			_run_simple(&"mix", MixCommand.new(), {})
		&"heat":
			_run_simple(&"heat", HeatCommand.new(), {"power": "toggle"})
		&"set_heater":
			_run_simple(&"heat", HeatCommand.new(), payload)
		&"vent_system":
			_run_simple(&"vent_system", VentSystemCommand.new(), {})
		&"run_demo":
			_run_simple(&"run_virtual_demo", RunVirtualDemoCommand.new(), {})
		&"amount_changed":
			_amounts["%s:%s" % [_selected_id, str(payload.get("unit", "mL"))]] = float(payload.get("value", 0.0))


func _run_simple(interaction: StringName, command: LabCommand, payload: Dictionary) -> void:
	if _selected_id == "":
		_say("Select an object first.", &"warning")
		return
	var context := _make_context(interaction, _selected_id, "", payload)
	var result := _host.submit(command.with_context(context))
	_say(result.message, &"info" if result.is_success else &"warning")


func _arm_pour() -> void:
	if _selected_id == "":
		_say("Select a vessel first.", &"warning")
		return
	_armed_action = &"pour"
	_say("Click the vessel you want to pour into. Press Esc to cancel.", &"info")


func _cancel_armed_action() -> void:
	_armed_action = &""


func _complete_armed_action(pointer: Vector2) -> void:
	var source_id := _selected_id
	_armed_action = &""
	var target_id := _workspace.object_id_at(pointer, source_id)
	if target_id == "":
		_say("Pouring cancelled: click a vessel to pour into.", &"warning")
		return
	var plan := _plan_drop_on_object(source_id, target_id, _pointer_data(pointer))
	if plan["command"] == null:
		_say(str(plan["reason"]), &"warning")
		return
	var result := _host.submit(plan["command"])
	if not result.is_success:
		_say(result.message, &"warning")
		return
	if not result.message.is_empty():
		_say(result.message, &"info")
	_workspace.play_pour(source_id, target_id, str(plan["kind"]))


func _amount_for(object_id: String, unit: String) -> float:
	var key := "%s:%s" % [object_id, unit]
	if _amounts.has(key):
		return float(_amounts[key])
	var equipment := _host.simulation.database.get_equipment(_host.simulation.state.get_object(object_id).equipment_id)
	return equipment.default_solid_g if unit == "g" else equipment.default_pour_ml


# ---------------------------------------------------------------- toolbar actions

func _on_undo_requested() -> void:
	var result := _host.undo()
	_say(result.message, &"info" if result.is_success else &"warning")


func _on_redo_requested() -> void:
	var result := _host.redo()
	_say(result.message, &"info" if result.is_success else &"warning")


func _on_reset_requested() -> void:
	_host.reset()
	on_lab_replaced()
	_say("The bench was reset.", &"info")


func _on_pause_toggled(paused: bool) -> void:
	_host.clock.paused = paused


func _on_speed_selected(speed: float) -> void:
	_host.clock.set_speed(speed)
	_say("Simulation speed: %s" % UnitFormat.speed(_host.clock.speed), &"info")


func _step_speed(direction: int) -> void:
	var presets: Array = _host.database.constants.get("speeds", [SimulationClock.NORMAL_SPEED])
	_host.clock.step_speed(direction, presets)
	_say("Simulation speed: %s" % UnitFormat.speed(_host.clock.speed), &"info")


# ---------------------------------------------------------------- helpers

func _make_context(interaction: StringName, source_id: String, target_id: String,
		payload: Dictionary, pointer_data: Dictionary = {}) -> InteractionContext:
	if not _registry.has_definition(interaction):
		push_error("InteractionController: interaction '%s' is not defined in the data." % interaction)
	var pointer_info := pointer_data if not pointer_data.is_empty() else _pointer_data(_pointer_position())
	return InteractionContext.create(interaction, source_id, target_id, pointer_info, payload,
		_host.simulation.state.time_s)


func _pointer_data(pointer: Vector2) -> Dictionary:
	return {"position": pointer, "device": DEVICE_MOUSE, "button": MOUSE_BUTTON_LEFT}


func _say(message: String, severity: StringName) -> void:
	if not message.is_empty():
		EventBus.feedback_message_requested.emit(message, severity)
