extends GameTest
## Checks the movers: they are drawn between two rows, a lower one is in
## front of a higher one, and each is drawn once however much it walks.

const WORLD := Rect2(0.0, 0.0, 4000.0, 2000.0)
const BOX := Vector2(30.0, 60.0)
const BOX_OFFSET := Vector2(0.0, -20.0)
## The fourth shader number the test gives its movers. A thing has 0 there.
const MOVER := 1.0

var _rows: BatchRows
var _cells := BatchTestKit.cells()
var _small := 0


func before_each() -> void:
	var atlas := BatchTestKit.atlas()
	_small = atlas.find(BatchTestKit.SMALL)
	_rows = BatchRows.new(_cells, atlas, WORLD, BatchTestKit.ART_SCALE, 500.0)
	_rows.shape_movers(BOX, BOX_OFFSET, 10.0)


func test_a_mover_is_drawn_between_its_row_and_the_next() -> void:
	for row in [3, 4, 5]:
		_rows.add_thing(row, Vector2i(2, row), _small, BatchTestKit.SMALL_OFFSET)
	_rows.resize_movers(1)
	_rows.place_mover(0, Vector2(300.0, _cells.row_y(4) + 10.0), Color.WHITE, _numbers(0))
	check_eq(_drawing_order(), ["thing 3", "thing 4", "mover 0", "thing 5"])


func test_a_mover_on_a_row_line_is_in_front_of_that_row() -> void:
	for row in [3, 4, 5]:
		_rows.add_thing(row, Vector2i(2, row), _small, BatchTestKit.SMALL_OFFSET)
	_rows.resize_movers(2)
	var spots := PackedVector2Array([
		Vector2(300.0, _cells.row_y(4)), Vector2(300.0, _cells.row_y(4) - 0.5),
	])
	_rows.place_mover(0, spots[0], Color.WHITE, _numbers(0))
	_rows.place_mover(1, spots[1], Color.WHITE, _numbers(1))
	var want := ["thing 3", "mover 1", "thing 4", "mover 0", "thing 5"]
	check_eq(_drawing_order(), want, "after placing")
	# Moving to the same spots must not change a band.
	_rows.move_movers(spots)
	check_eq(_drawing_order(), want, "after moving to the same spots")


func test_a_row_line_gives_the_same_band_when_placing_and_when_moving() -> void:
	# Row heights where dividing and multiplying by the inverse disagree. The
	# other grid numbers here are sample values.
	var atlas := BatchTestKit.atlas()
	for height: float in [49.0, 98.0, 103.0, 107.0, 161.0]:
		var cells := BatchCells.new(70.0, 50.0, height, Vector2.ZERO, Vector2.ZERO)
		var rows := BatchRows.new(cells, atlas, Rect2(0.0, 0.0, 4000.0, height * 40.0), 10.0)
		rows.shape_movers(BOX, BOX_OFFSET, 10.0)
		rows.resize_movers(30)
		var spots := PackedVector2Array()
		for row in 30:
			rows.add_thing(row, Vector2i(2, row), atlas.find(BatchTestKit.SMALL))
			spots.append(Vector2(300.0, cells.row_y(row)))
			rows.place_mover(row, spots[row], Color.WHITE, _numbers(row))
		var buffer := PackedFloat32Array()
		rows.assemble(BatchTestKit.everything(), buffer)
		var placed := BatchTestKit.read(buffer)
		rows.move_movers(spots)
		rows.assemble(BatchTestKit.everything(), buffer)
		check(BatchTestKit.read(buffer) == placed, "row height %s: a band changed" % height)
		# Each mover on a line comes right after the thing of that row.
		for row in 30:
			check_eq(placed[row * 2 + 1]["numbers"], _numbers(row), "row height %s" % height)


