class_name BatchRows
extends RefCounted
## The sprites of one village, kept in drawing order with no sorting.
##
## A [b]thing[/b] stands still on a cell: a tree, a rock, a building, a drop.
## Things are grouped by grid row. A row is only rebuilt when one of its own
## things is added, changed or removed.
## A [b]mover[/b] walks around: a meeple. Movers are slotted in between two
## rows, into thin bands that are one art pixel tall. A mover is in front of
## every mover in a band above it. Two movers in one band are drawn first by
## column, left to right, and inside a column by the height each had when it
## came into the band. Nothing is sorted afterwards, so two movers closer
## than one art pixel in height can be in the wrong order for a while.
## [method assemble] writes what is on screen into one buffer, back to front,
## and [SpriteBatch] draws that buffer. [method pick] finds the thing under a
## point with maths.
##
## Nothing here needs a window, so all of it can be tested alone.
## The cell maths, the atlas and the art scale are given once and cannot be
## changed later. A village is moved by moving its [SpriteBatch] node.

## How many numbers one sprite takes in the buffer: 8 say where it is and how
## big, 4 are its colour and 4 are for the shader.
## The colour and the four shader numbers reach the graphics card as 16-bit
## numbers on Godot's OpenGL renderer: about 3 digits, and whole numbers are
## only exact up to 2,048. Keep them small. The 8 place numbers are 32-bit.
const FLOATS := 16
## Returned when there is no thing.
const NO_THING := -1
## The fourth shader number of a plain sprite. Other values pick another way
## of drawing in the shader, such as the meeple.
const PLAIN := 0.0

const _X := 3
const _Y := 7
const _WIDTH := 0
const _HEIGHT := 5
const _COLOUR := 8
const _DATA := 12
const _INT32_MAX := 2147483647
## The bucket of a mover that was not placed yet. No real bucket is this big.
const _UNPLACED := _INT32_MAX

## The cell maths: where a cell is and which cell a point is in. Read-only.
var cells: BatchCells:
	get:
		return _cells
	set(_value):
		push_error("BatchRows: the cell maths cannot be changed. Make new rows.")
## The image that holds every sprite. Read-only.
var atlas: SpriteAtlas:
	get:
		return _atlas
	set(_value):
		push_error("BatchRows: the atlas cannot be changed. Make new rows.")
## How many pixels one art pixel takes at zoom 1. Read-only.
var pixel_scale: float:
	get:
		return _pixel_scale
	set(_value):
		push_error("BatchRows: the art scale cannot be changed. Make new rows.")

var _cells: BatchCells
var _atlas: SpriteAtlas
var _pixel_scale := 1.0
var _serial := 0

var _top_row := 0
var _top_y := 0.0
var _row_count := 0
var _row_height := 1.0
var _row_blocks: Array[PackedFloat32Array] = []
var _row_ids: Array[PackedInt32Array] = []
var _row_keys: Array[PackedFloat64Array] = []
var _row_up := PackedFloat64Array()
var _row_down := PackedFloat64Array()
var _row_versions := PackedInt32Array()
var _thing_cells: Dictionary[int, Vector2i] = {}
var _thing_footprints: Dictionary[int, Array] = {}
var _cell_things: Dictionary[Vector2i, int] = {}
var _cell_others: Dictionary[Vector2i, PackedInt32Array] = {}
var _max_up := 0.0
var _max_down := 0.0
var _reach_x := 0.0

var _left := 0.0
var _column_width := 960.0
var _columns := 1
var _mover_size := Vector2(10.0, 10.0)
var _mover_offset := Vector2.ZERO
var _mover_slack := 0.0
var _mover_buckets := PackedInt32Array()
var _mover_slots := PackedInt32Array()
var _bucket_blocks: Array[PackedFloat32Array] = []
var _bucket_movers: Dictionary[int, PackedInt32Array] = {}
var _bucket_made := PackedByteArray()
var _bands_per_row := 1.0
var _band_height := 1.0
var _band_count := 0
var _band_counts := PackedInt32Array()


