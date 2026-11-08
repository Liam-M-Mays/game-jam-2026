extends Sprite2D
class_name ResourceDrop

const LAND_ATTEMPTS := 8
const EXPIRE_FADE := 0.4

@export var kind := "wood"
@export var launch_distance_min := 30.0
@export var launch_distance_max := 80.0
@export var launch_duration := 0.35

var claimed := false
var storage : Storage = null
var surplus_time := 0.0

func _enter_tree() -> void:
	Inventory.register(self)

func _exit_tree() -> void:
	if storage != null:
		storage.take(self)
	Inventory.unregister(self)

func expire() -> void:
	claimed = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, EXPIRE_FADE)
	tween.tween_callback(queue_free)

func launch(grid : Grid) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", _pick_landing(grid), launch_duration)

func _pick_landing(grid : Grid) -> Vector2:
	for i in range(LAND_ATTEMPTS):
		var spot := position + Vector2.from_angle(randf() * TAU) * randf_range(launch_distance_min, launch_distance_max)
		var cell := grid.cell_at(grid.to_global(spot))
		if cell != null and cell.occupant == null:
			return spot
	return position
