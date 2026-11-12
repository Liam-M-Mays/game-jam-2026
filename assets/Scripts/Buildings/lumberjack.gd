extends Building
class_name Lumberjack

@export var chops : PackedScene = preload("res://assets/Scenes/Resources/Drops/wood.tscn")

func has_idle_work(_worker : Meeple) -> bool:
	return _closest_tree() != null

func _make_idle_job(_worker : Meeple) -> IdleJob:
	var tree := _closest_tree()
	if tree == null:
		return null
	return ChopJob.new(grid.wake(tree))

func _closest_tree() -> Standing:
	var closest : Standing = null
	var best := INF
	for tree in grid.standing:
		var look := tree.kind.template
		if not tree.is_free() or not look.drops.has(chops) or Inventory.count("food") < look.food_cost:
			continue
		var distance := position.distance_squared_to(tree.position)
		if distance < best:
			best = distance
			closest = tree
	return closest
