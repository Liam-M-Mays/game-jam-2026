extends GameTest
## Checks the grid of a village: cells, ground, placing and removing things,
## and the chunks. The rules are the ones of the jam game, see issue #60.

const WOOD := 1
const TREE := 11
const ROCK := 12
const HUT := 13
const BARN := 21

var _grid: VillageGrid


## Lays a block of 10 by 10 cells for every test.
func before_each() -> void:
	_grid = VillageGrid.new()
	for cell in GridLayout.block(Vector2i(0, 0), Vector2i(10, 10)):
		_grid.add_cell(cell)


func test_cell_at_a_position_gives_the_cell() -> void:
	check_eq(_grid.cell_at(Vector2(0, 0)), Vector2i(0, 0))
	check_eq(_grid.cell_at(Vector2(31, 10)), Vector2i(3, 2))
	check_eq(_grid.cell_at(Vector2(33.4, 11.9)), Vector2i(3, 2))
	check_eq(_grid.cell_at(GridLayout.position_of(Vector2i(9, 9))), Vector2i(9, 9))


func test_a_point_off_the_map_gives_no_cell() -> void:
	check_eq(_grid.cell_at(Vector2(-20, 0)), GridLayout.NO_CELL)
	check_eq(_grid.cell_at(GridLayout.position_of(Vector2i(10, 0))), GridLayout.NO_CELL)
	check_eq(_grid.cell_at(GridLayout.position_of(Vector2i(0, 10))), GridLayout.NO_CELL)
	check_eq(_grid.cell_at(Vector2(100000, 100000)), GridLayout.NO_CELL)


func test_a_point_over_a_missing_cell_gives_no_cell() -> void:
	var grid := VillageGrid.new()
	for cell in GridLayout.block(Vector2i(0, 0), Vector2i(5, 5)):
		if cell != Vector2i(2, 2):
			grid.add_cell(cell)
	check_eq(grid.cell_count(), 24)
	check(not grid.has_cell(Vector2i(2, 2)), "the hole is not a cell")
	check_eq(grid.cell_at(GridLayout.position_of(Vector2i(2, 2))), GridLayout.NO_CELL)
	check_eq(grid.cell_at(GridLayout.position_of(Vector2i(2, 1))), Vector2i(2, 1))


func test_a_cell_stores_its_ground_kind() -> void:
	check_eq(_grid.ground(Vector2i(4, 4)), VillageGrid.PLAIN_GROUND)
	check(_grid.add_cell(Vector2i(4, 4), 7), "the ground kind of a cell can change")
	check_eq(_grid.ground(Vector2i(4, 4)), 7)
	check_eq(_grid.cell_count(), 100)
	check_eq(_grid.ground(Vector2i(40, 40)), VillageGrid.NO_GROUND)
	check(not _grid.add_cell(Vector2i(40, 40), 0), "ground kind 0 means no cell")
	check(not _grid.add_cell(Vector2i(40, 40), 256), "a ground kind is at most 255")
	check(not _grid.has_cell(Vector2i(40, 40)), "a refused cell is not added")


func test_a_cell_in_the_middle_has_six_neighbours() -> void:
	var want: Array[Vector2i] = [
		Vector2i(6, 5),
		Vector2i(4, 5),
		Vector2i(5, 6),
		Vector2i(5, 4),
		Vector2i(6, 4),
		Vector2i(4, 6),
	]
	check_eq(_grid.neighbours(Vector2i(5, 5)), want)


func test_a_cell_at_the_edge_only_has_the_neighbours_that_exist() -> void:
	var corner: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	check_eq(_grid.neighbours(Vector2i(0, 0)), corner)
	var far_corner: Array[Vector2i] = [Vector2i(8, 9), Vector2i(9, 8)]
	check_eq(_grid.neighbours(Vector2i(9, 9)), far_corner)
	check_eq(_grid.neighbours(Vector2i(9, 0)).size(), 3)


func test_a_cell_holds_at_most_one_thing() -> void:
	check(_grid.place(TREE, Vector2i(3, 3)), "an empty cell takes a thing")
	check(not _grid.place(ROCK, Vector2i(3, 3)), "a taken cell refuses a second thing")
	check_eq(_grid.occupant(Vector2i(3, 3)), TREE)
	check(_grid.thing_cells(ROCK).is_empty(), "the refused thing is not on the grid")


