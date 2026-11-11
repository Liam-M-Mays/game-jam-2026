class_name MeepleView
extends Node
## Draws the meeples of one village through its sprite batch.
##
## It reads the rows of a [VillageMeeples] and never changes them. Each meeple
## is one mover of the batch, with the same number as its row.
##
## The village steps on ticks, and the screen draws more often than that. So
## in every frame a walking meeple is put between the spot it had one tick
## ago and the spot it has now: it glides. A meeple that stands still is not
## touched at all. The topple and the fade of a dying meeple glide the same way.
##
## Use it like this, with a batch that was set up with the meeple shader:
## [codeblock]
## var view := MeepleView.new()
## view.load_names = {1: &"wood", 2: &"stone"}
## view.setup(meeples, batch, look)
## add_child(view)
## [/codeblock]
## It then follows the village by itself. [method let_go] stops it.

## The look name of each load kind, by the number the village uses for the
## kind. [MeepleLook] has a head picture for each name. A kind that is not
## listed shows empty hands. Set it before [method setup].
var load_names: Dictionary[int, StringName] = {}

var _meeples: VillageMeeples
var _batch: SpriteBatch
var _rows: BatchRows
var _look: MeepleLook
## Where each mover is drawn, in the pixels of the batch.
var _shown := PackedVector2Array()
var _scale: float = 1.0
var _origin := Vector2.ZERO
## For each dying meeple, by id: the tilt it had when it died, in x, and how
## far that tilt had moved its feet, in y and z. The fall starts from there.
var _leans: Dictionary[int, Vector3] = {}
var _stale: bool = false
var _frame_usec: int = 0


func _process(_delta: float) -> void:
	show_frame(Game.clock.fraction())


## Starts drawing [param meeples] through [param batch]. The batch must have
## been set up with [constant MeepleLook.SHADER] and dressed by [param look].
func setup(meeples: VillageMeeples, batch: SpriteBatch, look: MeepleLook) -> void:
	let_go()
	_meeples = meeples
	_batch = batch
	_rows = batch.rows
	_look = look
	_scale = _rows.pixel_scale
	_origin = _rows.cells.origin
	meeples.meeple_added.connect(_on_added)
	meeples.meeple_removed.connect(_on_removed)
	meeples.meeple_changed.connect(_on_changed)
	meeples.closed.connect(let_go)
	var count := meeples.count()
	_rows.resize_movers(count)
	_shown.resize(count)
	for row in count:
		_place(row)


## Stops drawing: takes every meeple out of the batch and lets go of the
## village. It runs by itself when the village is closed.
func let_go() -> void:
	if _meeples == null:
		return
	_meeples.meeple_added.disconnect(_on_added)
	_meeples.meeple_removed.disconnect(_on_removed)
	_meeples.meeple_changed.disconnect(_on_changed)
	_meeples.closed.disconnect(let_go)
	_rows.resize_movers(0)
	_shown.clear()
	_leans.clear()
	_meeples = null
	_batch = null
	_rows = null
	_look = null


## Puts every meeple where it is [param fraction] of the way from the last
## tick to the next one, from 0 to 1. It runs by itself every frame, with the
## fraction of the game clock. Only walking and dying meeples are looked at.
func show_frame(fraction: float) -> void:
	if _meeples == null:
		return
	var started := Time.get_ticks_usec()
	var walkers := _meeples.walkers
	var dying := _meeples.dying
	if not (walkers.is_empty() and dying.is_empty() and not _stale):
		var spots := _meeples.spots
		var before := _meeples.before
		var shown := _shown
		var scale := _scale
		var origin := _origin
		for row in walkers:
			shown[row] = origin + before[row].lerp(spots[row], fraction) * scale
		for row in dying:
			_show_dying(row, fraction)
		_rows.move_movers(shown)
		_stale = false
	_frame_usec = Time.get_ticks_usec() - started


## Returns where the meeple in [param row] is drawn, in the pixels of the batch.
func shown_spot(row: int) -> Vector2:
	return _shown[row]


