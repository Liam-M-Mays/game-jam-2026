class_name TickTimers
extends RefCounted
## Timers that cost nothing while they wait.
##
## A thing sets a wake-up tick and is then left alone. Each tick looks only at
## the timers that are due on that tick, so 1,000 sleeping timers cost the same
## as none. Every village has its own timers.
##
## A village hands itself to every timer that wakes, so a timer never has to
## hold on to its village. A cancelled timer stays in its list until its tick
## comes, and is skipped then.

## A timer id that names no timer.
const NO_TIMER := 0

## The tick that ran last.
var now: int = 0
## How many timers have been looked at so far. A sleeping timer is never
## looked at, so this only grows on the tick a timer is due.
var steps: int = 0

var _due: Dictionary[int, PackedInt64Array] = {}
var _calls: Dictionary[int, Callable] = {}
var _wake_tick: Dictionary[int, int] = {}
var _next_timer: int = 1
var _closed: bool = false


## Calls [param on_wake] once, on tick [param tick]. A tick that is not in the
## future becomes the next tick. Returns the id of the timer, or
## [constant NO_TIMER] once the timers are closed.
func wake_at(tick: int, on_wake: Callable) -> int:
	if _closed:
		return NO_TIMER
	var wake := maxi(tick, now + 1)
	var timer := _next_timer
	_next_timer += 1
	_calls[timer] = on_wake
	_wake_tick[timer] = wake
	var bucket: PackedInt64Array = _due.get(wake, PackedInt64Array())
	bucket.append(timer)
	_due[wake] = bucket
	return timer


## Calls [param on_wake] once, [param ticks] ticks from now. Returns the id of
## the timer, or [constant NO_TIMER] once the timers are closed.
func wake_after(ticks: int, on_wake: Callable) -> int:
	return wake_at(now + maxi(ticks, 1), on_wake)


## Stops [param timer] before it wakes. Returns false when it is not sleeping.
func cancel(timer: int) -> bool:
	if not _calls.has(timer):
		return false
	_calls.erase(timer)
	_wake_tick.erase(timer)
	return true


## True while [param timer] is still waiting for its tick.
func is_sleeping(timer: int) -> bool:
	return _calls.has(timer)


## How many timers are waiting.
func sleeping() -> int:
	return _calls.size()


## Runs tick [param tick]: wakes every timer that is due, in the order they
## were set. Returns how many woke. When [param handed] is given, every timer
## that wakes gets it as its first argument. A village hands itself over here.
func run(tick: int, handed: Variant = null) -> int:
	var woke := 0
	while now < tick:
		now += 1
		if not _due.has(now):
			continue
		var bucket: PackedInt64Array = _due[now]
		_due.erase(now)
		for timer in bucket:
			steps += 1
			if not _calls.has(timer):
				continue
			var on_wake: Callable = _calls[timer]
			_calls.erase(timer)
			_wake_tick.erase(timer)
			woke += 1
			if not on_wake.is_valid():
				continue
			if handed == null:
				on_wake.call()
			else:
				on_wake.call(handed)
	return woke


## Drops every timer without waking it.
func clear() -> void:
	_due.clear()
	_calls.clear()
	_wake_tick.clear()


## Drops every timer and takes no new one from now on. A closed village
## closes its timers, so nothing can be set on it by mistake.
func close() -> void:
	_closed = true
	clear()


## True once the timers have been closed.
func is_closed() -> bool:
	return _closed


## The timers as plain data: the wake-up tick of every sleeping timer, in
## order. It does not hold what a timer calls.
func snapshot() -> Dictionary:
	var ticks: Array[int] = []
	ticks.assign(_wake_tick.values())
	ticks.sort()
	return {"now": now, "wake_ticks": ticks}