func test_free_cells_for_a_footprint_count_right_and_down_from_the_anchor() -> void:
	var want: Array[Vector2i] = [
		Vector2i(2, 5),
		Vector2i(3, 5),
		Vector2i(4, 5),
		Vector2i(2, 6),
		Vector2i(3, 6),
		Vector2i(4, 6),
	]
	check_eq(_grid.free_cells(Vector2i(2, 5), 3, 2), want)
	check_eq(_grid.free_cells(Vector2i(2, 5)), [Vector2i(2, 5)] as Array[Vector2i])


func test_a_footprint_with_one_missing_cell_is_refused_whole() -> void:
	check(_grid.free_cells(Vector2i(8, 0), 3, 1).is_empty(), "it runs off the right edge")
	check(_grid.free_cells(Vector2i(0, 9), 1, 2).is_empty(), "it runs off the bottom edge")
	check(not _grid.place(HUT, Vector2i(8, 8), 3, 3), "a thing that does not fit is refused")
	for cell in GridLayout.block(Vector2i(8, 8), Vector2i(2, 2)):
		check_eq(_grid.occupant(cell), VillageGrid.NOTHING, "no cell was marked")


func test_a_footprint_with_one_taken_cell_is_refused_whole() -> void:
	_grid.place(TREE, Vector2i(4, 4))
	check(_grid.free_cells(Vector2i(3, 3), 2, 2).is_empty(), "the tree is in the footprint")
	check(not _grid.place(HUT, Vector2i(3, 3), 2, 2), "the hut is refused")
	for cell: Vector2i in [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4)]:
		check_eq(_grid.occupant(cell), VillageGrid.NOTHING, "no cell was marked")
	check_eq(_grid.occupant(Vector2i(4, 4)), TREE)


func test_a_footprint_is_1_to_4_cells_wide_and_deep_and_1_by_1_when_not_named() -> void:
	check(_grid.place(TREE, Vector2i(0, 0)), "a thing with no footprint named is placed")
	check_eq(_grid.thing_cells(TREE), [Vector2i(0, 0)] as Array[Vector2i])
	check(_grid.place(HUT, Vector2i(2, 2), 4, 4), "4 by 4 is the biggest footprint")
	check_eq(_grid.thing_cells(HUT).size(), 16)
	check(not _grid.place(ROCK, Vector2i(0, 7), 5, 1), "5 wide is refused")
	check(not _grid.place(ROCK, Vector2i(0, 7), 1, 5), "5 deep is refused")
	check(not _grid.place(ROCK, Vector2i(0, 7), 0, 1), "0 wide is refused")
	check(not _grid.place(ROCK, Vector2i(0, 7), 1, 0), "0 deep is refused")
	check(_grid.free_cells(Vector2i(0, 7), 5, 1).is_empty(), "5 wide has no free cells")


func test_a_placed_thing_stands_on_its_anchor_cell_and_marks_all_its_cells() -> void:
	check(_grid.place(HUT, Vector2i(3, 2), 3, 2), "the hut fits")
	check_eq(_grid.thing_position(HUT), GridLayout.position_of(Vector2i(3, 2)))
	check_eq(_grid.thing_position(HUT), Vector2(31, 10))
	check_eq(_grid.thing_cells(HUT), GridLayout.footprint(Vector2i(3, 2), 3, 2))
	for cell in GridLayout.footprint(Vector2i(3, 2), 3, 2):
		check_eq(_grid.occupant(cell), HUT)
	check_eq(_grid.occupant(Vector2i(6, 2)), VillageGrid.NOTHING)
	check_eq(_grid.occupant(Vector2i(3, 4)), VillageGrid.NOTHING)
	check_eq(_grid.occupant(Vector2i(2, 2)), VillageGrid.NOTHING)


func test_a_thing_cannot_be_placed_twice_or_without_an_id() -> void:
	check(_grid.place(TREE, Vector2i(1, 1)), "the tree is placed")
	check(not _grid.place(TREE, Vector2i(5, 5)), "the same thing cannot stand in two places")
	check_eq(_grid.occupant(Vector2i(5, 5)), VillageGrid.NOTHING)
	check(not _grid.place(0, Vector2i(5, 5)), "id 0 means nothing")
	check(not _grid.place(-4, Vector2i(5, 5)), "an id is above zero")


