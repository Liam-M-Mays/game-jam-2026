extends Building
class_name Windmill

const GROUP := &"windmills"

@export var extra_barn_slots := 1
@export var spin_speed := 90.0
@export var bare_frame := 5
@export var wheel : Sprite2D

func complete() -> void:
	super()
	add_to_group(GROUP)
	frame = bare_frame
	wheel.show()

func _process(delta : float) -> void:
	if wheel.visible:
		wheel.rotation_degrees += spin_speed * delta
