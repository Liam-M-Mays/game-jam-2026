extends GameTest
## Checks adding many cells to a grid at once: it gives the same grid as
## adding them one by one.

## A block of cells on both sides of zero, so it crosses chunk borders.
const FIRST := Vector2i(-40, -23)
const SIZE := Vector2i(75, 41)


func test_many_cells_at_once_give_the_same_grid_as_one_by_one() -> void:
	var xs := PackedInt32Array()
	var ys := PackedInt32Array()
	var kinds := PackedByteArray()
	var one_by_one := VillageGrid.new()
	for cell in GridLayout.block(FIRST, SIZE):
		var kind := 1 + posmod(cell.x * 7 + cell.y * 3, 5)
		xs.append(cell.x)
		ys.append(cell.y)
		kinds.append(kind)
		one_by_one.add_cell(cell, kind)
	var at_once := VillageGrid.new()
	check_eq(at_once.add_cells(xs, ys, kinds), SIZE.x * SIZE.y, "every cell is new")
	check_eq(at_once.cell_count(), SIZE.x * SIZE.y)
	check(at_once.snapshot() == one_by_one.snapshot(), "the two grids are the same")
	check_eq(at_once.ground(Vector2i(-40, -23)), 1 + posmod(-40 * 7 - 23 * 3, 5))
	check_eq(at_once.ground(Vector2i(34, 17)), 1 + posmod(34 * 7 + 17 * 3, 5))
	check(not at_once.has_cell(Vector2i(35, 17)), "the cell past the block does not exist")


func test_a_cell_that_exists_is_changed_and_not_counted_again() -> void:
	var grid := VillageGrid.new()
	grid.add_cell(Vector2i(3, 3), 2)
	var xs := PackedInt32Array([3, 4, 5])
	var ys := PackedInt32Array([3, 3, 3])
	check_eq(grid.add_cells(xs, ys, PackedByteArray([7, 1, 1])), 2, "two of the three are new")
	check_eq(grid.cell_count(), 3)
	check_eq(grid.ground(Vector2i(3, 3)), 7, "the old cell has the new ground kind")


func test_a_ground_kind_of_zero_leaves_its_cell_out() -> void:
	var grid := VillageGrid.new()
	var xs := PackedInt32Array([0, 1, 2])
	var ys := PackedInt32Array([0, 0, 0])
	check_eq(grid.add_cells(xs, ys, PackedByteArray([1, 0, 1])), 2)
	check(grid.has_cell(Vector2i(0, 0)) and grid.has_cell(Vector2i(2, 0)), "the two with a kind")
	check(not grid.has_cell(Vector2i(1, 0)), "the one with kind 0 does not exist")
	check_eq(grid.cell_count(), 2)


func test_a_cell_is_found_right_after_it_was_added_at_once() -> void:
	var grid := VillageGrid.new()
	var far := Vector2i(100, -100)
	check(not grid.has_cell(far), "the cell is not there yet")
	grid.add_cells(PackedInt32Array([100]), PackedInt32Array([-100]), PackedByteArray([4]))
	check(grid.has_cell(far), "the grid finds the new cell, though it just looked there")
	check_eq(grid.ground(far), 4)
	check(grid.place(1, far), "and a thing can stand on it")


func test_lists_of_different_length_stop_at_the_shortest() -> void:
	var grid := VillageGrid.new()
	var added := grid.add_cells(
		PackedInt32Array([0, 1, 2]), PackedInt32Array([0, 0]), PackedByteArray([1, 1, 1])
	)
	check_eq(added, 2)
	check_eq(grid.cell_count(), 2)
