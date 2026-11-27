extends Node
## Visual/behaviour probe for the real main scene. Needs a display (e.g. xvfb-run), not --headless:
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 res://tests/ui_probe.tscn -- <outdir>
## It boots scenes/main.tscn, resizes the window to common desktop sizes, checks the top bar fits,
## drops beakers on the stage, sends clicks that must be ignored, and writes screenshots.

const SIZES: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1366, 768),
		Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]

var _out_dir := "/tmp/probe"
var _failures := 0
var _main: Node
var _selected_events: Array = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	EventBus.object_selected.connect(func(id: String) -> void: _selected_events.append(id))
	await _frames(8)
	_main.call("_on_welcome_mode_selected", "student")
	await _frames(4)
	await _run()
	print("PROBE DONE failures=%d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func _check(ok: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out_dir, name])


func _run() -> void:
	var iface := _main.get("lab_interface") as LabInterface
	var workspace := _main.get("workspace") as LabWorkspace
	var controller: InteractionController = _main.get("_controller")
	var host: SimulationHost = _main.get("_host")
	var window := get_window()
	window.mode = Window.MODE_WINDOWED
	for size in SIZES:
		window.size = size
		await _frames(6)
		var viewport_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
		var bar := iface.top_bar.get_global_rect()
		_check(bar.end.x <= viewport_rect.end.x + 0.5 and bar.position.x >= -0.5,
			"%s: top bar inside the window (bar right %.0f of %.0f)" % [size, bar.end.x, viewport_rect.end.x])
		var row := iface.reset_button.get_parent() as Control
		_check(row.get_combined_minimum_size().x <= row.size.x + 0.5,
			"%s: top bar row fits its minimum width (%.0f <= %.0f)" % [size, row.get_combined_minimum_size().x, row.size.x])
		var speeds_ok := true
		var texts: Array = []
		for button in iface.speed_box.get_children():
			texts.append((button as Button).text)
			var rect := (button as Control).get_global_rect()
			if rect.end.x > viewport_rect.end.x + 0.5:
				speeds_ok = false
		_check(speeds_ok and iface.speed_box.get_child_count() == 6, "%s: six speed buttons all on screen" % size)
		_check(texts == ["0.25x", "0.5x", "1x", "2x", "4x", "8x"], "%s: speed labels read %s" % [size, texts])
		_check(not iface.get("_log_window").visible, "%s: experiment log window is not open at startup" % size)
		var stage := iface.get_stage_rect()
		_check(stage.size.x > 300.0 and stage.size.y > 200.0 and viewport_rect.encloses(stage),
			"%s: stage rect %s is inside the window" % [size, stage])
		await _shot("layout_%dx%d" % [size.x, size.y])

	window.size = Vector2i(1600, 900)
	await _frames(6)
	await _test_placement(iface, workspace, controller, host)
	await _test_input_gating(iface, workspace, controller, host)
	await _test_offstage_sweep(iface, workspace, host)
	await _test_state_replacement(iface, workspace, controller, host)


func _test_placement(iface: LabInterface, workspace: LabWorkspace, controller: InteractionController, host: SimulationHost) -> void:
	var stage := iface.get_stage_rect()
	var spots := {
		"centre": stage.get_center(),
		"top_left": stage.position + Vector2(120.0, 120.0),
		"bottom_right": stage.end - Vector2(140.0, 140.0),
	}
	for label in spots.keys():
		var screen_point: Vector2 = spots[label]
		var before := host.simulation.state.objects.size()
		controller.on_library_item_dropped({"kind": "equipment", "id": "beaker_250ml"}, screen_point)
		await _frames(3)
		_check(host.simulation.state.objects.size() == before + 1, "beaker dropped at %s is created" % label)
		var created: LabObject = host.simulation.state.objects.values()[host.simulation.state.objects.size() - 1]
		var view := workspace.get_node("Views").get_children().back() as EquipmentView
		var global_pos := view.get_global_transform_with_canvas() * Vector2.ZERO
		var expected := screen_point + Vector2(0.0, 100.0 * 0.45 * workspace.scale.x)
		_check(global_pos.distance_to(expected) < 25.0 * maxf(workspace.scale.x, 1.0),
			"%s: beaker base on screen %s is where it was dropped %s" % [label, global_pos, screen_point])
		_check(stage.has_point(global_pos), "%s: beaker lies inside the visible stage" % label)
		_check(view.z_index > 0, "%s: beaker z_index %d is above the backdrop" % [label, view.z_index])
		_check(created != null, "%s: object exists in the simulation" % label)
	# far away: pan and drop
	workspace.pan_by_screen(Vector2(-4000.0, 3000.0))
	await _frames(3)
	var far_point := stage.get_center()
	controller.on_library_item_dropped({"kind": "equipment", "id": "beaker_250ml"}, far_point)
	await _frames(3)
	var far_view := workspace.get_node("Views").get_children().back() as EquipmentView
	_check(far_view.z_index > 0 and far_view.z_index < 2000, "far-away beaker keeps a valid z_index (%d)" % far_view.z_index)
	_check(stage.has_point(far_view.get_global_transform_with_canvas() * Vector2.ZERO),
		"far-away beaker is visible on the stage after panning")
	await _shot("placement_far")
	workspace.reset_view()
	await _frames(4)
	await _shot("placement_after_reset")


## Moves the real pointer (the viewport's mouse position follows the OS cursor, not pushed events).
## `position` is in canvas (UI) coordinates; warp_mouse wants window pixels.
func _move(position: Vector2) -> void:
	Input.warp_mouse(get_viewport().get_final_transform() * position)
	await _frames(3)


func _click(position: Vector2, pressed: bool) -> void:
	await _move(position)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = get_viewport().get_final_transform() * get_viewport().get_mouse_position()
	event.global_position = event.position
	get_viewport().push_input(event)


func _test_input_gating(iface: LabInterface, workspace: LabWorkspace, controller: InteractionController, host: SimulationHost) -> void:
	workspace.reset_view()
	await _frames(4)
	var stage := iface.get_stage_rect()
	# an object placed so that, on screen, it sits under the stage header / above the stage
	var transform := workspace.get_global_transform_with_canvas()
	var outside_screen := Vector2(stage.get_center().x, stage.position.y - 30.0)
	var inside_world := workspace.screen_to_workspace(outside_screen)
	var spawn := SpawnObjectCommand.new()
	spawn.context = InteractionContext.create(&"spawn", "", "", {"device": "test"}, {
		"equipment_id": "beaker_250ml", "position": inside_world + Vector2(0.0, 40.0), "contents": {}}, host.simulation.state.time_s)
	host.submit(spawn)
	await _frames(3)
	_check(workspace.object_id_at(inside_world) == "", "an object under the header is not hit-testable")
	var ghost_id := spawn.created_object_id
	var probes := {
		"stage header": outside_screen,
		"status bar": Vector2(stage.get_center().x, get_viewport().get_visible_rect().size.y - 10.0),
		"left of stage": Vector2(stage.position.x - 6.0, stage.get_center().y),
	}
	for label in probes.keys():
		_selected_events.clear()
		var point: Vector2 = probes[label]
		await _click(point, true)
		await _frames(2)
		await _click(point + Vector2(60.0, 0.0), true)
		await _frames(2)
		await _move(point + Vector2(120.0, 40.0))
		await _click(point + Vector2(120.0, 40.0), false)
		await _frames(2)
		_check(not _selected_events.has(ghost_id), "click/drag over %s does not select or drag the hidden object" % label)
		var item := host.simulation.state.get_object(ghost_id)
		_check(item.position.distance_to(inside_world + Vector2(0.0, 40.0)) < 0.01, "object did not move after interacting over %s" % label)
	# a real click on a visible object in the stage still works
	workspace.reset_view()
	await _frames(4)
	transform = workspace.get_global_transform_with_canvas()
	var visible_obj: LabObject = host.simulation.state.objects.values()[0]
	var screen_of_obj := transform * (visible_obj.position + Vector2(0.0, -40.0))
	_selected_events.clear()
	if stage.has_point(screen_of_obj):
		await _click(screen_of_obj, true)
		await _frames(2)
		await _click(screen_of_obj, false)
		await _frames(2)
		_check(_selected_events.has(visible_obj.id), "clicking a visible object on the stage still selects it")
	await _shot("input_gating")


## Property test: whatever is on the bench, a point outside the visible stage must never pick anything.
func _test_offstage_sweep(iface: LabInterface, workspace: LabWorkspace, host: SimulationHost) -> void:
	host.reset()
	workspace.reset_view()
	await _frames(4)
	var stage := iface.get_stage_rect()
	var window_size := get_viewport().get_visible_rect().size
	# Cover the whole window (and beyond) with objects so every screen point has something under it.
	var step := 70.0
	var y := -200.0
	while y < window_size.y + 200.0:
		var x := -200.0
		while x < window_size.x + 200.0:
			host.simulation.spawn_object("beaker_250ml", workspace.screen_to_workspace(Vector2(x, y)))
			x += step
		y += step
	await _frames(4)
	_check(workspace.audit_views().is_empty(), "view registry matches the simulation after a mass spawn: %s" % str(workspace.audit_views()))
	var leaks := 0
	var on_stage_hits := 0
	var probe_step := 23.0
	var py := 0.0
	while py < window_size.y:
		var px := 0.0
		while px < window_size.x:
			var point := Vector2(px, py)
			var picked := workspace.object_id_at(workspace.screen_to_workspace(point))
			if stage.has_point(point):
				if picked != "":
					on_stage_hits += 1
			elif picked != "":
				leaks += 1
			px += probe_step
		py += probe_step
	_check(leaks == 0, "no screen point outside the stage picks an object (%d leaks)" % leaks)
	_check(on_stage_hits > 0, "points on the stage still pick objects (%d hits)" % on_stage_hits)
	host.reset()
	await _frames(4)


func _test_state_replacement(iface: LabInterface, workspace: LabWorkspace, controller: InteractionController, host: SimulationHost) -> void:
	host.reset()
	workspace.reset_view()
	await _frames(4)
	var stage := iface.get_stage_rect()
	var spot := workspace.screen_to_workspace(stage.get_center())
	# 1. An id reused by different equipment must get a different view (this is what Open experiment does).
	var beaker := host.simulation.spawn_object("beaker_250ml", spot)
	var reused_id := beaker.id
	await _frames(3)
	var beaker_snapshot: Dictionary = host.simulation.capture_snapshot()
	host.reset()
	var thermometer := host.simulation.spawn_object("thermometer_general", spot)
	_check(thermometer.id == reused_id, "the id %s is reused by a thermometer after reset" % reused_id)
	await _frames(3)
	host.simulation.restore_snapshot(beaker_snapshot)
	# no frame wait: the views must already follow the state
	_check(workspace.audit_views().is_empty(), "views follow the state at once after a restore: %s" % str(workspace.audit_views()))
	var views_for_id := 0
	for child in workspace.get_node("Views").get_children():
		if (child as EquipmentView).object_id == reused_id and not child.is_queued_for_deletion():
			views_for_id += 1
	_check(views_for_id == 1, "exactly one live view exists for %s (%d)" % [reused_id, views_for_id])
	var restored: LabObject = host.simulation.state.get_object(reused_id)
	_check(restored.equipment_id == "beaker_250ml", "the restored object is a beaker")
	_check(workspace.object_id_at(spot + Vector2(0.0, -40.0)) == reused_id, "the restored beaker is picked where it stands")
	await _frames(3)
	_check(workspace.audit_views().is_empty(), "views stay consistent a few frames later")

	# 2. Reset and Open must remove the reference samples, and forget chosen amounts.
	workspace.add_reference_sample({"symbol": "Fe", "name": "Iron", "atomic_number": 26}, stage.get_center())
	await _frames(2)
	_check(workspace.reference_sample_count() == 1, "a reference sample is on the bench")
	controller.call("_select", reused_id)
	controller.call("_on_action_requested", &"amount_changed", {"unit": "mL", "value": 123.0})
	_check(not (controller.get("_amounts") as Dictionary).is_empty(), "a chosen pour amount is remembered")
	iface.reset_requested.emit()
	await _frames(3)
	_check(workspace.reference_sample_count() == 0, "Reset removes the reference samples")
	_check((controller.get("_amounts") as Dictionary).is_empty(), "Reset forgets amounts chosen for the old objects")
	_check(str(controller.get("_selected_id")) == "", "Reset clears the selection")
	_check(workspace.audit_views().is_empty(), "views are consistent after Reset")

	# 3. Undo of a spawn while the spawned object is selected must not leave a stale selection.
	var spawn := SpawnObjectCommand.new()
	spawn.context = InteractionContext.create(&"spawn", "", "", {"device": "test"}, {
		"equipment_id": "beaker_250ml", "position": spot, "contents": {}}, host.simulation.state.time_s)
	host.submit(spawn)
	controller.call("_select", spawn.created_object_id)
	await _frames(2)
	host.undo()
	_check(str(controller.get("_selected_id")) == "", "Undo of the selected object's spawn clears the selection")
	_check(workspace.audit_views().is_empty(), "views are consistent after Undo")
	_selected_events.clear()
	await _shot("state_replacement")
