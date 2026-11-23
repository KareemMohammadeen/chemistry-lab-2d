class_name InputActions
extends RefCounted
## Names of input actions. Bindings live in data/input/default_bindings.json;
## scripts reference actions only through these constants.

const UNDO := &"undo"
const REDO := &"redo"
const DESELECT := &"deselect"
const TOGGLE_PAUSE := &"toggle_pause"
const SPEED_UP := &"speed_up"
const SPEED_DOWN := &"speed_down"
const SPEED_NORMAL := &"speed_normal"
const VIEW_ZOOM_IN := &"view_zoom_in"
const VIEW_ZOOM_OUT := &"view_zoom_out"
const VIEW_RESET := &"view_reset"
const VIEW_PAN_LEFT := &"view_pan_left"
const VIEW_PAN_RIGHT := &"view_pan_right"
const VIEW_PAN_UP := &"view_pan_up"
const VIEW_PAN_DOWN := &"view_pan_down"