## Returns how long the last [method show_frame] took, in microseconds.
func frame_usec() -> int:
	return _frame_usec


## Turns a spot of the village, in art pixels, into the pixels of the batch.
func _to_batch(spot: Vector2) -> Vector2:
	return _origin + spot * _scale


## Glides one dying meeple: its last step, its topple and its fade.
func _show_dying(row: int, fraction: float) -> void:
	var meeple := _meeples.ids[row]
	var topple := lerpf(_meeples.topples_before[row], _meeples.topples[row], fraction)
	var fade := lerpf(_meeples.fades_before[row], _meeples.fades[row], fraction)
	var spot := _meeples.before[row].lerp(_meeples.spots[row], fraction)
	if _leans.has(meeple):
		# The jam game's fall starts from the tilt the meeple had, and that
		# tilt is used up as it falls. Once it has landed, nothing is left of it.
		var lean := _leans[meeple]
		var fallen := absf(topple) / MeepleTopple.LYING
		if absf(_meeples.topples[row]) < absf(_meeples.topples_before[row]):
			lean.x = 0.0
			_leans[meeple] = lean
		topple += lean.x * maxf(1.0 - fallen, 0.0)
		spot += Vector2(lean.y, lean.z)
	_shown[row] = _to_batch(spot)
	var tint := MeepleLook.shirt_colour(_meeples.hues[row])
	tint.a = fade
	_rows.look_mover(row, tint, _look.dying_numbers(_head_frame(row), topple))


func _head_frame(row: int) -> int:
	var kind: StringName = load_names.get(_meeples.load_kinds[row], &"")
	return MeepleLook.head_frame(kind, _meeples.load_counts[row])


func _tint(row: int) -> Color:
	var tint := MeepleLook.shirt_colour(_meeples.hues[row])
	tint.a = _meeples.fades[row]
	return tint


func _numbers(row: int) -> Vector4:
	var frame := _head_frame(row)
	if _meeples.states[row] == VillageMeeples.DYING:
		return _look.dying_numbers(frame, _meeples.topples[row])
	var phase := _meeples.bounces[row] * MeepleLook.PHASE_RANGE
	return _look.numbers(frame, phase, _meeples.walking[row] == 1)


func _place(row: int) -> void:
	_shown[row] = _to_batch(_meeples.spots[row])
	_rows.place_mover(row, _shown[row], _tint(row), _numbers(row))


func _on_added(row: int) -> void:
	var count := _meeples.count()
	_rows.resize_movers(count)
	_shown.resize(count)
	_place(row)


func _on_removed(meeple: int, row: int, moved_from: int) -> void:
	_leans.erase(meeple)
	if row != moved_from:
		# The last meeple took over this row, so its mover takes over this number.
		_shown[row] = _shown[moved_from]
		_rows.place_mover(row, _shown[row], _tint(row), _numbers(row))
	_shown.resize(moved_from)
	_rows.resize_movers(moved_from)


func _on_changed(row: int) -> void:
	var is_dying := _meeples.states[row] == VillageMeeples.DYING
	if is_dying and not _leans.has(_meeples.ids[row]):
		_note_lean(row)
	elif not is_dying and _meeples.walking[row] == 0:
		# It stopped. The glide ends a little short of the spot, so put it there.
		_shown[row] = _to_batch(_meeples.spots[row])
	_rows.look_mover(row, _tint(row), _numbers(row))
	_stale = true


## Notes the tilt a meeple has at the moment it dies. A walking meeple rocks
## from side to side, and the jam game let it fall from the tilt it had.
func _note_lean(row: int) -> void:
	var lean := 0.0
	if _meeples.walking[row] == 1:
		var phase := _meeples.bounces[row] * MeepleLook.PHASE_RANGE
		lean = deg_to_rad(MeepleLook.pose(_batch.clock, phase, true).y)
	var feet := Vector2(0.0, MeepleLook.FEET_BELOW)
	var shift := feet.rotated(lean) - feet
	_leans[_meeples.ids[row]] = Vector3(lean, shift.x, shift.y)
