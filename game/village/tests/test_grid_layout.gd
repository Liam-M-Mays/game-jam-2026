extends GameTest
## Checks the maths of the slanted grid against the numbers of the jam game.
##
## The jam numbers are in issue #60, under "Must keep from the jam game", and
## come from [code]assets/Scripts/Env/grid.gd[/code].

## The cell scale of the jam game: one art pixel was 10 grid units.
const JAM_CELL_SCALE := 10.0
## The sprite offset of the jam cell, in art pixels.
const JAM_CELL_OFFSET := Vector2(-0.5, 0.0)


func test_a_cell_sits_at_x7_plus_y5_and_y5_art_pixels() -> void:
	check_eq(GridLayout.position_of(Vector2i(0, 0)), Vector2(0, 0))
	check_eq(GridLayout.position_of(Vector2i(1, 0)), Vector2(7, 0))
	check_eq(GridLayout.position_of(Vector2i(0, 1)), Vector2(5, 5))
	check_eq(GridLayout.position_of(Vector2i(3, 2)), Vector2(31, 10))
	check_eq(GridLayout.position_of(Vector2i(-2, -3)), Vector2(-29, -15))


func test_a_cell_is_7_wide_and_5_tall_and_each_row_shifts_5_sideways() -> void:
	var cell := Vector2i(12, 9)
	var here := GridLayout.position_of(cell)
	check_eq(GridLayout.position_of(cell + Vector2i(1, 0)) - here, Vector2(7, 0))
	check_eq(GridLayout.position_of(cell + Vector2i(0, 1)) - here, Vector2(5, 5))


func test_the_positions_match_the_jam_formula_at_cell_scale_10() -> void:
	for x in range(-6, 50, 7):
		for y in range(-6, 50, 7):
			var jam := Vector2((x * 7 + y * 5) * JAM_CELL_SCALE, y * 5 * JAM_CELL_SCALE)
			check_eq(GridLayout.position_of(Vector2i(x, y)) * JAM_CELL_SCALE, jam)


func test_a_cell_has_the_six_neighbours_of_the_jam_game() -> void:
	var want: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
	]
	check_eq(GridLayout.NEIGHBOURS, want)


func test_distance_is_counted_the_hex_way() -> void:
	var from := Vector2i(4, 4)
	check_eq(GridLayout.distance(from, from), 0)
	for offset in GridLayout.NEIGHBOURS:
		check_eq(GridLayout.distance(from, from + offset), 1)
	check_eq(GridLayout.distance(from, from + Vector2i(1, 1)), 2)
	check_eq(GridLayout.distance(from, from + Vector2i(-1, -1)), 2)
	check_eq(GridLayout.distance(from, from + Vector2i(3, -1)), 3)
	check_eq(GridLayout.distance(from, from + Vector2i(-2, 5)), 5)
	check_eq(GridLayout.distance(Vector2i(0, 0), Vector2i(3, 4)), 7)


func test_distance_matches_the_jam_formula() -> void:
	for dx in range(-6, 7):
		for dy in range(-6, 7):
			@warning_ignore("integer_division")
			var jam := (absi(dx) + absi(dy) + absi(dx + dy)) / 2
			check_eq(GridLayout.distance(Vector2i(2, -3), Vector2i(2 + dx, -3 + dy)), jam)
			check_eq(GridLayout.distance(Vector2i(2 + dx, -3 + dy), Vector2i(2, -3)), jam)


func test_the_middle_of_a_cell_maps_to_that_cell() -> void:
	for x in range(-5, 30, 3):
		for y in range(-5, 30, 3):
			var cell := Vector2i(x, y)
			var middle := GridLayout.position_of(cell) + GridLayout.CELL_MIDDLE
			check_eq(GridLayout.cell_under(middle), cell)
			check_eq(GridLayout.cell_under(GridLayout.position_of(cell)), cell)


