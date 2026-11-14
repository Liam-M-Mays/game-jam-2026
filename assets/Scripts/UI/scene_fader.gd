extends CanvasLayer
## Autoload `SceneFader`. Fades the screen to black, swaps the scene, then fades back in.
## Use it instead of get_tree().change_scene_*() so every screen change gets the same fade.

const FADE_SECONDS := 0.35
## Above the HUD and menus, below the brightness overlay (layer 128).
const LAYER := 120

var _rect := ColorRect.new()
var _busy := false


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect.color = Color.BLACK
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	# The game opens with a fade in too.
	_fade(0.0)


## Pass a scene path, a PackedScene, or nothing to reload the current scene.
## The tree stays paused through the fade out and is unpaused when the new scene loads.
func change_scene(target: Variant = null) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade(1.0)
	get_tree().paused = false
	if target is PackedScene:
		get_tree().change_scene_to_packed(target)
	elif target is String:
		get_tree().change_scene_to_file(target)
	else:
		get_tree().reload_current_scene()
	# The swap happens at the end of the frame; give the new scene a frame to draw before revealing it.
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade(0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func is_busy() -> bool:
	return _busy


func _fade(to: float) -> Signal:
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(_rect, "color:a", to, FADE_SECONDS)
	return tween.finished
