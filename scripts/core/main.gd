extends Node
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


func _ready() -> void:
	get_window().min_size = MIN_WINDOW_SIZE
	get_window().size_changed.connect(_update_content_scale)
	_update_content_scale()
	var content := ContentDatabase.new()
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
	_controller = InteractionController.new()
	_controller.name = "InteractionController"
	add_child(_controller)
	_controller.setup(_host, workspace, lab_interface)


## The laboratory is scaled and centred inside the stage slot between the side panels. Done
## here, once the layout has settled, because container sizes are only known after a frame.
func _process(_delta: float) -> void:
	if _host == null or lab_interface == null:
		return
	var rect := lab_interface.get_stage_rect()
	if not rect.is_equal_approx(_last_stage_rect):
		_last_stage_rect = rect
		workspace.fit_to_rect(rect)


func _update_content_scale() -> void:
	var window := get_window()
	var stretch := minf(float(window.size.x) / DESIGN_SIZE.x, float(window.size.y) / DESIGN_SIZE.y)
	window.content_scale_factor = maxf(1.0, MIN_UI_SCALE / maxf(stretch, 0.01))
