extends Node2D

@export var grid_size := 50
@export var ground_sprites : Array[Sprite2D] = []
@export var ground_cover : Sprite2D

## Resource scenes that can spawn. Each one's spawn odds live on the scene itself
## (resource.gd > Spawning), not here.
@export var spawnables : Array[PackedScene] = []
## 0 = new random map each run; anything else reproduces the same layout.
@export var generation_seed := 0

const CELL = preload("res://assets/Scenes/Env/cell.tscn")

## Neighbouring cell offsets on this skewed grid (row above sits 5 px right).
const NEIGHBOURS : Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 1),
]

## Spawn settings read once from each spawnable scene.
class Spawnable:
	var scene : PackedScene
	var chance : float
	var footprint : int
	var curve : Curve
	var cluster_bonus : float

const CELL_OUTLINE : Array[Vector2] = [
	Vector2(4, 2), Vector2(4, 1), Vector2(1, -2), Vector2(-5, -2), Vector2(-5, -1), Vector2(-2, 2),
]

var grid : Array[Array] = []
var _cell_scale : Vector2
var _cell_offset : Vector2
## Per cell: 0 at the yard's edge, 1 at the deepest middle. Only set for real cells.
var _edge_distance := {}
var _rng := RandomNumberGenerator.new()

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
	generate_resources()
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

# --- Resource generation -------------------------------------------------------
# Every free cell is visited once, in random order. At each cell, every spawnable
# gets a weight = spawn_chance x edge-distance curve x cluster bonus, and a single
# roll picks at most one of them (or nothing). Random order means no left-to-right
# bias, and clumps grow naturally around resources placed earlier.

func generate_resources() -> void:
	if generation_seed != 0:
		_rng.seed = generation_seed
	else:
		_rng.randomize()
	var spawnables := _load_spawnables()
	if spawnables.is_empty():
		return
	_compute_edge_distance()

	var spots : Array[Vector2i] = []
	for coords in _edge_distance:
		spots.append(coords)
	_shuffle(spots)

	for coords in spots:
		_try_spawn_at(coords, spawnables)

func _load_spawnables() -> Array[Spawnable]:
	var list : Array[Spawnable] = []
	for scene in spawnables:
		if scene == null:
			continue
		var template = scene.instantiate()
		if template is resource and template.spawn_chance > 0.0:
			var s := Spawnable.new()
			s.scene = scene
			s.chance = template.spawn_chance
			s.footprint = template.footprint
			s.curve = template.edge_distance_curve
			s.cluster_bonus = template.cluster_bonus
			list.append(s)
		template.free()
	return list

## Multi-source BFS from every cell touching empty space, so distance is measured
## to the nearest real edge of the yard (including any holes), then normalised 0-1.
func _compute_edge_distance() -> void:
	_edge_distance.clear()
	var queue : Array[Vector2i] = []
	for x in range(grid_size):
		for y in range(grid_size):
			if grid[x][y] == null:
				continue
			var coords := Vector2i(x, y)
			for n in NEIGHBOURS:
				if _cell_or_null(coords + n) == null:
					_edge_distance[coords] = 0
					queue.append(coords)
					break
	var head := 0
	var max_dist := 0
	while head < queue.size():
		var coords := queue[head]
		head += 1
		var d : int = _edge_distance[coords]
		for n in NEIGHBOURS:
			var next := coords + n
			if _cell_or_null(next) != null and not _edge_distance.has(next):
				_edge_distance[next] = d + 1
				max_dist = maxi(max_dist, d + 1)
				queue.append(next)
	for coords in _edge_distance:
		_edge_distance[coords] = float(_edge_distance[coords]) / maxf(max_dist, 1.0)

func _cell_or_null(coords : Vector2i):
	if coords.x < 0 or coords.y < 0 or coords.x >= grid_size or coords.y >= grid_size:
		return null
	return grid[coords.x][coords.y]

func _footprint_cells(coords : Vector2i, width : int) -> Array:
	var cells : Array = []
	for i in range(width):
		var cell = _cell_or_null(coords + Vector2i(i, 0))
		if cell == null or cell.resource != null:
			return []
		cells.append(cell)
	return cells

func _spawn_weight(s : Spawnable, coords : Vector2i) -> float:
	var weight := s.chance
	if s.curve != null:
		weight *= maxf(s.curve.sample(_edge_distance[coords]), 0.0)
	if s.cluster_bonus != 0.0:
		weight *= maxf(1.0 + s.cluster_bonus * _matching_neighbours(s, coords), 0.0)
	return weight

## How many cells around this footprint already hold the same kind of resource.
func _matching_neighbours(s : Spawnable, coords : Vector2i) -> int:
	var found := 0
	for i in range(s.footprint):
		for n in NEIGHBOURS:
			var cell = _cell_or_null(coords + Vector2i(i, 0) + n)
			if cell != null and cell.resource != null and cell.resource.scene_file_path == s.scene.resource_path:
				found += 1
	return found

func _try_spawn_at(coords : Vector2i, spawnables : Array[Spawnable]) -> void:
	if _cell_or_null(coords) == null or grid[coords.x][coords.y].resource != null:
		return
	var options : Array = []
	var total := 0.0
	for s in spawnables:
		var cells := _footprint_cells(coords, s.footprint)
		if cells.is_empty():
			continue
		var weight := _spawn_weight(s, coords)
		if weight <= 0.0:
			continue
		options.append([s, cells, weight])
		total += weight
	if options.is_empty():
		return
	# One roll for all candidates: below `total` picks one in proportion to its
	# weight, above it leaves the cell empty. If weights sum past 1, always spawn.
	var roll := _rng.randf() * maxf(total, 1.0)
	for option in options:
		roll -= option[2]
		if roll < 0.0:
			_spawn(option[0], option[1])
			return

func _spawn(s : Spawnable, cells : Array) -> void:
	var res = s.scene.instantiate()
	res.position = cells[0].position
	for cell in cells:
		cell.resource = res
		res.cells.append(cell)
	add_child(res)
	count -= cells.size()

func _shuffle(arr : Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
