extends Node
## Builds the InputMap from data (autoload: InputManager).
## No controls are hardcoded in gameplay scripts; rebinding and new devices
## only require changing data/input/default_bindings.json (or its future user override).

const BINDINGS_PATH := "res://data/input/default_bindings.json"


func _ready() -> void:
	_register_bindings(JsonDataLoader.load_dictionary(BINDINGS_PATH))


## Human-readable label of the preferred binding for an action (keyboard first).
func get_action_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	var events := InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey:
			return event.as_text_physical_keycode()
	if events.is_empty():
		return ""
	return events[0].as_text()


func _register_bindings(data: Dictionary) -> void:
	var actions: Dictionary = data.get("actions", {})
	for action_name in actions.keys():
		var action_data: Dictionary = actions[action_name]
		if InputMap.has_action(action_name):
			InputMap.erase_action(action_name)
		InputMap.add_action(action_name, float(action_data.get("deadzone", 0.5)))
		for event_data in action_data.get("events", []):
			var event := _create_event(event_data)
			if event != null:
				InputMap.action_add_event(action_name, event)


func _create_event(event_data: Dictionary) -> InputEvent:
	var event_type := str(event_data.get("type", ""))
	match event_type:
		"key":
			var keycode: Key = OS.find_keycode_from_string(str(event_data.get("key", "")))
			if keycode == KEY_NONE:
				push_error("InputManager: unknown key in binding: %s" % str(event_data))
				return null
			var key_event := InputEventKey.new()
			key_event.physical_keycode = keycode
			key_event.ctrl_pressed = bool(event_data.get("ctrl", false))
			key_event.shift_pressed = bool(event_data.get("shift", false))
			key_event.alt_pressed = bool(event_data.get("alt", false))
			return key_event
		"mouse_button":
			var mouse_event := InputEventMouseButton.new()
			mouse_event.button_index = int(event_data.get("button", 1)) as MouseButton
			return mouse_event
		"joypad_button":
			var button_event := InputEventJoypadButton.new()
			button_event.button_index = int(event_data.get("button", 0)) as JoyButton
			return button_event
		"joypad_axis":
			var axis_event := InputEventJoypadMotion.new()
			axis_event.axis = int(event_data.get("axis", 0)) as JoyAxis
			axis_event.axis_value = float(event_data.get("value", 1.0))
			return axis_event
	push_error("InputManager: unknown binding type '%s'" % event_type)
	return null