func test_a_lower_mover_is_in_front_of_a_higher_one_in_the_same_row_band() -> void:
	# Both stand between the lines of row 2 and row 3. The lower one came first.
	_rows.resize_movers(2)
	var line := _cells.row_y(2)
	_rows.place_mover(0, Vector2(300.0, line + 40.0), Color.WHITE, _numbers(0))
	_rows.place_mover(1, Vector2(310.0, line + 5.0), Color.WHITE, _numbers(1))
	check_eq(_drawing_order(), ["mover 1", "mover 0"])
	# They swap heights: the order follows.
	_rows.move_movers(PackedVector2Array([Vector2(300.0, line + 5.0), Vector2(310.0, line + 40.0)]))
	check_eq(_drawing_order(), ["mover 0", "mover 1"])
	# One art pixel apart is enough, also across a column line at x 500.
	_rows.move_movers(PackedVector2Array([Vector2(501.0, line + 22.0), Vector2(499.0, line + 12.0)]))
	check_eq(_drawing_order(), ["mover 1", "mover 0"])
	_rows.move_movers(PackedVector2Array([Vector2(501.0, line + 12.0), Vector2(499.0, line + 22.0)]))
	check_eq(_drawing_order(), ["mover 0", "mover 1"])


func test_a_pair_that_walks_down_or_up_together_keeps_the_lower_one_in_front() -> void:
	# Two overlapping movers, 8 pixels apart sideways and 4 pixels apart in
	# height: less than one art pixel. Mover 1 is the lower one. They walk
	# 200 pixels down and 200 pixels back up, at 100 pixels a second and 60
	# frames a second, through twenty thin bands each way.
	_rows.resize_movers(2)
	var spots := PackedVector2Array([Vector2(300.0, 203.0), Vector2(308.0, 207.0)])
	_rows.place_mover(0, spots[0], Color.WHITE, _numbers(0))
	_rows.place_mover(1, spots[1], Color.WHITE, _numbers(1))
	var step := Vector2(0.0, 100.0 / 60.0)
	var wrong_down := 0
	var wrong_up := 0
	for frame in 120:
		spots[0] += step
		spots[1] += step
		_rows.move_movers(spots)
		if _drawing_order() != ["mover 0", "mover 1"]:
			wrong_down += 1
	for frame in 120:
		spots[0] -= step
		spots[1] -= step
		_rows.move_movers(spots)
		if _drawing_order() != ["mover 0", "mover 1"]:
			wrong_up += 1
	check_eq(wrong_down, 0, "frames with the higher mover in front while walking down")
	check_eq(wrong_up, 0, "frames with the higher mover in front while walking up")


func test_a_standing_pair_is_drawn_by_height_whichever_was_placed_first() -> void:
	# The right-hand pair of the same_band picture: 4 pixels apart in height,
	# in one thin band. Mover 0 is the lower one.
	_rows.resize_movers(2)
	var line := _cells.row_y(2)
	var lower := Vector2(320.0, line + 16.0)
	var higher := Vector2(330.0, line + 12.0)
	_rows.place_mover(0, lower, Color.WHITE, _numbers(0))
	_rows.place_mover(1, higher, Color.WHITE, _numbers(1))
	check_eq(_drawing_order(), ["mover 1", "mover 0"], "the lower one was placed first")
	_rows.resize_movers(0)
	_rows.resize_movers(2)
	_rows.place_mover(1, higher, Color.WHITE, _numbers(1))
	_rows.place_mover(0, lower, Color.WHITE, _numbers(0))
	check_eq(_drawing_order(), ["mover 1", "mover 0"], "the higher one was placed first")
	# A third one goes between them, by height.
	_rows.resize_movers(3)
	_rows.place_mover(2, Vector2(325.0, line + 14.0), Color.WHITE, _numbers(2))
	check_eq(_drawing_order(), ["mover 1", "mover 2", "mover 0"])


func test_two_movers_keep_their_order_when_a_third_leaves() -> void:
	# Three movers in one thin band, less than one art pixel apart in height.
	_rows.resize_movers(4)
	var line := _cells.row_y(2)
	var spots := PackedVector2Array([
		Vector2(300.0, line + 12.0), Vector2(305.0, line + 14.0),
		Vector2(310.0, line + 16.0), Vector2(315.0, line + 18.0),
	])
	for index in spots.size():
		_rows.place_mover(index, spots[index], Color.WHITE, _numbers(index))
	check_eq(_drawing_order(), ["mover 0", "mover 1", "mover 2", "mover 3"])
	# The first one walks down into the next row band. The others did not move.
	spots[0] = Vector2(300.0, line + 70.0)
	_rows.move_movers(spots)
	check_eq(_drawing_order(), ["mover 1", "mover 2", "mover 3", "mover 0"])
	# One from the middle walks up and out.
	spots[2] = Vector2(310.0, line - 30.0)
	_rows.move_movers(spots)
	check_eq(_drawing_order(), ["mover 2", "mover 1", "mover 3", "mover 0"])
	# A look change and a dropped mover leave the order alone too.
	_rows.look_mover(3, Color.RED, _numbers(3))
	_rows.resize_movers(3)
	check_eq(_drawing_order(), ["mover 2", "mover 1", "mover 0"])


