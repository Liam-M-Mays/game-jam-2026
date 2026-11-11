class_name VillageMeeples
extends VillagePart
## The meeples of one village, as rows in arrays.
##
## There is no node and no script per meeple. A meeple is a row number, and
## each array below is one column: the entry at row 7 belongs to the meeple
## in row 7. A meeple is named by its id, because its row changes: when a
## meeple is taken out, the last row moves into its place, so no row is ever
## left empty.
##
## Hang it on a village with
## [code]village.add_part(Village.MEEPLES, VillageMeeples.new())[/code].
##
## Only walking and dying meeples are stepped on a tick. A meeple that stands
## still sleeps on one of the village's wake-up timers and costs nothing.
## A walk takes its last step on one tick and is over on the next one, so the
## picture has a tick to glide the last step in.
##
## The picture reads the arrays and never writes to them. The numbers are the
## jam game's, in [MeepleNumbers].

## A meeple was added in [param row].
signal meeple_added(row: int)
## [param meeple] was taken out of [param row]. When [param moved_from] is
## another row, the meeple that was there is in [param row] now.
signal meeple_removed(meeple: int, row: int, moved_from: int)
## The look of the meeple in [param row] changed: it started or stopped
## walking, its load changed, or it started to die.
signal meeple_changed(row: int)
## [param meeple] started to die at [param spot]. The hurt sound listens here.
signal meeple_died(meeple: int, spot: Vector2)
## [param meeple] reached the place a job sent it to with [method walk_to].
signal meeple_arrived(meeple: int)
## The village was closed. There are no meeples any more.
signal closed

## The id that names no meeple.
const NO_MEEPLE := 0
## The row of a meeple that is not here.
const NO_ROW := -1
## State: nothing to do. The meeple wanders.
const IDLE := 0
## State: a job sent it somewhere with [method walk_to].
const ON_JOB := 1
## State: its job let it go while it walked. It finishes the walk, then wanders.
const FREED := 2
## State: it is tipping over and fading.
const DYING := 3
## The load kind of a meeple that carries nothing.
const NO_LOAD := 0

const _NO_SLOT := -1
## What each column holds in a new row.
const _BLANK := {
	"ids": 0,
	"spots": Vector2.ZERO,
	"before": Vector2.ZERO,
	"states": IDLE,
	"walking": 0,
	"load_kinds": NO_LOAD,
	"load_counts": 0,
	"hues": 0.0,
	"bounces": 0.0,
	"homes": Vector2.ZERO,
	"hangouts": MeepleWander.NO_HANGOUT,
	"topples": 0.0,
	"topples_before": 0.0,
	"fades": 1.0,
	"fades_before": 1.0,
	"targets": Vector2.ZERO,
	"strides": Vector2.ZERO,
	"steps_left": 0,
	"stop_things": 0,
	"timers": TickTimers.NO_TIMER,
	"slots": _NO_SLOT,
	"died_at": 0,
	"sides": 0.0,
}

## The id of each meeple.
var ids := PackedInt32Array()
## Where each meeple is, as of the last tick, in art pixels.
var spots := PackedVector2Array()
## Where each meeple was one tick earlier. The picture glides from here to
## [member spots]. For a meeple that stands still both are the same.
var before := PackedVector2Array()
## What each meeple is doing: [constant IDLE], [constant ON_JOB],
## [constant FREED] or [constant DYING].
var states := PackedByteArray()
## 1 while a meeple shows its walking pose, 0 while it stands. A dying meeple
## keeps the value it had when it died.
var walking := PackedByteArray()
## The kind of thing each meeple carries, as a number. The picture knows
## which head to show for it. [constant NO_LOAD] with empty hands.
var load_kinds := PackedInt32Array()
## How many pieces each meeple carries.
var load_counts := PackedByteArray()
## The shirt colour of each meeple, as a hue from 0 to 1.
var hues := PackedFloat32Array()
## Where each meeple's bounce starts, from 0 to 1 of one full bounce. Every
## meeple has its own, so a crowd does not move as one.
var bounces := PackedFloat32Array()
## The spot where each meeple went idle. It wanders around it.
var homes := PackedVector2Array()
## The hangout each meeple strolls around, or [constant MeepleWander.NO_HANGOUT].
var hangouts := PackedInt32Array()
## How far each dying meeple has tipped over, in radians. Above zero is to
## the right. The meeple shader reads it.
var topples := PackedFloat32Array()
## [member topples] one tick earlier, for the glide.
var topples_before := PackedFloat32Array()
## How solid each meeple is: 1, and down to 0 while a dying one fades. The
## meeple shader reads it.
var fades := PackedFloat32Array()
## [member fades] one tick earlier, for the glide.
var fades_before := PackedFloat32Array()
## The rows of the meeples that walk. Only these and [member dying] are
## stepped on a tick.
var walkers := PackedInt32Array()
## The rows of the meeples that are dying.
var dying := PackedInt32Array()
## How many meeple steps have been run so far. A meeple that stands still is
## never stepped, so this only grows by the walking and the dying ones.
var steps: int = 0
## The wander rules and the list of hangouts.
var wander := MeepleWander.new()

