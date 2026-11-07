extends Sprite2D

@export var fase_dist := 250

#func _process(delta: float) -> void:
	#var distance = global_position.distance_to(get_global_mouse_position())
	#
	#set_modulate(
		#Color(0.26,0.26,0.26,
		#max(0, (fase_dist-distance)/fase_dist)
		#)
	#)
	#print((fase_dist-distance)/fase_dist)
