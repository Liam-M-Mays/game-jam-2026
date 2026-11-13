extends GameTest
## From #67: "A site does not take the materials for all its stages at once. It asks only for what
## it can do next." A statue (48 stages) and a hut stand side by side with little stock, and both
## get deliveries.

const STATUE_SCENE := preload("res://assets/Scenes/Buildings/statue.tscn")
const HUT_SCENE := preload("res://assets/Scenes/Buildings/small_hut.tscn")

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


## The runner starts tests from its own `_ready`, so the tree takes new nodes only after a frame.
func _set_up(wood : int, stone : int) -> void:
	await tree.process_frame
	Inventory.reset()
	JobSystem.reset()
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
	_world.free()
	Inventory.reset()


func test_a_statue_reserves_only_its_next_stage() -> void:
	await _set_up(3, 6)
	_start(STATUE_SCENE, Vector2i(3, 3))
	check_eq(Inventory.available("wood"), 2, "one stage needs 1 wood, so 2 of 3 are left")
	check_eq(Inventory.available("stone"), 4, "one stage needs 2 stone, so 4 of 6 are left")


func test_a_hut_next_to_a_statue_still_gets_wood() -> void:
	await _set_up(2, 2)
	_start(STATUE_SCENE, Vector2i(3, 3))
	var hut := _start(HUT_SCENE, Vector2i(10, 10))
	check_eq(Inventory.available("wood"), 0, "the statue took 1 wood and the hut the other")
	check(hut.missing().is_empty(), "the hut's next stage is on its way")