## [param world] is the area, in pixels, that holds every cell and every mover.
## [param art_scale] is how many pixels one art pixel takes at zoom 1.
## Movers are also grouped in columns of [param column_width] pixels, so that
## only the columns on screen are drawn.
func _init(
		cell_maths: BatchCells,
		sprite_atlas: SpriteAtlas,
		world: Rect2,
		art_scale: float,
		column_width: float = 960.0
) -> void:
	_cells = cell_maths
	_atlas = sprite_atlas
	_pixel_scale = art_scale
	_row_height = _cells.row_height
	_top_row = _cells.band_at(world.position.y) - 1
	_top_y = _cells.row_y(_top_row)
	_row_count = _cells.band_at(world.end.y) + 2 - _top_row
	_column_width = maxf(column_width, 1.0)
	_left = world.position.x - _column_width
	_columns = ceili(world.size.x / _column_width) + 2
	# A mover band is one art pixel tall, or a little less when a row is not
	# a whole number of art pixels.
	_bands_per_row = float(maxi(ceili(_row_height / maxf(art_scale, 0.001) - 0.001), 1))
	_band_height = _row_height / _bands_per_row
	_band_count = _row_count * int(_bands_per_row)
	for row in _row_count:
		_row_blocks.append(PackedFloat32Array())
		_row_ids.append(PackedInt32Array())
		_row_keys.append(PackedFloat64Array())
	_row_up.resize(_row_count)
	_row_down.resize(_row_count)
	_row_versions.resize(_row_count)
	_band_counts.resize(_band_count)
	# A bucket is one band in one column. The table covers the whole world, so
	# a bucket is only made when its first mover comes. Until then every
	# bucket shares one empty block.
	_bucket_blocks.resize(_band_count * _columns)
	_bucket_blocks.fill(PackedFloat32Array())
	_bucket_made.resize(_band_count * _columns)


## Adds a thing that stands still on [param cell], and returns true when it
## went in. [param id] is the caller's own number for the thing. It must fit
## in 32 bits and it cannot be -1, which means "no thing".
## [param offset] is in art pixels, from the cell to the middle of the sprite,
## like the offset of a Sprite2D. [param footprint] lists every cell the thing
## takes. Leave it empty for a thing that takes only its own cell.
## Inside its row the thing is drawn behind everything to its left.
func add_thing(
		id: int,
		cell: Vector2i,
		sprite: int,
		offset: Vector2 = Vector2.ZERO,
		tint: Color = Color.WHITE,
		footprint: Array[Vector2i] = []
) -> bool:
	var row := _cells.row_of(cell) - _top_row
	var fits := id >= -_INT32_MAX and id <= _INT32_MAX and row >= 0 and row < _row_count
	if not fits or id == NO_THING or _thing_cells.has(id) or not _atlas.has_sprite(sprite):
		push_error("BatchRows: thing %d cannot be added on cell %s" % [id, cell])
		return false
	var anchor := _cells.position_of(cell)
	var keys: PackedFloat64Array = _row_keys[row]
	var at := keys.bsearch(-anchor.x, false)
	keys.insert(at, -anchor.x)
	var ids: PackedInt32Array = _row_ids[row]
	ids.insert(at, id)
	var block: PackedFloat32Array = _row_blocks[row]
	var record := _thing_record(anchor, sprite, offset, tint)
	if at * FLOATS == block.size():
		block.append_array(record)
	else:
		_row_blocks[row] = block.slice(0, at * FLOATS) + record + block.slice(at * FLOATS)
	_thing_cells[id] = cell
	if footprint.is_empty():
		_claim_cell(cell, id)
	else:
		_thing_footprints[id] = footprint.duplicate()
		for taken in footprint:
			_claim_cell(taken, id)
	var half := record[_HEIGHT] * 0.5
	_stretch_row(row, anchor.y - (record[_Y] - half), record[_Y] + half - anchor.y)
	_touch_row(row)
	return true


## Gives the thing [param id] another sprite, offset or colour. It stays on its
## cell. Only its own row is rebuilt.
func change_thing(
		id: int, sprite: int, offset: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE
) -> void:
	if not _thing_cells.has(id) or not _atlas.has_sprite(sprite):
		push_error("BatchRows: thing %d cannot be changed" % id)
		return
	var cell: Vector2i = _thing_cells[id]
	var row := _cells.row_of(cell) - _top_row
	var at := _row_ids[row].find(id) * FLOATS
	var record := _thing_record(_cells.position_of(cell), sprite, offset, tint)
	var block: PackedFloat32Array = _row_blocks[row]
	for index in FLOATS:
		block[at + index] = record[index]
	_measure_row(row)
	_touch_row(row)