var _targets := PackedVector2Array()
var _strides := PackedVector2Array()
var _steps_left := PackedInt32Array()
var _stop_things := PackedInt32Array()
var _timers := PackedInt64Array()
var _slots := PackedInt32Array()
var _died_at := PackedInt32Array()
var _sides := PackedFloat32Array()
var _columns: Dictionary[String, Variant] = {}
var _row_of: Dictionary[int, int] = {}
var _arrivals := PackedInt32Array()
var _closed: bool = false


func _init() -> void:
	_columns = {
		"ids": ids,
		"spots": spots,
		"before": before,
		"states": states,
		"walking": walking,
		"load_kinds": load_kinds,
		"load_counts": load_counts,
		"hues": hues,
		"bounces": bounces,
		"homes": homes,
		"hangouts": hangouts,
		"topples": topples,
		"topples_before": topples_before,
		"fades": fades,
		"fades_before": fades_before,
		"targets": _targets,
		"strides": _strides,
		"steps_left": _steps_left,
		"stop_things": _stop_things,
		"timers": _timers,
		"slots": _slots,
		"died_at": _died_at,
		"sides": _sides,
	}


## Steps the meeples that walk and the ones that are dying. Nobody else is
## looked at.
func tick(village: Village) -> void:
	if not walkers.is_empty():
		_step_walkers(village)
	if not dying.is_empty():
		_step_dying(village)


## Lets go of every meeple and every hangout.
func close() -> void:
	if _closed:
		return
	_closed = true
	for column: Variant in _columns.values():
		column.clear()
	walkers.clear()
	dying.clear()
	_arrivals.clear()
	_row_of.clear()
	wander.close()
	closed.emit()


## The meeples as plain data: every column, the two lists and the hangouts.
func snapshot() -> Dictionary:
	var columns := {}
	for column_name in _columns:
		columns[column_name] = _columns[column_name].duplicate()
	return {
		"columns": columns,
		"walkers": walkers.duplicate(),
		"dying": dying.duplicate(),
		"steps": steps,
		"wander": wander.snapshot(),
	}


## How many meeples there are, the dying ones too.
func count() -> int:
	return ids.size()


## True when [param meeple] is in this village.
func has_meeple(meeple: int) -> bool:
	return _row_of.has(meeple)


## The row [param meeple] is in right now, or [constant NO_ROW].
func row_of(meeple: int) -> int:
	return _row_of.get(meeple, NO_ROW)


## How many entries every array, list and lookup holds. Each column has one
## entry per meeple, so with no meeple every number is 0.
func sizes() -> Dictionary:
	var found := {}
	for column_name in _columns:
		found[column_name] = _columns[column_name].size()
	found["walkers"] = walkers.size()
	found["dying"] = dying.size()
	found["row_of"] = _row_of.size()
	found["arrivals"] = _arrivals.size()
	return found


## Adds a meeple at [param spot], in art pixels, and returns its id. It gets
## a random shirt colour and bounce start, has nothing to do and starts to
## wander. Returns [constant NO_MEEPLE] once the village is closed.
func spawn(village: Village, spot: Vector2) -> int:
	if _closed or village.is_closed():
		return NO_MEEPLE
	var meeple := village.new_id()
	var row := ids.size()
	for column_name in _columns:
		_columns[column_name].append(_BLANK[column_name])
	ids[row] = meeple
	spots[row] = spot
	before[row] = spot
	hues[row] = village.rng.randf()
	bounces[row] = village.rng.randf()
	_row_of[meeple] = row
	_go_idle(village, row)
	meeple_added.emit(row)
	return meeple