func test_a_mover_that_walks_down_moves_to_the_next_band() -> void:
	for row in [3, 4, 5]:
		_rows.add_thing(row, Vector2i(2, row), _small, BatchTestKit.SMALL_OFFSET)
	_rows.resize_movers(1)
	_rows.place_mover(0, Vector2(300.0, _cells.row_y(3) + 40.0), Color.WHITE, _numbers(0))
	check_eq(_drawing_order(), ["thing 3", "mover 0", "thing 4", "thing 5"])
	_rows.move_movers(PackedVector2Array([Vector2(300.0, _cells.row_y(4) + 5.0)]))
	check_eq(_drawing_order(), ["thing 3", "thing 4", "mover 0", "thing 5"])
	var mover := BatchTestKit.read(_assembled())[2]
	check_eq(mover["middle"], Vector2(300.0, _cells.row_y(4) + 5.0) + BOX_OFFSET)
	check_eq(mover["size"], BOX)


func test_every_mover_is_drawn_once_after_a_lot_of_walking() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 64
	var spots := _scatter(400, rng)
	for step in 120:
		for index in spots.size():
			var move := Vector2(rng.randf_range(-120.0, 120.0), rng.randf_range(-120.0, 120.0))
			spots[index] = (spots[index] + move).clamp(WORLD.position, WORLD.end - Vector2.ONE)
		_rows.move_movers(spots)
		if step % 20 == 19:
			_check_movers(spots, "after %d steps" % (step + 1))


func test_a_mover_outside_the_world_is_still_drawn_once() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 65
	var spots := _scatter(100, rng)
	for step in 40:
		for index in spots.size():
			spots[index] += Vector2(rng.randf_range(-400.0, 400.0), rng.randf_range(-400.0, 400.0))
		_rows.move_movers(spots)
	var seen := {}
	for sprite in BatchTestKit.read(_assembled()):
		var index := int(sprite["numbers"].y)
		check(not seen.has(index), "mover %d is drawn twice" % index)
		seen[index] = true
		check_eq(sprite["middle"], _as_stored(spots[index] + BOX_OFFSET))
	check_eq(seen.size(), spots.size())


func test_a_mover_above_or_below_the_world_is_drawn_when_the_view_looks_there() -> void:
	_rows.resize_movers(2)
	_rows.place_mover(0, Vector2(300.0, -400.0), Color.WHITE, _numbers(0))
	_rows.place_mover(1, Vector2(300.0, 2600.0), Color.WHITE, _numbers(1))
	var buffer := PackedFloat32Array()
	check_eq(_rows.assemble(Rect2(0.0, -700.0, 1920.0, 500.0), buffer), 1)
	check_eq(int(BatchTestKit.read(buffer)[0]["numbers"].y), 0)
	check_eq(_rows.assemble(Rect2(0.0, 2300.0, 1920.0, 500.0), buffer), 1)
	check_eq(int(BatchTestKit.read(buffer)[0]["numbers"].y), 1)
	# After walking further out they are still there.
	_rows.move_movers(PackedVector2Array([Vector2(350.0, -450.0), Vector2(350.0, 2650.0)]))
	check_eq(_rows.assemble(Rect2(0.0, -700.0, 1920.0, 500.0), buffer), 1)
	check_eq(BatchTestKit.read(buffer)[0]["middle"], Vector2(350.0, -450.0) + BOX_OFFSET)


