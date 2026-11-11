class_name EffectTable
extends RefCounted
## The table the effect shader reads: one line of numbers per effect number.
##
## A sprite with an effect carries the number of its line as its extra number
## (see [method BatchRows.set_thing_extra]). Line 0 means "no effect" and is
## never given out. A line is [constant TEXELS] pixels of a small texture,
## four numbers each, all 32-bit. The table grows by itself.

## How many pixels of the texture one line takes.
const TEXELS := 8
## How many numbers one line holds.
const NUMBERS := TEXELS * 4
## The line that means "no effect".
const NONE := 0
## How many lines the table starts with.
const START_LINES := 64
## The most lines a table can have. A texture cannot be taller.
const MAX_LINES := 16384

var _data := PackedFloat32Array()
var _lines := 0
var _next := 1
var _free := PackedInt32Array()
var _in_use := 0
var _texture: ImageTexture
var _dirty := true


func _init() -> void:
	_grow(START_LINES)


## Hands out a free line, or [constant NONE] when the table is full.
func take() -> int:
	var line := NONE
	if not _free.is_empty():
		line = _free[_free.size() - 1]
		_free.remove_at(_free.size() - 1)
	else:
		if _next >= _lines:
			if _lines >= MAX_LINES:
				return NONE
			_grow(mini(_lines * 2, MAX_LINES))
		line = _next
		_next += 1
	_in_use += 1
	return line


## Takes [param line] back, so it can be handed out again. Its numbers are
## set to 0.
func give_back(line: int) -> void:
	if line <= NONE or line >= _next:
		return
	for index in NUMBERS:
		_data[line * NUMBERS + index] = 0.0
	_free.append(line)
	_in_use -= 1
	_dirty = true


## Writes the four numbers of pixel [param texel] of [param line].
func write(line: int, texel: int, x: float, y: float, z: float, w: float) -> void:
	var at := line * NUMBERS + texel * 4
	_data[at] = x
	_data[at + 1] = y
	_data[at + 2] = z
	_data[at + 3] = w
	_dirty = true


## Returns the four numbers of pixel [param texel] of [param line].
func read(line: int, texel: int) -> Vector4:
	var at := line * NUMBERS + texel * 4
	return Vector4(_data[at], _data[at + 1], _data[at + 2], _data[at + 3])


## Returns how many lines are handed out.
func lines_in_use() -> int:
	return _in_use


## Returns how many lines the table has room for right now.
func line_count() -> int:
	return _lines


## Returns true when the numbers changed since [method texture] was last asked for.
func is_dirty() -> bool:
	return _dirty


## Returns the table as a texture for the shader. It is only built again
## when a number changed.
func texture() -> ImageTexture:
	if _dirty or _texture == null:
		var image := Image.create_from_data(
			TEXELS, _lines, false, Image.FORMAT_RGBAF, _data.to_byte_array()
		)
		if _texture == null or _texture.get_height() != _lines:
			_texture = ImageTexture.create_from_image(image)
		else:
			_texture.update(image)
		_dirty = false
	return _texture


func _grow(lines: int) -> void:
	_lines = lines
	_data.resize(lines * NUMBERS)
	_dirty = true
