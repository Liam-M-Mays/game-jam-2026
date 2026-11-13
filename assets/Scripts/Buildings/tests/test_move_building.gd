extends GameTest
## Moving a building, from part 15b of #6. A moved barn takes its farms and its kept cells along as
## one shape, and refuses a spot where any of that shape does not fit.

const BARN_SCENE := preload("res://assets/Scenes/Buildings/barn.tscn")
const FARM_SCENE := preload("res://assets/Scenes/Buildings/farm.tscn")

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
	_farm = FARM_SCENE.instantiate()
	_grid.place(_farm, [_grid.at(5, 3)])
	_farm.start_construction()


func after_each() -> void:
	JobSystem.reset()
	_world.free()
	Inventory.reset()


func test_a_moved_barn_takes_its_farm_and_kept_cells_along() -> void:
	await _set_up()
	var old_area := _barn.area_at(_grid, _barn.cells[0])
	_barn.lift()
	var spot : Array[Cell] = [_grid.at(6, 6), _grid.at(7, 6)]
	check(_barn.can_place_at(_grid, spot), "the barn may overlap its own old plot area")
	_barn.land(spot)
	check(_farm.cells[0] == _grid.at(6, 4), "the farm keeps its place in the plot area")
	check(_grid.at(6, 4).occupant == _farm, "the farm sits on its new cell")
	check(_grid.at(5, 3).occupant == null, "the farm's old cell is empty")
	var new_area := _barn.area_at(_grid, _barn.cells[0])
	check(new_area.all(func(c : Cell): return c.kept_for == _barn), "the new plot area is kept for the barn")
	var left := old_area.filter(func(c : Cell): return not new_area.has(c) and not _barn.cells.has(c))
	check(left.all(func(c : Cell): return c.kept_for == null), "the old plot area is free again")


func test_a_barn_does_not_move_where_its_plot_area_is_blocked() -> void:
	await _set_up()
	_grid.at(9, 9).occupant = RefCounted.new()
	_barn.lift()
	var spot : Array[Cell] = [_grid.at(8, 8), _grid.at(9, 8)]
	check(not _barn.can_place_at(_grid, spot), "a rock in the plot area blocks the move")
	_barn.land(_barn.cells)
	check(_grid.at(5, 3).occupant == _farm, "put back, the farm is where it was")
