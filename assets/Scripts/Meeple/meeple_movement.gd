extends Sprite2D

@export var speed := 100
@export var y_stretch := 0.1
@export var stretch_speed := 0.25
@export var wobble := 10
@export var wobble_speed := 1.5

var target : Vector2

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		target = get_global_mouse_position()

func _physics_process(delta: float) -> void:
	if target.distance_to(global_position) > 1:
		var offset_vector = (target - global_position).normalized()
		global_position += offset_vector*delta*speed
		scale.y = 1 + sin(Time.get_ticks_msec() * stretch_speed* delta) * y_stretch 
		set_rotation_degrees(sin(Time.get_ticks_msec() * delta * wobble_speed) * wobble)
	else:
		scale.y = 1 + sin(Time.get_ticks_msec() * stretch_speed* delta * 0.5) * y_stretch * 0.5
		set_rotation_degrees(0)
	
