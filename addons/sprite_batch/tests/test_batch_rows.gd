extends GameTest
## Checks the things that stand still: their drawing order, and that a change
## only rebuilds the row it happens in.

const COLUMNS := 20
const ROWS := 20
const NEW_THING := 9999

var _rows: BatchRows
var _cells := BatchTestKit.cells()
var _small := 0
var _tall := 0


func before_each() -> void:
	var atlas := BatchTestKit.atlas()
	_small = atlas.find(BatchTestKit.SMALL)
	_tall = atlas.find(BatchTestKit.TALL)
	_rows = BatchRows.new(_cells, atlas, Rect2(0.0, 0.0, 2600.0, 1100.0), BatchTestKit.ART_SCALE)


func test_adding_changing_and_removing_one_thing_only_rebuilds_its_own_row() -> void:
	_fill_all_but(Vector2i(10, 7))
	var untouched := _assembled()
	var before := _versions()
	_rows.add_thing(NEW_THING, Vector2i(10, 7), _small, BatchTestKit.SMALL_OFFSET)
	before = _check_only_row_rebuilt(before, 7, "adding")
	_rows.change_thing(NEW_THING, _tall, BatchTestKit.TALL_OFFSET)
	before = _check_only_row_rebuilt(before, 7, "changing")
	_rows.tint_thing(NEW_THING, Color.RED)
	before = _check_only_row_rebuilt(before, 7, "tinting")
	_rows.remove_thing(NEW_THING)
	_check_only_row_rebuilt(before, 7, "removing")
	check(_assembled() == untouched, "after the thing is gone the buffer is what it was")


func test_a_change_leaves_the_other_rows_as_they_were() -> void:
	_fill_all_but(Vector2i(10, 7))
	var others_before := _rows_without(7)
	_rows.add_thing(NEW_THING, Vector2i(10, 7), _tall, BatchTestKit.TALL_OFFSET)
	check(_rows_without(7) == others_before, "adding changed another row")
	_rows.remove_thing(NEW_THING)
	check(_rows_without(7) == others_before, "removing changed another row")


func test_a_new_thing_is_drawn_behind_the_thing_to_its_left() -> void:
	# The columns in the order the things are placed. Every thing is in row 4.
	var placed: Array[int] = [5, 2, 9, 0, 7, 3]
	for column in placed:
		_rows.add_thing(column, Vector2i(column, 4), _small, BatchTestKit.SMALL_OFFSET)
	# The first one is drawn first, so it is at the back: the right-most thing.
	check_eq(_rows.things_in_row(4), PackedInt32Array([9, 7, 5, 3, 2, 0]))
	var drawn := BatchTestKit.read(_assembled())
	for index in range(1, drawn.size()):
		var left_of_last: bool = drawn[index]["middle"].x < drawn[index - 1]["middle"].x
		check(left_of_last, "sprite %d is not left of the one drawn before it" % index)


func test_rows_are_drawn_back_to_front() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var cells: Array[Vector2i] = []
	for row in ROWS:
		for column in COLUMNS:
			cells.append(Vector2i(column, row))
	for index in range(cells.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var held := cells[index]
		cells[index] = cells[other]
		cells[other] = held
	for index in cells.size():
		_rows.add_thing(index, cells[index], _small, BatchTestKit.SMALL_OFFSET)
	var drawn := BatchTestKit.read(_assembled())
	check_eq(drawn.size(), ROWS * COLUMNS)
	var out_of_order := 0
	for index in range(1, drawn.size()):
		var this: Vector2 = drawn[index]["middle"]
		var last: Vector2 = drawn[index - 1]["middle"]
		# A lower row is drawn later. Inside one row, further left is drawn later.
		if this.y < last.y or (this.y == last.y and this.x >= last.x):
			out_of_order += 1
	check_eq(out_of_order, 0, "sprites that are drawn too early")


func test_a_second_thing_on_a_cell_is_drawn_in_front_of_the_first() -> void:
	_rows.add_thing(1, Vector2i(3, 3), _small)
	_rows.add_thing(2, Vector2i(3, 3), _small)
	check_eq(_rows.things_in_row(3), PackedInt32Array([1, 2]))


func test_a_sprite_is_drawn_at_ten_times_its_size() -> void:
	check_eq(_rows.pixel_scale, BatchTestKit.ART_SCALE)
	_rows.add_thing(1, Vector2i(4, 6), _tall, Vector2(3.0, -13.0), Color(0.5, 0.25, 1.0, 0.75))
	var sprite := BatchTestKit.read(_assembled())[0]
	check_eq(sprite["size"], Vector2(60.0, 300.0))
	check_eq(sprite["middle"], _cells.position_of(Vector2i(4, 6)) + Vector2(30.0, -130.0))
	check_eq(sprite["tint"], Color(0.5, 0.25, 1.0, 0.75))
	check_eq(sprite["sprite"], _tall)
	check_eq(sprite["numbers"].w, BatchRows.PLAIN)


func test_a_thing_is_found_by_any_cell_it_takes() -> void:
	var footprint: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 5), Vector2i(5, 6)]
	_rows.add_thing(1, Vector2i(5, 5), _tall, BatchTestKit.TALL_OFFSET, Color.WHITE, footprint)
	_rows.add_thing(2, Vector2i(9, 9), _small)
	for cell in footprint:
		check_eq(_rows.thing_on_cell(cell), 1)
	check_eq(_rows.thing_on_cell(Vector2i(9, 9)), 2)
	check_eq(_rows.thing_on_cell(Vector2i(7, 5)), BatchRows.NO_THING)
	check_eq(_rows.thing_count(), 2)
	_rows.remove_thing(1)
	check(not _rows.has_thing(1), "the thing is gone")
	for cell in footprint:
		check_eq(_rows.thing_on_cell(cell), BatchRows.NO_THING)