## Gives the thing [param id] another colour and nothing else.
func tint_thing(id: int, tint: Color) -> void:
	if not _thing_cells.has(id):
		return
	var row := _cells.row_of(_thing_cells[id]) - _top_row
	var at := _row_ids[row].find(id) * FLOATS + _COLOUR
	var block: PackedFloat32Array = _row_blocks[row]
	block[at] = tint.r
	block[at + 1] = tint.g
	block[at + 2] = tint.b
	block[at + 3] = tint.a
	_touch_row(row)


## Takes the thing [param id] away. Only its own row is rebuilt.
func remove_thing(id: int) -> void:
	if not _thing_cells.has(id):
		return
	var cell: Vector2i = _thing_cells[id]
	var row := _cells.row_of(cell) - _top_row
	var at := _row_ids[row].find(id)
	_row_ids[row].remove_at(at)
	_row_keys[row].remove_at(at)
	var block: PackedFloat32Array = _row_blocks[row]
	var line := _top_y + row * _row_height
	var half := block[at * FLOATS + _HEIGHT] * 0.5
	var up := line - (block[at * FLOATS + _Y] - half)
	var down := block[at * FLOATS + _Y] + half - line
	_row_blocks[row] = block.slice(0, at * FLOATS) + block.slice((at + 1) * FLOATS)
	var footprint: Array = _thing_footprints.get(id, [cell])
	for taken: Vector2i in footprint:
		_release_cell(taken, id)
	_thing_cells.erase(id)
	_thing_footprints.erase(id)
	# The row only has to be measured again when its tallest thing left.
	if up >= _row_up[row] or down >= _row_down[row]:
		_measure_row(row)
	_touch_row(row)


## Returns true when a thing with this [param id] is in the batch.
func has_thing(id: int) -> bool:
	return _thing_cells.has(id)


## Returns how many things are in the batch.
func thing_count() -> int:
	return _thing_cells.size()


## Returns the thing that stands on [param cell], or [constant NO_THING].
## When several things share the cell, such as two drops, it is the newest one.
func thing_on_cell(cell: Vector2i) -> int:
	return _cell_things.get(cell, NO_THING)


## Returns the ids of the things in grid row [param row], in drawing order:
## the first is drawn first, so it is behind the others.
func things_in_row(row: int) -> PackedInt32Array:
	var index := row - _top_row
	if index < 0 or index >= _row_count:
		return PackedInt32Array()
	return _row_ids[index].duplicate()


## Returns how many times grid row [param row] was rebuilt. A test uses it to
## prove that a change only touches its own row.
func row_version(row: int) -> int:
	var index := row - _top_row
	return _row_versions[index] if index >= 0 and index < _row_count else 0


## Returns a number that goes up with every change, and with every call of
## [method move_movers]. The batch only sends a new buffer when this number or
## the view has changed.
func serial() -> int:
	return _serial


## Sets the sprite box every mover has, in pixels at zoom 1. [param offset]
## goes from the mover's position to the middle of the box. [param slack] is
## how far the shader may move the picture out of the box, for bounce and tilt.
## Call it before the first mover is placed.
func shape_movers(size: Vector2, offset: Vector2, slack: float = 0.0) -> void:
	_mover_size = size
	_mover_offset = offset
	_mover_slack = slack


## Sets how many movers there are. A new mover is not drawn until
## [method place_mover] is called for it. Movers beyond the new count are dropped.
func resize_movers(count: int) -> void:
	var before := _mover_buckets.size()
	for index in range(count, before):
		_drop_mover(index)
	_mover_buckets.resize(count)
	_mover_slots.resize(count)
	for index in range(before, count):
		_mover_buckets[index] = _UNPLACED
	_serial += 1


## Returns how many movers there are.
func mover_count() -> int:
	return _mover_buckets.size()


## Puts mover [param index] at [param spot] with a colour and the four numbers
## its shader reads. Use it for a new mover, and to move one a long way.
## The mover goes into its band by height: in front of the movers that are
## higher in the band and behind the lower ones.
func place_mover(index: int, spot: Vector2, tint: Color, data: Vector4) -> void:
	_drop_mover(index)
	var record := PackedFloat32Array([
		_mover_size.x, 0.0, 0.0, spot.x + _mover_offset.x,
		0.0, _mover_size.y, 0.0, spot.y + _mover_offset.y,
		tint.r, tint.g, tint.b, tint.a,
		data.x, data.y, data.z, data.w,
	])
	_insert_mover(index, _bucket_at(spot), record)
	_serial += 1