func test_the_lookup_is_centred_half_an_art_pixel_left_of_the_cell_position() -> void:
	check_eq(GridLayout.CELL_MIDDLE, JAM_CELL_OFFSET)
	var cell := Vector2i(6, 4)
	var middle := GridLayout.position_of(cell) + GridLayout.CELL_MIDDLE
	check_eq(GridLayout.cell_under(middle + Vector2(3.4, 0)), cell)
	check_eq(GridLayout.cell_under(middle + Vector2(-3.4, 0)), cell)
	check_eq(GridLayout.cell_under(middle + Vector2(3.6, 0)), cell + Vector2i(1, 0))
	check_eq(GridLayout.cell_under(middle + Vector2(-3.6, 0)), cell + Vector2i(-1, 0))
	check_eq(GridLayout.cell_under(middle + Vector2(0, 2.4)), cell)
	check_eq(GridLayout.cell_under(middle + Vector2(0, -2.4)), cell)
	check_eq(GridLayout.cell_under(middle + Vector2(5, 2.6)), cell + Vector2i(0, 1))
	check_eq(GridLayout.cell_under(middle + Vector2(-5, -2.6)), cell + Vector2i(0, -1))


func test_a_point_maps_to_the_same_cell_as_in_the_jam_game() -> void:
	var points := 0
	var x := -60.031
	while x < 160.0:
		var y := -40.071
		while y < 120.0:
			var point := Vector2(x, y)
			check_eq(GridLayout.cell_under(point), _jam_coords_at(point * JAM_CELL_SCALE))
			points += 1
			y += 1.37
		x += 1.93
	check(points > 10000, "the sweep should cover more than 10,000 points")


func test_a_footprint_counts_right_for_width_and_down_for_depth() -> void:
	var want: Array[Vector2i] = [
		Vector2i(5, 2),
		Vector2i(6, 2),
		Vector2i(7, 2),
		Vector2i(5, 3),
		Vector2i(6, 3),
		Vector2i(7, 3),
	]
	check_eq(GridLayout.footprint(Vector2i(5, 2), 3, 2), want)
	check_eq(GridLayout.footprint(Vector2i(5, 2)), [Vector2i(5, 2)] as Array[Vector2i])


func test_a_footprint_is_between_1_and_4_wide_and_deep() -> void:
	check_eq(GridLayout.MIN_FOOTPRINT, 1)
	check_eq(GridLayout.MAX_FOOTPRINT, 4)
	for width in range(-1, 7):
		for depth in range(-1, 7):
			var fits := width >= 1 and width <= 4 and depth >= 1 and depth <= 4
			check_eq(GridLayout.is_footprint(width, depth), fits, "%d x %d" % [width, depth])


func test_the_offsets_within_one_step_are_the_cell_and_its_six_neighbours() -> void:
	var want: Array[Vector2i] = [
		Vector2i(-1, 0),
		Vector2i(-1, 1),
		Vector2i(0, -1),
		Vector2i(0, 0),
		Vector2i(0, 1),
		Vector2i(1, -1),
		Vector2i(1, 0),
	]
	check_eq(GridLayout.offsets_within(1), want)
	check_eq(GridLayout.offsets_within(0), [Vector2i(0, 0)] as Array[Vector2i])
	check_eq(GridLayout.offsets_within(2).size(), 19)
	check_eq(GridLayout.offsets_within(3).size(), 37)


## The point lookup of the jam game, copied from grid.gd lines 121 to 125,
## with the cell scale and the cell offset of cell.tscn.
func _jam_coords_at(local_pos: Vector2) -> Vector2i:
	var cell_scale := Vector2(JAM_CELL_SCALE, JAM_CELL_SCALE)
	var pos: Vector2 = local_pos - JAM_CELL_OFFSET * cell_scale
	var y := roundi(pos.y / (cell_scale.y * 5))
	var x := roundi((pos.x - 5 * y * cell_scale.x) / (cell_scale.x * 7))
	return Vector2i(x, y)
