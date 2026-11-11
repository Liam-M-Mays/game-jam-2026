extends GameTest
## Checks the movers: they are drawn between two rows, and each is drawn once
## however much it walks.

const WORLD := Rect2(0.0, 0.0, 4000.0, 2000.0)
const BOX := Vector2(30.0, 60.0)
const BOX_OFFSET := Vector2(0.0, -20.0)
## The fourth shader number the test gives its movers. A thing has 0 there.
const MOVER := 1.0

var _rows: BatchRows
var _cells := BatchCells.new()
var _small := 0


func before_each() -> void:
	var atlas := BatchTestKit.atlas()
	_small = atlas.find(BatchTestKit.SMALL)
	_rows = BatchRows.new(_cells, atlas, WORLD, 500.0)
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
	_rows.place_mover(0, Vector2(300.0, _cells.row_y(4)), Color.WHITE, _numbers(0))
	_rows.place_mover(1, Vector2(300.0, _cells.row_y(4) - 0.5), Color.WHITE, _numbers(1))
	check_eq(_drawing_order(), ["thing 3", "mover 1", "thing 4", "mover 0", "thing 5"])


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
		var band := _cells.band_at(spots[index].y)
		if band < last_band:
			wrong += 1
		last_band = band
	check_eq(wrong, 0, "%s: movers drawn twice, in the wrong place or in the wrong band" % when)
	check_eq(seen.size(), spots.size(), "%s: movers drawn" % when)


## The buffer holds small numbers, so a position comes back a little rounded.
func _as_stored(spot: Vector2) -> Vector2:
	var stored := PackedFloat32Array([spot.x, spot.y])
	return Vector2(stored[0], stored[1])
