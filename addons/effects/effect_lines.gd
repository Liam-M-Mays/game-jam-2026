class_name EffectLines
extends RefCounted
## Which sprite reads which line of the effect table.
##
## [SpriteEffects] extends this class and adds the effects themselves. Always
## make a [SpriteEffects], never this class.
##
## A sprite with an effect carries an effect number: its extra number in the
## batch ([method BatchStore.set_thing_extra]). The number is a line of the
## [EffectTable], and the shader works the effect out from that line.
## - A sprite with no effect carries 0.
## - Sprites that only have lasting values, and the same ones, share a line.
##   So a thousand selected trees take one line.
## - A sprite with a timed effect has a line of its own while the effect runs.

## The effect clock starts again after this many seconds of game time, so the
## shader only ever counts with small numbers. No effect may run longer than
## a quarter of it.
const CLOCK_WRAP := 256.0

var _style: EffectStyle
var _rows: BatchRows
var _table := EffectTable.new()
var _now := 0.0
var _states: Dictionary[int, EffectState] = {}
var _timed: Dictionary[int, bool] = {}
var _next_end := INF
var _shared_lines: Dictionary[Array, int] = {}
var _shared_keys: Dictionary[int, Array] = {}
var _shared_counts: Dictionary[int, int] = {}
var _full_warned := false


## Returns the effect clock: seconds of game time since the toolkit was made.
func clock() -> float:
	return _now


## Takes every effect off [param target]. Call it when the sprite leaves the batch.
func forget(target: int) -> void:
	var state: EffectState = _states.get(target)
	if state == null:
		return
	_release(state)
	_set_line(target, EffectTable.NONE)
	_states.erase(target)
	_timed.erase(target)


## Returns true when [param target] has an effect right now.
func has_effect(target: int) -> bool:
	return _states.has(target)


## Returns the line of the effect table that [param target] reads, or
## [constant EffectTable.NONE] when it has no effect.
func line_of(target: int) -> int:
	var state: EffectState = _states.get(target)
	return state.line if state != null else EffectTable.NONE


## Returns how many sprites have an effect right now.
func active_count() -> int:
	return _states.size()


## Returns the table the shader reads. For tests and tools.
func table() -> EffectTable:
	return _table


func _is_mover(target: int) -> bool:
	return target & 1 == 1


func _exists(target: int) -> bool:
	var number := target >> 1
	if _is_mover(target):
		return number >= 0 and number < _rows.mover_count()
	return _rows.has_thing(number)


## The state of a target. With [param make] a missing one is made. Returns
## null for a sprite that is not in the batch.
func _state(target: int, make: bool) -> EffectState:
	var state: EffectState = _states.get(target)
	if state != null or not make or not _exists(target):
		return state
	state = EffectState.new()
	_states[target] = state
	return state


func _set_line(target: int, line: int) -> void:
	if not _is_mover(target):
		_rows.set_thing_extra(target >> 1, float(line))
	elif _exists(target):
		_rows.set_mover_extra(target >> 1, float(line))


## Puts a state on the right table line after it changed: none when nothing
## is left, a line it shares while only lasting values are set, and a line of
## its own while a timed effect runs.
func _refresh(target: int, state: EffectState) -> void:
	var before := state.line
	if not _exists(target) or not (state.is_timed() or state.is_lasting()):
		forget(target)
		return
	if state.is_timed():
		if state.shared or state.line == EffectTable.NONE:
			_release(state)
			state.line = _table.take()
		if state.line != EffectTable.NONE:
			state.offset = _offset_of(target)
			_write(state.line, state, true)
		_timed[target] = true
		_next_end = minf(_next_end, state.next_end())
	else:
		_timed.erase(target)
		_share(state)
	if state.line == EffectTable.NONE and not _full_warned:
		_full_warned = true
		push_warning("SpriteEffects: the effect table is full. Some effects are not shown.")
	if state.line != before:
		_set_line(target, state.line)


func _offset_of(target: int) -> Vector2:
	return _rows.mover_offset() if _is_mover(target) else _rows.thing_offset(target >> 1)


## Moves a state with only lasting values onto the line for those values.
func _share(state: EffectState) -> void:
	var key := state.lasting_key()
	if state.shared and _shared_keys.get(state.line, []) == key:
		return
	_release(state)
	var line: int = _shared_lines.get(key, EffectTable.NONE)
	if line == EffectTable.NONE:
		line = _table.take()
		if line == EffectTable.NONE:
			return
		_shared_lines[key] = line
		_shared_keys[line] = key
		_shared_counts[line] = 0
		_write(line, state, false)
	_shared_counts[line] += 1
	state.line = line
	state.shared = true


## Gives the line of a state back.
func _release(state: EffectState) -> void:
	var line := state.line
	state.line = EffectTable.NONE
	if line == EffectTable.NONE:
		return
	if not state.shared:
		_table.give_back(line)
		return
	state.shared = false
	_shared_counts[line] -= 1
	if _shared_counts[line] <= 0:
		_shared_lines.erase(_shared_keys[line])
		_shared_keys.erase(line)
		_shared_counts.erase(line)
		_table.give_back(line)


## Writes a state into a table line. This is the layout the shader reads in
## effects.gdshaderinc. A start time is written wrapped to the clock.
func _write(line: int, state: EffectState, with_timed: bool) -> void:
	var bits := (1.0 if state.hovered else 0.0) + (2.0 if state.selected else 0.0)
	var tint := state.select_tint
	var ghost_tint := state.ghost_tint
	var offset := state.offset if with_timed else Vector2.ZERO
	_table.write(line, 0, bits, tint.r, tint.g, tint.b)
	_table.write(line, 1, ghost_tint.r, ghost_tint.g, ghost_tint.b, state.ghost)
	_table.write(line, 2, float(state.under_sprite + 1), state.under, offset.x, offset.y)
	var starts := PackedFloat32Array([-1.0, -1.0, -1.0, -1.0, -1.0])
	if with_timed:
		for slot in EffectState.SLOTS:
			if state.starts[slot] != EffectState.OFF:
				starts[slot] = fmod(state.starts[slot], CLOCK_WRAP)
	var flash := state.flash_colour
	_table.write(line, 3, flash.r, flash.g, flash.b, starts[EffectState.FLASH])
	_table.write(
		line, 4, state.flash_fade, state.flash_hold, starts[EffectState.SHAKE], state.shake_seconds
	)
	_table.write(
		line, 5, state.shake_distance, starts[EffectState.SQUASH], state.squash_seconds,
		state.pop_fall
	)
	_table.write(
		line, 6, state.squash_from.x, state.squash_from.y, starts[EffectState.WOBBLE],
		state.wobble_seconds
	)
	_table.write(
		line, 7, state.wobble_radians, starts[EffectState.POP], state.pop_amount, state.pop_rise
	)


## Switches off the timed effects that have run out, and finds the next end.
func _end_finished() -> void:
	_next_end = INF
	for target: int in _timed.keys():
		var state := _states[target]
		if state.end_finished(_now):
			_refresh(target, state)
		if _states.has(target):
			_next_end = minf(_next_end, state.next_end())
