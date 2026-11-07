extends Node2D

@export var grid_size := 50

const CELL = preload("res://assets/Scenes/cell.tscn")
const TREE = preload("res://assets/Scenes/tree.tscn")
const BIG_TREE = preload("res://assets/Scenes/big-tree.tscn")
const ROCK = preload("res://assets/Scenes/rock.tscn")
const BIG_ROCK = preload("res://assets/Scenes/big-rock.tscn")

var grid : Array[Array] = []

func _init() -> void:
	for x in range(grid_size):
		var column : Array = []
		column.resize(grid_size)
		grid.append(column)

func place_cell(x : int, y : int):
	var cell = CELL.instantiate()
	cell.position.x = (x * cell.scale.x * 7) + (5 * y * cell.scale.x)
	cell.position.y = y * cell.scale.y * 5
	grid[x][y] = cell
	add_child(cell)

func _ready() -> void:
	for x in range(grid_size):
		for y in range(grid_size):
			place_cell(x,y)
	
	for x in range(grid_size):
		for y in range(grid_size):
			place_resource(x,y)


func place_resource(x, y):
	var cell = grid[x][y]
	if cell.resource != null:
		return
	if(randf() < 0.01):
		var tree = TREE.instantiate()
		tree.position = cell.position
		cell.resource = tree
		tree.cells.append(cell)
		add_child(tree)
		return
	if(randf() < 0.02):
		var rock = ROCK.instantiate()
		rock.position = cell.position
		cell.resource = rock
		rock.cells.append(cell)
		add_child(rock)
		return
	if x == grid_size-1:
		return
	var next_cell = grid[x+1][y]
	if next_cell.resource != null:
		return
	if(randf() < 0.03):
		var big_tree = BIG_TREE.instantiate()
		big_tree.position = cell.position
		cell.resource = big_tree
		next_cell.resource = big_tree
		big_tree.cells.append(cell)
		big_tree.cells.append(next_cell)
		add_child(big_tree)
	elif(randf() < 0.04):
		var big_rock = BIG_ROCK.instantiate()
		big_rock.position = cell.position
		cell.resource = big_rock
		next_cell.resource = big_rock
		big_rock.cells.append(cell)
		big_rock.cells.append(next_cell)
		add_child(big_rock)
	
