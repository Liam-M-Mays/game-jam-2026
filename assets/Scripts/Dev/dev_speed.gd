extends Node
## DEV TOOL: hold X to run the game at 3x speed.
## Self-contained autoload; to remove, delete this file and the DevSpeed line
## under [autoload] in project.godot.

const FAST := 3.0
const KEY := KEY_X

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event : InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode == KEY and not event.echo:
		Engine.time_scale = FAST if event.pressed else 1.0

func _notification(what : int) -> void:
	# Releasing the key while the window is unfocused never reaches _input.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Engine.time_scale = 1.0
