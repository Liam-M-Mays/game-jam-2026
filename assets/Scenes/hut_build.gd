extends building

const MEEPLE = preload("res://assets/Scenes/meeple.tscn")
const DOOR_OFFSET := Vector2(40, 35)

func _on_mouse_entered() -> void:
	pass

func _on_mouse_exited() -> void:
	pass

func _get_preview():
	frame = hframes-1

func finish_build() -> void:
	super()
	var meeple = MEEPLE.instantiate()
	get_parent().get_parent().add_child(meeple)
	meeple.global_position = get_parent().to_global(position + DOOR_OFFSET)
	meeple.move_to(meeple.global_position)
