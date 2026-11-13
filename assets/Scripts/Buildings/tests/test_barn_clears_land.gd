extends GameTest
## From #129: "when building a barn it should allow oyu to place it with overlap to trees or other
## resources however it will queue up meeples to destory them ... and if the player cancels it the farm
## will not be build ... farm land should not start growing until the barn is finished building."

const BARN_SCENE := preload("res://assets/Scenes/Buildings/barn.tscn")
const FARM_SCENE := preload("res://assets/Scenes/Buildings/farm.tscn")
const TREE_SCENE := preload("res://assets/Scenes/Resources/tree.tscn")

## A small square of cells with no trees, rocks or start building. `plant` puts a tree on a cell.
class SmallGrid extends Grid:
	var tree_kind := Spawnable.new()

	func _ready() -> void:
		grid_size = 14
		var template : Sprite2D = CELL.instantiate()
		_cell_scale = template.scale
		_cell_offset = template.offset
		_cell_layer = CellLayer.new(template)
		template.free()
		add_child(_cell_layer)
		_build_cells()
		tree_kind.scene = TREE_SCENE
		tree_kind.footprint = 1
		tree_kind.template = TREE_SCENE.instantiate()

	func _exit_tree() -> void:
		_clear_drops()
		tree_kind.template.free()

	func at(x : int, y : int) -> Cell:
		return _cell_or_null(Vector2i(x, y))

	func plant(cell : Cell) -> Standing:
		return _add_standing(tree_kind, [cell])

var _world : Node2D
var _grid : SmallGrid


## The runner starts tests from its own `_ready`, so the tree takes new nodes only after a frame.
func _set_up() -> void:
	await tree.process_frame
	_world = Node2D.new()
	tree.root.add_child(_world)
	_grid = SmallGrid.new()
	_world.add_child(_grid)


func after_each() -> void:
	JobSystem.reset()
	_world.free()
	Inventory.reset()


func _barn_at(x : int, y : int) -> Barn:
	var barn : Barn = BARN_SCENE.instantiate()
	barn.put_down(_grid, [_grid.at(x, y), _grid.at(x + 1, y)])
	return barn


func _farm_at(cell : Cell) -> Farm:
	var farm : Farm = FARM_SCENE.instantiate()
	farm.put_down(_grid, [cell])
	return farm


func test_a_barn_over_trees_is_built_and_marks_them() -> void:
	await _set_up()
	var item := _grid.plant(_grid.at(5, 3))
	var barn := _barn_at(5, 5)
	check(barn.is_under_construction(), "a tree in the plot area does not stop the barn")
	check(item.node != null and item.node.is_marked(), "the tree is marked to be cleared")
	check(JobSystem.waiting_player_jobs() == 1, "the clearing is a queued job")
	check(barn.plot_area().has(_grid.at(5, 3)), "a farm may still be placed on the tree's cell")


func test_a_farm_on_a_tree_waits_and_then_is_built() -> void:
	await _set_up()
	var item := _grid.plant(_grid.at(5, 3))
	var barn := _barn_at(5, 5)
	var farm := _farm_at(_grid.at(5, 3))
	check(farm.is_waiting_for_land(), "the farm waits while the tree stands")
	check(_grid.at(5, 3).occupant == item, "the tree keeps its cell")
	check(barn.plots.has(farm), "the waiting farm takes one of the barn's slots")
	check(not barn.plot_area().has(_grid.at(5, 3)), "no second farm can go on that cell")
	_grid.remove(item.node)
	farm._check_land()
	check(not farm.is_waiting_for_land(), "with the tree gone the farm stops waiting")
	check(_grid.at(5, 3).occupant == farm, "the farm is put on its cell and started")


func test_cancelling_the_clearing_cancels_the_farm() -> void:
	await _set_up()
	var item := _grid.plant(_grid.at(5, 3))
	var barn := _barn_at(5, 5)
	var farm := _farm_at(_grid.at(5, 3))
	item.node._on_clicked()
	check(farm.is_queued_for_deletion(), "a click on the marked tree cancels the farm")
	check(not barn.plots.has(farm), "the barn gets its slot back")
	check(not barn.is_queued_for_deletion(), "the barn stays")


func test_clear_all_cancels_a_barn_waiting_for_its_own_cells() -> void:
	await _set_up()
	_grid.plant(_grid.at(5, 5))
	var plot_tree := _grid.plant(_grid.at(5, 3))
	var barn := _barn_at(5, 5)
	check(barn.is_waiting_for_land(), "a tree on the barn's own cell makes it wait")
	var farm := _farm_at(_grid.at(6, 3))
	check(_grid.at(6, 3).occupant == farm, "a farm on clear land next to it starts")
	JobSystem.clear_waiting_player_jobs()
	check(barn.is_queued_for_deletion(), "Clear all cancels the barn")
	check(farm.is_queued_for_deletion(), "its farm goes with it")
	check(not plot_tree.node.is_marked(), "its plot area is no longer cleared")
	check(_grid.at(5, 3).kept_for == null and _grid.at(5, 5).kept_for == null, "its land is free again")


func test_farm_land_grows_only_once_the_barn_is_finished() -> void:
	await _set_up()
	var barn := _barn_at(5, 5)
	var farm := _farm_at(_grid.at(5, 3))
	if not farm.is_in_group(Building.COMPLETED_GROUP):
		farm.complete()
	check(not farm._growing, "a farm finished before its barn stays bare")
	barn.complete()
	check(farm._growing, "it starts growing when the barn is finished")
