extends Building
class_name Hut

const DOOR_OFFSET := Vector2(40, 35)

@export var meeple_capacity := 1
## Meeples that move in the moment it is finished. The rest of `meeple_capacity` fills by growth,
## when there is food.
@export var meeples_when_finished := 1

func _exit_tree() -> void:
	Population.remove_hut(self)

func complete() -> void:
	super()
	Population.add_hut(self)
	for i in range(mini(meeples_when_finished, meeple_capacity)):
		spawn_meeple()

func spawn_meeple() -> void:
	grid.spawn_meeple(position + DOOR_OFFSET)
