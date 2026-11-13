extends Node2D
class_name Grid

const CELL := preload("res://assets/Scenes/Env/cell.tscn")
const MEEPLE := preload("res://assets/Scenes/Meeple/meeple.tscn")
const DEV_SPAWN_KEY := KEY_M
const DEV_SPAWN_COUNT := 500
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

@export_group("Round world")
## About how many cells a round world on the ground has. A dev setting. 0 keeps the cells on the
## ground sprites, as on the giant.
@export var world_cells := 0
## How far the edge of a round world goes in and out, as a share of its radius.
@export_range(0.0, 0.5) var edge_wobble := 0.08
## The ground of a round world. It moves to the middle of the world and takes its shape.
@export var round_ground : YardGround
@export_group("")

const SPAWN_ATTEMPTS := 100
## How many cells left of a building a tree or rock can be and still reach under its art.
const PIN_REACH := 4
## A cell covers 7 by 5 art pixels.
const CELL_AREA := 35.0
## The cells of the jam map on the giant. A round world gets more of each kind by its size compared to this.
const JAM_CELLS := 2091
## How many points along the edge of a round world get their own distance from the middle.
const EDGE_POINTS := 360

class Spawnable:
	var scene : PackedScene
	var target : int
	var respawn_chance : float
	var footprint : int
	var curve : Curve
	var cluster_bonus : float
	var max_weight : float
	## A copy of the scene, out of the tree. Rows draw from its look and lumberjacks read its drops.
	var template : Harvestable
	## The click box around a tree or rock's position, read from the scene's Area2D.
	var hit_box : Rect2
	var count := 0

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
var _building_cells : Array[Vector2i] = []
var _cell_layer : CellLayer
var _meeple_look : MeepleLook
var _meeples : Array[Meeple] = []
## One copy of each drop scene, out of the tree. Every drop draws from the copy of its scene.
var _drop_looks := {}
## Every tree, rock and bush on the grid.
var standing : Array[Standing] = []
var _awake : Array[Standing] = []
var _hovered : Array[Standing] = []
var _rows := {}
var _reach_rows := 0
## Bushes that grow back while their row draws them.
var _regrowing : Array[Standing] = []
var _amount_scale := 1.0
var _round_middle := Vector2.ZERO
var _round_radius := 0.0

func _ready() -> void:
	var started := Time.get_ticks_usec()
	_meeple_look = MEEPLE.instantiate()
	var template : Sprite2D = CELL.instantiate()
	_cell_scale = template.scale
	_cell_offset = template.offset
	_cell_layer = CellLayer.new(template)
	template.free()
	add_child(_cell_layer)
	if world_cells > 0:
		_seed_world()
		_build_round_world()
	else:
		_build_cells()
		_compute_edge_distance()
		_seed_world()
	_place_start_building()
	_generate_resources()
	print("World built in %d ms, %d cells" % [(Time.get_ticks_usec() - started) / 1000, _coords_of.size()])

func _exit_tree() -> void:
	_clear_drops()
	for meeple in _meeples:
		meeple.free_item()
	_meeples.clear()
	JobSystem.workers.clear()
	_meeple_look.free()
	for s in _spawnables:
		s.template.free()

## Adds a meeple at `at`, in this grid's space, and gives it to the jobs.
func spawn_meeple(at : Vector2) -> Meeple:
	var meeple := Meeple.new(self, _meeple_look, at)
	_meeples.append(meeple)
	JobSystem.add_worker(meeple)
	return meeple

## Adds a drop of `scene` at `at`, in this grid's space, and gives it to Inventory.
func add_drop(scene : PackedScene, at : Vector2) -> ResourceDrop:
	if not _drop_looks.has(scene):
		_drop_looks[scene] = scene.instantiate()
	var drop := ResourceDrop.new(self, _drop_looks[scene], at)
	Inventory.register(drop)
	return drop

func _clear_drops() -> void:
	Inventory.clear_drops()
	for look in _drop_looks.values():
		look.free()
	_drop_looks.clear()