## Kills [param meeple]. It freezes where it is, tips over to a random side,
## bounces once, lies still, fades and is then taken out: about 2 seconds.
## Returns false when it is not here or is dying already.
func kill(village: Village, meeple: int) -> bool:
	var row := row_of(meeple)
	if row == NO_ROW or states[row] == DYING:
		return false
	_cancel_timer(village, row)
	if _slots[row] != _NO_SLOT:
		_leave_list(walkers, row)
	states[row] = DYING
	_steps_left[row] = 0
	_died_at[row] = village.now
	_sides[row] = 1.0 if village.rng.randf() < 0.5 else -1.0
	_slots[row] = dying.size()
	dying.append(row)
	meeple_changed.emit(row)
	meeple_died.emit(meeple, spots[row])
	return true


## Sends [param meeple] to [param point] in a straight line at job speed. It
## aims a little below the point, so it is drawn in front of what is there.
## With a [param stop_thing] it stops as soon as it stands on any cell of
## that thing. [signal meeple_arrived] says when it is there. The meeple then
## waits for its job until [method release] lets it go.
## Returns false when the meeple is not here or is dying.
func walk_to(village: Village, meeple: int, point: Vector2, stop_thing: int = 0) -> bool:
	var row := row_of(meeple)
	if row == NO_ROW or states[row] == DYING:
		return false
	_cancel_timer(village, row)
	states[row] = ON_JOB
	var target := point + MeepleNumbers.AIM_BELOW
	_start_walk(village, row, target, MeepleNumbers.JOB_SPEED, stop_thing)
	return true


## Stops [param meeple] where it is. Its walk is over on the next tick, as if
## it had arrived. Returns false when it is not walking.
func halt(meeple: int) -> bool:
	var row := row_of(meeple)
	if row == NO_ROW or states[row] == DYING or _slots[row] == _NO_SLOT:
		return false
	_targets[row] = spots[row]
	_steps_left[row] = 0
	return true


## Tells [param meeple] that its job has nothing more for it. It finishes
## the walk it is on, remembers where it stopped as its home, and wanders.
## Returns false when it is not on a job.
func release(village: Village, meeple: int) -> bool:
	var row := row_of(meeple)
	if row == NO_ROW or states[row] != ON_JOB:
		return false
	if _slots[row] != _NO_SLOT:
		states[row] = FREED
	else:
		_go_idle(village, row)
	return true


## Sets what [param meeple] carries: [param amount] pieces of [param kind].
## An amount of 0 means empty hands. Returns false when it is not here.
func carry(meeple: int, kind: int, amount: int) -> bool:
	var row := row_of(meeple)
	if row == NO_ROW:
		return false
	var pieces := clampi(amount, 0, 255)
	var load_kind := kind if pieces > 0 else NO_LOAD
	if load_kinds[row] != load_kind or load_counts[row] != pieces:
		load_kinds[row] = load_kind
		load_counts[row] = pieces
		meeple_changed.emit(row)
	return true


## Moves every walking meeple one step. A walk that took its last step on the
## tick before is over now.
func _step_walkers(village: Village) -> void:
	var grid := village.grid
	steps += walkers.size()
	var index := walkers.size() - 1
	while index >= 0:
		var row := walkers[index]
		var spot := spots[row]
		var left := _steps_left[row]
		before[row] = spot
		if left <= 0:
			_leave_list(walkers, row)
			_arrivals.append(ids[row])
		else:
			spot = _targets[row] if left == 1 else spot + _strides[row]
			spots[row] = spot
			_steps_left[row] = left - 1
			var thing := _stop_things[row]
			if thing != 0 and grid.occupant(GridLayout.cell_under(spot)) == thing:
				_targets[row] = spot
				_steps_left[row] = 0
		index -= 1
	_handle_arrivals(village)


## Deals with the walks that ended on this tick, after all the stepping, so
## nothing a listener does can disturb the stepping.
func _handle_arrivals(village: Village) -> void:
	if _arrivals.is_empty():
		return
	var arrived := _arrivals.duplicate()
	_arrivals.clear()
	for meeple in arrived:
		var row := row_of(meeple)
		if row == NO_ROW or _slots[row] != _NO_SLOT:
			continue
		if walking[row] == 1:
			walking[row] = 0
			meeple_changed.emit(row)
		if states[row] == ON_JOB:
			meeple_arrived.emit(meeple)
		elif states[row] == FREED:
			_go_idle(village, row)
		else:
			_sleep(village, row)


