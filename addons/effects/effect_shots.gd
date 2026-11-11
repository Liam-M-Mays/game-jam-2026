class_name EffectShots
extends RefCounted
## One-shot effect sprites: a few pictures played once, such as a spark or a
## dust cloud.
##
## A one-shot is a decor sprite of the batch ([method BatchStore.add_decor]).
## It plays on game time and takes itself away after its last picture.
## [SpriteEffects] owns one of these as [member SpriteEffects.shots] and
## moves its clock.

## Returned when nothing was played.
const NO_SHOT := -1
## A layer only a one-shot has: it is put in the drawing order by the height
## of its own middle, as a node in a parent that sorts by height would be.
## So it is in front of the things on the last row line at or above its
## middle, and behind the things of the next row. A one-shot whose middle is
## above the line its thing stands on is drawn behind that thing's own row.
const BY_HEIGHT := 3

var _rows: BatchRows
var _now := 0.0
var _shots: Dictionary[int, Dictionary] = {}
var _next_change := INF


## [param batch_rows] is the batch the pictures are drawn in.
func _init(batch_rows: BatchRows) -> void:
	_rows = batch_rows


## Plays the pictures in [param frames] once, one after the other, and takes
## them away again. It plays [param frames_per_second] pictures a second of
## game time. The place is given like the place of a thing: a cell and an
## offset in art pixels. [param layer] is a decor layer: in front of the
## cell's own row, or over everything. Or it is [constant BY_HEIGHT].
## Returns a number for [method stop].
func play(
		frames: PackedInt32Array,
		frames_per_second: float,
		cell: Vector2i,
		offset: Vector2 = Vector2.ZERO,
		layer: int = BatchStore.FRONT
) -> int:
	if frames.is_empty() or frames_per_second <= 0.0:
		return NO_SHOT
	var on := cell
	var by := offset
	var decor_layer := layer
	if layer == BY_HEIGHT:
		decor_layer = BatchStore.FRONT
		on = _cell_by_height(cell, offset)
		var cells := _rows.cells
		by = offset + (cells.position_of(cell) - cells.position_of(on)) / _rows.pixel_scale
	var shot := _rows.add_decor(on, frames[0], by, Color.WHITE, decor_layer)
	if shot == BatchStore.NO_DECOR:
		return NO_SHOT
	_shots[shot] = {
		"frames": frames, "rate": frames_per_second, "start": _now, "offset": by, "shown": 0,
	}
	_next_change = minf(_next_change, _now + 1.0 / frames_per_second)
	return shot


## Plays [param frames] once at the middle of the picture of the thing
## [param id], moved by [param effect_offset] art pixels. It keeps playing
## when the thing is taken away. See [method play].
func play_on(
		id: int,
		frames: PackedInt32Array,
		frames_per_second: float,
		effect_offset: Vector2 = Vector2.ZERO,
		layer: int = BatchStore.FRONT
) -> int:
	if not _rows.has_thing(id):
		return NO_SHOT
	var offset := _rows.thing_offset(id) + effect_offset
	return play(frames, frames_per_second, _rows.thing_cell(id), offset, layer)


## A cell of the row whose line is the last at or above the middle of a
## picture that is drawn [param offset] art pixels from [param cell]. The
## front decor of that row is where a sprite sorted by height belongs.
func _cell_by_height(cell: Vector2i, offset: Vector2) -> Vector2i:
	var cells := _rows.cells
	var middle := cells.position_of(cell) + offset * _rows.pixel_scale
	var row := cells.band_at(middle.y)
	if row == cells.row_of(cell):
		return cell
	var found := cells.cell_at(Vector2(middle.x, cells.row_y(row)) + cells.middle)
	return found if cells.row_of(found) == row else cell


## Takes the one-shot [param shot] away before it has finished.
func stop(shot: int) -> void:
	if _shots.erase(shot):
		_rows.remove_decor(shot)


## Takes every one-shot away.
func stop_all() -> void:
	for shot: int in _shots.keys():
		stop(shot)


## Returns how many one-shots are playing.
func count() -> int:
	return _shots.size()


## Returns the picture the one-shot [param shot] shows right now: 0 is its
## first. Returns -1 when it has finished.
func frame_of(shot: int) -> int:
	return _shots[shot]["shown"] if _shots.has(shot) else -1


## Sets the clock to [param now] seconds of game time. Every one-shot that
## is due shows its next picture, and the finished ones are taken away.
func advance_to(now: float) -> void:
	_now = now
	if now < _next_change:
		return
	_next_change = INF
	for shot: int in _shots.keys():
		var entry := _shots[shot]
		var frames: PackedInt32Array = entry["frames"]
		var rate: float = entry["rate"]
		var start: float = entry["start"]
		var frame := floori((now - start) * rate + 0.000001)
		if frame >= frames.size():
			stop(shot)
			continue
		if frame != entry["shown"]:
			entry["shown"] = frame
			_rows.change_decor(shot, frames[frame], entry["offset"])
		_next_change = minf(_next_change, start + (frame + 1) / rate)