func test_the_cell_maths_and_the_art_scale_cannot_be_swapped_afterwards() -> void:
	# Each of these two writes is refused and logs an error, which shows as a
	# warning in the test run.
	_rows.cells = BatchTestKit.cells(Vector2(500.0, 500.0))
	_rows.pixel_scale = 3.0
	check_eq(_rows.cells, _cells)
	check_eq(_rows.pixel_scale, BatchTestKit.ART_SCALE)
	_rows.add_thing(1, Vector2i(2, 2), _small)
	check_eq(BatchTestKit.read(_assembled())[0]["middle"], _cells.position_of(Vector2i(2, 2)))
	check_eq(BatchTestKit.read(_assembled())[0]["size"], Vector2(40.0, 40.0))


func test_a_thing_cannot_have_the_number_that_means_no_thing() -> void:
	# The refusal also logs an error, which shows as a warning in the test run.
	check(not _rows.add_thing(BatchRows.NO_THING, Vector2i(3, 3), _small), "-1 is refused")
	check_eq(_rows.thing_count(), 0)
	check_eq(_rows.pick(_cells.position_of(Vector2i(3, 3))), BatchRows.NO_THING)
	check(_rows.add_thing(-2, Vector2i(3, 3), _small), "another negative number is fine")
	check_eq(_rows.pick(_cells.position_of(Vector2i(3, 3))), -2)


func test_a_cell_with_two_things_finds_the_one_that_is_left() -> void:
	var cell := Vector2i(3, 3)
	_rows.add_thing(1, cell, _small)
	_rows.add_thing(2, cell, _small)
	check_eq(_rows.thing_on_cell(cell), 2, "the newest thing")
	_rows.remove_thing(2)
	check_eq(_rows.thing_on_cell(cell), 1, "the older thing, after the newer one left")
	_rows.add_thing(3, cell, _small)
	_rows.add_thing(4, cell, _small)
	_rows.remove_thing(3)
	check_eq(_rows.thing_on_cell(cell), 4, "the newest, after one in the middle left")
	_rows.remove_thing(4)
	check_eq(_rows.thing_on_cell(cell), 1)
	_rows.remove_thing(1)
	check_eq(_rows.thing_on_cell(cell), BatchRows.NO_THING)


func _fill_all_but(skip: Vector2i) -> void:
	for row in ROWS:
		for column in COLUMNS:
			if Vector2i(column, row) != skip:
				var cell := Vector2i(column, row)
				_rows.add_thing(row * 100 + column, cell, _small, BatchTestKit.SMALL_OFFSET)


func _assembled() -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	_rows.assemble(BatchTestKit.everything(), buffer)
	return buffer


func _versions() -> Array[int]:
	var versions: Array[int] = []
	for row in range(-2, ROWS + 4):
		versions.append(_rows.row_version(row))
	return versions


## Checks that only [param row] was rebuilt since [param before], once.
## Returns the versions as they are now.
func _check_only_row_rebuilt(before: Array[int], row: int, what: String) -> Array[int]:
	var now := _versions()
	for index in now.size():
		var want := 1 if index - 2 == row else 0
		check_eq(now[index] - before[index], want, "%s: rebuilds of row %d" % [what, index - 2])
	return now


## Returns what is drawn for every row but [param skip], as ids in drawing order.
func _rows_without(skip: int) -> Array[PackedInt32Array]:
	var kept: Array[PackedInt32Array] = []
	for row in ROWS:
		if row != skip:
			kept.append(_rows.things_in_row(row))
	return kept
