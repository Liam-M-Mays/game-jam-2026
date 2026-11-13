extends Node

signal changed

const START_STOCK := { "food": 10 }
const BASE_FOOD_CAP := 20
const MAX_GROUND_DROPS := 30
const GROUND_DROP_LIFETIME := 20.0
## How often the drops past MAX_GROUND_DROPS move closer to fading, in seconds.
const SURPLUS_CHECK := 0.5

var _drops := {}
var _all_drops : Array[ResourceDrop] = []
## Drops on the ground that nothing has claimed, per kind.
var _loose := {}
var _surplus_clock := 0.0
## True while some drop has a surplus clock running, so the next check still resets it.
var _counting_surplus := false
var _stored := START_STOCK.duplicate()
var _reserved := {}
## Drops kept in piles, and how many of those hauls have claimed, per kind.
var _piled := {}
var _pile_claims := {}
var _dirty := false

func _ready() -> void:
	process_priority = 100

## Runs after the game's nodes, so `changed` fires once a frame with every change of that frame.
func _process(delta : float) -> void:
	_surplus_clock += delta
	if _surplus_clock >= SURPLUS_CHECK:
		_fade_surplus(_surplus_clock)
		_surplus_clock = 0.0
	if _dirty:
		_dirty = false
		changed.emit()

## Loose drops past MAX_GROUND_DROPS that nothing needs fade out after GROUND_DROP_LIFETIME, oldest first.
## It walks the drops only while there are too many, and once more after, to reset their clocks.
func _fade_surplus(elapsed : float) -> void:
	var surplus : int = _loose.values().reduce(func(sum : int, n : int) -> int: return sum + n, 0) - MAX_GROUND_DROPS
	if surplus <= 0 and not _counting_surplus:
		return
	_counting_surplus = surplus > 0
	var spare := {}
	for kind in _drops:
		spare[kind] = available(kind)
	for drop in _all_drops:
		if surplus > 0 and _is_loose(drop) and spare[drop.kind] > 0:
			surplus -= 1
			spare[drop.kind] -= 1
			drop.surplus_time += elapsed
			if drop.surplus_time >= GROUND_DROP_LIFETIME:
				drop.expire()
		else:
			drop.surplus_time = 0.0

## Asks for `changed` at the end of this frame. However often it is called, `changed` fires once.
func mark_changed() -> void:
	_dirty = true

func reset() -> void:
	_stored = START_STOCK.duplicate()
	_reserved.clear()
	_piled.clear()
	_pile_claims.clear()
	mark_changed()

func count(kind : String) -> int:
	return _drops_of(kind).size() + _piled.get(kind, 0) + _stored.get(kind, 0)

func food_cap() -> int:
	var cap := BASE_FOOD_CAP
	for silo in get_tree().get_nodes_in_group(Silo.GROUP):
		cap += silo.food_capacity
	return cap

func food_full() -> bool:
	return count("food") >= food_cap()

func add(kind : String, amount : int) -> void:
	var total : int = _stored.get(kind, 0) + amount
	_stored[kind] = mini(total, food_cap()) if kind == "food" else total
	mark_changed()

func spend(kind : String, amount : int) -> void:
	if amount <= 0:
		return
	var have : int = _stored.get(kind, 0)
	_stored[kind] = maxi(have - amount, 0)
	mark_changed()

func register(drop : ResourceDrop) -> void:
	_drops_of(drop.kind).append(drop)
	_all_drops.append(drop)
	_count_loose(drop, 1)
	mark_changed()

func unregister(drop : ResourceDrop) -> void:
	# Already gone: consumed before, or forgotten when the grid left.
	if not drop.is_in_world():
		return
	_drops_of(drop.kind).erase(drop)
	_all_drops.erase(drop)
	_count_loose(drop, -1)
	mark_changed()

## Forgets every drop and frees what they draw. The grid calls this when it leaves the game.
func clear_drops() -> void:
	for drop in _all_drops:
		drop.free_item()
	_all_drops.clear()
	_drops.clear()
	_loose.clear()
	mark_changed()

## A pile tells this when its stock or its claims change.
func pile_changed(kind : String, stock : int, claims : int) -> void:
	_piled[kind] = _piled.get(kind, 0) + stock
	_pile_claims[kind] = _pile_claims.get(kind, 0) + claims
	mark_changed()

## Every drop in the world: on the ground, or carried. Drops in piles are counts.
func all_drops() -> Array[ResourceDrop]:
	return _all_drops

func available(kind : String) -> int:
	var in_piles : int = _piled.get(kind, 0) - _pile_claims.get(kind, 0)
	return _loose.get(kind, 0) + in_piles - _reserved.get(kind, 0)

func reserve(kind : String, amount : int) -> void:
	_reserved[kind] = _reserved.get(kind, 0) + amount

## Claims the closest drop of `kind` for a haul that reserved one.
## Returns the loose drop, or the pile when the closest is in a pile.
func claim_closest(kind : String, world_pos : Vector2) -> Object:
	var closest : Object = null
	var nearest := INF
	for drop : ResourceDrop in _drops_of(kind):
		if drop.claimed:
			continue
		var distance := world_pos.distance_squared_to(drop.global_position)
		if distance < nearest:
			nearest = distance
			closest = drop
	for pile : Storage in get_tree().get_nodes_in_group(Storage.GROUP):
		if pile.kind != kind or pile.unclaimed() <= 0:
			continue
		var distance := world_pos.distance_squared_to(pile.global_position)
		if distance < nearest:
			nearest = distance
			closest = pile
	_reserved[kind] -= 1
	if closest is Storage:
		(closest as Storage).claim()
	else:
		_claim(closest as ResourceDrop, true)
	return closest

## The loose drop of `kind` with the shortest walk from `from` to it and on to `to`.
func shortest_trip_loose(kind : String, from : Vector2, to : Vector2) -> ResourceDrop:
	var best : ResourceDrop = null
	var best_trip := INF
	for drop in _drops_of(kind):
		if not _is_loose(drop):
			continue
		var trip : float = from.distance_to(drop.global_position) + drop.global_position.distance_to(to)
		if trip < best_trip:
			best_trip = trip
			best = drop
	return best

func _is_loose(drop : ResourceDrop) -> bool:
	return not drop.claimed

func set_claimed(drop : ResourceDrop, on : bool) -> void:
	_claim(drop, on)
	mark_changed()

func _claim(drop : ResourceDrop, on : bool) -> void:
	var counted := drop.is_in_world()
	if counted:
		_count_loose(drop, -1)
	drop.claimed = on
	if counted:
		_count_loose(drop, 1)

## Adds `sign` to the loose count of `drop`'s kind when nothing has claimed it.
func _count_loose(drop : ResourceDrop, sign : int) -> void:
	if not drop.claimed:
		_loose[drop.kind] = _loose.get(drop.kind, 0) + sign

func _drops_of(kind : String) -> Array:
	return _drops.get_or_add(kind, [])