func test_a_mover_that_was_not_placed_is_left_alone() -> void:
	_rows.resize_movers(3)
	_rows.place_mover(1, Vector2(1000.0, 1000.0), Color.WHITE, _numbers(1))
	# Movers 0 and 2 were never placed. Their positions are far outside the world.
	var spots := PackedVector2Array([
		Vector2(-2000.0, -20.0), Vector2(1010.0, 1005.0), Vector2(99999.0, 99999.0),
	])
	_rows.move_movers(spots)
	_rows.look_mover(0, Color.RED, _numbers(0))
	_rows.set_mover_number(2, 3, 2.0)
	var drawn := BatchTestKit.read(_assembled())
	check_eq(drawn.size(), 1)
	check_eq(int(drawn[0]["numbers"].y), 1)
	check_eq(drawn[0]["middle"], Vector2(1010.0, 1005.0) + BOX_OFFSET)


func test_a_new_look_reaches_the_right_mover() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 66
	var spots := _scatter(200, rng)
	for step in 30:
		for index in spots.size():
			var move := Vector2(rng.randf_range(-200.0, 200.0), rng.randf_range(-200.0, 200.0))
			spots[index] = (spots[index] + move).clamp(WORLD.position, WORLD.end - Vector2.ONE)
		_rows.move_movers(spots)
	_rows.look_mover(57, Color(0.25, 0.5, 0.75, 1.0), Vector4(2.0, 57.0, 0.5, 2.0))
	_rows.set_mover_number(120, 2, 0.5)
	for sprite in BatchTestKit.read(_assembled()):
		var index := int(sprite["numbers"].y)
		if index == 57:
			check_eq(sprite["tint"], Color(0.25, 0.5, 0.75, 1.0))
			check_eq(sprite["numbers"], Vector4(2.0, 57.0, 0.5, 2.0))
		elif index == 120:
			check_eq(sprite["numbers"], Vector4(float(_small), 120.0, 0.5, MOVER))
		elif sprite["numbers"] != _numbers(index) or sprite["tint"] != Color.WHITE:
			fail("mover %d changed its look" % index)


func test_dropped_movers_are_not_drawn() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 67
	var spots := _scatter(50, rng)
	_rows.resize_movers(20)
	check_eq(_rows.mover_count(), 20)
	spots.resize(20)
	_check_movers(spots, "after dropping 30 movers")
	_rows.resize_movers(25)
	_check_movers(spots, "new movers are not drawn until they are placed")


func _numbers(index: int) -> Vector4:
	return Vector4(float(_small), float(index), 0.0, MOVER)


func _scatter(count: int, rng: RandomNumberGenerator) -> PackedVector2Array:
	var spots := PackedVector2Array()
	_rows.resize_movers(count)
	for index in count:
		var spot := Vector2(rng.randf_range(0.0, WORLD.end.x), rng.randf_range(0.0, WORLD.end.y))
		spots.append(spot)
		_rows.place_mover(index, spot, Color.WHITE, _numbers(index))
	return spots


func _assembled() -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	_rows.assemble(BatchTestKit.everything(), buffer)
	return buffer


## Returns what is drawn, in order, as "thing <id>" and "mover <index>".
func _drawing_order() -> Array:
	var order := []
	for sprite in BatchTestKit.read(_assembled()):
		if sprite["numbers"].w == MOVER:
			order.append("mover %d" % int(sprite["numbers"].y))
		else:
			order.append("thing %d" % _cells.cell_at(sprite["middle"]).y)
	return order


## Checks that every mover is drawn exactly once, where it stands, and that
## the movers come out band after band.
func _check_movers(spots: PackedVector2Array, when: String) -> void:
	var seen := {}
	var last_band := -1000
	var wrong := 0
	for sprite in BatchTestKit.read(_assembled()):
		var index := int(sprite["numbers"].y)
		if seen.has(index) or index >= spots.size():
			wrong += 1
			continue
		seen[index] = true
		if sprite["middle"] != _as_stored(spots[index] + BOX_OFFSET):
			wrong += 1
		# Mover bands are one art pixel tall, and they come out top to bottom.
		var band := floori(spots[index].y / BatchTestKit.ART_SCALE)
		if band < last_band:
			wrong += 1
		last_band = band
	check_eq(wrong, 0, "%s: movers drawn twice, in the wrong place or in the wrong band" % when)
	check_eq(seen.size(), spots.size(), "%s: movers drawn" % when)


## The buffer holds small numbers, so a position comes back a little rounded.
func _as_stored(spot: Vector2) -> Vector2:
	var stored := PackedFloat32Array([spot.x, spot.y])
	return Vector2(stored[0], stored[1])
