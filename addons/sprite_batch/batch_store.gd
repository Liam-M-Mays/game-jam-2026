class_name BatchStore
extends RefCounted
## What a [BatchRows] keeps: the 16 numbers of every sprite, and where each
## sprite's numbers are.
##
## [BatchRows] extends this class and adds the drawing order: it puts things
## and movers in, moves them, puts together what is on screen and finds the
## thing under a point. Always make a [BatchRows], never this class.
##
## This class holds what looks one sprite up or adds to it:
## - the [b]extra number[/b] of a sprite, next to its colour and its four
##   shader numbers. The effects toolkit keeps its effect number there.
## - where a thing stands: its cells and its offset.
## - [b]decor[/b]: sprites that are only drawn, such as a lit cell or a spark.
##   They are never picked and stand on no cell.

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
## Returned when a decor sprite could not be added.
const NO_DECOR := -1
## A decor layer: under everything, such as a lit cell.
const UNDER := 0
## A decor layer: in front of the things of its own row and behind the next row.
const FRONT := 1
## A decor layer: over everything.
const OVER := 2

const _X := 3
const _Y := 7
const _WIDTH := 0
const _HEIGHT := 5
const _COLOUR := 8
const _DATA := 12
## The place of the extra number. Of the 8 place numbers, the third and the
## seventh move nothing on screen. The third carries the extra number.
const _EXTRA := 2
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

var _next_decor := 0
var _decor_layers: Dictionary[int, int] = {}
var _decor_cells: Dictionary[int, Vector2i] = {}
var _under_block := PackedFloat32Array()
var _under_ids := PackedInt32Array()
var _over_block := PackedFloat32Array()
var _over_ids := PackedInt32Array()
var _front_blocks: Dictionary[int, PackedFloat32Array] = {}
var _front_ids: Dictionary[int, PackedInt32Array] = {}
var _front_counts := PackedInt32Array()

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


## Returns the cell the thing [param id] was added on. Only ask for a thing
## that is in the batch.
func thing_cell(id: int) -> Vector2i:
	return _thing_cells[id]


## Returns every cell the thing [param id] takes: its footprint, or its own
## cell when it was added with none.
func thing_cells(id: int) -> Array[Vector2i]:
	var cells_taken: Array[Vector2i] = []
	if _thing_cells.has(id):
		cells_taken.assign(_thing_footprints.get(id, [_thing_cells[id]]))
	return cells_taken


## Returns the offset of the thing [param id] in art pixels: from its cell to
## the middle of its sprite.
func thing_offset(id: int) -> Vector2:
	if not _thing_cells.has(id):
		return Vector2.ZERO
	var cell: Vector2i = _thing_cells[id]
	var row := _cells.row_of(cell) - _top_row
	var at := _row_ids[row].find(id) * FLOATS
	var block: PackedFloat32Array = _row_blocks[row]
	return (Vector2(block[at + _X], block[at + _Y]) - _cells.position_of(cell)) / _pixel_scale


## Sets the extra number of the thing [param id]. Every sprite has one, next
## to its colour and its four shader numbers. It is 32-bit, so it stays exact
## for whole numbers up to 16 million. The batch itself does not use it: it
## is there for an add-on such as the effects toolkit. A shader reads it with
## [code]batch_extra(MODEL_MATRIX)[/code]. [method change_thing] keeps it.
func set_thing_extra(id: int, value: float) -> void:
	if not _thing_cells.has(id):
		return
	var row := _cells.row_of(_thing_cells[id]) - _top_row
	_row_blocks[row][_row_ids[row].find(id) * FLOATS + _EXTRA] = value
	_touch_row(row)


## Returns the extra number of the thing [param id]. It starts at 0.
func thing_extra(id: int) -> float:
	if not _thing_cells.has(id):
		return 0.0
	var row := _cells.row_of(_thing_cells[id]) - _top_row
	return _row_blocks[row][_row_ids[row].find(id) * FLOATS + _EXTRA]


## Adds a decor sprite: a picture that is only drawn. It is never found by
## [method pick], and it does not stand on its cell for
## [method thing_on_cell]. Returns the number the decor sprite is known by
## from now on, or [constant NO_DECOR] when it could not be added.
## [param layer] says where it is drawn: [constant UNDER] everything,
## [constant FRONT] of the things of its own row, or [constant OVER]
## everything. Inside a layer a newer decor sprite is in front of an older one.
## The place is given like the place of a thing: a cell and an offset in art pixels.
func add_decor(
		cell: Vector2i,
		sprite: int,
		offset: Vector2 = Vector2.ZERO,
		tint: Color = Color.WHITE,
		layer: int = FRONT
) -> int:
	var row := _cells.row_of(cell) - _top_row
	var known := layer == UNDER or layer == FRONT or layer == OVER
	var fits := layer != FRONT or (row >= 0 and row < _row_count)
	if not known or not fits or not _atlas.has_sprite(sprite):
		push_error("BatchRows: decor cannot be added on cell %s" % cell)
		return NO_DECOR
	var id := _next_decor
	_next_decor += 1
	var record := _record(_cells.position_of(cell), sprite, offset, tint)
	_decor_layers[id] = layer
	_decor_cells[id] = cell
	match layer:
		UNDER:
			_under_ids.append(id)
			_under_block.append_array(record)
		OVER:
			_over_ids.append(id)
			_over_block.append_array(record)
		_:
			if not _front_blocks.has(row):
				_front_blocks[row] = PackedFloat32Array()
				_front_ids[row] = PackedInt32Array()
			_front_ids[row].append(id)
			_front_blocks[row].append_array(record)
			_front_counts[row] += 1
			_stretch_front(row, record)
	_serial += 1
	return id


