class_name MeepleWander
extends RefCounted
## Where an idle meeple strolls next: the wander rules of the jam game.
##
## It answers with plain values and moves nobody: [VillageMeeples] does the
## walking. Every random number comes from the village that is handed in.
##
## It also keeps the list of hangouts. A hangout is a thing on the grid that
## idle meeples stroll around. In the jam game these were the finished
## buildings. Buildings come with a later part, so whoever finishes a building
## calls [method add_hangout], and [method remove_hangout] when it goes.
## The list keeps the place a hangout had when it was added. A thing that is
## moved has to be removed and added again.
## The numbers are in [MeepleNumbers].

## The hangout of a meeple that has none.
const NO_HANGOUT := 0
## The answer when no spot was found. Check it with [code]is_finite()[/code].
const NO_SPOT := Vector2.INF

var _things := PackedInt32Array()
var _places := PackedVector2Array()
var _slots: Dictionary[int, int] = {}


## Makes [param thing] a hangout. It has to stand on the grid of
## [param village]. Returns false when it does not, or when it is one already.
## Its place is read once, here. After a move of the thing, call
## [method remove_hangout] and then this again, or the meeples keep measuring
## to the old place.
func add_hangout(village: Village, thing: int) -> bool:
	if _slots.has(thing) or village.grid.thing_cells(thing).is_empty():
		return false
	_slots[thing] = _things.size()
	_things.append(thing)
	_places.append(village.grid.thing_position(thing))
	return true


## Takes [param thing] off the list of hangouts. A meeple that hung around it
## picks another one on its next stroll. Returns false when it was not one.
func remove_hangout(thing: int) -> bool:
	if not _slots.has(thing):
		return false
	var slot := _slots[thing]
	var last := _things.size() - 1
	_things[slot] = _things[last]
	_places[slot] = _places[last]
	_slots[_things[slot]] = slot
	_things.resize(last)
	_places.resize(last)
	_slots.erase(thing)
	return true


## True when [param thing] is a hangout.
func has_hangout(thing: int) -> bool:
	return _slots.has(thing)


## How many hangouts there are.
func hangout_count() -> int:
	return _things.size()


## How many ticks a meeple stands still before its next stroll: a random
## pause of 1.0 to 3.5 seconds.
func pause_ticks(village: Village) -> int:
	var seconds := village.rng.randf_range(MeepleNumbers.PAUSE_MIN, MeepleNumbers.PAUSE_MAX)
	return village.ticks_for(seconds)


## The hangout closest to [param from], or [constant NO_HANGOUT] when there is
## none. A meeple that goes idle takes this one.
func nearest_hangout(from: Vector2) -> int:
	var best := NO_HANGOUT
	var best_distance := INF
	for slot in _things.size():
		var distance := from.distance_squared_to(_places[slot])
		if distance < best_distance:
			best_distance = distance
			best = _things[slot]
	return best


## A hangout picked at random for a meeple at [param from], or
## [constant NO_HANGOUT] when there is none. A near one is much more likely
## than a far one: its weight is 1 / (1 + (distance / 100 art pixels) squared).
## One at 100 art pixels, about 14 cells, is half as likely as one right here.
func pick_hangout(village: Village, from: Vector2) -> int:
	if _things.is_empty():
		return NO_HANGOUT
	var weights := PackedFloat32Array()
	var total := 0.0
	for place in _places:
		var reaches := from.distance_to(place) / MeepleNumbers.HOP_REACH
		var weight := 1.0 / (1.0 + reaches * reaches)
		weights.append(weight)
		total += weight
	var roll := village.rng.randf() * total
	for slot in _things.size():
		roll -= weights[slot]
		if roll <= 0.0:
			return _things[slot]
	return _things[_things.size() - 1]


## The hangout a meeple at [param from] strolls around next. It keeps
## [param current], except that it picks again when that one is gone, and with
## a chance of 15 percent on every stroll.
func next_hangout(village: Village, from: Vector2, current: int) -> int:
	if not _slots.has(current) or village.rng.randf() < MeepleNumbers.HOP_CHANCE:
		return pick_hangout(village, from)
	return current


## A spot on an empty cell at most two steps from the hangout [param thing],
## nudged a little so meeples do not line up. Up to 8 cells are tried. The
## first spot that a meeple at [param from] can reach without crossing a
## hangout wins. When none is clear, the closest tried spot wins anyway.
## Answers [constant NO_SPOT] when the hangout has no empty cell near it.
func spot_near(village: Village, from: Vector2, thing: int) -> Vector2:
	var rng := village.rng
	var cells := village.grid.empty_cells_near(thing, MeepleNumbers.WANDER_RING)
	var closest := NO_SPOT
	var closest_distance := INF
	for index in mini(cells.size(), MeepleNumbers.WANDER_TRIES):
		# The cells are shuffled one at a time, with the village's own random numbers.
		var pick := rng.randi_range(index, cells.size() - 1)
		var cell := cells[pick]
		cells[pick] = cells[index]
		var nudge := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		var spot := GridLayout.position_of(cell) + nudge * MeepleNumbers.WANDER_JITTER
		if is_clear(village, from, spot):
			return spot
		var distance := from.distance_squared_to(spot)
		if distance < closest_distance:
			closest_distance = distance
			closest = spot
	return closest


## True when no hangout stands on the straight way from [param from] to
## [param to]. The way is checked at 8 points. Trees and rocks do not count.
func is_clear(village: Village, from: Vector2, to: Vector2) -> bool:
	var grid := village.grid
	for step in range(1, MeepleNumbers.PATH_CHECKS + 1):
		var point := from.lerp(to, float(step) / MeepleNumbers.PATH_CHECKS)
		if _slots.has(grid.occupant(GridLayout.cell_under(point))):
			return false
	return true


## A random spot 15 to 60 jam units from [param home] that is on the grid.
## Up to 8 spots are tried. Answers [constant NO_SPOT] when none is on the grid.
func spot_around(village: Village, home: Vector2) -> Vector2:
	var rng := village.rng
	var radius := MeepleNumbers.WANDER_RADIUS
	for attempt in MeepleNumbers.WANDER_TRIES:
		var turn := Vector2.from_angle(rng.randf() * TAU)
		var spot := home + turn * rng.randf_range(radius * MeepleNumbers.WANDER_NEAREST, radius)
		if village.grid.cell_at(spot) != GridLayout.NO_CELL:
			return spot
	return NO_SPOT


## Where a meeple at [param from] strolls next: near its [param hangout] when
## it has one with an empty cell near it, and around [param home] otherwise.
## Answers [constant NO_SPOT] when the meeple should stay where it is.
func next_spot(village: Village, from: Vector2, home: Vector2, hangout: int) -> Vector2:
	if hangout != NO_HANGOUT:
		var spot := spot_near(village, from, hangout)
		if spot.is_finite():
			return spot
	return spot_around(village, home)


## Forgets every hangout.
func close() -> void:
	_things.clear()
	_places.clear()
	_slots.clear()


## The hangouts as plain data.
func snapshot() -> Dictionary:
	return {"things": _things.duplicate(), "places": _places.duplicate()}
