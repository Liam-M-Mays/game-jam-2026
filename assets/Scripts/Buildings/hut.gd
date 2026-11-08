extends Building
class_name Hut

const MEEPLE := preload("res://assets/Scenes/Meeple/meeple.tscn")
const DOOR_OFFSET := Vector2(40, 35)

func _exit_tree() -> void:
	Population.remove_hut(self)

func complete() -> void:
	super()
	Population.add_hut(self)
	spawn_meeple()

func spawn_meeple() -> void:
	var meeple : Meeple = MEEPLE.instantiate()
	meeple.grid = grid
	meeple.position = position + DOOR_OFFSET
	grid.add_child(meeple)
