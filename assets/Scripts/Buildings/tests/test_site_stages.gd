extends GameTest
## #149: a site asks for its next stage, then for whole later stages up to its max_hauls, so a hut is
## swarmed, a statue builds in the background, and a free builder takes the oldest site's haul first.
## Builders with nothing to do work past the cap.

const STATUE_SCENE := preload("res://assets/Scenes/Buildings/statue.tscn")
const HUT_SCENE := preload("res://assets/Scenes/Buildings/small_hut.tscn")
const MEEPLE_SCENE := preload("res://assets/Scenes/Meeple/meeple.tscn")

## A small square of cells with no trees, rocks or start building.
class SmallGrid extends Grid:
	func _ready() -> void:
		grid_size = 14
		var template : Sprite2D = CELL.instantiate()
		_cell_scale = template.scale
		_cell_offset = template.offset
		_cell_layer = CellLayer.new(template)
		template.free()
		add_child(_cell_layer)
		_build_cells()

	func _exit_tree() -> void:
		_clear_drops()

var _world : Node2D
var _grid : SmallGrid
var _look : MeepleLook
var _meeple : Meeple


## The runner starts tests from its own `_ready`, so the tree takes new nodes only after a frame.
func _set_up(wood : int, stone : int) -> void:
	await tree.process_frame
	Inventory.reset()
	JobSystem.reset()
	JobSystem.workers.clear()
	_world = Node2D.new()
	tree.root.add_child(_world)
	_grid = SmallGrid.new()
	_world.add_child(_grid)
	for i in range(wood):
		_grid.add_drop(ResourceDrop.scene_of("wood"), Vector2.ZERO)
	for i in range(stone):
		_grid.add_drop(ResourceDrop.scene_of("stone"), Vector2.ZERO)


func _start(scene : PackedScene, at : Vector2i) -> Building:
	var site : Building = scene.instantiate()
	_grid.place(site, _grid.free_cells_at(_grid._cell_or_null(at).position, site.footprint, site.footprint_depth))
	site.start_construction()
	return site


func after_each() -> void:
	JobSystem.reset()
	JobSystem.workers.clear()
	if _meeple != null:
		_meeple.free_item()
		_meeple = null
	if _look != null:
		_look.free()
		_look = null
	_world.free()
	Inventory.reset()


func test_a_site_asks_ahead_only_up_to_its_cap() -> void:
	await _set_up(10, 20)
	var statue := _start(STATUE_SCENE, Vector2i(3, 3))
	check_eq(JobSystem.job_count(), statue.max_hauls, "the statue has exactly max_hauls hauls out")
	check_eq(Inventory.available("wood"), 8, "2 whole stages of 1 wood under the default cap of 6")
	check_eq(Inventory.available("stone"), 16, "2 whole stages of 2 stone")
	_start(HUT_SCENE, Vector2i(10, 10))
	check_eq(Inventory.available("wood"), 4, "the hut asked for all 4 of its wood at once")


func test_a_hut_next_to_a_statue_still_gets_wood() -> void:
	await _set_up(1, 20)
	_start(STATUE_SCENE, Vector2i(3, 3))
	var hut := _start(HUT_SCENE, Vector2i(10, 10))
	check(not hut.missing().is_empty(), "the statue took the only wood for its next stage")
	_grid.add_drop(ResourceDrop.scene_of("wood"), Vector2.ZERO)
	Inventory.changed.emit()
	check_eq(Inventory.available("wood"), 0, "the new wood was taken")
	check(hut.missing().is_empty(), "the hut's next stage got it, not the statue's look-ahead")


func test_a_free_builder_takes_the_oldest_sites_haul_first() -> void:
	await _set_up(0, 0)
	var spot_a := _grid._cell_or_null(Vector2i(3, 3)).position
	var spot_b := _grid._cell_or_null(Vector2i(10, 10)).position
	for i in range(4):
		_grid.add_drop(ResourceDrop.scene_of("wood"), spot_a)
		_grid.add_drop(ResourceDrop.scene_of("wood"), spot_b)
	var older := _start(HUT_SCENE, Vector2i(3, 3))
	_start(HUT_SCENE, Vector2i(10, 10))
	JobSystem.match_jobs()
	_look = MEEPLE_SCENE.instantiate()
	_meeple = Meeple.new(_grid, _look, spot_b)
	JobSystem.add_worker(_meeple)
	JobSystem.match_jobs()
	check(_meeple.job is HaulJob and (_meeple.job as HaulJob).site == older,
		"a builder on the newer hut's wood took the older hut's haul")


func test_a_newer_sites_haul_does_not_jump_an_older_sites_waiting_haul() -> void:
	await _set_up(0, 0)
	var spot_b := _grid._cell_or_null(Vector2i(10, 10)).position
	for i in range(4):
		_grid.add_drop(ResourceDrop.scene_of("wood"), Vector2.ZERO)
		_grid.add_drop(ResourceDrop.scene_of("wood"), spot_b)
	var older := _start(HUT_SCENE, Vector2i(3, 3))
	JobSystem.match_jobs()
	_look = MEEPLE_SCENE.instantiate()
	# Free, but not just freed: only a new job reaches it.
	_meeple = Meeple.new(_grid, _look, spot_b)
	JobSystem.workers.append(_meeple)
	_start(HUT_SCENE, Vector2i(10, 10))
	JobSystem.match_jobs()
	check(_meeple.job is HaulJob and (_meeple.job as HaulJob).site == older,
		"the newer hut's new haul gave the builder the older hut's waiting haul")


func test_idle_builders_work_past_the_cap_until_a_new_site_needs_them() -> void:
	await _set_up(10, 20)
	var statue := _start(STATUE_SCENE, Vector2i(3, 3))
	_look = MEEPLE_SCENE.instantiate()
	var meeples : Array[Meeple] = []
	for i in range(statue.max_hauls + 2):
		meeples.append(Meeple.new(_grid, _look, Vector2.ZERO))
		JobSystem.add_worker(meeples[-1])
	JobSystem.match_jobs()
	check_eq(JobSystem.job_count(), statue.max_hauls, "the cap holds while every haul has a builder")
	JobSystem.match_jobs()
	check(JobSystem.job_count() > statue.max_hauls, "the 2 idle builders made the statue ask for another stage")
	JobSystem.match_jobs()
	var on_extra := meeples.filter(func(m : Meeple) -> bool: return m.job is HaulJob and (m.job as HaulJob).extra)
	check_eq(on_extra.size(), 2, "the 2 idle builders took the statue's extra hauls")
	var hut := _start(HUT_SCENE, Vector2i(10, 10))
	JobSystem.match_jobs()
	var on_hut := meeples.filter(func(m : Meeple) -> bool: return m.job is HaulJob and (m.job as HaulJob).site == hut)
	check_eq(on_hut.size(), 2, "the 2 builders on the statue's extra hauls left them for the new hut")
	JobSystem.reset()
	for meeple in meeples:
		meeple.free_item()
