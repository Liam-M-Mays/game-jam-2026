extends Building
class_name Hut

const MEEPLE := preload("res://assets/Scenes/meeple.tscn")
const DOOR_OFFSET := Vector2(40, 35)

func complete() -> void:
	super()
	var meeple : Meeple = MEEPLE.instantiate()
	meeple.grid = grid
	meeple.position = position + DOOR_OFFSET
	grid.add_child(meeple)