## Gives the decor sprite [param id] another sprite, offset or colour. It
## keeps its cell, its layer and its place in the drawing order.
func change_decor(
		id: int, sprite: int, offset: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE
) -> void:
	if not _decor_layers.has(id) or not _atlas.has_sprite(sprite):
		push_error("BatchRows: decor %d cannot be changed" % id)
		return
	var record := _record(_cells.position_of(_decor_cells[id]), sprite, offset, tint)
	var block := _decor_block(id)
	var at := _decor_ids(id).find(id) * FLOATS
	for index in FLOATS:
		block[at + index] = record[index]
	if _decor_layers[id] == FRONT:
		_stretch_front(_cells.row_of(_decor_cells[id]) - _top_row, record)
	_serial += 1


## Gives the decor sprite [param id] another colour and nothing else.
func tint_decor(id: int, tint: Color) -> void:
	if not _decor_layers.has(id):
		return
	var block := _decor_block(id)
	var at := _decor_ids(id).find(id) * FLOATS + _COLOUR
	block[at] = tint.r
	block[at + 1] = tint.g
	block[at + 2] = tint.b
	block[at + 3] = tint.a
	_serial += 1


## Takes the decor sprite [param id] away.
func remove_decor(id: int) -> void:
	if not _decor_layers.has(id):
		return
	var layer := _decor_layers[id]
	var row := _cells.row_of(_decor_cells[id]) - _top_row
	var ids := _decor_ids(id)
	var block := _decor_block(id)
	var at := ids.find(id)
	ids.remove_at(at)
	var rest := block.slice(0, at * FLOATS) + block.slice((at + 1) * FLOATS)
	match layer:
		UNDER:
			_under_ids = ids
			_under_block = rest
		OVER:
			_over_ids = ids
			_over_block = rest
		_:
			_front_ids[row] = ids
			_front_blocks[row] = rest
			_front_counts[row] -= 1
	_decor_layers.erase(id)
	_decor_cells.erase(id)
	_serial += 1


## Returns true when a decor sprite with this [param id] is in the batch.
func has_decor(id: int) -> bool:
	return _decor_layers.has(id)


## Returns how many decor sprites are in the batch.
func decor_count() -> int:
	return _decor_layers.size()


## Returns true when mover [param index] was placed with
## [method BatchRows.place_mover], so it is drawn and can carry an extra number.
func is_mover_placed(index: int) -> bool:
	return index >= 0 and index < _mover_buckets.size() and _mover_buckets[index] != _UNPLACED


## Sets the extra number of mover [param index]. See [method set_thing_extra].
## [method place_mover] and [method look_mover] keep it. A mover that was not
## placed yet takes none.
func set_mover_extra(index: int, value: float) -> void:
	var bucket := _mover_buckets[index]
	if bucket == _UNPLACED:
		return
	_bucket_blocks[bucket][_mover_slots[index] * FLOATS + _EXTRA] = value
	_serial += 1


## Returns the extra number of mover [param index]. It is 0 for a mover that
## was not placed yet.
func mover_extra(index: int) -> float:
	var bucket := _mover_buckets[index]
	if bucket == _UNPLACED:
		return 0.0
	return _bucket_blocks[bucket][_mover_slots[index] * FLOATS + _EXTRA]


## Returns the offset every mover has, in art pixels: from its position to
## the middle of its box.
func mover_offset() -> Vector2:
	return _mover_offset / _pixel_scale


## The 16 numbers of a plain sprite that stands on [param anchor].
func _record(anchor: Vector2, sprite: int, offset: Vector2, tint: Color) -> PackedFloat32Array:
	var size := Vector2(_atlas.size_of(sprite)) * _pixel_scale
	var middle := anchor + offset * _pixel_scale
	return PackedFloat32Array([
		size.x, 0.0, 0.0, middle.x,
		0.0, size.y, 0.0, middle.y,
		tint.r, tint.g, tint.b, tint.a,
		float(sprite), 0.0, 0.0, PLAIN,
	])


## The block that holds the decor sprite [param id].
func _decor_block(id: int) -> PackedFloat32Array:
	match _decor_layers[id]:
		UNDER:
			return _under_block
		OVER:
			return _over_block
	return _front_blocks[_cells.row_of(_decor_cells[id]) - _top_row]


## The ids of the layer that holds the decor sprite [param id], in drawing order.
func _decor_ids(id: int) -> PackedInt32Array:
	match _decor_layers[id]:
		UNDER:
			return _under_ids
		OVER:
			return _over_ids
	return _front_ids[_cells.row_of(_decor_cells[id]) - _top_row]


## Makes a row reach far enough for a front decor sprite, so the row is sent
## whenever that sprite is on screen.
func _stretch_front(row: int, record: PackedFloat32Array) -> void:
	var line := _top_y + row * _row_height
	var half := record[_HEIGHT] * 0.5
	_stretch_row(row, line - (record[_Y] - half), record[_Y] + half - line)


## Makes a row's reach bigger when a new thing reaches further than the others.
func _stretch_row(row: int, up: float, down: float) -> void:
	_row_up[row] = maxf(_row_up[row], up)
	_row_down[row] = maxf(_row_down[row], down)
	_max_up = maxf(_max_up, up)
	_max_down = maxf(_max_down, down)


func _touch_row(row: int) -> void:
	_row_versions[row] += 1
	_serial += 1
