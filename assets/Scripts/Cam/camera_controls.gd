extends Camera2D

@export var pan_speed: float = 1.0
@export var min_zoom: float = 0.5
@export var max_zoom: float = 3.0
@export var zoom_speed: float = 0.1

var is_panning: bool = false

func _unhandled_input(event: InputEvent) -> void:
	# Handle Right-Click Panning
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_panning = event.pressed
			
		# Handle Zooming In
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_to_mouse(zoom_speed)
			
		# Handle Zooming Out
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_to_mouse(-zoom_speed)

	elif event is InputEventMouseMotion and is_panning:
		position -= event.relative / zoom

func zoom_to_mouse(factor: float) -> void:
	# Save the mouse position in world space before zooming
	var mouse_pos = get_global_mouse_position()
	
	# Calculate new zoom vector and clamp it within bounds
	var new_zoom = zoom.x + factor
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)
	zoom = Vector2(new_zoom, new_zoom)
	
	# Reposition camera so the mouse points to the exact same world coordinate
	position += mouse_pos - get_global_mouse_position()
