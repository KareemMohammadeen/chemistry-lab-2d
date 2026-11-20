extends Node

const WELCOME_OVERLAY_SCRIPT := preload("res://scripts/ui/welcome_overlay.gd")
const LAB_AUDIO_SCRIPT := preload("res://scripts/core/lab_audio.gd")
const LAB_REPORT_SCRIPT := preload("res://scripts/core/lab_report.gd")
## Composition root. Builds the content database, the simulation host and the interaction
## controller and hands them to the views. It contains no laboratory logic of its own.

## Smallest window that still shows the whole laboratory legibly.
const MIN_WINDOW_SIZE := Vector2i(960, 540)
const SETUP_PATH := "res://data/setups/classroom_demo.json"
## Window size the interface is designed at (project stretch base) and the smallest effective
## scale text may shrink to: below it the interface is enlarged so fonts stay readable.
const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const MIN_UI_SCALE := 0.75

@export var workspace: LabWorkspace
@export var lab_interface: LabInterface

var _host: SimulationHost
var _controller: InteractionController
var _last_stage_rect: Rect2 = Rect2()
var _welcome_overlay: WelcomeOverlay
var _audio: LabAudio


func _ready() -> void:
	get_window().min_size = MIN_WINDOW_SIZE
	get_window().size_changed.connect(_update_content_scale)
	_update_content_scale()
	var content := ContentDatabasePlus.new()
	content.load_all()
	for message in content.errors:
		push_error("Content: %s" % message)
	_host = SimulationHost.new()
	_host.name = "SimulationHost"
	add_child(_host)
	if not _host.initialise(content, SETUP_PATH):
		push_error("Main: the laboratory setup '%s' could not be loaded." % SETUP_PATH)
		return
	workspace.bind(_host)
	lab_interface.bind(_host)
	if workspace.get_parent() != lab_interface.stage_slot:
		var parent := workspace.get_parent()
		if parent != null:
			parent.remove_child(workspace)
		lab_interface.stage_slot.add_child(workspace)
	lab_interface.save_session_requested.connect(_on_save_session_requested)
	lab_interface.load_session_requested.connect(_on_load_session_requested)
	_audio = LAB_AUDIO_SCRIPT.new() as LabAudio
	_audio.name = "LabAudio"
	add_child(_audio)
	_audio.bind()
	lab_interface.sound_enabled_changed.connect(_audio.set_enabled)
	_controller = InteractionController.new()
	_controller.name = "InteractionController"
	add_child(_controller)
	_controller.setup(_host, workspace, lab_interface)
	lab_interface.library_item_dropped.connect(_controller.on_library_item_dropped)
	lab_interface.periodic_sample_dropped.connect(workspace.add_reference_sample)
	lab_interface.canvas_zoom_requested.connect(workspace.zoom_by)
	lab_interface.canvas_reset_requested.connect(workspace.reset_view)
	workspace.view_changed.connect(lab_interface.update_zoom_label)
	_show_welcome_overlay()


func _show_welcome_overlay() -> void:
	_welcome_overlay = WELCOME_OVERLAY_SCRIPT.new() as WelcomeOverlay
	_welcome_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_welcome_overlay.mode_selected.connect(_on_welcome_mode_selected)
	lab_interface.add_child(_welcome_overlay)


func _on_welcome_mode_selected(mode: String) -> void:
	if is_instance_valid(_welcome_overlay):
		_welcome_overlay.queue_free()
	_welcome_overlay = null
	if mode == "teacher":
		lab_interface.open_teacher_mode()


## The laboratory is scaled and centred inside the stage slot between the side panels. Done
## here, once the layout has settled, because container sizes are only known after a frame.
func _process(_delta: float) -> void:
	if _host == null or lab_interface == null:
		return
	var rect := lab_interface.get_stage_rect()
	var local_rect := Rect2(Vector2.ZERO, rect.size)
	if not local_rect.is_equal_approx(_last_stage_rect):
		if _last_stage_rect.size.x <= 0.0:
			workspace.fit_to_rect(local_rect)
		else:
			workspace.update_stage_rect(local_rect)
		_last_stage_rect = local_rect


func _on_save_session_requested(path: String) -> void:
	if _host == null or _host.simulation == null:
		lab_interface.show_message("The laboratory is not ready to save.", &"warning")
		return
	var result := LabSessionStore.save_to_path(_host.simulation, _host.commands, path)
	if not bool(result.get("ok", false)):
		lab_interface.show_message(str(result.get("message", "Save failed.")), &"warning")
		return
	var report_result := LAB_REPORT_SCRIPT.save_to_path(_host.simulation, _host.commands, path)
	if bool(report_result.get("ok", false)):
		lab_interface.show_message("%s %s" % [
			str(result.get("message", "Session saved.")),
			str(report_result.get("message", "Lab report exported.")),
		], &"info")
	else:
		lab_interface.show_message("%s Report export failed: %s" % [
			str(result.get("message", "Session saved.")),
			str(report_result.get("message", "Could not write the report.")),
		], &"warning")


func _on_load_session_requested(path: String) -> void:
	if _host == null or _host.simulation == null:
		lab_interface.show_message("The laboratory is not ready to open a session.", &"warning")
		return
	var result := LabSessionStore.load_from_path(
		_host.simulation, _host.commands, _host.database, path)
	if bool(result.get("ok", false)) and _controller != null:
		_controller.clear_selection()
	lab_interface.show_message(str(result.get("message", "Open failed.")),
		&"info" if bool(result.get("ok", false)) else &"warning")


func _update_content_scale() -> void:
	var window := get_window()
	var stretch := minf(float(window.size.x) / DESIGN_SIZE.x, float(window.size.y) / DESIGN_SIZE.y)
	window.content_scale_factor = maxf(1.0, MIN_UI_SCALE / maxf(stretch, 0.01))
