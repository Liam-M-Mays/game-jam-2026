extends Building
class_name Lumberjack

@export var chops : PackedScene = preload("res://assets/Scenes/Resources/Drops/wood.tscn")

func find_work(_worker : Meeple) -> Job:
	var tree := _closest_tree()
	if tree == null:
		return null
	return ChopJob.new(grid.wake(tree))

func _closest_tree() -> Standing:
	return grid.nearest_standing(position, func(look : Harvestable) -> bool:
		return look.drops.has(chops) and Inventory.count("food") >= look.food_cost)
