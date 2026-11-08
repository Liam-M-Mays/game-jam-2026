extends Camera2D
class_name CameraControls

@export var move_speed: float = 1000.0
@export var min_zoom: float = 0.3
@export var max_zoom: float = 3.0
@export var zoom_speed: float = 0.1
@export var key_zoom_speed: float = 2.0

var _panning := false

func _process(delta: float) -> void:
	var move := Vector2(
		_key_axis(KEY_A, KEY_D),
		_key_axis(KEY_W, KEY_S)
	)
	position += move.normalized() * move_speed * delta / zoom.x
	var zoom_input := _key_axis(KEY_Q, KEY_E)
	if zoom_input != 0.0:
		zoom_by(pow(key_zoom_speed, zoom_input * delta))

func _key_axis(negative: Key, positive: Key) -> float:
	return float(Input.is_physical_key_pressed(positive)) - float(Input.is_physical_key_pressed(negative))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_panning = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_to_mouse(1.0 + zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_to_mouse(1.0 / (1.0 + zoom_speed))
	elif event is InputEventMouseMotion and _panning:
		position -= event.relative / zoom
	elif event is InputEventMagnifyGesture:
		zoom_to_mouse(event.factor)
	elif event is InputEventPanGesture:
		zoom_to_mouse(pow(1.0 + zoom_speed, -event.delta.y))

func is_zoomed_out() -> bool:
	return is_equal_approx(zoom.x, min_zoom)

func zoom_by(factor: float) -> void:
	var new_zoom = clamp(zoom.x * factor, min_zoom, max_zoom)
	zoom = Vector2(new_zoom, new_zoom)

func zoom_to_mouse(factor: float) -> void:
	var mouse_pos = get_global_mouse_position()
	zoom_by(factor)
	position += mouse_pos - get_global_mouse_position()
