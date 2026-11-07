extends Node2D

@export var grid_size := 50
@export var ground_sprites : Array[Sprite2D] = []
@export var ground_cover : Sprite2D

const CELL = preload("res://assets/Scenes/Env/cell.tscn")
const TREE = preload("res://assets/Scenes/Resources/tree.tscn")
const BIG_TREE = preload("res://assets/Scenes/Resources/big-tree.tscn")
const ROCK = preload("res://assets/Scenes/Resources/rock.tscn")
const BIG_ROCK = preload("res://assets/Scenes/Resources/big-rock.tscn")
const BUSH = preload("res://assets/Scenes/george_bush.tscn")

const CELL_OUTLINE : Array[Vector2] = [
	Vector2(4, 2), Vector2(4, 1), Vector2(1, -2), Vector2(-5, -2), Vector2(-5, -1), Vector2(-2, 2),
]

var grid : Array[Array] = []
var _cell_scale : Vector2
var _cell_offset : Vector2

var count := 0

func _cell_position(x : int, y : int) -> Vector2:
	return Vector2(
		(x * _cell_scale.x * 7) + (5 * y * _cell_scale.x),
		y * _cell_scale.y * 5
	)

func _is_ground(world_pos : Vector2) -> bool:
	if ground_cover != null and ground_cover.is_pixel_opaque(ground_cover.to_local(world_pos)):
		return false
	for sprite in ground_sprites:
		if sprite.get_rect().has_point(sprite.to_local(world_pos)):
			return true
	return false

func _cell_fits(pos : Vector2) -> bool:
	if ground_sprites.is_empty():
		return true
	for point in CELL_OUTLINE:
		if not _is_ground(to_global(pos + point * _cell_scale)):
			return false
	return true

func place_cell(x : int, y : int):
	var pos := _cell_position(x, y)
	if not _cell_fits(pos):
		return
	var cell = CELL.instantiate()
	cell.position = pos
	grid[x][y] = cell
	count += 1
	add_child(cell)

func _ready() -> void:
	var template = CELL.instantiate()
	_cell_scale = template.scale
	_cell_offset = template.offset
	template.free()

	for x in range(grid_size):
		var column : Array = []
		column.resize(grid_size)
		grid.append(column)

	for x in range(grid_size):
		for y in range(grid_size):
			place_cell(x,y)
	print(count)
	for x in range(grid_size):
		for y in range(grid_size):
			place_resource(x,y)
	print(count)



func _coords_at(world_pos : Vector2) -> Vector2i:
	var pos : Vector2 = to_local(world_pos) - _cell_offset * _cell_scale
	var y := roundi(pos.y / (_cell_scale.y * 5))
	var x := roundi((pos.x - 5 * y * _cell_scale.x) / (_cell_scale.x * 7))
	return Vector2i(x, y)

func cell_at(world_pos : Vector2):
	var coords := _coords_at(world_pos)
	if coords.y < 0 or coords.y >= grid_size or coords.x < 0 or coords.x >= grid_size:
		return null
	return grid[coords.x][coords.y]

func free_cells_at(world_pos : Vector2, width := 1) -> Array:
	var coords := _coords_at(world_pos)
	if coords.y < 0 or coords.y >= grid_size or coords.x < 0 or coords.x + width > grid_size:
		return []
	var cells : Array = []
	for i in range(width):
		var cell = grid[coords.x + i][coords.y]
		if cell == null or cell.resource != null:
			return []
		cells.append(cell)
	return cells

func place_resource(x, y):
	var cell = grid[x][y]
	if cell == null or cell.resource != null:
		return
	if(randf() < 0.02):
		var tree = TREE.instantiate()
		tree.position = cell.position
		cell.resource = tree
		tree.cells.append(cell)
		add_child(tree)
		count -= 1
		return
	if(randf() < 0.02):
		var rock = ROCK.instantiate()
		rock.position = cell.position
		cell.resource = rock
		rock.cells.append(cell)
		add_child(rock)
		count -= 1
		return
	if x == grid_size-1:
		return
	var next_cell = grid[x+1][y]
	if next_cell == null or next_cell.resource != null:
		return
	if(randf() < 0.01):
		var big_tree = BIG_TREE.instantiate()
		big_tree.position = cell.position
		cell.resource = big_tree
		next_cell.resource = big_tree
		big_tree.cells.append(cell)
		big_tree.cells.append(next_cell)
		add_child(big_tree)
		count -= 2
	elif(randf() < 0.015):
		var bush = BUSH.instantiate()
		bush.position = cell.position
		cell.resource = bush
		next_cell.resource = bush
		bush.cells.append(cell)
		bush.cells.append(next_cell)
		add_child(bush)
		count -= 2
	elif(randf() < 0.01):
		var big_rock = BIG_ROCK.instantiate()
		big_rock.position = cell.position
		cell.resource = big_rock
		next_cell.resource = big_rock
		big_rock.cells.append(cell)
		big_rock.cells.append(next_cell)
		add_child(big_rock)
		count -= 2
	
