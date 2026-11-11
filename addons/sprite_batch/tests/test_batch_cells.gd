extends GameTest
## Checks the cell maths with made-up numbers. The game's own grid numbers
## are checked on the game side.

const STEP := 40.0
const SLANT := 12.0
const ROW_HEIGHT := 30.0
const MIDDLE := Vector2(-3.0, 2.0)
const ORIGIN := Vector2(100.0, -60.0)


func test_a_cell_is_where_its_numbers_put_it() -> void:
	var cells := BatchCells.new(STEP, SLANT, ROW_HEIGHT, MIDDLE, ORIGIN)
	for x in range(-4, 9, 3):
		for y in range(-4, 9, 3):
			var want := ORIGIN + Vector2(x * STEP + y * SLANT, y * ROW_HEIGHT)
			check_eq(cells.position_of(Vector2i(x, y)), want)


func test_a_cell_finds_itself() -> void:
	var cells := BatchCells.new(STEP, SLANT, ROW_HEIGHT, MIDDLE, ORIGIN)
	for x in range(-20, 40):
		for y in range(-20, 40):
			var cell := Vector2i(x, y)
			if cells.cell_at(cells.position_of(cell)) != cell:
				fail("cell %s was not found at its own position" % cell)
	check(true)


func test_a_point_belongs_to_the_cell_whose_middle_is_nearest() -> void:
	var cells := BatchCells.new(STEP, SLANT, ROW_HEIGHT, MIDDLE, ORIGIN)
	var cell := Vector2i(-3, 5)
	var middle := cells.position_of(cell) + MIDDLE
	check_eq(cells.cell_at(middle + Vector2(STEP * 0.49, ROW_HEIGHT * 0.49)), cell)
	check_eq(cells.cell_at(middle - Vector2(STEP * 0.49, ROW_HEIGHT * 0.49)), cell)
	check_eq(cells.cell_at(middle + Vector2(STEP * 0.51, 0.0)), cell + Vector2i(1, 0))
	check_eq(cells.cell_at(middle + Vector2(0.0, ROW_HEIGHT * 0.51)).y, cell.y + 1)


func test_a_point_exactly_between_two_cells_goes_right_on_both_sides_of_zero() -> void:
	var cells := BatchCells.new(STEP, SLANT, ROW_HEIGHT, Vector2.ZERO, Vector2.ZERO)
	# Half a cell right of cell 0, and half a cell left of it.
	check_eq(cells.cell_at(Vector2(STEP * 0.5, 0.0)), Vector2i(1, 0))
	check_eq(cells.cell_at(Vector2(-STEP * 0.5, 0.0)), Vector2i(0, 0))
	check_eq(cells.cell_at(Vector2(-STEP * 1.5, 0.0)), Vector2i(-1, 0))
	check_eq(cells.cell_at(Vector2(STEP * 1.5, 0.0)), Vector2i(2, 0))


func test_a_point_exactly_between_two_rows_goes_down_on_both_sides_of_zero() -> void:
	var cells := BatchCells.new(STEP, 0.0, ROW_HEIGHT, Vector2.ZERO, Vector2.ZERO)
	check_eq(cells.cell_at(Vector2(0.0, ROW_HEIGHT * 0.5)).y, 1)
	check_eq(cells.cell_at(Vector2(0.0, -ROW_HEIGHT * 0.5)).y, 0)
	check_eq(cells.cell_at(Vector2(0.0, -ROW_HEIGHT * 1.5)).y, -1)
	check_eq(cells.cell_at(Vector2(0.0, ROW_HEIGHT * 1.5)).y, 2)


func test_a_band_runs_from_its_row_to_the_next() -> void:
	var cells := BatchCells.new(STEP, SLANT, ROW_HEIGHT, MIDDLE, ORIGIN)
	for row in range(-3, 4):
		var line := cells.row_y(row)
		check_eq(cells.band_at(line), row)
		check_eq(cells.band_at(line + ROW_HEIGHT - 0.01), row)
		check_eq(cells.band_at(line - 0.01), row - 1)
		check_eq(cells.row_of(Vector2i(7, row)), row)
		check_near(cells.position_of(Vector2i(7, row)).y, line)


func test_the_numbers_cannot_be_changed_afterwards() -> void:
	var cells := BatchCells.new(STEP, SLANT, ROW_HEIGHT, MIDDLE, ORIGIN)
	var before := cells.position_of(Vector2i(3, 4))
	cells.step_x = 999.0
	cells.slant_x = 999.0
	cells.row_height = 999.0
	cells.middle = Vector2(999.0, 999.0)
	cells.origin = Vector2(999.0, 999.0)
	check_eq(cells.step_x, STEP)
	check_eq(cells.slant_x, SLANT)
	check_eq(cells.row_height, ROW_HEIGHT)
	check_eq(cells.middle, MIDDLE)
	check_eq(cells.origin, ORIGIN)
	check_eq(cells.position_of(Vector2i(3, 4)), before)
	check_eq(cells.cell_at(before), Vector2i(3, 4))
