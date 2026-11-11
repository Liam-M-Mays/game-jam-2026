extends GameTest
## Checks that the cell maths is the slanted six-neighbour grid of the jam game.

## The six neighbours of a cell in the jam game, from assets/Scripts/Env/grid.gd.
const JAM_NEIGHBOURS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, -1), Vector2i(-1, 1),
]


func test_a_cell_is_where_the_jam_grid_puts_it() -> void:
	var cells := BatchCells.new()
	# The jam game: ((x * 7 + y * 5) * 10, y * 5 * 10), with a cell scale of 10.
	for x in range(-3, 50, 7):
		for y in range(-3, 50, 7):
			check_eq(cells.position_of(Vector2i(x, y)), Vector2((x * 7 + y * 5) * 10, y * 5 * 10))


func test_a_point_finds_the_cell_the_jam_grid_finds() -> void:
	var cells := BatchCells.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	for sample in 2000:
		var point := Vector2(rng.randf_range(-800.0, 6000.0), rng.randf_range(-800.0, 2600.0))
		check_eq(cells.cell_at(point), _jam_coords_at(point))


func test_a_cell_finds_itself() -> void:
	var cells := BatchCells.new()
	for x in range(-5, 50):
		for y in range(-5, 50):
			var cell := Vector2i(x, y)
			if cells.cell_at(cells.position_of(cell)) != cell:
				fail("cell %s was not found at its own position" % cell)
	check(true)


func test_the_six_nearest_cells_are_the_jam_neighbours() -> void:
	var cells := BatchCells.new()
	var home := Vector2i(10, 10)
	var around: Array[Vector2i] = []
	for x in range(-3, 4):
		for y in range(-3, 4):
			if x != 0 or y != 0:
				around.append(Vector2i(x, y))
	var here := cells.position_of(home)
	around.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var far_a := here.distance_to(cells.position_of(home + a))
		var far_b := here.distance_to(cells.position_of(home + b))
		return far_a < far_b)
	var nearest := around.slice(0, 6)
	for neighbour in JAM_NEIGHBOURS:
		check(nearest.has(neighbour), "%s is not one of the six nearest cells" % neighbour)


func test_a_band_runs_from_its_row_to_the_next() -> void:
	var cells := BatchCells.new()
	for row in range(-3, 4):
		var line := cells.row_y(row)
		check_eq(cells.band_at(line), row)
		check_eq(cells.band_at(line + cells.row_height - 0.01), row)
		check_eq(cells.band_at(line - 0.01), row - 1)
		check_eq(cells.row_of(Vector2i(7, row)), row)
		check_near(cells.position_of(Vector2i(7, row)).y, line)


func test_the_grid_can_start_somewhere_else() -> void:
	var cells := BatchCells.new()
	cells.origin = Vector2(1000.0, -300.0)
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(4, 9), Vector2i(-6, 2)]:
		check_eq(cells.cell_at(cells.position_of(cell)), cell)
	check_eq(cells.band_at(-300.0), 0)


## The jam game's own sum, from Grid._coords_at. The cell scale is 10 and the
## cell picture has an offset of (-0.5, 0).
func _jam_coords_at(point: Vector2) -> Vector2i:
	var cell_scale := Vector2(10.0, 10.0)
	var pos := point - Vector2(-0.5, 0.0) * cell_scale
	var y := roundi(pos.y / (cell_scale.y * 5))
	var x := roundi((pos.x - 5 * y * cell_scale.x) / (cell_scale.x * 7))
	return Vector2i(x, y)
