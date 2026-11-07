extends Area2D

@export var fase_dist := 250
@export var enabled := true

func _process(delta: float) -> void:
	if !enabled:
		return
	position = get_global_mouse_position()
	for area in get_overlapping_areas():
		var owner = area.get_parent()
		var distance = global_position.distance_to(owner.global_position)
		owner.set_modulate(
			Color(0.26,0.26,0.26,
			max(0, (fase_dist-distance)/fase_dist)
			)
		)
	
