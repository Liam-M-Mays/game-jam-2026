extends Sprite2D

@export var speed := 100
@export var y_stretch := 0.1
@export var stretch_speed := 0.25
@export var wobble := 10
@export var wobble_speed := 1.5

func _physics_process(delta: float) -> void:
	var target = get_global_mouse_position()
	var offset_vector = (target - global_position).normalized()
	global_position += offset_vector*delta*speed
	
	scale.y = 1 + sin(Time.get_ticks_msec() * stretch_speed* delta) * y_stretch 
	set_rotation_degrees(sin(Time.get_ticks_msec() * delta * wobble_speed) * wobble)
