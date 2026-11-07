extends Sprite2D
class_name Cell

@export var fase_dist := 250
var resource : Node2D = null



func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print(resource)

func set_trans(trans):
	set_modulate(Color(0.40,0.40,0.40,trans))

func _on_area_2d_mouse_entered() -> void:
	pass

func _on_area_2d_mouse_exited() -> void:
	pass
