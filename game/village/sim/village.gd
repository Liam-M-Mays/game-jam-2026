class_name Village
extends RefCounted
## One village: a simulation that ticks.
##
## A village owns its grid, its timers, its random numbers and its parts.
## Nothing about a village lives in a global, so two villages can run side by
## side, and a test can run one with no window.
##
## Commands go in through [method send]. The picture reads the state and
## never changes it. The Game service calls [method tick] on every village of
## the session, shown or not.

## The name of the part that holds the stock. Hung by #63.
const STOCK := &"stock"
## The name of the part that holds the job board. Hung by #65.
const JOBS := &"jobs"
## The name of the part that holds the meeples. Hung by #64.
const MEEPLES := &"meeples"
## The name of the part that holds the buildings. Hung by #67.
const BUILDINGS := &"buildings"

## The seed this village was made from. The same seed and the same commands
## give the same village.
var village_seed: int
## How many ticks make one second at game speed x1.
var ticks_per_second: int
## The number of the tick that ran last. A new village is at 0.
var now: int = 0
## The random numbers of this village. Everything random in a village takes
## its numbers from here, never from a global.
var rng := RandomNumberGenerator.new()
## The cells of this village.
var grid := VillageGrid.new()
## The wake-up ticks of this village. A timer that wakes is called with this
## village as its first argument, so never bind the village into a timer.
var timers := TickTimers.new()

var _parts: Dictionary[StringName, VillagePart] = {}
var _order: Array[VillagePart] = []
var _next_id: int = 1
var _commands_done: int = 0
var _closed: bool = false


## Makes a village from [param start_seed]. Leave [param start_ticks_per_second]
## at 0 to use the tick rate of the dev settings.
func _init(start_seed: int = 0, start_ticks_per_second: int = 0) -> void:
	village_seed = start_seed
	rng.seed = start_seed
	ticks_per_second = start_ticks_per_second
	if ticks_per_second <= 0:
		ticks_per_second = DevSettings.load_settings().ticks_per_second


## Runs one tick: wakes the timers that are due, then steps every part in the
## order the parts were hung. Every timer that wakes is handed this village.
func tick() -> void:
	if _closed:
		return
	now += 1
	timers.run(now, self)
	var index := 0
	while index < _order.size():
		_order[index].tick(self)
		index += 1


## Does [param command] on this village, at once. Returns false when the
## command was refused.
func send(command: VillageCommand) -> bool:
	if _closed or command == null:
		return false
	_commands_done += 1
	return command.apply(self)


## Hangs [param part] on this village under [param part_name]. Returns false
## when the name is taken.
func add_part(part_name: StringName, part: VillagePart) -> bool:
	if _closed or part == null or _parts.has(part_name):
		return false
	_parts[part_name] = part
	_order.append(part)
	part.start(self)
	return true


## The part that hangs under [param part_name], or null.
func part(part_name: StringName) -> VillagePart:
	return _parts.get(part_name)


## A fresh number to name a thing of this village with. It starts at 1 and
## never repeats.
func new_id() -> int:
	var id := _next_id
	_next_id += 1
	return id


## How many ticks [param seconds] of game time are. Never less than 1.
func ticks_for(seconds: float) -> int:
	return maxi(roundi(seconds * ticks_per_second), 1)


## Closes the village: closes its parts, last one first, and closes its
## timers. A closed village does not tick any more, takes no new timer and
## holds on to nothing.
func close() -> void:
	if _closed:
		return
	_closed = true
	for index in range(_order.size() - 1, -1, -1):
		_order[index].close()
	_order.clear()
	_parts.clear()
	timers.close()


## True once the village has been closed.
func is_closed() -> bool:
	return _closed


## The whole village as plain data. Two villages with the same snapshot are
## the same.
func snapshot() -> Dictionary:
	var parts := {}
	for part_name in _parts:
		parts[part_name] = _parts[part_name].snapshot()
	return {
		"seed": village_seed,
		"now": now,
		"next_id": _next_id,
		"commands": _commands_done,
		"rng": rng.state,
		"grid": grid.snapshot(),
		"timers": timers.snapshot(),
		"parts": parts,
	}


## One number that stands for the whole village. Villages that are the same
## give the same number. Two different villages can share a number by chance,
## so compare [method snapshot] to be sure.
func state_hash() -> int:
	return snapshot().hash()