func _unhandled_input(event : InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		for s in _hovered:
			s.node._on_clicked()
	var key := event as InputEventKey
	if not OS.is_debug_build() or key == null or key.physical_keycode != DEV_SPAWN_KEY or not key.pressed or key.echo:
		return
	var hall := TownHall.find_town_hall()
	if hall != null:
		for i in range(DEV_SPAWN_COUNT):
			hall.spawn_meeple()

func cell_at(world_pos : Vector2) -> Cell:
	return _cell_or_null(_coords_at(world_pos))

## The cells whose outline touches a circle of `radius` around `world_pos`, in this grid's space.
func cells_near(world_pos : Vector2, radius : float) -> Array[Cell]:
	var found : Array[Cell] = []
	var center := _coords_at(world_pos)
	var local := to_local(world_pos)
	var rows := ceili(radius / (_cell_scale.y * 5)) + 1
	var columns := ceili(radius / (_cell_scale.x * 7)) + rows
	for dy in range(-rows, rows + 1):
		for dx in range(-columns, columns + 1):
			var cell := _cell_or_null(center + Vector2i(dx, dy))
			if cell != null and _touches(cell, local, radius):
				found.append(cell)
	return found

func _touches(cell : Cell, local : Vector2, radius : float) -> bool:
	var point := (local - cell.position) / _cell_scale
	var outline := PackedVector2Array(CELL_OUTLINE)
	if Geometry2D.is_point_in_polygon(point, outline):
		return true
	for i in range(outline.size()):
		var closest := Geometry2D.get_closest_point_to_segment(point, outline[i - 1], outline[i])
		if (closest - point).length() * _cell_scale.x <= radius:
			return true
	return false

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
	if obj is Building:
		for cell in cells:
			_building_cells.append(_coords_of[cell])
	_sort_into_row(obj)
	if obj is Building:
		_wake_left_of(obj as Building)

## Puts `obj` before the objects on its row that stand left of it, so the ones on the right draw behind.
func _sort_into_row(obj : GridObject) -> void:
	var coords : Vector2i = _coords_of[obj.cells[0]]
	for x in range(coords.x - 1, -1, -1):
		var cell := _cell_or_null(Vector2i(x, coords.y))
		var other : Object = cell.occupant if cell != null else null
		if other is Standing:
			other = (other as Standing).node
		var node := other as GridObject
		if node != null and node != obj and node.position.y == obj.position.y:
			move_child(obj, node.get_index())
			return

func remove(obj : GridObject) -> void:
	for cell in obj.cells:
		cell.occupant = null
		cell.highlight(0.0)
		if obj is Building:
			_building_cells.erase(_coords_of[cell])
	if obj is Harvestable:
		_forget((obj as Harvestable).standing)
	obj.queue_free()

func _build_cells() -> void:
	for x in range(grid_size):
		var column : Array = []
		column.resize(grid_size)
		_cells.append(column)
		for y in range(grid_size):
			var pos := _cell_position(x, y)
			if _fits_ground(pos):
				_add_cell(x, y)

func _add_cell(x : int, y : int) -> void:
	var cell := Cell.new(_cell_position(x, y), _cell_layer)
	_cells[x][y] = cell
	_coords_of[cell] = Vector2i(x, y)

## Makes a round world of about `world_cells` cells, with an uneven edge. The test is on the cell numbers
## only, so it stays fast at any size. Each cell gets the shade of the ground in place of its distance to
## the edge, so the spawn curves put the big trees and rocks in the dark areas and the small ones in the light.
func _build_round_world() -> void:
	var radius := sqrt(world_cells * CELL_AREA / PI)
	var noise := FastNoiseLite.new()
	noise.seed = _rng.seed
	var edge := PackedFloat32Array()
	for i in range(EDGE_POINTS):
		var direction := Vector2.from_angle(TAU * i / EDGE_POINTS)
		edge.append(radius * (1.0 + edge_wobble * noise.get_noise_2dv(direction * 150.0)))
	# In art pixels a cell sits at (7x + 5y, 5y). The middle is placed so every cell number is 0 or more.
	var reach := radius * (1.0 + edge_wobble)
	var inner := radius * (1.0 - edge_wobble)
	var rows := ceili(reach * 2.0 / 5.0) + 1
	var middle := Vector2(reach + 5.0 * rows, reach)
	grid_size = maxi(rows, ceili((middle.x + reach) / 7.0) + 1)
	for x in range(grid_size):
		var column : Array = []
		column.resize(grid_size)
		_cells.append(column)
	for y in range(rows):
		for x in range(maxi(floori((middle.x - reach - 5 * y) / 7.0), 0), mini(ceili((middle.x + reach - 5 * y) / 7.0), grid_size)):
			var offset := Vector2(7 * x + 5 * y, 5 * y) - middle
			var distance := offset.length()
			if distance < inner or distance < edge[posmod(roundi(offset.angle() / TAU * EDGE_POINTS), EDGE_POINTS)]:
				_add_cell(x, y)
	_round_middle = middle * _cell_scale
	_round_radius = radius * _cell_scale.x
	round_ground.global_position = to_global(_round_middle).round()
	var outline := PackedVector2Array()
	for i in range(EDGE_POINTS):
		var point := middle + Vector2.from_angle(TAU * i / EDGE_POINTS) * edge[i]
		outline.append(to_global(point * _cell_scale) - round_ground.global_position)
	round_ground.generate_round(_rng.seed, outline)
	for cell : Cell in _coords_of:
		_edge_distance[_coords_of[cell]] = round_ground.shade_at(to_global(cell.position))
	_amount_scale = _coords_of.size() / float(JAM_CELLS)

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
	if world_cells > 0:
		spots = [_middle_of_light_area()]
	else:
		spots.sort_custom(func(a, b): return _edge_distance[a] > _edge_distance[b])
	for coords in spots:
		var cells := _free_cells(coords, building.footprint, building.footprint_depth)
		if not cells.is_empty():
			place(building, cells)
			building.complete()
			_keep_clear = cells_around(building)
			return
	building.free()

## The lightest cell in the inner half of a round world, which is the middle of a light area.
func _middle_of_light_area() -> Vector2i:
	var best := Vector2i.ZERO
	var best_shade := -INF
	for coords : Vector2i in _edge_distance:
		var shade : float = _edge_distance[coords]
		if shade > best_shade and _cell_position(coords.x, coords.y).distance_to(_round_middle) < _round_radius * 0.5:
			best = coords
			best_shade = shade
	return best

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
			s.target = roundi(template.target_count * _amount_scale)
			s.respawn_chance = template.respawn_chance
			s.footprint = template.footprint
			s.curve = template.edge_distance_curve
			s.cluster_bonus = template.cluster_bonus
			s.max_weight = template.edge_distance_curve.max_value if template.edge_distance_curve != null else 1.0
			if s.cluster_bonus > 0.0:
				s.max_weight *= 1.0 + s.cluster_bonus * NEIGHBOURS.size() * s.footprint
			s.template = template
			var shape : CollisionShape2D = template.area.get_child(0)
			s.hit_box = template.transform * template.area.transform * shape.transform * shape.shape.get_rect()
			_reach_rows = maxi(_reach_rows, ceili(-s.hit_box.position.y / (_cell_scale.y * 5)))
			list.append(s)
		else:
			template.free()
	return list

func _process(delta : float) -> void:
	var i := 0
	while i < _meeples.size():
		if _meeples[i].tick(delta):
			i += 1
		else:
			_meeples.remove_at(i)
	_update_hover()
	_sleep_still()
	_regrow_asleep(delta)
	if _spawnables.is_empty():
		return
	_respawn_timer += delta
	if _respawn_timer < respawn_interval:
		return
	_respawn_timer -= respawn_interval
	_respawn()

func _respawn() -> void:
	var blocked := {}
	var blocked_ready := false
	for s in _spawnables:
		var missing := s.target - s.count
		if missing <= 0:
			continue
		if _rng.randf() >= s.respawn_chance * missing / float(s.target):
			continue
		if not blocked_ready:
			blocked = _cells_with_movers()
			blocked_ready = true
		var item := _spawn(s, blocked)
		if item != null:
			wake(item).grow_in()

func _cells_with_movers() -> Dictionary:
	var blocked := {}
	var spots : Array[Vector2] = []
	for worker in JobSystem.workers:
		spots.append(worker.global_position)
	for drop in Inventory.all_drops():
		spots.append(drop.global_position)
	for spot in spots:
		var cell := cell_at(spot)
		if cell != null:
			blocked[cell] = true
	return blocked

func _spawn(s : Spawnable, blocked := {}) -> Standing:
	if _spots.is_empty():
		return null
	var building_coords := _building_cells
	for i in range(SPAWN_ATTEMPTS):
		var coords : Vector2i = _spots[_rng.randi_range(0, _spots.size() - 1)]
		var cells := _free_cells(coords, s.footprint)
		if cells.is_empty() or cells.any(func(c): return blocked.has(c) or _keep_clear.has(c)):
			continue
		var weight := _spawn_weight(s, coords) * _building_factor(s, coords, building_coords)
		if _rng.randf() * s.max_weight >= weight:
			continue
		return _add_standing(s, cells)
	return null

func _add_standing(kind : Spawnable, cells : Array[Cell]) -> Standing:
	var item := Standing.new()
	item.kind = kind
	item.cells = cells
	item.position = cells[0].position
	for cell in cells:
		cell.occupant = item
	standing.append(item)
	kind.count += 1
	if not _under_building(item):
		_row(item).add(item)
	else:
		wake(item)
	return item

func _forget(item : Standing) -> void:
	standing.erase(item)
	_awake.erase(item)
	_hovered.erase(item)
	item.kind.count -= 1

## Gives `item` its real scene, for as long as something happens to it. Returns the scene's node.
func wake(item : Standing) -> Harvestable:
	if item.node != null:
		return item.node
	_row(item).remove(item)
	var node : Harvestable = item.kind.scene.instantiate()
	node.standing = item
	node.grid = self
	node.position = item.position
	node.cells = item.cells
	add_child(node)
	_sort_into_row(node)
	item.node = node
	_awake.append(item)
	return node

## Hands the trees, rocks and bushes that are still again back to their rows.
func _sleep_still() -> void:
	for item in _awake.duplicate():
		if not _hovered.has(item) and item.node.is_still() and not _under_building(item):
			_awake.erase(item)
			item.node.queue_free()
			item.node = null
			_row(item).add(item)
			if item.stage > 0 and not _regrowing.has(item):
				_regrowing.append(item)

## Counts down the regrow timers of picked bushes that have no node, and redraws a row when one grows back.
func _regrow_asleep(delta : float) -> void:
	var i := 0
	while i < _regrowing.size():
		var item := _regrowing[i]
		if item.node != null or item.stage == 0:
			_regrowing.remove_at(i)
			continue
		if (item.kind.template as Bush).regrow(item, delta):
			_row(item).queue_redraw()
		i += 1

## The node that draws the still trees, rocks and bushes of `item`'s row. It goes first among the grid's
## children, so on a tie in y it draws behind buildings.
func _row(item : Standing) -> StandingRow:
	if not _rows.has(item.position.y):
		var row := StandingRow.new()
		row.position.y = item.position.y
		row.z_index = item.kind.template.z_index
		add_child(row)
		move_child(row, 0)
		_rows[item.position.y] = row
	return _rows[item.position.y]

## True when a building on the same row starts just right of `item` and its art reaches over it.
## Such a tree or rock keeps its node, so it still draws in front of the building as before.
func _under_building(item : Standing) -> bool:
	var coords : Vector2i = _coords_of[item.cells[-1]]
	for x in range(coords.x + 1, coords.x + 1 + PIN_REACH):
		var cell := _cell_or_null(Vector2i(x, coords.y))
		var building := cell.occupant as Building if cell != null else null
		if building != null and building.position.y == item.position.y:
			var item_right := item.position.x + item.kind.template.get_rect().end.x * item.kind.template.scale.x
			return building.position.x + building.get_rect().position.x * building.scale.x < item_right
	return false

func _wake_left_of(building : Building) -> void:
	var coords : Vector2i = _coords_of[building.cells[0]]
	for x in range(coords.x - PIN_REACH, coords.x):
		var cell := _cell_or_null(Vector2i(x, coords.y))
		var item := cell.occupant as Standing if cell != null else null
		if item != null and _under_building(item):
			wake(item)

func _update_hover() -> void:
	var under := _standing_under_mouse()
	for item in _hovered:
		if not under.has(item) and item.node != null:
			item.node._set_hovered(false)
	for item in under:
		if not _hovered.has(item):
			wake(item)._set_hovered(true)
	_hovered = under

## The trees, rocks and bushes whose click box holds the mouse, found through the cells under it.
## Tall ones reach up over the rows behind them, so this also looks a few rows further down.
func _standing_under_mouse() -> Array[Standing]:
	var found : Array[Standing] = []
	if get_viewport().gui_get_hovered_control() != null:
		return found
	var mouse := get_local_mouse_position()
	var center := _coords_at(get_global_mouse_position())
	for dy in range(-1, _reach_rows + 1):
		# Each row further down starts 5/7 of a cell further right.
		for dx in range(-3 - dy, 3):
			var cell := _cell_or_null(center + Vector2i(dx, dy))
			var item := cell.occupant as Standing if cell != null else null
			if item != null and not found.has(item) and item.kind.hit_box.has_point(mouse - item.position):
				found.append(item)
	return found

func _spawn_weight(s : Spawnable, coords : Vector2i) -> float:
	var weight := 1.0
	if s.curve != null:
		weight *= maxf(s.curve.sample(_edge_distance[coords]), 0.0)
	if s.cluster_bonus != 0.0:
		weight *= maxf(1.0 + s.cluster_bonus * _matching_neighbours(s, coords), 0.0)
	return weight

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
			if cell != null and cell.occupant is Standing and (cell.occupant as Standing).kind == s:
				found += 1
	return found

func _shuffle(arr : Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
