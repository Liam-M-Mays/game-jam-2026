extends Sprite2D

@export var fase_dist := 250
#const TREE = preload("res://tree.tscn")
var resource : Node2D = null
#
#func _init() -> void:
	#if randi() % 2 == 0:
		#var tree = TREE.instantiate()
		#add_child(tree)


func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print(resource)
