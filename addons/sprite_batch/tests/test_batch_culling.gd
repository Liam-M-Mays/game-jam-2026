extends GameTest
## Checks that only what is on screen is sent to the batch, on a flat test
## grid of 100,000 cells with a 1920x1080 view.

## 400 by 250 cells is 100,000 cells.
const GRID := Vector2i(400, 250)
const VIEW_SIZE := Vector2(1920.0, 1080.0)
const MOVERS := 5000
const BOX := Vector2(30.0, 60.0)
const BOX_OFFSET := Vector2(0.0, -20.0)
const BOX_SLACK := 10.0

var _rows: BatchRows
var _cells := BatchTestKit.cells()
var _small := 0
var _tall := 0
var _world := Rect2()
var _thing_cells: Array[Vector2i] = []
var _mover_spots := PackedVector2Array()
var _buffer := PackedFloat32Array()


func before_each() -> void:
	var atlas := BatchTestKit.atlas()
	_small = atlas.find(BatchTestKit.SMALL)
	_tall = atlas.find(BatchTestKit.TALL)
	var far_corner := _cells.position_of(GRID - Vector2i.ONE)
	_world = Rect2(Vector2.ZERO, far_corner)
	_rows = BatchRows.new(_cells, atlas, _world, BatchTestKit.ART_SCALE)
	_rows.shape_movers(BOX, BOX_OFFSET, BOX_SLACK)
	# A small thing on every second cell: 50,000 things.
	for row in GRID.y:
		for column in GRID.x:
			if (row + column) % 2 == 0:
				var cell := Vector2i(column, row)
				_rows.add_thing(_thing_cells.size(), cell, _small, BatchTestKit.SMALL_OFFSET)
				_thing_cells.append(cell)
	var rng := RandomNumberGenerator.new()
	rng.seed = 100000
	_rows.resize_movers(MOVERS)
	for index in MOVERS:
		var spot := Vector2(rng.randf_range(0.0, _world.end.x), rng.randf_range(0.0, _world.end.y))
		_mover_spots.append(spot)
		_rows.place_mover(index, spot, Color.WHITE, Vector4(float(_small), float(index), 0.0, 1.0))


func test_no_more_is_sent_than_the_rows_on_screen_and_one_row_each_side() -> void:
	check_eq(GRID.x * GRID.y, 100000)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1080
	for view in _views(rng):
		var sent := _rows.assemble(view, _buffer)
		var first_row := _cells.band_at(view.position.y) - 1
		var last_row := _cells.band_at(view.end.y) + 1
		var allowed := _sprites_in_rows(first_row, last_row)
		check(sent <= allowed, "view %s: %d sent, %d allowed" % [view, sent, allowed])
		check(sent > 0, "view %s: nothing was sent" % view)
		# The things are lower than one row, so none may come from a row further out.
		for sprite in BatchTestKit.read(_buffer):
			var row: int = _cells.cell_at(sprite["middle"]).y
			if sprite["numbers"].w == BatchRows.PLAIN and (row < first_row or row > last_row):
				fail("view %s: a thing of row %d was sent" % [view, row])
		# A tighter limit, which also fails when the sides are not cut off.
		var near := _sprites_near(view)
		check(sent <= near, "view %s: %d sent, only %d are near the screen" % [view, sent, near])
		print(
			"CULL view at %s: %d sprites sent, %d are near the screen, " % [view.position, sent, near],
			"%d sprites in the rows on screen plus one row each side, " % allowed,
			"%d sprites in all" % (_thing_cells.size() + MOVERS)
		)


func test_every_sprite_that_is_sent_is_near_the_screen() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 960
	for view in _views(rng):
		_rows.assemble(view, _buffer)
		var far_things := 0
		var far_movers := 0
		for sprite in BatchTestKit.read(_buffer):
			var box := Rect2(sprite["middle"] - sprite["size"] * 0.5, sprite["size"])
			if sprite["numbers"].w == BatchRows.PLAIN:
				# A thing is only sent when its picture touches the screen.
				if not box.grow(1.0).intersects(view):
					far_things += 1
			elif not box.intersects(_mover_window(view)):
				far_movers += 1
		check_eq(far_things, 0, "view %s: things sent that do not touch the screen" % view)
		check_eq(far_movers, 0, "view %s: movers sent from further than one column" % view)


func test_nothing_that_is_on_screen_is_left_out() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1920
	for view in _views(rng):
		_rows.assemble(view, _buffer)
		var sent_things := {}
		var sent_movers := {}
		for sprite in BatchTestKit.read(_buffer):
			if sprite["numbers"].w == BatchRows.PLAIN:
				sent_things[sprite["middle"]] = true
			else:
				sent_movers[int(sprite["numbers"].y)] = true
		var missing := 0
		for cell in _thing_cells:
			var middle := _cells.position_of(cell) + BatchTestKit.SMALL_OFFSET * 10.0
			if Rect2(middle - Vector2(20.0, 20.0), Vector2(40.0, 40.0)).intersects(view):
				if not sent_things.has(middle):
					missing += 1
		for index in MOVERS:
			var box := Rect2(_mover_spots[index] + BOX_OFFSET - BOX * 0.5, BOX).grow(BOX_SLACK)
			if box.intersects(view) and not sent_movers.has(index):
				missing += 1
		check_eq(missing, 0, "view %s: sprites on screen that were not sent" % view)


