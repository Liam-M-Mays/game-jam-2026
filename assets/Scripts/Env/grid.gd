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
@export var respawn_interval := 2.0

@export var building_clearance := 4

const SPAWN_ATTEMPTS := 100

class Spawnable:
	var scene : PackedScene
	var target : int
	var respawn_chance : float
	var footprint : int
	var curve : Curve
	var cluster_bonus : float
	var max_weight : float

var _cells : Array[Array] = []
var _cell_scale : Vector2
var _cell_offset : Vector2
var _edge_distance := {}
var _rng := RandomNumberGenerator.new()
var _spawnables : Array[Spawnable] = []
var _spots : Array = []
var _respawn_timer := 0.0
var _coords_of := {}
var _keep_clear : Array[Cell] = []

func _ready() -> void:
	var template := CELL.instantiate()
	_cell_scale = template.scale
	_cell_offset = template.offset
	template.free()
	_build_cells()
	_compute_edge_distance()
	_seed_world()
	_place_start_building()
	_generate_resources()

func cell_at(world_pos : Vector2) -> Cell:
	return _cell_or_null(_coords_at(world_pos))

func free_cells_at(world_pos : Vector2, width := 1, depth := 1) -> Array[Cell]:
	return _free_cells(_coords_at(world_pos), width, depth)

func cells_around(obj : GridObject, radius := 1) -> Array[Cell]:
	var found : Array[Cell] = []
	for cell in obj.cells:
		var center : Vector2i = _coords_of.get(cell, Vector2i(-1, -1))
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var offset := Vector2i(dx, dy)
				if _hex_distance(offset) > radius:
					continue
				var near := _cell_or_null(center + offset)
				if near != null and near.occupant == null and not found.has(near):
					found.append(near)
	return found

func cells_at_offsets(origin : Cell, offsets : Array[Vector2i]) -> Array[Cell]:
	var found : Array[Cell] = []
	for offset in offsets:
		var cell := _cell_or_null(_coords_of[origin] + offset)
		if cell != null:
			found.append(cell)
	return found

func place(obj : GridObject, cells : Array[Cell]) -> void:
	obj.grid = self
	obj.position = cells[0].position
	obj.cells = cells
	for cell in cells:
		cell.occupant = obj
	add_child(obj)
	_sort_into_row(obj)

func _sort_into_row(obj : GridObject) -> void:
	for child in get_children():
		if child != obj and child is GridObject and child.position.y == obj.position.y and child.position.x < obj.position.x:
			move_child(obj, child.get_index())
			return

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
				_coords_of[cell] = Vector2i(x, y)
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

func _free_cells(coords : Vector2i, width : int, depth := 1) -> Array[Cell]:
	var cells : Array[Cell] = []
	for row in range(depth):
		for i in range(width):
			var cell := _cell_or_null(coords + Vector2i(i, row))
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
		var cells := _free_cells(coords, building.footprint, building.footprint_depth)
		if not cells.is_empty():
			place(building, cells)
			building.complete()
			_keep_clear = cells_around(building)
			return
	building.free()

func _seed_world() -> void:
	if generation_seed != 0:
		_rng.seed = generation_seed
	else:
		_rng.randomize()
	print("World seed: ", _rng.seed)
	if ground_sprites.is_empty() or not ground_sprites[0] is YardGround:
		return
	var yard : YardGround = ground_sprites[0]
	yard.generate(_rng.seed, _is_ground)

func _generate_resources() -> void:
	_spawnables = _load_spawnables()
	_spots = _edge_distance.keys()
	var queue : Array[Spawnable] = []
	for s in _spawnables:
		for i in range(s.target):
			queue.append(s)
	_shuffle(queue)
	for s in queue:
		_spawn(s)

func _load_spawnables() -> Array[Spawnable]:
	var list : Array[Spawnable] = []
	for scene in spawnables:
		if scene == null:
			continue
		var template = scene.instantiate()
		if template is Harvestable and template.target_count > 0:
			var s := Spawnable.new()
			s.scene = scene
			s.target = template.target_count
			s.respawn_chance = template.respawn_chance
			s.footprint = template.footprint
			s.curve = template.edge_distance_curve
			s.cluster_bonus = template.cluster_bonus
			s.max_weight = template.edge_distance_curve.max_value if template.edge_distance_curve != null else 1.0
			if s.cluster_bonus > 0.0:
				s.max_weight *= 1.0 + s.cluster_bonus * NEIGHBOURS.size() * s.footprint
			list.append(s)
		template.free()
	return list

func _process(delta : float) -> void:
	if _spawnables.is_empty():
		return
	_respawn_timer += delta
	if _respawn_timer < respawn_interval:
		return
	_respawn_timer -= respawn_interval
	_respawn()

func _respawn() -> void:
	var counts := {}
	for node in get_tree().get_nodes_in_group(Harvestable.GROUP):
		if not node.is_queued_for_deletion():
			counts[node.scene_file_path] = counts.get(node.scene_file_path, 0) + 1
	var blocked := {}
	var blocked_ready := false
	for s in _spawnables:
		var missing : int = s.target - counts.get(s.scene.resource_path, 0)
		if missing <= 0:
			continue
		if _rng.randf() >= s.respawn_chance * missing / float(s.target):
			continue
		if not blocked_ready:
			blocked = _cells_with_movers()
			blocked_ready = true
		var obj := _spawn(s, blocked)
		if obj != null:
			obj.grow_in()

func _cells_with_movers() -> Dictionary:
	var blocked := {}
	var movers : Array[Node2D] = []
	movers.append_array(JobSystem.workers)
	for child in get_children():
		if child is ResourceDrop:
			movers.append(child)
	for mover in movers:
		var cell := cell_at(mover.global_position)
		if cell != null:
			blocked[cell] = true
	return blocked

func _spawn(s : Spawnable, blocked := {}) -> Harvestable:
	if _spots.is_empty():
		return null
	var building_coords := _building_coords()
	for i in range(SPAWN_ATTEMPTS):
		var coords : Vector2i = _spots[_rng.randi_range(0, _spots.size() - 1)]
		var cells := _free_cells(coords, s.footprint)
		if cells.is_empty() or cells.any(func(c): return blocked.has(c) or _keep_clear.has(c)):
			continue
		var weight := _spawn_weight(s, coords) * _building_factor(s, coords, building_coords)
		if _rng.randf() * s.max_weight >= weight:
			continue
		var obj : Harvestable = s.scene.instantiate()
		place(obj, cells)
		return obj
	return null

func _spawn_weight(s : Spawnable, coords : Vector2i) -> float:
	var weight := 1.0
	if s.curve != null:
		weight *= maxf(s.curve.sample(_edge_distance[coords]), 0.0)
	if s.cluster_bonus != 0.0:
		weight *= maxf(1.0 + s.cluster_bonus * _matching_neighbours(s, coords), 0.0)
	return weight

func _building_coords() -> Array[Vector2i]:
	var list : Array[Vector2i] = []
	for child in get_children():
		if child is Building:
			for cell in child.cells:
				list.append(_coords_of[cell])
	return list

func _building_factor(s : Spawnable, coords : Vector2i, building_coords : Array[Vector2i]) -> float:
	if building_clearance <= 0 or building_coords.is_empty():
		return 1.0
	var nearest := building_clearance
	for i in range(s.footprint):
		for b in building_coords:
			nearest = mini(nearest, _hex_distance(coords + Vector2i(i, 0) - b))
	var t := float(nearest) / building_clearance
	return t * t

func _hex_distance(offset : Vector2i) -> int:
	return (absi(offset.x) + absi(offset.y) + absi(offset.x + offset.y)) / 2

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
