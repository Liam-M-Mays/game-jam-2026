extends Sprite2D
class_name resource

@export var area : Area2D

var cells : Array = []

func _ready() -> void:
	area.input_event.connect(_on_area_input_event)
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)

func _on_area_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_left_click()
			else:
				_on_left_release()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_on_right_click()
			else:
				_on_right_release()
				
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event)

func _on_left_click() -> void:
	JobSystem.add_mine_job(self)
	pass

func _on_left_release() -> void:
	pass

func _on_right_click() -> void:
	pass

func _on_right_release() -> void:
	pass

func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	pass

func _on_mouse_entered() -> void:
	modulate = Color.RED
	for cell in cells:
		cell.set_trans(0.5)

func _on_mouse_exited() -> void:
	modulate = Color.WHITE
	for cell in cells:
		cell.set_trans(0)
		
func mine():
	print("mined me")
	queue_free()
