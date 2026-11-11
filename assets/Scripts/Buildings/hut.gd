extends Building
class_name Hut

const DOOR_OFFSET := Vector2(40, 35)

@export var meeple_capacity := 1

func _exit_tree() -> void:
	Population.remove_hut(self)

func complete() -> void:
	super()
	Population.add_hut(self)
	spawn_meeple()

func spawn_meeple() -> void:
	grid.spawn_meeple(position + DOOR_OFFSET)
