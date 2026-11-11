class_name EffectState
extends RefCounted
## What [SpriteEffects] knows about one sprite that has an effect.
##
## There are two kinds of value. A [b]lasting[/b] one stays until it is
## switched off: hovered, selected, drawn as a ghost. A [b]timed[/b] one runs
## for a moment and ends by itself. The timed effects run in named slots, so
## a new flash takes the place of the old flash and plays next to a squash.

## The named slots of the timed effects.
const FLASH := 0
const SHAKE := 1
const SQUASH := 2
const WOBBLE := 3
const POP := 4
## How many named slots there are.
const SLOTS := 5
## The start of a slot that is not running.
const OFF := -1.0

## The line of the effect table this sprite reads, or [constant EffectTable.NONE].
var line: int = EffectTable.NONE
## True when other sprites with the same lasting values read the same line.
var shared: bool = false

## The mouse is over it.
var hovered: bool = false
## It is selected or marked.
var selected: bool = false
## The colour its selected outline is tinted with.
var select_tint: Color = Color.WHITE
## How solid it is when drawn as a ghost itself. 0 means it is no ghost.
var ghost: float = 0.0
## The sprite that is drawn as a ghost behind it, or -1 for none.
var under_sprite: int = -1
## How solid the ghost behind it is.
var under: float = 0.0
## The colour of both ghosts.
var ghost_tint: Color = Color.WHITE
## From the point it stands on to the middle of its picture, in art pixels.
## Squash, wobble and pop turn and stretch it around the point it stands on.
var offset: Vector2 = Vector2.ZERO

## When each named slot started, in game seconds, or [constant OFF].
var starts := PackedFloat64Array([OFF, OFF, OFF, OFF, OFF])
## When each named slot ends, in game seconds.
var ends := PackedFloat64Array([OFF, OFF, OFF, OFF, OFF])
var flash_colour: Color = Color.WHITE
var flash_hold: float = 0.0
var flash_fade: float = 0.0
var shake_seconds: float = 0.0
var shake_distance: float = 0.0
var squash_from: Vector2 = Vector2.ONE
var squash_seconds: float = 0.0
var wobble_radians: float = 0.0
var wobble_seconds: float = 0.0
var pop_amount: float = 0.0
var pop_rise: float = 0.0
var pop_fall: float = 0.0
## The size a pop starts from, against full size. It is not 1 when the pop
## took over from a pop that was still running.
var pop_from: float = 1.0
## The tilt a wobble starts from, in radians.
var wobble_from: float = 0.0


## Starts the named slot [param slot] at [param now] for [param seconds].
## What ran in that slot before is gone.
func start(slot: int, now: float, seconds: float) -> void:
	starts[slot] = now
	ends[slot] = now + seconds


## Switches off every named slot that has ended by [param now]. Returns true
## when one was switched off.
func end_finished(now: float) -> bool:
	var ended := false
	for slot in SLOTS:
		if starts[slot] != OFF and ends[slot] <= now:
			starts[slot] = OFF
			ended = true
	return ended


## Returns true while a named slot is running.
func is_timed() -> bool:
	for slot in SLOTS:
		if starts[slot] != OFF:
			return true
	return false


## Returns true while a lasting value is set.
func is_lasting() -> bool:
	return hovered or selected or ghost > 0.0 or under_sprite >= 0


## Returns when the next named slot ends, or INF when none is running.
func next_end() -> float:
	var soonest := INF
	for slot in SLOTS:
		if starts[slot] != OFF:
			soonest = minf(soonest, ends[slot])
	return soonest


## Returns the lasting values as one list. Two sprites with the same list
## look the same while no timed effect runs, so they can share a table line.
func lasting_key() -> Array:
	return [hovered, selected, select_tint, ghost, under_sprite, under, ghost_tint]