## Moves every mover to its place in [param positions], one entry per mover.
## Call it in every frame in which a mover moved. It marks the batch as
## changed, so the buffer for the screen is put together and sent again.
## A mover that stays in its band costs two writes here.
## A mover outside the world area is kept in the band and column at the edge.
func move_movers(positions: PackedVector2Array) -> void:
	var count := mini(_mover_buckets.size(), positions.size())
	if count == 0:
		return
	var bands := _bands_per_row
	var row_height := _row_height
	var column_width := _column_width
	var columns := _columns
	var bucket_count := _band_count * _columns
	var top := _top_y
	var left := _left
	var right := _left + _columns * _column_width
	var shift_x := _mover_offset.x
	var shift_y := _mover_offset.y
	var buckets := _mover_buckets
	var slots := _mover_slots
	var blocks := _bucket_blocks
	for index in count:
		var spot := positions[index]
		# The same two sums as in _bucket_at, so both always agree.
		var bucket := (
			int((spot.y - top) * bands / row_height) * columns
			+ int((spot.x - left) / column_width)
		)
		if bucket == buckets[index]:
			var block: PackedFloat32Array = blocks[bucket]
			var at := slots[index] * FLOATS
			block[at + _X] = spot.x + shift_x
			block[at + _Y] = spot.y + shift_y
		elif buckets[index] != _UNPLACED:
			if bucket < 0 or bucket >= bucket_count or spot.x < left or spot.x >= right:
				bucket = _bucket_at(spot)
			if bucket != buckets[index]:
				_rebucket(index, bucket, spot)
			else:
				_rewrite_spot(index, spot)
	_serial += 1


## Gives mover [param index] another colour and other shader numbers.
func look_mover(index: int, tint: Color, data: Vector4) -> void:
	var bucket := _mover_buckets[index]
	if bucket == _UNPLACED:
		return
	var block: PackedFloat32Array = _bucket_blocks[bucket]
	var at := _mover_slots[index] * FLOATS + _COLOUR
	block[at] = tint.r
	block[at + 1] = tint.g
	block[at + 2] = tint.b
	block[at + 3] = tint.a
	block[at + 4] = data.x
	block[at + 5] = data.y
	block[at + 6] = data.z
	block[at + 7] = data.w
	_serial += 1


## Changes one of the four shader numbers of mover [param index].
## [param which] is 0 to 3.
func set_mover_number(index: int, which: int, value: float) -> void:
	var bucket := _mover_buckets[index]
	if bucket == _UNPLACED:
		return
	var block: PackedFloat32Array = _bucket_blocks[bucket]
	block[_mover_slots[index] * FLOATS + _DATA + which] = value
	_serial += 1


## Writes every sprite that can be seen in [param view] into [param into],
## back to front, and returns how many sprites that is. Rows and columns that
## are off screen are left out. Nothing is sorted: a row's things come first,
## then the mover bands below that row from top to bottom, then the next row.
func assemble(view: Rect2, into: PackedFloat32Array) -> int:
	into.clear()
	var top := view.position.y
	var bottom := view.end.y
	var height := _row_height
	var band_height := _band_height
	var bands := int(_bands_per_row)
	var mover_up := _mover_size.y * 0.5 - _mover_offset.y + _mover_slack
	var mover_down := _mover_size.y * 0.5 + _mover_offset.y + _mover_slack + band_height
	var mover_side := _mover_size.x * 0.5 + absf(_mover_offset.x) + _mover_slack
	var first := floori((top - maxf(_max_down, mover_down) - _top_y) / height) - 1
	var last := ceili((bottom + maxf(_max_up, mover_up) - _top_y) / height)
	var low_key := -(view.end.x + _reach_x)
	var high_key := -(view.position.x - _reach_x)
	var last_column := _columns - 1
	var from_column := floori((view.position.x - mover_side - _left) / _column_width)
	var to_column := floori((view.end.x + mover_side - _left) / _column_width)
	from_column = clampi(from_column, 0, last_column)
	to_column = clampi(to_column, 0, last_column)
	# A mover outside the world is kept in the band at the edge. So the first
	# band has no top and the last band has no bottom.
	var last_row := _row_count - 1
	var last_band := _band_count - 1
	for row in range(clampi(first, 0, last_row), clampi(last, 0, last_row) + 1):
		var line := _top_y + row * height
		var keys: PackedFloat64Array = _row_keys[row]
		if not keys.is_empty() and line - _row_up[row] < bottom and line + _row_down[row] > top:
			var from := keys.bsearch(low_key, true)
			var to := keys.bsearch(high_key, false)
			if from == 0 and to == keys.size():
				into.append_array(_row_blocks[row])
			elif to > from:
				into.append_array(_row_blocks[row].slice(from * FLOATS, to * FLOATS))
		for band in range(row * bands, row * bands + bands):
			if _band_counts[band] == 0:
				continue
			var band_line := _top_y + band * band_height
			if band != last_band and band_line + mover_down <= top:
				continue
			if band != 0 and band_line - mover_up >= bottom:
				continue
			var base := band * _columns
			for column in range(from_column, to_column + 1):
				var block: PackedFloat32Array = _bucket_blocks[base + column]
				if not block.is_empty():
					into.append_array(block)
	@warning_ignore("integer_division")
	return into.size() / FLOATS