func test_a_tall_thing_below_the_screen_is_sent_when_its_top_shows() -> void:
	var view := Rect2(_cells.position_of(Vector2i(100, 100)), VIEW_SIZE)
	var bottom_row := _cells.band_at(view.end.y)
	# Four rows below the bottom edge: the 300 pixel tall sprite still pokes in.
	var near := Vector2i(105, bottom_row + 4)
	# Eight rows below: it does not reach the screen.
	var far := Vector2i(105, bottom_row + 8)
	_rows.add_thing(900001, near, _tall, BatchTestKit.TALL_OFFSET)
	_rows.add_thing(900002, far, _tall, BatchTestKit.TALL_OFFSET)
	_rows.assemble(view, _buffer)
	var tall_rows := {}
	for sprite in BatchTestKit.read(_buffer):
		if sprite["sprite"] == _tall:
			tall_rows[_cells.band_at(sprite["middle"].y + 140.0)] = true
	check(tall_rows.has(near.y), "the tall thing whose top is on screen was not sent")
	check(not tall_rows.has(far.y), "a tall thing that does not reach the screen was sent")


func test_a_row_is_left_out_again_when_its_tall_thing_is_gone() -> void:
	var view := Rect2(_cells.position_of(Vector2i(100, 100)), VIEW_SIZE)
	var row := _cells.band_at(view.end.y) + 4
	check_eq(_sent_from_row(view, row), 0, "sprites sent from a row far below the screen")
	_rows.add_thing(900001, Vector2i(105, row), _tall, BatchTestKit.TALL_OFFSET)
	check(_sent_from_row(view, row) > 0, "the row of the tall thing is sent")
	_rows.remove_thing(900001)
	check_eq(_sent_from_row(view, row), 0, "sprites sent from the row after the tall thing left")


## Counts the things of grid row [param row] that are sent for [param view].
func _sent_from_row(view: Rect2, row: int) -> int:
	_rows.assemble(view, _buffer)
	var count := 0
	for sprite in BatchTestKit.read(_buffer):
		var line: float = sprite["middle"].y + sprite["size"].y * 0.5 - 10.0
		if sprite["numbers"].w == BatchRows.PLAIN and _cells.band_at(line + 0.5) == row:
			count += 1
	return count


## Views in the middle, in the corners, over the edge, and at random places.
## One has its bottom edge just above a row line, and one just below.
func _views(rng: RandomNumberGenerator) -> Array[Rect2]:
	var middle := _world.get_center() - VIEW_SIZE * 0.5
	var views: Array[Rect2] = [
		Rect2(middle, VIEW_SIZE),
		Rect2(Vector2.ZERO, VIEW_SIZE),
		Rect2(_world.end - VIEW_SIZE, VIEW_SIZE),
		Rect2(Vector2(-900.0, -500.0), VIEW_SIZE),
		Rect2(Vector2(middle.x, _cells.row_y(120) - VIEW_SIZE.y - 0.25), VIEW_SIZE),
		Rect2(Vector2(middle.x, _cells.row_y(120) - VIEW_SIZE.y + 0.25), VIEW_SIZE),
	]
	for index in 10:
		var corner := Vector2(
			rng.randf_range(0.0, _world.end.x - VIEW_SIZE.x),
			rng.randf_range(0.0, _world.end.y - VIEW_SIZE.y)
		)
		views.append(Rect2(corner, VIEW_SIZE))
	return views


## The area a mover may be sent from: the screen, one column of movers to
## each side, one thin band above and below, and the slack of its box.
func _mover_window(view: Rect2) -> Rect2:
	var sideways := 960.0 + BOX_SLACK
	var window := view.grow_individual(sideways, BOX_SLACK, sideways, BOX_SLACK)
	return window.grow_individual(0.0, BatchTestKit.ART_SCALE, 0.0, BatchTestKit.ART_SCALE)


## Counts the things whose picture touches [param view], and the movers
## inside the area a mover may be sent from.
func _sprites_near(view: Rect2) -> int:
	var count := 0
	for cell in _thing_cells:
		var middle := _cells.position_of(cell) + BatchTestKit.SMALL_OFFSET * BatchTestKit.ART_SCALE
		if Rect2(middle - Vector2(20.0, 20.0), Vector2(40.0, 40.0)).grow(1.0).intersects(view):
			count += 1
	var window := _mover_window(view)
	for spot in _mover_spots:
		if Rect2(spot + BOX_OFFSET - BOX * 0.5, BOX).intersects(window):
			count += 1
	return count


## Counts the things and movers in the grid rows [param first] to [param last].
func _sprites_in_rows(first: int, last: int) -> int:
	var count := 0
	for cell in _thing_cells:
		if cell.y >= first and cell.y <= last:
			count += 1
	for spot in _mover_spots:
		var band := _cells.band_at(spot.y)
		if band >= first and band <= last:
			count += 1
	return count
