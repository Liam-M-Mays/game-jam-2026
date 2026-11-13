extends Node2D
## The ground level: the village on a round world, with no giant.

@export var camera : Camera2D

func _ready() -> void:
	var hall := TownHall.find_town_hall()
	if hall != null:
		camera.global_position = hall.global_position