## Returns the thing under [param point], or [constant NO_THING]. Hover and
## click both use this one test.
## The thing whose picture is in front at that point wins, so a tall sprite
## that sticks up over the row behind it is found. Only solid pixels count.
## Where no picture is hit, the thing that stands on the cell under the point wins.
## That second step reads the batch's own list of what was added on which
## cell. It is a stand-in until the village grid answers that question: a
## view can then call [method pick_sprite] and ask the grid itself.
func pick(point: Vector2) -> int:
	var hit := pick_sprite(point)
	return hit if hit != NO_THING else thing_on_cell(_cells.cell_at(point))


## Returns the front-most thing that has a solid pixel at [param point], or
## [constant NO_THING].
func pick_sprite(point: Vector2) -> int:
	var height := _row_height
	var front := mini(floori((point.y + _max_up - _top_y) / height), _row_count - 1)
	var back := maxi(ceili((point.y - _max_down - _top_y) / height), 0)
	for row in range(front, back - 1, -1):
		var keys: PackedFloat64Array = _row_keys[row]
		var line := _top_y + row * height
		if keys.is_empty() or line - _row_up[row] > point.y or line + _row_down[row] < point.y:
			continue
		var block: PackedFloat32Array = _row_blocks[row]
		var from := keys.bsearch(-(point.x + _reach_x), true)
		var to := keys.bsearch(-(point.x - _reach_x), false)
		for index in range(to - 1, from - 1, -1):
			if _is_solid_at(block, index * FLOATS, point):
				return _row_ids[row][index]
	return NO_THING


func _is_solid_at(block: PackedFloat32Array, at: int, point: Vector2) -> bool:
	var across := (point.x - block[at + _X]) / block[at + _WIDTH] + 0.5
	var down := (point.y - block[at + _Y]) / block[at + _HEIGHT] + 0.5
	if across < 0.0 or across >= 1.0 or down < 0.0 or down >= 1.0:
		return false
	var sprite := int(block[at + _DATA])
	var size := _atlas.size_of(sprite)
	return _atlas.is_solid(sprite, Vector2i(int(across * size.x), int(down * size.y)))


func _thing_record(
		anchor: Vector2, sprite: int, offset: Vector2, tint: Color
) -> PackedFloat32Array:
	var size := Vector2(_atlas.size_of(sprite)) * _pixel_scale
	var middle := anchor + offset * _pixel_scale
	_reach_x = maxf(_reach_x, absf(middle.x - anchor.x) + size.x * 0.5)
	return PackedFloat32Array([
		size.x, 0.0, 0.0, middle.x,
		0.0, size.y, 0.0, middle.y,
		tint.r, tint.g, tint.b, tint.a,
		float(sprite), 0.0, 0.0, PLAIN,
	])


## Works out how far the things of one row reach above and below its line.
func _measure_row(row: int) -> void:
	var block: PackedFloat32Array = _row_blocks[row]
	var line := _top_y + row * _row_height
	var up := 0.0
	var down := 0.0
	for at in range(0, block.size(), FLOATS):
		var half := block[at + _HEIGHT] * 0.5
		up = maxf(up, line - (block[at + _Y] - half))
		down = maxf(down, block[at + _Y] + half - line)
	_row_up[row] = up
	_row_down[row] = down
	_max_up = maxf(_max_up, up)
	_max_down = maxf(_max_down, down)


## Makes a row's reach bigger when a new thing reaches further than the others.
func _stretch_row(row: int, up: float, down: float) -> void:
	_row_up[row] = maxf(_row_up[row], up)
	_row_down[row] = maxf(_row_down[row], down)
	_max_up = maxf(_max_up, up)
	_max_down = maxf(_max_down, down)


