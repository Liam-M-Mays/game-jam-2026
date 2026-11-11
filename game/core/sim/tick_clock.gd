class_name TickClock
extends RefCounted
## Turns real time into whole simulation ticks.
##
## Game speed means more ticks per second. Nothing here touches the engine's
## time scale. Give [method advance] the seconds of each frame, and run as many
## ticks as it answers.

## A frame longer than this many seconds counts as this long, so one slow
## frame cannot ask for a pile of ticks at once.
const MAX_SECONDS_PER_ADVANCE := 0.25
## Rounding slack, in ticks. With it, 60 frames of 1/60 second make one full second.
const SLACK := 0.000001

## Ticks per second at game speed x1.
var ticks_per_second: int
## Game speed. 3.0 means three times the ticks per second.
var speed: float = 1.0
## While true, no time passes.
var paused: bool = false

var _owed: float = 0.0


func _init(start_ticks_per_second: int) -> void:
	ticks_per_second = start_ticks_per_second


## Takes [param seconds] of real time and returns how many ticks to run now.
## The part of a tick that is left over is kept for the next call.
func advance(seconds: float) -> int:
	if paused or seconds <= 0.0:
		return 0
	_owed += minf(seconds, MAX_SECONDS_PER_ADVANCE) * ticks_per_second * maxf(speed, 0.0)
	var whole := floori(_owed + SLACK)
	_owed = maxf(_owed - whole, 0.0)
	return whole


## How far the clock is into the next tick, from 0.0 to 1.0. The picture uses
## it to glide a thing from its last position to its next one.
func fraction() -> float:
	return clampf(_owed, 0.0, 1.0)


## Forgets the left-over part of a tick. A new session starts from here.
func reset() -> void:
	_owed = 0.0
