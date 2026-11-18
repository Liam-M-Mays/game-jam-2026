extends GameTest
## #149: a site asks for its next stage, then for whole later stages up to its max_hauls, so a hut is
## swarmed, a statue builds in the background, and a free builder takes the oldest site's haul first.

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

## A job that is not a haul, standing in for a marked tree.
class SpotJob extends Job:
	var at : Vector2

	func _init(spot : Vector2) -> void:
		at = spot

	func place() -> Vector2:
		return at

	func update(_worker : Meeple, _delta : float) -> bool:
		return false

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
	await _set_up(2, 2)
	_start(STATUE_SCENE, Vector2i(3, 3))
	var hut := _start(HUT_SCENE, Vector2i(10, 10))
	check_eq(Inventory.available("wood"), 0, "the statue took 1 wood and the hut the other")
	check(hut.missing().is_empty(), "the hut's next stage is on its way")


func test_a_free_builder_takes_the_oldest_sites_haul_first() -> void:
	await _set_up(0, 0)
	var spot_a := _grid._cell_or_null(Vector2i(3, 3)).position
	var spot_b := _grid._cell_or_null(Vector2i(10, 10)).position
	for i in range(4):
		_grid.add_drop(ResourceDrop.scene_of("wood"), spot_a)
		_grid.add_drop(ResourceDrop.scene_of("wood"), spot_b)
	var older := _start(HUT_SCENE, Vector2i(3, 3))
	JobSystem.add(SpotJob.new(_grid.to_global(spot_b)))
	JobSystem.match_jobs()
	_start(HUT_SCENE, Vector2i(10, 10))
	_look = MEEPLE_SCENE.instantiate()
	_meeple = Meeple.new(_grid, _look, spot_b)
	JobSystem.add_worker(_meeple)
	JobSystem.match_jobs()
	check(_meeple.job is HaulJob and (_meeple.job as HaulJob).site == older,
		"a builder on the newer hut's wood, next to a tree, took the older hut's haul")
