extends VillagePart
## The demo's stand-in for nature. It is not part of the game.
##
## Every half second it grows a thing on a free spot. Once enough things
## stand, it also clears one every half second and leaves wood on the cell,
## and it picks the oldest wood up again. It sleeps on timers in between, and
## takes its random numbers from the village, so the same seed gives the same
## picture every time.

const GROW_SECONDS := 0.5
const CLEAR_SECONDS := 0.5
const TRIES := 20
const MOST_THINGS := 40
const MOST_DROP_CELLS := 25
const WOOD := 1

## The things that stand on the grid now.
var things: Array[int] = []
## How many drops lie on the ground now.
var drops_left: int = 0

var _cells: Array[Vector2i] = []
var _drop_cells: Array[Vector2i] = []


func _init(cells: Array[Vector2i]) -> void:
	_cells = cells


## Sets the two timers this part sleeps on.
func start(village: Village) -> void:
	village.timers.wake_after(village.ticks_for(GROW_SECONDS), _grow)
	village.timers.wake_after(village.ticks_for(CLEAR_SECONDS), _clear)


## The things, the drop count and the cells that carry drops, as plain data.
func snapshot() -> Dictionary:
	return {
		"things": things.duplicate(),
		"drops_left": drops_left,
		"drop_cells": _drop_cells.duplicate(),
	}


func _grow(village: Village) -> void:
	var rng := village.rng
	for i in TRIES:
		var anchor := _cells[rng.randi_range(0, _cells.size() - 1)]
		var thing := village.new_id()
		if village.grid.place(thing, anchor, rng.randi_range(1, 3), rng.randi_range(1, 2)):
			things.append(thing)
			break
	village.timers.wake_after(village.ticks_for(GROW_SECONDS), _grow)


func _clear(village: Village) -> void:
	if things.size() > MOST_THINGS:
		var thing: int = things.pop_at(village.rng.randi_range(0, things.size() - 1))
		var freed := village.grid.remove(thing)
		var count := village.rng.randi_range(1, 3)
		if not freed.is_empty() and village.grid.drops.add(freed[0], WOOD, count):
			drops_left += count
			_drop_cells.append(freed[0])
	if _drop_cells.size() > MOST_DROP_CELLS:
		var oldest: Vector2i = _drop_cells.pop_front()
		drops_left -= village.grid.drops.take(oldest, WOOD, 99)
		_drop_cells.erase(oldest)
	village.timers.wake_after(village.ticks_for(CLEAR_SECONDS), _clear)
