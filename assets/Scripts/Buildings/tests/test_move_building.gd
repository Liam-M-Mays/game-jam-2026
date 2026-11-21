extends GameTest
## Moving a building, from #144: the old building comes down as builders carry what it cost to a
## new site, so the move spends no stock. A moved barn takes its farms and its kept cells along as
## one shape.

const BARN_SCENE := preload("res://assets/Scenes/Buildings/barn.tscn")
const FARM_SCENE := preload("res://assets/Scenes/Buildings/farm.tscn")
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

	func at(x : int, y : int) -> Cell:
		return _cell_or_null(Vector2i(x, y))

var _world : Node2D
var _grid : SmallGrid
var _barn : Barn
var _farm : Farm


## The runner starts tests from its own `_ready`, so the tree takes new nodes only after a frame.
func _set_up() -> void:
	await tree.process_frame
	_world = Node2D.new()
	tree.root.add_child(_world)
	_grid = SmallGrid.new()
	_world.add_child(_grid)
	_barn = BARN_SCENE.instantiate()
	_grid.place(_barn, [_grid.at(5, 5), _grid.at(6, 5)])
	_barn.start_construction()
	_barn._finish_construction()
	_farm = FARM_SCENE.instantiate()
	_grid.place(_farm, [_grid.at(5, 3)])
	_farm.start_construction()
	if _farm.is_under_construction():
		_farm._finish_construction()


func after_each() -> void:
	JobSystem.reset()
	_world.free()
	Inventory.reset()


func test_a_moved_building_is_built_from_its_old_self() -> void:
	await _set_up()
	var old : Building = HUT_SCENE.instantiate()
	_grid.place(old, _grid.free_cells_at(_grid.at(10, 2).position, old.footprint, old.footprint_depth))
	var wood := Inventory.available("wood")
	var site := old.rebuild_at(_grid, _grid.free_cells_at(_grid.at(10, 10).position, old.footprint, old.footprint_depth))
	var hauls := JobSystem._pending.filter(func(j : Job) -> bool: return j is HaulJob and j.site == site)
	check_eq(hauls.size(), old.total_cost(), "every drop in the old building is asked for at once")
	for haul : HaulJob in hauls:
		check(not old.is_queued_for_deletion(), "the old building stands until its last drop is taken")
		haul._pick_up()
		haul._deliver()
	check(old.is_queued_for_deletion(), "the old building goes once it is empty")
	check(site.is_in_group(Building.COMPLETED_GROUP), "the new building is finished")
	check_eq(Inventory.available("wood"), wood, "the move spends no stock")


func test_a_moved_barn_rebuilds_its_farm_in_the_same_place() -> void:
	await _set_up()
	var old_area := _barn.area_at(_grid, _barn.cells[0])
	var site : Barn = _barn.rebuild_at(_grid, [_grid.at(9, 9), _grid.at(10, 9)])
	check_eq(site.plots.size(), 1, "the new barn has a farm")
	check(site.plots[0] is Farm and site.plots[0].cells[0] == _grid.at(9, 7), "the farm keeps its place in the plot area")
	var new_area := site.area_at(_grid, site.cells[0])
	check(new_area.all(func(c : Cell): return c.kept_for == site), "the new plot area is kept for the new barn")
	check(old_area.all(func(c : Cell): return c.kept_for == null), "the old plot area is free again")
