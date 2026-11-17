extends Node
## Autoload `InputMode`. Lets every menu work with a controller (and the arrow keys).
## - Adds the controller's A button to ui_accept and B to ui_cancel. The D-pad and left stick
##   already move between buttons in Godot by default.
## - Remembers whether the player is on the mouse or on a controller/keyboard.
## - On a controller, the topmost open menu's default button gets focus, so there is always
##   something highlighted. With the mouse, nothing keeps focus, so no highlight sticks after a click.
##
## A menu takes part by adding its default button (or itself) to the DEFAULT_FOCUS group.
## A node in the group can define default_focus_target() -> Control to choose the button itself.

signal changed(using_mouse: bool)

const DEFAULT_FOCUS := &"menu_default_focus"
## How far the stick has to move before it counts as the player picking up the controller.
const STICK_DEADZONE := 0.5
## Mouse movement shorter than this (in pixels) doesn't switch back to mouse mode.
const MOUSE_JITTER := 4.0

var using_mouse := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add_button(&"ui_accept", JOY_BUTTON_A)
	_add_button(&"ui_cancel", JOY_BUTTON_B)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_set_mouse(true)
		# A clicked button keeps focus in Godot; drop it so its highlight doesn't stay on.
		if not event.pressed:
			get_viewport().gui_release_focus.call_deferred()
	elif event is InputEventMouseMotion and event.relative.length() > MOUSE_JITTER:
		_set_mouse(true)
	elif event is InputEventJoypadButton and event.pressed:
		_set_mouse(false)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > STICK_DEADZONE:
		_set_mouse(false)
	elif event is InputEventKey and event.pressed and _is_menu_key(event):
		_set_mouse(false)


## Highlights the topmost open menu's default button, unless the player is on the mouse.
func focus_default() -> void:
	if using_mouse:
		return
	var target := _default_target()
	if target:
		target.grab_focus()


func _set_mouse(on: bool) -> void:
	if on == using_mouse:
		if not on and get_viewport().gui_get_focus_owner() == null:
			focus_default.call_deferred()
		return
	using_mouse = on
	if on:
		get_viewport().gui_release_focus()
	else:
		focus_default.call_deferred()
	changed.emit(on)


## Later in the tree is drawn on top, so the last visible menu in the group is the one in front.
func _default_target() -> Control:
	var found: Control = null
	for node in get_tree().get_nodes_in_group(DEFAULT_FOCUS):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if control.has_method(&"default_focus_target"):
			control = control.default_focus_target()
		if control and control.is_visible_in_tree():
			found = control
	return found


func _is_menu_key(event: InputEventKey) -> bool:
	for action in [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept", &"ui_focus_next"]:
		if event.is_action(action):
			return true
	return false


func _add_button(action: StringName, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)
