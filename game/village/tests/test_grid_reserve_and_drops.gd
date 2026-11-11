extends GameTest
## Checks reserving and releasing cells, and the loose drops on a cell.

const WOOD := 1
const STONE := 2
const TREE := 11
const ROCK := 12
const HUT := 13
const BARN := 21
const OTHER_BARN := 22

var _grid: VillageGrid


## Lays a block of 10 by 10 cells for every test.
func before_each() -> void:
	_grid = VillageGrid.new()
	for cell in GridLayout.block(Vector2i(0, 0), Vector2i(10, 10)):
		_grid.add_cell(cell)


func test_reserve_marks_the_cells_and_release_gives_them_back() -> void:
	var plot := GridLayout.block(Vector2i(2, 2), Vector2i(3, 3))
	check(_grid.reserve(plot, BARN), "free cells can be reserved")
	for cell in plot:
		check_eq(_grid.reserved_by(cell), BARN)
	check_eq(_grid.reserved_by(Vector2i(5, 5)), VillageGrid.NOBODY)
	check_eq(_grid.release(BARN), 9)
	for cell in plot:
		check_eq(_grid.reserved_by(cell), VillageGrid.NOBODY)
	check_eq(_grid.release(BARN), 0)


func test_a_reserved_cell_cannot_be_reserved_by_somebody_else() -> void:
	_grid.reserve(GridLayout.block(Vector2i(2, 2), Vector2i(3, 3)), BARN)
	var overlap := GridLayout.block(Vector2i(4, 4), Vector2i(3, 3))
	check(not _grid.reserve(overlap, OTHER_BARN), "one shared cell refuses the whole lot")
	check_eq(_grid.reserved_by(Vector2i(4, 4)), BARN)
	check_eq(_grid.reserved_by(Vector2i(5, 5)), VillageGrid.NOBODY)
	var beside := GridLayout.block(Vector2i(5, 2), Vector2i(2, 3))
	check(_grid.reserve(beside, OTHER_BARN), "two reserved areas may touch")
	var into_other := GridLayout.block(Vector2i(2, 2), Vector2i(4, 1))
	check(not _grid.reserve(into_other, BARN), "a cell of the other barn refuses the lot")
	check_eq(_grid.release(OTHER_BARN), 6)
	check_eq(_grid.reserved_by(Vector2i(2, 2)), BARN)


func test_reserve_refuses_missing_cells_and_a_missing_id() -> void:
	var off_map: Array[Vector2i] = [Vector2i(9, 9), Vector2i(10, 9)]
	check(not _grid.reserve(off_map, BARN), "a missing cell refuses the whole lot")
	check_eq(_grid.reserved_by(Vector2i(9, 9)), VillageGrid.NOBODY)
	var one: Array[Vector2i] = [Vector2i(1, 1)]
	check(not _grid.reserve(one, 0), "id 0 means nobody")


func test_reserving_the_same_cells_twice_counts_them_once() -> void:
	var plot := GridLayout.block(Vector2i(0, 0), Vector2i(2, 2))
	check(_grid.reserve(plot, BARN), "first time")
	check(_grid.reserve(plot, BARN), "the same reserver may ask again")
	check_eq(_grid.release(BARN), 4)


func test_a_reserved_cell_is_only_free_for_its_reserver() -> void:
	_grid.reserve(GridLayout.block(Vector2i(2, 2), Vector2i(3, 3)), BARN)
	check(_grid.free_cells(Vector2i(3, 3)).is_empty(), "not free for a thing of nobody")
	check(_grid.free_cells(Vector2i(3, 3), 1, 1, OTHER_BARN).is_empty(), "not free for another")
	check_eq(_grid.free_cells(Vector2i(3, 3), 2, 1, BARN).size(), 2)
	check(not _grid.place(TREE, Vector2i(3, 3)), "a tree cannot stand on a reserved cell")
	check(_grid.place(HUT, Vector2i(3, 3), 2, 1, BARN), "a thing of the reserver can")
	check(_grid.place(ROCK, Vector2i(4, 5), 2, 1, BARN), "it may reach outside the area too")
	check(not _grid.place(TREE, Vector2i(1, 2), 2, 1), "one reserved cell refuses the lot")
	_grid.release(BARN)
	check(_grid.place(TREE, Vector2i(2, 2)), "a released cell is free again")


func test_a_reserved_cell_with_nothing_on_it_still_counts_as_empty_near_a_thing() -> void:
	_grid.place(TREE, Vector2i(5, 5))
	_grid.reserve([Vector2i(4, 5), Vector2i(6, 5)] as Array[Vector2i], BARN)
	check_eq(_grid.empty_cells_near(TREE).size(), 6)


func test_a_cell_stores_its_loose_drops() -> void:
	var cell := Vector2i(3, 3)
	check(_grid.drops.add(cell, WOOD), "one drop")
	check(_grid.drops.add(cell, WOOD, 2), "two more")
	check(_grid.drops.add(cell, STONE, 4), "another kind")
	check_eq(_grid.drops.count_at(cell, WOOD), 3)
	check_eq(_grid.drops.count_at(cell, STONE), 4)
	check_eq(_grid.drops.at(cell), {WOOD: 3, STONE: 4})
	check_eq(_grid.drops.count_at(Vector2i(4, 3), WOOD), 0)
	check_eq(_grid.drops.at(Vector2i(4, 3)), {})


func test_taking_drops_gives_only_what_is_there() -> void:
	var cell := Vector2i(3, 3)
	_grid.drops.add(cell, WOOD, 3)
	check_eq(_grid.drops.take(cell, WOOD, 2), 2)
	check_eq(_grid.drops.take(cell, WOOD, 5), 1)
	check_eq(_grid.drops.take(cell, WOOD), 0)
	check_eq(_grid.drops.take(cell, STONE), 0)
	check_eq(_grid.drops.at(cell), {})


func test_drops_need_a_cell_and_a_count_above_zero() -> void:
	check(not _grid.drops.add(Vector2i(50, 50), WOOD), "no cell, no drop")
	check(not _grid.drops.add(Vector2i(3, 3), WOOD, 0), "a count of 0 is refused")
	check(not _grid.drops.add(Vector2i(3, 3), WOOD, -2), "a count below 0 is refused")
	check_eq(_grid.drops.take(Vector2i(50, 50), WOOD), 0)


func test_drops_and_things_can_share_a_cell() -> void:
	_grid.drops.add(Vector2i(3, 3), WOOD, 2)
	check(_grid.place(TREE, Vector2i(3, 3)), "a drop does not take the cell")
	check_eq(_grid.drops.count_at(Vector2i(3, 3), WOOD), 2)
