extends Building
class_name Lumberjack

@export var chops : PackedScene = preload("res://assets/Scenes/Resources/Drops/wood.tscn")

func has_idle_work(_worker : Meeple) -> bool:
	return _closest_tree() != null

func _make_idle_job(_worker : Meeple) -> IdleJob:
	var tree := _closest_tree()
	if tree == null:
		return null
	return ChopJob.new(tree)

func _closest_tree() -> Harvestable:
	var closest : Harvestable = null
	var best := INF
	for node in get_tree().get_nodes_in_group(Harvestable.GROUP):
		var tree : Harvestable = node
		if not tree.is_free() or not tree.drops.has(chops) or Inventory.count("food") < tree.food_cost:
			continue
		var distance := global_position.distance_squared_to(tree.global_position)
		if distance < best:
			best = distance
			closest = tree
	return closest
