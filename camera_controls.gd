extends Camera2D

var is_panning : bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_panning = event.pressed
	elif event is InputEventMouseMotion and is_panning:
		position -= event.relative / zoom
			
