extends Node2D
class_name Grid

const CELL := preload("res://assets/Scenes/Env/cell.tscn")
const NEIGHBOURS : Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 1),
]
const CELL_OUTLINE : Array[Vector2] = [
	Vector2(4, 2), Vector2(4, 1), Vector2(1, -2), Vector2(-5, -2), Vector2(-5, -1), Vector2(-2, 2),
]

@export var grid_size := 50
@export var ground_sprites : Array[Sprite2D] = []
@export var ground_cover : Sprite2D
@export var start_building : PackedScene
@export var spawnables : Array[PackedScene] = []
@export var generation_seed := 0

class Spawnable:
	var scene : PackedScene
	var chance : float
	var footprint : int
	var curve : Curve
	var cluster_bonus : float

var _cells : Array[Array] = []
var _cell_scale : Vector2
var _cell_offset : Vector2
var _edge_distance := {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	var template := CELL.instantiate()
	_cell_scale = template.scale
	_cell_offset = template.offset
	template.free()
	_build_cells()
	_compute_edge_distance()
	_place_start_building()
	_generate_resources()

func cell_at(world_pos : Vector2) -> Cell:
	return _cell_or_null(_coords_at(world_pos))

func free_cells_at(world_pos : Vector2, width := 1) -> Array[Cell]:
	return _free_cells(_coords_at(world_pos), width)

func place(obj : GridObject, cells : Array[Cell]) -> void:
	obj.grid = self
	obj.position = cells[0].position
	obj.cells = cells
	for cell in cells:
		cell.occupant = obj
	add_child(obj)

func remove(obj : GridObject) -> void:
	for cell in obj.cells:
		cell.occupant = null
		cell.highlight(0.0)
	obj.queue_free()

func _build_cells() -> void:
	for x in range(grid_size):
		var column : Array = []
		column.resize(grid_size)
		_cells.append(column)
		for y in range(grid_size):
			var pos := _cell_position(x, y)
			if _fits_ground(pos):
				var cell := CELL.instantiate()
				cell.position = pos
				column[y] = cell
				add_child(cell)

func _cell_position(x : int, y : int) -> Vector2:
	return Vector2((x * 7 + y * 5) * _cell_scale.x, y * 5 * _cell_scale.y)

func _coords_at(world_pos : Vector2) -> Vector2i:
	var pos : Vector2 = to_local(world_pos) - _cell_offset * _cell_scale
	var y := roundi(pos.y / (_cell_scale.y * 5))
	var x := roundi((pos.x - 5 * y * _cell_scale.x) / (_cell_scale.x * 7))
	return Vector2i(x, y)

func _cell_or_null(coords : Vector2i) -> Cell:
	if coords.x < 0 or coords.y < 0 or coords.x >= grid_size or coords.y >= grid_size:
		return null
	return _cells[coords.x][coords.y]

func _free_cells(coords : Vector2i, width : int) -> Array[Cell]:
	var cells : Array[Cell] = []
	for i in range(width):
		var cell := _cell_or_null(coords + Vector2i(i, 0))
		if cell == null or cell.occupant != null:
			return []
		cells.append(cell)
	return cells

func _fits_ground(pos : Vector2) -> bool:
	if ground_sprites.is_empty():
		return true
	for point in CELL_OUTLINE:
		if not _is_ground(to_global(pos + point * _cell_scale)):
			return false
	return true

func _is_ground(world_pos : Vector2) -> bool:
	if ground_cover != null and ground_cover.is_pixel_opaque(ground_cover.to_local(world_pos)):
		return false
	for sprite in ground_sprites:
		if sprite.get_rect().has_point(sprite.to_local(world_pos)):
			return true
	return false

func _compute_edge_distance() -> void:
	_edge_distance.clear()
	var queue : Array[Vector2i] = []
	for x in range(grid_size):
		for y in range(grid_size):
			var coords := Vector2i(x, y)
			if _cell_or_null(coords) == null:
				continue
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

func _place_start_building() -> void:
	if start_building == null:
		return
	var building : Building = start_building.instantiate()
	var spots := _edge_distance.keys()
	spots.sort_custom(func(a, b): return _edge_distance[a] > _edge_distance[b])
	for coords in spots:
		var cells := _free_cells(coords, building.footprint)
		if not cells.is_empty():
			place(building, cells)
			building.complete()
			return
	building.free()

func _generate_resources() -> void:
	if generation_seed != 0:
		_rng.seed = generation_seed
	else:
		_rng.randomize()
	var options := _load_spawnables()
	if options.is_empty():
		return
	var spots := _edge_distance.keys()
	_shuffle(spots)
	for coords in spots:
		_try_spawn_at(coords, options)

func _load_spawnables() -> Array[Spawnable]:
	var list : Array[Spawnable] = []
	for scene in spawnables:
		if scene == null:
			continue
		var template = scene.instantiate()
		if template is Harvestable and template.spawn_chance > 0.0:
			var s := Spawnable.new()
			s.scene = scene
			s.chance = template.spawn_chance
			s.footprint = template.footprint
			s.curve = template.edge_distance_curve
			s.cluster_bonus = template.cluster_bonus
			list.append(s)
		template.free()
	return list

func _try_spawn_at(coords : Vector2i, options : Array[Spawnable]) -> void:
	var candidates : Array = []
	var total := 0.0
	for s in options:
		var cells := _free_cells(coords, s.footprint)
		if cells.is_empty():
			continue
		var weight := _spawn_weight(s, coords)
		if weight <= 0.0:
			continue
		candidates.append([s, cells, weight])
		total += weight
	var roll := _rng.randf() * maxf(total, 1.0)
	for candidate in candidates:
		roll -= candidate[2]
		if roll < 0.0:
			place(candidate[0].scene.instantiate(), candidate[1])
			return

func _spawn_weight(s : Spawnable, coords : Vector2i) -> float:
	var weight := s.chance
	if s.curve != null:
		weight *= maxf(s.curve.sample(_edge_distance[coords]), 0.0)
	if s.cluster_bonus != 0.0:
		weight *= maxf(1.0 + s.cluster_bonus * _matching_neighbours(s, coords), 0.0)
	return weight

func _matching_neighbours(s : Spawnable, coords : Vector2i) -> int:
	var found := 0
	for i in range(s.footprint):
		for n in NEIGHBOURS:
			var cell := _cell_or_null(coords + Vector2i(i, 0) + n)
			if cell != null and cell.occupant != null and cell.occupant.scene_file_path == s.scene.resource_path:
				found += 1
	return found

func _shuffle(arr : Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
