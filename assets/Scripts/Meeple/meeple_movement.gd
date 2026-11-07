extends Sprite2D
class_name Meeple

@export var speed := 100
@export var y_stretch := 0.1
@export var stretch_speed := 0.25
@export var wobble := 10
@export var wobble_speed := 1.5

var target : Vector2
var job : Job

@onready var _base_scale_y := scale.y

func move_to(pos : Vector2) -> void:
	target = pos

func has_arrived() -> bool:
	return target.distance_to(global_position) <= 1

func _physics_process(delta: float) -> void:
	if has_arrived():
		scale.y = _base_scale_y * (1 + sin(Time.get_ticks_msec() * stretch_speed* delta) * y_stretch * 0.5)
		set_rotation_degrees(0)
	else:
		var offset_vector = (target - global_position).normalized()
		global_position += offset_vector*delta*speed
		scale.y = _base_scale_y * (1 + sin(Time.get_ticks_msec() * stretch_speed* delta) * y_stretch)
		set_rotation_degrees(sin(Time.get_ticks_msec() * delta * wobble_speed) * wobble)

func _process(delta : float) -> void:
	if job == null:
		job = JobSystem.take_job()
		if job == null:
			return
		job.start(self)
	if job.update(self, delta):
		job = null