## Sets the topple and the fade of every dying meeple for this tick, and
## takes out the ones that have faded away.
func _step_dying(village: Village) -> void:
	steps += dying.size()
	var index := dying.size() - 1
	while index >= 0:
		var row := dying[index]
		var seconds := float(village.now - _died_at[row]) / village.ticks_per_second
		before[row] = spots[row]
		topples_before[row] = topples[row]
		fades_before[row] = fades[row]
		topples[row] = _sides[row] * MeepleTopple.angle_at(seconds)
		fades[row] = MeepleTopple.fade_at(seconds)
		if MeepleTopple.is_over(seconds):
			_remove_row(row)
		index -= 1


## Starts a straight walk to [param target] at [param speed] art pixels a
## second. A meeple that is there already joins the walkers for one tick, so
## its arrival comes on a tick like every other.
func _start_walk(
	village: Village, row: int, target: Vector2, speed: float, stop_thing: int
) -> void:
	var spot := spots[row]
	var way := target - spot
	var distance := way.length()
	var stride := speed / village.ticks_per_second
	var needed := 0
	var there := stop_thing != 0 and village.grid.occupant(GridLayout.cell_under(spot)) == stop_thing
	if distance > MeepleNumbers.ARRIVE and not there:
		needed = maxi(ceili(distance / stride - 0.0001), 1)
		_strides[row] = way * (stride / distance)
	_targets[row] = target if needed > 0 else spot
	_steps_left[row] = needed
	_stop_things[row] = stop_thing
	if _slots[row] == _NO_SLOT:
		_slots[row] = walkers.size()
		walkers.append(row)
	var shows := 1 if needed > 0 else 0
	if walking[row] != shows:
		walking[row] = shows
		meeple_changed.emit(row)


## The meeple has nothing to do: where it stands is its home, the nearest
## hangout is its hangout, and it pauses before its first stroll.
func _go_idle(village: Village, row: int) -> void:
	states[row] = IDLE
	homes[row] = spots[row]
	hangouts[row] = wander.nearest_hangout(spots[row])
	_sleep(village, row)


## Puts the meeple to sleep for one pause. It costs nothing until it wakes.
func _sleep(village: Village, row: int) -> void:
	var ticks := wander.pause_ticks(village)
	_timers[row] = village.timers.wake_after(ticks, _wake.bind(ids[row]))


## The pause of an idle meeple is over: it strolls to its next spot, or
## pauses again when there is none.
func _wake(village: Village, meeple: int) -> void:
	var row := row_of(meeple)
	if row == NO_ROW or states[row] != IDLE:
		return
	_timers[row] = TickTimers.NO_TIMER
	var spot := spots[row]
	var hangout := wander.next_hangout(village, spot, hangouts[row])
	hangouts[row] = hangout
	var target := wander.next_spot(village, spot, homes[row], hangout)
	if target.is_finite():
		_start_walk(village, row, target, MeepleNumbers.WANDER_SPEED, 0)
	else:
		_sleep(village, row)


func _cancel_timer(village: Village, row: int) -> void:
	if _timers[row] != TickTimers.NO_TIMER:
		village.timers.cancel(_timers[row])
		_timers[row] = TickTimers.NO_TIMER


## Takes [param row] out of [param list], which is the walkers or the dying.
## The last entry of the list moves into its place.
func _leave_list(list: PackedInt32Array, row: int) -> void:
	var slot := _slots[row]
	var last := list.size() - 1
	var moved := list[last]
	list[slot] = moved
	_slots[moved] = slot
	list.resize(last)
	_slots[row] = _NO_SLOT


## Takes the meeple in [param row] out for good. The last row moves into its
## place, so the rows stay packed.
func _remove_row(row: int) -> void:
	var meeple := ids[row]
	if _slots[row] != _NO_SLOT:
		_leave_list(dying if states[row] == DYING else walkers, row)
	_row_of.erase(meeple)
	var last := ids.size() - 1
	if row != last:
		for column: Variant in _columns.values():
			column[row] = column[last]
		_row_of[ids[row]] = row
		if _slots[row] != _NO_SLOT:
			var list := dying if states[row] == DYING else walkers
			list[_slots[row]] = row
	for column: Variant in _columns.values():
		column.resize(last)
	meeple_removed.emit(meeple, row, last)