func test_removing_a_thing_frees_its_cells_and_forgets_it() -> void:
	_grid.place(HUT, Vector2i(3, 2), 3, 2)
	var freed := _grid.remove(HUT)
	check_eq(freed, GridLayout.footprint(Vector2i(3, 2), 3, 2))
	for cell in freed:
		check_eq(_grid.occupant(cell), VillageGrid.NOTHING)
	check(_grid.thing_cells(HUT).is_empty(), "the hut is forgotten")
	check(_grid.remove(HUT).is_empty(), "it cannot be removed twice")
	check(_grid.place(ROCK, Vector2i(4, 3)), "a freed cell takes a new thing")
	check(_grid.place(HUT, Vector2i(0, 0)), "a removed thing can be placed again")


func test_the_grid_works_across_chunk_edges_and_below_zero() -> void:
	var grid := VillageGrid.new()
	for cell in GridLayout.block(Vector2i(-20, -20), Vector2i(60, 60)):
		grid.add_cell(cell)
	check_eq(grid.cell_count(), 3600)
	check(grid.place(HUT, Vector2i(14, 14), 4, 4), "a hut over four chunks")
	check(grid.place(TREE, Vector2i(-17, -1), 3, 2), "a tree across zero")
	for cell in GridLayout.footprint(Vector2i(14, 14), 4, 4):
		check_eq(grid.occupant(cell), HUT)
	for cell in GridLayout.footprint(Vector2i(-17, -1), 3, 2):
		check_eq(grid.occupant(cell), TREE)
	check_eq(grid.occupant(Vector2i(-18, -1)), VillageGrid.NOTHING)
	check_eq(grid.occupant(Vector2i(13, 14)), VillageGrid.NOTHING)
	check_eq(grid.neighbours(Vector2i(-16, 16)).size(), 6)
	check_eq(grid.cell_at(GridLayout.position_of(Vector2i(-20, -20))), Vector2i(-20, -20))
	check_eq(grid.cell_at(GridLayout.position_of(Vector2i(-21, -20))), GridLayout.NO_CELL)
	grid.drops.add(Vector2i(-1, -1), WOOD)
	grid.drops.add(Vector2i(15, -1), WOOD, 2)
	check_eq(grid.drops.count_at(Vector2i(-1, -1), WOOD), 1)
	check_eq(grid.drops.count_at(Vector2i(15, -1), WOOD), 2)
	check_eq(grid.drops.count_at(Vector2i(-1, 15), WOOD), 0)
	check_eq(grid.remove(HUT).size(), 16)
	check(grid.free_cells(Vector2i(14, 14), 4, 4).size() == 16, "the four chunks are free again")


func test_chunks_are_16_by_16_and_handle_cells_below_zero() -> void:
	check_eq(GridChunk.SIZE, 16)
	check_eq(GridChunk.key_of(Vector2i(0, 0)), Vector2i(0, 0))
	check_eq(GridChunk.key_of(Vector2i(15, 15)), Vector2i(0, 0))
	check_eq(GridChunk.key_of(Vector2i(16, 15)), Vector2i(1, 0))
	check_eq(GridChunk.key_of(Vector2i(-1, -16)), Vector2i(-1, -1))
	check_eq(GridChunk.key_of(Vector2i(-17, 31)), Vector2i(-2, 1))
	check_eq(GridChunk.index_of(Vector2i(0, 0)), 0)
	check_eq(GridChunk.index_of(Vector2i(15, 15)), 255)
	check_eq(GridChunk.index_of(Vector2i(-1, -1)), 255)
	check_eq(GridChunk.index_of(Vector2i(17, 2)), 33)


func test_two_grids_with_the_same_content_have_the_same_snapshot() -> void:
	var other := VillageGrid.new()
	for cell in GridLayout.block(Vector2i(0, 0), Vector2i(10, 10)):
		other.add_cell(cell)
	for grid: VillageGrid in [_grid, other]:
		grid.place(HUT, Vector2i(2, 2), 2, 2)
		grid.reserve(GridLayout.block(Vector2i(6, 6), Vector2i(2, 2)), BARN)
		grid.drops.add(Vector2i(1, 1), WOOD, 3)
	check_eq(_grid.snapshot(), other.snapshot())
	check_eq(_grid.snapshot().hash(), other.snapshot().hash())
	other.drops.take(Vector2i(1, 1), WOOD)
	check(_grid.snapshot() != other.snapshot(), "one drop less is a different grid")
