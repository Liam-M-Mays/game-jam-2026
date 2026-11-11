extends Node

const FAST := 3.0
const KEY := KEY_X

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event : InputEvent) -> void:
	if not OldGame.is_running(get_tree()):
		return
	if event is InputEventKey and event.physical_keycode == KEY and not event.echo:
		Engine.time_scale = FAST if event.pressed else GameState.speed

func _notification(what : int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree() and OldGame.is_running(get_tree()):
		Engine.time_scale = GameState.speed
