extends building

const MEEPLE = preload("res://assets/Scenes/meeple.tscn")
const DOOR_OFFSET := Vector2(40, 35)

func start_build() -> void:
	modulate = Color.WHITE
	area.input_pickable = true

func progress():
	if frame >= hframes - 1:
		return
	if Inventory.wood < 1:
		_flash(Color.RED)
		return
	Inventory.add(-1, 0)
	frame += 1
	if frame == hframes - 1:
		finish_build()

func _on_left_click() -> void:
	progress()

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
	meeple.global_position = global_position + DOOR_OFFSET
	meeple.move_to(meeple.global_position)
