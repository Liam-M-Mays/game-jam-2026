extends Node2D

@export var cell : Node2D
@export var grid_size := 50

const CELL = preload("res://cell.tscn")

func place_cell(x : int, y : int):
	var cell = CELL.instantiate()
	cell.position.x = (x * cell.scale.x * 7) + (5 * y * cell.scale.x)
	cell.position.y = y * cell.scale.y * 5
	add_child(cell)
	
func _init() -> void:
	for x in range(grid_size):
		for y in range(grid_size):
			place_cell(x,y)