## Notes that the thing [param id] stands on [param cell]. A thing that was
## there before is kept, and the cell finds it again when the new one leaves.
func _claim_cell(cell: Vector2i, id: int) -> void:
	if _cell_things.has(cell):
		var others: PackedInt32Array = _cell_others.get(cell, PackedInt32Array())
		others.append(_cell_things[cell])
		_cell_others[cell] = others
	_cell_things[cell] = id


func _release_cell(cell: Vector2i, id: int) -> void:
	var others: PackedInt32Array = _cell_others.get(cell, PackedInt32Array())
	if _cell_things.get(cell, NO_THING) != id:
		var at := others.find(id)
		if at >= 0:
			others.remove_at(at)
	elif others.is_empty():
		_cell_things.erase(cell)
	else:
		_cell_things[cell] = others[others.size() - 1]
		others.remove_at(others.size() - 1)
	if others.is_empty():
		_cell_others.erase(cell)
	else:
		_cell_others[cell] = others


func _touch_row(row: int) -> void:
	_row_versions[row] += 1
	_serial += 1


## The bucket of a spot: its band and its column. The two sums are the same
## as in move_movers, so a mover on a row line gets the same band from both.
func _bucket_at(spot: Vector2) -> int:
	var band := int((spot.y - _top_y) * _bands_per_row / _row_height)
	var column := int((spot.x - _left) / _column_width)
	return clampi(band, 0, _band_count - 1) * _columns + clampi(column, 0, _columns - 1)


## Puts a mover into a bucket by height: in front of the movers that are
## higher in the band, behind the lower ones. A mover that walks down into a
## band is the highest one there, so it goes to the back. One that walks up
## into a band goes to the front. This happens once, when the mover comes in.
func _insert_mover(index: int, bucket: int, record: PackedFloat32Array) -> void:
	if _bucket_made[bucket] == 0:
		_bucket_made[bucket] = 1
		_bucket_blocks[bucket] = PackedFloat32Array()
		_bucket_movers[bucket] = PackedInt32Array()
	var movers: PackedInt32Array = _bucket_movers[bucket]
	var block: PackedFloat32Array = _bucket_blocks[bucket]
	var height := record[_Y]
	var count := movers.size()
	var slot := count
	if count > 0 and block[(count - 1) * FLOATS + _Y] > height:
		slot = 0
		while block[slot * FLOATS + _Y] <= height:
			slot += 1
	if slot == count:
		movers.append(index)
		block.append_array(record)
	else:
		movers.insert(slot, index)
		_bucket_blocks[bucket] = block.slice(0, slot * FLOATS) + record + block.slice(slot * FLOATS)
		for behind in range(slot + 1, count + 1):
			_mover_slots[movers[behind]] = behind
	_mover_slots[index] = slot
	_mover_buckets[index] = bucket
	@warning_ignore("integer_division")
	_band_counts[bucket / _columns] += 1


## Takes a mover out of its bucket. The movers behind it move up one place,
## so the drawing order of the others stays as it was.
func _drop_mover(index: int) -> void:
	var bucket := _mover_buckets[index]
	if bucket == _UNPLACED:
		return
	var slot := _mover_slots[index]
	var movers: PackedInt32Array = _bucket_movers[bucket]
	var block: PackedFloat32Array = _bucket_blocks[bucket]
	movers.remove_at(slot)
	if slot == movers.size():
		block.resize(slot * FLOATS)
	else:
		_bucket_blocks[bucket] = block.slice(0, slot * FLOATS) + block.slice((slot + 1) * FLOATS)
		for behind in range(slot, movers.size()):
			_mover_slots[movers[behind]] = behind
	@warning_ignore("integer_division")
	_band_counts[bucket / _columns] -= 1
	_mover_buckets[index] = _UNPLACED


func _rewrite_spot(index: int, spot: Vector2) -> void:
	var block: PackedFloat32Array = _bucket_blocks[_mover_buckets[index]]
	var at := _mover_slots[index] * FLOATS
	block[at + _X] = spot.x + _mover_offset.x
	block[at + _Y] = spot.y + _mover_offset.y


func _rebucket(index: int, bucket: int, spot: Vector2) -> void:
	var at := _mover_slots[index] * FLOATS
	var record := _bucket_blocks[_mover_buckets[index]].slice(at, at + FLOATS)
	record[_X] = spot.x + _mover_offset.x
	record[_Y] = spot.y + _mover_offset.y
	_drop_mover(index)
	_insert_mover(index, bucket, record)
